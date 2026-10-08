import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/geo_api.dart';
import '../../../../data/services/location_service.dart';
import '../../../../data/services/places_service.dart';
import '../../../../data/services/realtime_client.dart';
import '../../../../data/services/routing_service.dart';
import '../../../../data/services/trip_api.dart';
import '../../../../domain/models/geo_place.dart';
import '../../../../domain/models/fare_policy.dart';
import '../../../../domain/models/ride_offer.dart';
import '../../../../domain/models/session_user.dart';

enum DriverStage { home, locked, arrived, driving }

const _pickupArrivalRadiusM = 60.0;
const _journeyStartSpeedKmh = 5.0;
const _routeDeviationThresholdM = 80.0;
const _routeRefreshCooldown = Duration(seconds: 10);
const _passengerRouteRefreshCooldown = Duration(seconds: 5);

class DriverHomeViewModel extends ChangeNotifier {
  DriverHomeViewModel({
    required LocationService locationService,
    required PlacesService placesService,
    required RoutingService routingService,
    required GeoApi geoApi,
    required TripApi tripApi,
    required RealtimeClient realtime,
    required AuthRepository authRepository,
    required this.user,
    required this.onSessionRefreshed,
  }) : _location = locationService,
       _places = placesService,
       _routing = routingService,
       _geo = geoApi,
       _trips = tripApi,
       _realtime = realtime,
       _auth = authRepository;

  final LocationService _location;
  final PlacesService _places;
  final RoutingService _routing;
  final GeoApi _geo;
  final TripApi _trips;
  final RealtimeClient _realtime;
  final AuthRepository _auth;
  final SessionUser user;
  final void Function(AuthSession session) onSessionRefreshed;

  DriverStage stage = DriverStage.home;
  bool online = false;
  bool onlineBusy = false;
  bool hideEarnings = true;
  bool busy = false;
  String? errorMessage;
  int? counteredAmount;
  DriverStats stats = const DriverStats();
  List<DriverQuest> quests = const [];
  List<RideOffer> offers = const [];
  final Map<String, int> localFares = {};
  ActiveRide? ride;
  String? pendingRatingRideId;
  String pendingRatingPassengerName = '';
  int passengerRating = 0;
  String passengerRatingComment = '';
  bool passengerRatingBusy = false;
  String? passengerRatingError;
  List<LatLng> routePoints = const [];
  List<LatLng> actualTrackPoints = const [];
  int? etaMinutes;
  double? routeDistanceKm;
  double routeDeviationMeters = 0;
  bool routeDeviated = false;
  LatLng? driverPoint;
  LatLng? passengerPoint;
  double passengerSpeedKmh = 0;
  Position? _fix;
  double _speedKmh = 0;

  Timer? _inboxPoll;
  Timer? _pingTimer;
  DateTime? _lastLocationPingAt;
  var _locationPingBusy = false;
  bool _inboxRefreshing = false;
  bool _statusBusy = false;
  bool _routeRefreshing = false;
  DateTime? _lastRouteRefreshAt;
  DateTime? _lastPassengerRouteRefreshAt;
  DateTime? _lastEtaRefreshAt;
  int _routeRequestGeneration = 0;
  StreamSubscription<Position>? _gps;
  StreamSubscription<RealtimeMessage>? _ws;
  StreamSubscription<void>? _realtimeConnected;
  bool _assignmentSyncBusy = false;

  bool get onTrip => stage != DriverStage.home;

  String get etaChip {
    final minutes = etaMinutes;
    if (minutes == null) return 'on_the_way';
    return 'minutes_to_pickup';
  }

  int fareFor(RideOffer offer) =>
      FarePolicy.normalize(localFares[offer.requestId] ?? offer.offeredPrice);

  Future<void> bootstrap() async {
    await _location.ensureLocationPermission();
    _fix =
        await _location.freshPosition() ?? await _location.lastKnownPosition();
    if (_fix != null) {
      driverPoint = LatLng(_fix!.latitude, _fix!.longitude);
    }
    stats = await _trips.stats();
    quests = await _trips.quests();
    final active = await _trips.activeRide();
    if (active != null && active.rideId.isNotEmpty) {
      await _enterRide(active);
    }
    _ws = _realtime.messages.listen(_onRealtime);
    _realtimeConnected = _realtime.connected.listen((_) {
      if (!onTrip) unawaited(_restoreActiveRide());
    });
    unawaited(_realtime.connect());
    unawaited(_realtime.subscribe('driver:${user.id}'));
    _startGpsTracking(background: onTrip);
    final shouldResumeOnline = await _location.driverOnlineIntent();
    if (shouldResumeOnline) {
      await toggleOnline(true);
    }
    notifyListeners();
  }

  void _startGpsTracking({required bool background}) {
    _gps?.cancel();
    _gps = _location.positionStream(background: background).listen((position) {
      final previous = _fix;
      _speedKmh = LocationService.speedKmh(position, previous);
      _fix = position;
      driverPoint = LatLng(position.latitude, position.longitude);
      _recordActualPoint(driverPoint!);
      if (online || onTrip) {
        unawaited(_pingCurrentLocation());
      }
      _maybeRefreshLiveEta(position);
      _maybeRefreshRoute(position);
      _maybeDetectTripProgress(_speedKmh);
      notifyListeners();
    });
  }

  Future<void> toggleOnline(bool value) async {
    if (onlineBusy || value == online) return;
    final previous = online;
    onlineBusy = true;
    online = value;
    errorMessage = null;
    notifyListeners();
    try {
      if (value) {
        final backgroundReady = await _location.ensureLocationPermission(
          background: true,
        );
        if (!backgroundReady) {
          online = previous;
          errorMessage = 'allow_background_location';
          return;
        }
        await _location.requestNotifications();
      }
      // Do not go online using the bootstrap/last-known fix when a fresh GPS
      // reading is available. The first presence coordinate is user-visible.
      final fix = await _location.freshPosition() ?? _fix;
      if (value && fix == null) {
        online = previous;
        errorMessage = 'turn_on_location';
        return;
      }
      var error = await _geo.setOnline(
        online: value,
        lat: fix?.latitude,
        lng: fix?.longitude,
      );

      // If verification required, try refreshing the token — documents may
      // have been approved since the current JWT was issued.
      if (error == 'verification_required' && value) {
        final refreshed = await _auth.refreshSession();
        if (refreshed != null) {
          onSessionRefreshed(refreshed);
          error = await _geo.setOnline(
            online: value,
            lat: fix?.latitude,
            lng: fix?.longitude,
          );
        }
      }

      if (error != null) {
        online = previous;
        switch (error) {
          case 'verification_required':
            errorMessage = 'documents_need_approval';
            break;
          case 'unauthorized':
            errorMessage = 'session_expired';
            break;
          default:
            errorMessage = 'could_not_update_online';
        }
        notifyListeners();
        return;
      }
      online = value;
      errorMessage = null;
      await _location.setDriverOnlineIntent(value);
      _startGpsTracking(background: value || onTrip);
      if (online) {
        _inboxPoll?.cancel();
        _inboxPoll = Timer.periodic(const Duration(seconds: 4), (_) {
          unawaited(refreshInbox());
        });
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          unawaited(_pingCurrentLocation());
        });
        unawaited(refreshInbox());
      } else {
        _inboxPoll?.cancel();
        _pingTimer?.cancel();
        offers = const [];
      }
    } finally {
      onlineBusy = false;
      notifyListeners();
    }
  }

  Future<void> _pingCurrentLocation() async {
    if (!online && !onTrip) return;
    final now = DateTime.now();
    final last = _lastLocationPingAt;
    if (_locationPingBusy ||
        (last != null && now.difference(last) < const Duration(seconds: 4))) {
      return;
    }
    final pos = _fix;
    if (pos == null) return;
    _locationPingBusy = true;
    _lastLocationPingAt = now;
    try {
      await _geo.ping(
        lat: pos.latitude,
        lng: pos.longitude,
        headingDeg: pos.heading.isFinite ? pos.heading : 0,
        speedKmh: _speedKmh,
        rideId: ride?.rideId,
      );
    } finally {
      _locationPingBusy = false;
    }
  }

  void toggleEarningsHidden() {
    hideEarnings = !hideEarnings;
    notifyListeners();
  }

  Future<void> refreshInbox() async {
    if (!online || onTrip || _inboxRefreshing) return;
    _inboxRefreshing = true;
    try {
      final next = await _trips.inbox();
      for (final offer in next) {
        if (offer.fromName.isEmpty) {
          final place = await _places.reverse(
            offer.from.latitude,
            offer.from.longitude,
          );
          offer.fromName = place.name;
        }
        if (offer.toName.isEmpty) {
          final place = await _places.reverse(
            offer.to.latitude,
            offer.to.longitude,
          );
          offer.toName = place.name;
        }
        if (offer.suggestedPrice <= 0) {
          offer.suggestedPrice = _routing.suggestFare(
            GeoPlace(
              name: offer.fromName,
              latitude: offer.from.latitude,
              longitude: offer.from.longitude,
            ),
            GeoPlace(
              name: offer.toName,
              latitude: offer.to.latitude,
              longitude: offer.to.longitude,
            ),
          );
        }
      }
      offers = next;
    } catch (_) {
      if (online && !onTrip) {
        errorMessage = 'keep_trying_offers';
      }
    } finally {
      _inboxRefreshing = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: clear sticky errors and reload stats / offers / active ride.
  Future<void> reload() async {
    errorMessage = null;
    notifyListeners();
    try {
      stats = await _trips.stats();
      quests = await _trips.quests();
      final active = await _trips.activeRide();
      if (active != null && active.rideId.isNotEmpty) {
        await _enterRide(active);
        return;
      }
      if (online) {
        await refreshInbox();
      }
    } catch (_) {
      errorMessage = 'could_not_refresh';
    }
    notifyListeners();
  }

  void adjustFare(RideOffer offer, int delta) {
    final current = fareFor(offer);
    localFares[offer.requestId] = FarePolicy.normalize(current + delta);
    notifyListeners();
  }

  Future<void> skip(RideOffer offer) async {
    await _trips.decline(offer.requestId);
    offers = offers.where((item) => item.requestId != offer.requestId).toList();
    notifyListeners();
  }

  Future<void> accept(RideOffer offer) async {
    if (busy) return;
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final price = fareFor(offer);
      if (price > offer.offeredPrice) {
        await _trips.counter(
          offer.requestId,
          price,
          driverName: user.displayName,
          vehiclePlate: user.vehiclePlate ?? '',
          driverRating: stats.avgRating,
          driverAvatarUrl: user.avatarUrl,
        );
        busy = false;
        errorMessage = 'counter_sent_driver';
        notifyListeners();
        return;
      }
      final locked = await _trips.accept(
        offer.requestId,
        driverName: user.displayName,
        vehiclePlate: user.vehiclePlate ?? '',
        driverRating: stats.avgRating,
        driverAvatarUrl: user.avatarUrl,
      );
      if (locked.rideId.isEmpty) {
        throw StateError('missing ride');
      }
      await _enterRide(
        ActiveRide(
          rideId: locked.rideId,
          requestId: offer.requestId,
          passengerId: offer.passengerId,
          status: locked.status,
          fare: locked.fare == 0 ? offer.offeredPrice : locked.fare,
          from: offer.from,
          to: offer.to,
          paymentMethod: offer.paymentMethod,
          passengerName: offer.displayName,
          passengerPhone: offer.passengerPhone,
          fromName: offer.fromName,
          toName: offer.toName,
        ),
      );
    } catch (_) {
      errorMessage = 'offer_expired';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> startTrip() async {
    final current = ride;
    if (current == null || busy) return;
    busy = true;
    notifyListeners();
    try {
      if (stage == DriverStage.driving) {
        await _setRideStatus('completed');
        _preparePassengerRating(current);
        ride = null;
        stage = DriverStage.home;
        routePoints = const [];
        actualTrackPoints = const [];
        routeDeviationMeters = 0;
        routeDeviated = false;
        routeDistanceKm = null;
        _invalidateRouteRequests();
        if (online) await refreshInbox();
        notifyListeners();
        return;
      }
      await _setRideStatus(
        stage == DriverStage.arrived ? 'in_progress' : 'en_route',
      );
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> cancelTrip() async {
    final current = ride;
    if (current == null) return;
    await _trips.cancelRide(current.rideId);
    ride = null;
    stage = DriverStage.home;
    routePoints = const [];
    actualTrackPoints = const [];
    routeDeviationMeters = 0;
    routeDeviated = false;
    routeDistanceKm = null;
    _invalidateRouteRequests();
    if (online) await refreshInbox();
    notifyListeners();
  }

  Future<void> _enterRide(ActiveRide next) async {
    ride = next;
    passengerPoint = null;
    passengerSpeedKmh = 0;
    actualTrackPoints = const [];
    routeDeviationMeters = 0;
    routeDeviated = false;
    _invalidateRouteRequests();
    _lastRouteRefreshAt = null;
    _lastEtaRefreshAt = null;
    offers = const [];
    stage = next.isDriving ? DriverStage.driving : DriverStage.locked;
    // Show the trip sheet immediately. Route, status, and ETA enrichment can
    // finish asynchronously without making the driver wait or refresh.
    notifyListeners();
    if (next.status == 'matched') {
      try {
        await _trips.updateStatus(next.rideId, 'en_route');
        ride = _withStatus(next, 'en_route');
      } catch (_) {}
    }
    await _realtime.subscribe('ride:${next.rideId}');
    await _refreshRoute(toDropoff: next.isDriving);
    final origin = driverPoint ?? next.from;
    final dest = next.isDriving ? next.to : next.from;
    final quote = await _geo.pickupEta(driver: origin, pickup: dest);
    etaMinutes = quote?.minutes;
    routeDistanceKm = quote?.distanceKm;
    actualTrackPoints = [origin];
  }

  Future<void> _syncAssignedRide(String rideId) async {
    if (_assignmentSyncBusy || rideId.isEmpty) return;
    if (ride?.rideId == rideId) return;
    _assignmentSyncBusy = true;
    try {
      // The realtime event and the ride row are written close together. A
      // short bounded retry handles that write-order race without polling.
      const delays = <Duration>[
        Duration.zero,
        Duration(milliseconds: 150),
        Duration(milliseconds: 500),
      ];
      for (final delay in delays) {
        if (delay > Duration.zero) await Future<void>.delayed(delay);
        final active = await _trips.activeRide();
        if (active?.rideId != rideId) continue;
        try {
          await _enterRide(active!);
        } catch (_) {
          // _enterRide assigns the ride and notifies before route/ETA calls.
          // Keep the sheet visible even if enrichment is temporarily down.
          notifyListeners();
        }
        return;
      }
    } finally {
      _assignmentSyncBusy = false;
    }
  }

  Future<void> _restoreActiveRide() async {
    if (_assignmentSyncBusy || onTrip) return;
    _assignmentSyncBusy = true;
    try {
      final active = await _trips.activeRide();
      if (active == null || active.rideId.isEmpty || onTrip) return;
      await _enterRide(active);
    } catch (_) {
      notifyListeners();
    } finally {
      _assignmentSyncBusy = false;
    }
  }

  void _invalidateRouteRequests() {
    _routeRequestGeneration++;
    _lastRouteRefreshAt = null;
    _lastPassengerRouteRefreshAt = null;
  }

  Future<void> _refreshRoute({required bool toDropoff}) async {
    final current = ride;
    if (current == null) return;
    final requestGeneration = ++_routeRequestGeneration;
    final rideId = current.rideId;
    final start = driverPoint ?? current.from;
    final end = toDropoff ? current.to : (passengerPoint ?? current.from);
    final result = await _routing.route(
      GeoPlace(
        name: 'You',
        latitude: start.latitude,
        longitude: start.longitude,
      ),
      GeoPlace(
        name: toDropoff ? current.toName : current.fromName,
        latitude: end.latitude,
        longitude: end.longitude,
      ),
      steps: true,
      useCache: false,
    );
    // A newer location/status update may have requested another route while
    // this response was in flight. Do not let the stale response replace it.
    if (requestGeneration != _routeRequestGeneration ||
        ride?.rideId != rideId) {
      return;
    }
    routePoints = result.points;
    routeDistanceKm = result.distanceKm;
    routeDeviationMeters = 0;
    routeDeviated = false;
    if (result.durationMin > 0) {
      etaMinutes = result.durationMin;
    }
    notifyListeners();
  }

  void _maybeRefreshRoute(Position position) {
    final current = ride;
    if (current == null || !onTrip || _routeRefreshing) return;
    final point = LatLng(position.latitude, position.longitude);
    if (routePoints.length < 2) return;
    routeDeviationMeters = RoutingService.distanceToPolylineMeters(
      point,
      routePoints,
    );
    final reportedAccuracy = position.accuracy;
    final accuracyBuffer = reportedAccuracy.isFinite && reportedAccuracy > 0
        ? (reportedAccuracy * 1.5).clamp(0.0, 180.0)
        : 0.0;
    final deviationThreshold = math.max(
      _routeDeviationThresholdM,
      accuracyBuffer,
    );
    if (routeDeviationMeters < deviationThreshold) {
      routeDeviated = false;
      return;
    }
    routeDeviated = true;
    final lastRefresh = _lastRouteRefreshAt;
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _routeRefreshCooldown) {
      return;
    }
    _lastRouteRefreshAt = DateTime.now();
    _routeRefreshing = true;
    unawaited(
      _refreshRoute(toDropoff: stage == DriverStage.driving).whenComplete(() {
        _routeRefreshing = false;
      }),
    );
  }

  void _recordActualPoint(LatLng point) {
    if (!onTrip) return;
    final last = actualTrackPoints.isEmpty ? null : actualTrackPoints.last;
    if (last != null && _distanceMeters(last, point) < 5) return;
    final next = [...actualTrackPoints, point];
    actualTrackPoints = List.unmodifiable(
      next.length > 300 ? next.sublist(next.length - 300) : next,
    );
  }

  void _maybeRefreshLiveEta(Position position) {
    final current = ride;
    if (current == null || !onTrip) return;
    final now = DateTime.now();
    final last = _lastEtaRefreshAt;
    if (last != null && now.difference(last) < const Duration(seconds: 4)) {
      return;
    }
    _lastEtaRefreshAt = now;
    unawaited(_refreshLiveEta(position));
  }

  Future<void> _refreshLiveEta(Position position) async {
    final current = ride;
    if (current == null) return;
    final destination = stage == DriverStage.driving
        ? current.to
        : (passengerPoint ?? current.from);
    final quote = await _geo.pickupEta(
      driver: LatLng(position.latitude, position.longitude),
      pickup: destination,
      speedKmh: _speedKmh > 1 ? _speedKmh : null,
      rideId: current.rideId,
    );
    if (quote == null || ride?.rideId != current.rideId) return;
    etaMinutes = quote.minutes;
    routeDistanceKm = quote.distanceKm;
    notifyListeners();
  }

  void _onRealtime(RealtimeMessage message) {
    if (message.event == 'matched') {
      final rideId = '${message.data['rideId'] ?? ''}'.trim();
      if (rideId.isNotEmpty) unawaited(_syncAssignedRide(rideId));
      return;
    }
    if (message.event == 'incoming_request' && online && !onTrip) {
      unawaited(refreshInbox());
    }
    if (message.event == 'passenger_counter' && online && !onTrip) {
      final requestId = '${message.data['requestId'] ?? ''}';
      final price = (message.data['price'] as num?)?.toInt();
      if (requestId.isEmpty || price == null || price <= 0) return;
      for (final offer in offers) {
        if (offer.requestId != requestId) continue;
        offer.offeredPrice = FarePolicy.normalize(price);
        counteredAmount = offer.offeredPrice;
        offer.negotiationRound =
            (message.data['round'] as num?)?.toInt() ??
            offer.negotiationRound + 1;
        offer.maxNegotiationRounds =
            (message.data['maxRounds'] as num?)?.toInt() ??
            offer.maxNegotiationRounds;
        localFares.remove(requestId);
        errorMessage = 'passenger_countered_at';
        notifyListeners();
        return;
      }
      unawaited(refreshInbox());
      return;
    }
    if (message.event == 'status') {
      final status = '${message.data['status'] ?? ''}';
      final current = ride;
      if (current != null && (status == 'arrived' || status == 'in_progress')) {
        ride = _withStatus(current, status);
        stage = status == 'in_progress'
            ? DriverStage.driving
            : DriverStage.arrived;
        if (status == 'in_progress') {
          unawaited(_refreshRoute(toDropoff: true));
        }
        notifyListeners();
      }
      if (status == 'cancelled') {
        ride = null;
        stage = DriverStage.home;
        routePoints = const [];
        actualTrackPoints = const [];
        routeDeviationMeters = 0;
        routeDeviated = false;
        routeDistanceKm = null;
        _invalidateRouteRequests();
        notifyListeners();
      }
      if (status == 'completed') {
        if (current != null) _preparePassengerRating(current);
        ride = null;
        stage = DriverStage.home;
        routePoints = const [];
        actualTrackPoints = const [];
        routeDeviationMeters = 0;
        routeDeviated = false;
        routeDistanceKm = null;
        _invalidateRouteRequests();
        notifyListeners();
      }
    }
    if (message.event == 'location' &&
        '${message.data['role'] ?? ''}'.toLowerCase() == 'passenger') {
      final current = ride;
      if (current == null ||
          '${message.data['rideId'] ?? ''}' != current.rideId) {
        return;
      }
      final coords = message.data['coords'];
      if (coords is! List || coords.length < 2) return;
      final lat = (coords[0] as num?)?.toDouble();
      final lng = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      passengerPoint = LatLng(lat, lng);
      passengerSpeedKmh = (message.data['speedKmh'] as num?)?.toDouble() ?? 0;
      if (stage == DriverStage.locked) {
        final now = DateTime.now();
        final lastRefresh = _lastPassengerRouteRefreshAt;
        if (lastRefresh == null ||
            now.difference(lastRefresh) >= _passengerRouteRefreshCooldown) {
          _lastPassengerRouteRefreshAt = now;
          unawaited(_refreshRoute(toDropoff: false));
        }
      }
      final driverSpeed = _fix?.speed;
      _maybeDetectTripProgress(
        driverSpeed != null && driverSpeed.isFinite ? driverSpeed * 3.6 : 0,
      );
      notifyListeners();
    }
  }

  Future<void> _maybeDetectTripProgress(double speedKmh) async {
    final current = ride;
    final driver = driverPoint;
    final passenger = passengerPoint;
    if (current == null || driver == null || passenger == null || _statusBusy) {
      return;
    }
    final distance = _distanceMeters(driver, passenger);
    if (stage == DriverStage.locked &&
        current.status == 'en_route' &&
        distance <= _pickupArrivalRadiusM) {
      await _setRideStatus('arrived');
      return;
    }
    if (stage == DriverStage.arrived &&
        speedKmh >= _journeyStartSpeedKmh &&
        passengerSpeedKmh >= _journeyStartSpeedKmh) {
      await _setRideStatus('in_progress');
    }
  }

  Future<void> _setRideStatus(String status) async {
    final current = ride;
    if (current == null || _statusBusy) return;
    _statusBusy = true;
    try {
      await _trips.updateStatus(current.rideId, status);
      ride = _withStatus(current, status);
      stage = status == 'in_progress'
          ? DriverStage.driving
          : status == 'arrived'
          ? DriverStage.arrived
          : DriverStage.locked;
      if (status == 'in_progress') {
        await _refreshRoute(toDropoff: true);
      }
      notifyListeners();
    } finally {
      _statusBusy = false;
    }
  }

  void _preparePassengerRating(ActiveRide completedRide) {
    pendingRatingRideId = completedRide.rideId;
    pendingRatingPassengerName = completedRide.passengerName.trim();
    passengerRating = 0;
    passengerRatingComment = '';
    passengerRatingError = null;
  }

  void setPassengerRating(int value) {
    passengerRating = value;
    notifyListeners();
  }

  void setPassengerRatingComment(String value) {
    passengerRatingComment = value;
    notifyListeners();
  }

  Future<void> submitPassengerRating() async {
    final rideId = pendingRatingRideId;
    if (rideId == null || rideId.isEmpty || passengerRating < 1) return;
    passengerRatingBusy = true;
    passengerRatingError = null;
    notifyListeners();
    try {
      await _trips.rateRide(
        rideId,
        rating: passengerRating,
        comment: passengerRatingComment,
      );
      skipPassengerRating();
    } catch (_) {
      passengerRatingBusy = false;
      passengerRatingError = 'could_not_submit_rating';
      notifyListeners();
    }
  }

  void skipPassengerRating() {
    pendingRatingRideId = null;
    pendingRatingPassengerName = '';
    passengerRating = 0;
    passengerRatingComment = '';
    passengerRatingBusy = false;
    passengerRatingError = null;
    notifyListeners();
  }

  ActiveRide _withStatus(ActiveRide current, String status) {
    return ActiveRide(
      rideId: current.rideId,
      requestId: current.requestId,
      passengerId: current.passengerId,
      driverId: current.driverId,
      status: status,
      fare: current.fare,
      from: current.from,
      to: current.to,
      paymentMethod: current.paymentMethod,
      driverName: current.driverName,
      driverVehiclePlate: current.driverVehiclePlate,
      driverRating: current.driverRating,
      passengerName: current.passengerName,
      passengerPhone: current.passengerPhone,
      fromName: current.fromName,
      toName: current.toName,
      driverAvatarUrl: current.driverAvatarUrl,
    );
  }

  @override
  void dispose() {
    _inboxPoll?.cancel();
    _pingTimer?.cancel();
    _gps?.cancel();
    _ws?.cancel();
    _realtimeConnected?.cancel();
    if (online) {
      unawaited(_geo.setOnline(online: false));
    }
    unawaited(_location.setDriverOnlineIntent(false));
    super.dispose();
  }
}

double _distanceMeters(LatLng a, LatLng b) {
  const earthRadiusM = 6371000.0;
  const degreesToRadians = 3.141592653589793 / 180;
  final dLat = (b.latitude - a.latitude) * degreesToRadians;
  final dLng = (b.longitude - a.longitude) * degreesToRadians;
  final lat1 = a.latitude * degreesToRadians;
  final lat2 = b.latitude * degreesToRadians;
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(h));
}
