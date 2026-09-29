import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/services/geo_api.dart';
import '../../../../data/services/location_service.dart';
import '../../../../data/services/places_service.dart';
import '../../../../data/services/pricing_api.dart';
import '../../../../data/services/realtime_client.dart';
import '../../../../data/services/routing_service.dart';
import '../../../../data/services/trip_api.dart';
import '../../../../data/services/support_api.dart';
import '../../../../domain/models/geo_place.dart';
import '../../../../domain/models/fare_estimate.dart';
import '../../../../domain/models/fare_policy.dart';
import '../../../../domain/models/live_driver.dart';
import '../../../../domain/models/ride_bid.dart';
import '../../../../domain/models/ride_stage.dart';

class MatchedDriver {
  const MatchedDriver({
    required this.name,
    required this.plate,
    required this.rating,
    this.avatarUrl,
  });

  final String name;
  final String plate;
  final double rating;
  final String? avatarUrl;
}

class _TrackedDriver {
  _TrackedDriver({
    required this.id,
    required this.target,
    required this.display,
    required this.headingDeg,
    required this.speedKmh,
  });

  final String id;
  LatLng target;
  LatLng display;
  double headingDeg;
  double speedKmh;
}

/// Passenger home map: permissions, places, offer, match, live geo.
class HomeMapViewModel extends ChangeNotifier {
  HomeMapViewModel({
    required LocationService this._locationService,
    required PlacesService this._placesService,
    required RoutingService this._routingService,
    required GeoApi this._geoApi,
    required RealtimeClient this._realtime,
    TripApi? tripApi,
    PricingApi? pricingApi,
    SupportApi? supportApi,
    this.passengerName = '',
  }) : _tripApi = tripApi,
       _pricingApi = pricingApi,
       _supportApi = supportApi;

  final LocationService _locationService;
  final PlacesService _placesService;
  final RoutingService _routingService;
  final GeoApi _geoApi;
  final RealtimeClient _realtime;
  final TripApi? _tripApi;
  final PricingApi? _pricingApi;
  final SupportApi? _supportApi;
  final String passengerName;

  MatchedDriver? matchedDriver;
  String driverPhone = '';
  List<RideBid> counterOffers = const [];
  bool bidBusy = false;
  String? bidError;

  RideStage stage = RideStage.route;
  bool locationPromptNeeded = false;
  bool bootstrapped = false;
  LocationField activeField = LocationField.dropoff;
  GeoPlace? pickup;
  GeoPlace? dropoff;
  GeoPlace? pickCandidate;
  List<GeoPlace> suggestions = const [];
  bool searchingPlaces = false;
  List<LatLng> routePoints = const [];
  List<List<LatLng>> routeAlternatives = const [];
  List<RouteStep> routeSteps = const [];
  List<LiveMapMarker> nearbyDrivers = const [];
  int offeredPrice = 0;
  FareEstimate? fareEstimate;
  bool loadingFareEstimate = false;
  String? fareEstimateError;
  int agreedFare = 0;
  int driversNotified = 0;
  Duration offerTimer = Duration.zero;
  String paymentMethod = 'Cash';
  bool loadingRoute = false;
  bool locating = false;
  int rating = 0;
  String searchQuery = '';
  String recordNumber = '';
  String? liveRequestId;
  String? liveRideId;
  String liveRideStatus = '';
  bool lastOfferMissed = false;
  bool lastOfferHadRiders = false;
  double tripKm = 0;
  int tripDurationMin = 0;
  String routeMethod = '';
  int? etaMinutes;
  String? focusedDriverId;
  String ratingComment = '';
  bool ratingBusy = false;
  String? ratingError;
  bool sharingTrip = false;
  String? shareError;

  Timer? _ticker;
  Timer? _matchTimer;
  Timer? _searchDebounce;
  Timer? _interp;
  Timer? _pingTimer;
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<RealtimeMessage>? _wsSub;
  Position? _lastFix;
  final Map<String, _TrackedDriver> _tracked = {};
  bool _liveStarted = false;
  bool _pickupFollowsGps = true;
  Timer? _nameDebounce;

  bool _openedPickerFromSearch = false;
  int _routeGen = 0;

  String get tripDistanceLabel => '${tripKm.toStringAsFixed(1)} Km';

  String get tripEtaLabel {
    if (tripDurationMin < 1) return '—';
    return '$tripDurationMin min';
  }

  String get etaLabel {
    final minutes =
        etaMinutes ?? (tripDurationMin > 0 ? tripDurationMin : null);
    if (minutes == null) return '—';
    if (minutes < 1) return '<1 min';
    return '$minutes min';
  }

  String get driverReceiptLabel {
    final driver = matchedDriver;
    if (driver == null || driver.name.trim().isEmpty) {
      return 'Driver details pending';
    }
    final parts = driver.name.trim().split(RegExp(r'\s+'));
    final short = parts.length <= 1
        ? driver.name
        : '${parts.sublist(0, parts.length - 1).join(' ')} ${parts.last[0]}.';
    return driver.plate.trim().isEmpty ? short : '$short - ${driver.plate}';
  }

  int get payableFare => agreedFare > 0 ? agreedFare : offeredPrice;

  String get receiptSummary {
    return 'Ridons $recordNumber\n'
        'Paid to the driver  $payableFare Rwf\n'
        '$pickupLabel → $dropoffLabel  $tripDistanceLabel\n'
        'Driver  $driverReceiptLabel';
  }

  String get pickupLabel => pickup?.name ?? 'My current location';
  String get dropoffLabel => dropoff?.name ?? '';

  String get rideStatusLabel {
    switch (liveRideStatus) {
      case 'en_route':
        return 'Driver on the way';
      case 'arrived':
        return 'Driver has arrived';
      case 'in_progress':
        return 'Trip in progress';
      case 'completed':
        return 'Trip complete';
      default:
        return 'Match found';
    }
  }
  bool get hasRoute =>
      pickup != null && dropoff != null && routePoints.length >= 2;

  String get timerLabel {
    if (offerTimer == Duration.zero) return '';
    final minutes = offerTimer.inMinutes;
    final seconds = offerTimer.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  LatLng? get userPoint {
    final fix = _lastFix;
    if (fix != null) {
      // Reverse-geocoded place coordinates are labels, not a replacement for
      // the device fix. Keep the marker and all presence requests on GPS.
      return LatLng(fix.latitude, fix.longitude);
    }
    final origin = pickup;
    if (origin == null) return null;
    return LatLng(origin.latitude, origin.longitude);
  }

  bool get hasGpsFix => _lastFix != null;

  double get gpsAccuracyMeters {
    final accuracy = _lastFix?.accuracy;
    if (accuracy == null || !accuracy.isFinite || accuracy <= 0) return 28;
    return accuracy.clamp(12, 42);
  }

  bool get pickupIsUser => _pickupFollowsGps;

  LatLng get mapCenter {
    final candidate = pickCandidate;
    if (candidate != null) {
      return LatLng(candidate.latitude, candidate.longitude);
    }
    final dest = dropoff;
    if (dest != null) {
      return LatLng(dest.latitude, dest.longitude);
    }
    final you = userPoint;
    if (you != null) return you;
    final origin = pickup;
    if (origin != null) {
      return LatLng(origin.latitude, origin.longitude);
    }
    // No embedded city — wait for GPS (map recenters on first fix).
    return const LatLng(0, 0);
  }

  Future<void> bootstrap() async {
    locating = true;
    stage = RideStage.route;
    notifyListeners();

    final granted = await _locationService.hasLocationPermission();
    bootstrapped = true;
    if (granted) {
      await _afterLocationGranted();
      return;
    }

    locating = false;
    locationPromptNeeded = true;
    notifyListeners();
  }

  Future<void> allowLocation() async {
    locating = true;
    notifyListeners();
    final granted = await _locationService.ensureLocationPermission();
    locating = false;
    if (!granted) {
      notifyListeners();
      return;
    }
    locationPromptNeeded = false;
    notifyListeners();
    await _afterLocationGranted();
  }

  void skipPermissions() {
    locationPromptNeeded = false;
    locating = false;
    notifyListeners();
    unawaited(_startLive());
  }

  void openMapPickerFor(LocationField field) {
    activeField = field;
    openMapPicker();
  }

  Future<void> _afterLocationGranted() async {
    locating = true;
    notifyListeners();

    // Prefer a fresh GPS fix (emulator Extended Controls / real device).
    // Fall back to OS last-known, then last cached fix — never a hardcoded city.
    final fresh = await _locationService.freshPosition();
    final last = fresh ?? await _locationService.lastKnownPosition();
    if (last != null) {
      _applyGps(last);
      locating = false;
      notifyListeners();
    }
    unawaited(_startLive());
    unawaited(_locationService.requestNotifications());
    if (fresh != null) {
      locating = false;
      notifyListeners();
      if (_pickupFollowsGps) {
        unawaited(_renamePickup(fresh.latitude, fresh.longitude));
      }
    } else {
      unawaited(_refineFixAndName(last));
    }
  }

  Future<void> _renamePickup(double latitude, double longitude) async {
    final named = await _placesService.reverse(latitude, longitude);
    if (!_pickupFollowsGps) return;
    pickup = GeoPlace(
      name: named.name,
      subtitle: named.subtitle,
      latitude: latitude,
      longitude: longitude,
    );
    notifyListeners();
  }

  void _applyGps(Position position) {
    _lastFix = position;
    _pickupFollowsGps = true;
    pickup = GeoPlace(
      name: pickup?.name ?? 'My current location',
      subtitle: pickup?.subtitle ?? '',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _refineFixAndName(Position? last) async {
    locating = last == null;
    if (last == null) notifyListeners();
    final position = await _locationService.freshPosition() ?? last;
    if (position != null) {
      _applyGps(position);
      locating = false;
      notifyListeners();
      if (!_pickupFollowsGps) return;
      final named = await _placesService.reverse(
        position.latitude,
        position.longitude,
      );
      if (!_pickupFollowsGps) return;
      pickup = GeoPlace(
        name: named.name,
        subtitle: named.subtitle,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
    locating = false;
    notifyListeners();
  }

  Future<void> _startLive() async {
    if (_liveStarted) {
      await _refreshNearby();
      return;
    }
    _liveStarted = true;
    _wsSub = _realtime.messages.listen(_onRealtime);
    unawaited(_realtime.connect());
    await _realtime.subscribe('marketplace:presence');
    _interp?.cancel();
    _interp = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _interpolate();
    });
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_pingLocation());
    });
    _gpsSub?.cancel();
    _gpsSub = _locationService.positionStream().listen((position) {
      final firstFix = _lastFix == null;
      _lastFix = position;
      if (_pickupFollowsGps && firstFix) {
        _applyGps(position);
        _schedulePickupRename(position.latitude, position.longitude);
      } else if (_pickupFollowsGps) {
        _maybeResnapFromGps(position);
      }
      notifyListeners();
      unawaited(_pingLocation());
    }, onError: (_) {});
    await _refreshNearby();
    await _pingLocation();
    await _restoreActiveRide();
  }

  Future<void> _restoreActiveRide() async {
    final api = _tripApi;
    if (api == null) return;
    final active = await api.passengerActiveRide();
    if (active == null || active.rideId.isEmpty) return;

    liveRequestId = active.requestId.isEmpty ? null : active.requestId;
    liveRideId = active.rideId;
    liveRideStatus = active.status;
    agreedFare = active.fare;
    matchedDriver = MatchedDriver(
      name: active.driverName,
      plate: active.driverVehiclePlate,
      rating: active.driverRating,
      avatarUrl: active.driverAvatarUrl,
    );
    driverPhone = active.driverPhone;
    pickup = GeoPlace(
      name: active.fromName.isEmpty ? 'Pickup location' : active.fromName,
      latitude: active.from.latitude,
      longitude: active.from.longitude,
    );
    dropoff = GeoPlace(
      name: active.toName.isEmpty ? 'Dropoff location' : active.toName,
      latitude: active.to.latitude,
      longitude: active.to.longitude,
    );
    focusedDriverId = active.driverId.isEmpty
        ? focusedDriverId
        : active.driverId;
    stage = active.status == 'completed'
        ? RideStage.payment
        : RideStage.matched;
    await _realtime.subscribe('ride:${active.rideId}');
    await _refreshEta();
    notifyListeners();
  }

  Future<void> _pingLocation() async {
    final fix = _lastFix;
    final origin = pickup;
    final lat = fix?.latitude ?? origin?.latitude;
    final lng = fix?.longitude ?? origin?.longitude;
    if (lat == null || lng == null) return;
    final heading = (fix != null && fix.heading.isFinite && fix.heading >= 0)
        ? fix.heading
        : 0.0;
    final speedMps = (fix != null && fix.speed.isFinite)
        ? math.max(0, fix.speed)
        : 0.0;
    await _geoApi.ping(
      lat: lat,
      lng: lng,
      headingDeg: heading,
      speedKmh: math.max(0, speedMps * 3.6),
      rideId: liveRideId ?? liveRequestId,
    );
  }

  void _maybeResnapFromGps(Position position) {
    final origin = pickup;
    if (origin == null) {
      _applyGps(position);
      _schedulePickupRename(position.latitude, position.longitude);
      return;
    }
    final meters = _metersBetween(
      LatLng(origin.latitude, origin.longitude),
      LatLng(position.latitude, position.longitude),
    );
    // Keep the exact GPS coordinate even when the display label stays the
    // same. Reverse geocoding is only used to refresh the label occasionally.
    _applyGps(position);
    if (meters >= 120) {
      _schedulePickupRename(position.latitude, position.longitude);
    }
  }

  void _schedulePickupRename(double lat, double lng) {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!_pickupFollowsGps) return;
      final named = await _placesService.reverse(lat, lng);
      if (!_pickupFollowsGps) return;
      pickup = GeoPlace(
        name: named.name,
        subtitle: named.subtitle,
        latitude: lat,
        longitude: lng,
      );
      notifyListeners();
    });
  }

  Future<void> _refreshNearby() async {
    final origin =
        userPoint ??
        (pickup == null ? null : LatLng(pickup!.latitude, pickup!.longitude));
    if (origin == null) return;
    final drivers = await _geoApi.nearby(
      lat: origin.latitude,
      lng: origin.longitude,
    );
    _applyNearby(drivers);
    if (stage != RideStage.offering) {
      driversNotified = nearbyDrivers.length;
    }
    unawaited(_realtime.connect());
    await _realtime.syncDriverChannels(drivers.map((d) => d.id));
    await _refreshEta();
    notifyListeners();
  }

  void _applyNearby(List<LiveMapMarker> drivers) {
    final seen = <String>{};
    for (final driver in drivers) {
      seen.add(driver.id);
      final existing = _tracked[driver.id];
      if (existing == null) {
        _tracked[driver.id] = _TrackedDriver(
          id: driver.id,
          target: driver.point,
          display: driver.point,
          headingDeg: driver.headingDeg,
          speedKmh: driver.speedKmh,
        );
      } else {
        existing.target = driver.point;
        existing.headingDeg = driver.headingDeg;
        existing.speedKmh = driver.speedKmh;
      }
    }
    final assignedId = stage == RideStage.matched ? focusedDriverId : null;
    _tracked.removeWhere((id, _) => !seen.contains(id) && id != assignedId);
    _publishMarkers();
    if (focusedDriverId == null || !_tracked.containsKey(focusedDriverId)) {
      focusedDriverId = drivers.isEmpty ? null : drivers.first.id;
    }
  }

  void _publishMarkers() {
    nearbyDrivers = _tracked.values
        .map(
          (d) => LiveMapMarker(
            id: d.id,
            point: d.display,
            headingDeg: d.headingDeg,
            speedKmh: d.speedKmh,
          ),
        )
        .toList(growable: false);
  }

  void _interpolate() {
    if (_tracked.isEmpty) return;
    var changed = false;
    for (final driver in _tracked.values) {
      final next = _lerp(driver.display, driver.target, 0.32);
      if (next != driver.display) {
        driver.display = next;
        changed = true;
      }
    }
    if (!changed) return;
    _publishMarkers();
    notifyListeners();
  }

  void _onRealtime(RealtimeMessage message) {
    if (message.event == 'bid' && stage == RideStage.offering) {
      final requestId = '${message.data['requestId'] ?? ''}';
      if (requestId.isNotEmpty && requestId != liveRequestId) return;
      final raw = message.data['bid'];
      if (raw is! Map) return;
      final bid = RideBid.fromJson(
        Map<String, dynamic>.from(raw),
        requestId: requestId.isEmpty ? liveRequestId : requestId,
      );
      if (bid.bidId.isEmpty || bid.price <= 0) return;
      final updated = [
        ...counterOffers.where(
          (item) => item.bidId != bid.bidId && item.driverId != bid.driverId,
        ),
        bid,
      ]..sort((a, b) => a.price.compareTo(b.price));
      counterOffers = List.unmodifiable(updated);
      bidError = null;
      notifyListeners();
      return;
    }
    if (message.event == 'location') {
      if ('${message.data['role'] ?? ''}'.toLowerCase() != 'driver') {
        return;
      }
      final rideId = '${message.data['rideId'] ?? ''}';
      if (liveRideId != null &&
          liveRideId!.isNotEmpty &&
          rideId.isNotEmpty &&
          rideId != liveRideId) {
        return;
      }
      final id = (message.data['driverId'] ?? '').toString();
      final coords = message.data['coords'];
      if (id.isEmpty || coords is! List || coords.length < 2) return;
      final lat = (coords[0] as num?)?.toDouble();
      final lng = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      if (rideId.isEmpty && !_isNearUser(LatLng(lat, lng))) {
        _tracked.remove(id);
        _publishMarkers();
        notifyListeners();
        return;
      }
      final existing = _tracked[id];
      final point = LatLng(lat, lng);
      final heading = (message.data['headingDeg'] as num?)?.toDouble() ?? 0;
      final speed = (message.data['speedKmh'] as num?)?.toDouble() ?? 0;
      if (existing == null) {
        _tracked[id] = _TrackedDriver(
          id: id,
          target: point,
          display: point,
          headingDeg: heading,
          speedKmh: speed,
        );
      } else {
        existing.target = point;
        existing.headingDeg = heading;
        existing.speedKmh = speed;
      }
      _publishMarkers();
      if (stage == RideStage.matched) unawaited(_refreshEta());
      notifyListeners();
      return;
    }
    if (message.event == 'presence') {
      if ('${message.data['role'] ?? 'driver'}'.toLowerCase() != 'driver') {
        return;
      }
      final id = '${message.data['driverId'] ?? ''}';
      final online = message.data['online'] == true;
      if (id.isEmpty || !online) {
        if (id.isNotEmpty) _tracked.remove(id);
        _publishMarkers();
        notifyListeners();
        return;
      }
      final coords = message.data['coords'];
      if (coords is! List || coords.length < 2) return;
      final lat = (coords[0] as num?)?.toDouble();
      final lng = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      final point = LatLng(lat, lng);
      if (!_isNearUser(point)) {
        _tracked.remove(id);
        _publishMarkers();
        notifyListeners();
        return;
      }
      _upsertTracked(
        id: id,
        point: point,
        headingDeg: (message.data['headingDeg'] as num?)?.toDouble() ?? 0,
        speedKmh: (message.data['speedKmh'] as num?)?.toDouble() ?? 0,
      );
      unawaited(_realtime.subscribe('driver:$id'));
      notifyListeners();
      return;
    }
    if (message.event == 'eta') {
      final minutes = (message.data['minutes'] as num?)?.toInt();
      if (minutes != null && minutes != etaMinutes) {
        etaMinutes = minutes;
        notifyListeners();
      }
      return;
    }
    if (message.event == 'matched' && stage == RideStage.offering) {
      final id = '${message.data['rideId'] ?? ''}';
      if (id.isNotEmpty) liveRideId = id;
      final driverId = '${message.data['driverId'] ?? ''}';
      final driverName = '${message.data['driverName'] ?? ''}';
      final vehiclePlate = '${message.data['vehiclePlate'] ?? ''}';
      final driverRating =
          (message.data['driverRating'] as num?)?.toDouble() ?? 0;
      final driverAvatarUrl = message.data['driverAvatarUrl']?.toString();
      driverPhone = '${message.data['driverPhone'] ?? driverPhone}'.trim();
      matchedDriver = MatchedDriver(
        name: driverName.isEmpty ? matchedDriver?.name ?? '' : driverName,
        plate: vehiclePlate.isEmpty ? matchedDriver?.plate ?? '' : vehiclePlate,
        rating: driverRating > 0 ? driverRating : matchedDriver?.rating ?? 0,
        avatarUrl: driverAvatarUrl ?? matchedDriver?.avatarUrl,
      );
      final fare = (message.data['fare'] as num?)?.toInt() ?? 0;
      if (fare > 0) agreedFare = fare;
      liveRideStatus = 'matched';
      if (driverId.isNotEmpty && !_tracked.containsKey(driverId)) {
        focusedDriverId = driverId;
      }
      showMatch(driverId: driverId, fare: fare);
      return;
    }
    if (message.event == 'status') {
      final eventRideId = '${message.data['rideId'] ?? ''}';
      if (liveRideId == null ||
          liveRideId!.isEmpty ||
          eventRideId != liveRideId) {
        return;
      }
      final status = '${message.data['status'] ?? ''}';
      if (!const {
        'matched',
        'en_route',
        'arrived',
        'in_progress',
        'completed',
      }.contains(status)) {
        if (status == 'cancelled') {
          resetToHome();
        }
        return;
      }
      liveRideStatus = status;
      if (status == 'completed') {
        stage = RideStage.payment;
      } else {
        stage = RideStage.matched;
      }
      notifyListeners();
      return;
    }
    if (message.event == 'dispatch' && stage == RideStage.offering) {
      final count = (message.data['candidateCount'] as num?)?.toInt();
      if (count != null) {
        driversNotified = count;
        lastOfferHadRiders = count > 0;
        notifyListeners();
      }
      return;
    }
    if (message.event == 'timeout' && stage == RideStage.offering) {
      final count = (message.data['candidateCount'] as num?)?.toInt();
      if (count != null) {
        lastOfferHadRiders = count > 0;
      }
      _offerTimedOut();
    }
  }

  bool _isNearUser(LatLng point) {
    final origin = userPoint;
    return origin != null && _metersBetween(origin, point) <= 3000;
  }

  void _upsertTracked({
    required String id,
    required LatLng point,
    required double headingDeg,
    required double speedKmh,
  }) {
    final existing = _tracked[id];
    if (existing == null) {
      _tracked[id] = _TrackedDriver(
        id: id,
        target: point,
        display: point,
        headingDeg: headingDeg,
        speedKmh: speedKmh,
      );
      return;
    }
    existing.target = point;
    existing.headingDeg = headingDeg;
    existing.speedKmh = speedKmh;
  }

  Future<void> _refreshEta() async {
    final origin = pickup;
    final tracked = focusedDriverId == null ? null : _tracked[focusedDriverId!];
    final driver = tracked ?? (_tracked.isEmpty ? null : _tracked.values.first);
    if (origin == null || driver == null) {
      etaMinutes = null;
      return;
    }
    final quote = await _geoApi.pickupEta(
      driver: driver.display,
      pickup: LatLng(origin.latitude, origin.longitude),
      speedKmh: driver.speedKmh > 1 ? driver.speedKmh : 22,
    );
    etaMinutes = quote?.minutes;
  }

  int _searchGen = 0;
  int _pinGen = 0;
  bool resolvingPin = false;

  void openSearch(LocationField field) {
    activeField = field;
    searchQuery = '';
    suggestions = const [];
    searchingPlaces = true;
    stage = RideStage.search;
    notifyListeners();
    unawaited(_runPlaceSearch(''));
  }

  void closeSearch() {
    _searchGen++;
    searchingPlaces = false;
    stage = dropoff == null ? RideStage.route : RideStage.preview;
    notifyListeners();
  }

  void updateSearch(String query) {
    searchQuery = query;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_runPlaceSearch(query));
    });
  }

  Future<void> _runPlaceSearch(String query) async {
    final gen = ++_searchGen;
    searchingPlaces = suggestions.isEmpty;
    if (searchingPlaces) notifyListeners();
    final origin =
        userPoint ??
        (pickup == null ? null : LatLng(pickup!.latitude, pickup!.longitude));
    final results = await _placesService.search(
      query: query,
      latitude: origin?.latitude,
      longitude: origin?.longitude,
    );
    if (gen != _searchGen) return;
    suggestions = results;
    searchingPlaces = false;
    notifyListeners();
  }

  Future<void> choosePlace(GeoPlace place) async {
    if (activeField == LocationField.pickup) {
      _pickupFollowsGps = false;
      pickup = place;
      stage = dropoff == null ? RideStage.route : RideStage.preview;
    } else {
      dropoff = place;
      stage = RideStage.preview;
    }
    pickCandidate = null;
    notifyListeners();
    await _refreshRoute();
  }

  void openMapPicker() {
    _openedPickerFromSearch = stage == RideStage.search;
    _pinGen++;
    resolvingPin = false;
    pickCandidate = null;
    stage = RideStage.pickOnMap;
    notifyListeners();
  }

  void closeMapPicker() {
    _pinGen++;
    resolvingPin = false;
    pickCandidate = null;
    stage = _openedPickerFromSearch ? RideStage.search : RideStage.route;
    notifyListeners();
  }

  Future<void> pickOnMap(LatLng point) async {
    final gen = ++_pinGen;
    resolvingPin = true;
    pickCandidate = GeoPlace(
      name: 'Dropped pin',
      subtitle: 'Finding address…',
      latitude: point.latitude,
      longitude: point.longitude,
    );
    notifyListeners();
    final named = await _placesService.reverseFast(
      point.latitude,
      point.longitude,
    );
    if (gen != _pinGen) return;
    resolvingPin = false;
    pickCandidate = GeoPlace(
      name: (named?.name.trim().isNotEmpty ?? false)
          ? named!.name
          : 'Dropped pin',
      subtitle: named?.subtitle ?? '',
      latitude: point.latitude,
      longitude: point.longitude,
    );
    notifyListeners();
  }

  Future<void> confirmMapPick() async {
    final place = pickCandidate;
    if (place == null) return;
    await choosePlace(place);
  }

  void continueFromRoute() {
    if (dropoff == null) {
      openSearch(LocationField.dropoff);
      return;
    }
    startEstimate();
  }

  void startEstimate() {
    final from = pickup;
    final to = dropoff;
    if (from == null || to == null) return;
    stage = RideStage.estimate;
    offerTimer = Duration.zero;
    offeredPrice = 0;
    fareEstimate = null;
    fareEstimateError = null;
    loadingFareEstimate = true;
    notifyListeners();
    unawaited(_loadFareEstimate(from, to));
  }

  Future<void> _loadFareEstimate(GeoPlace from, GeoPlace to) async {
    final api = _pricingApi;
    if (api == null) {
      loadingFareEstimate = false;
      fareEstimateError = 'Price service is unavailable.';
      notifyListeners();
      return;
    }
    try {
      final estimate = await api.estimate(
        from: LatLng(from.latitude, from.longitude),
        to: LatLng(to.latitude, to.longitude),
      );
      if (!_samePlace(from, pickup) || !_samePlace(to, dropoff)) return;
      fareEstimate = estimate;
      offeredPrice = estimate.suggestedPrice;
      if (tripKm <= 0 && estimate.distanceKm > 0) {
        tripKm = estimate.distanceKm;
      }
      fareEstimateError = estimate.suggestedPrice > 0
          ? null
          : 'Price service returned no fare.';
    } catch (_) {
      if (!_samePlace(from, pickup) || !_samePlace(to, dropoff)) return;
      offeredPrice = 0;
      fareEstimateError = 'Could not load the current fare. Please try again.';
    } finally {
      if (_samePlace(from, pickup) && _samePlace(to, dropoff)) {
        loadingFareEstimate = false;
        notifyListeners();
      }
    }
  }

  bool _samePlace(GeoPlace a, GeoPlace? b) {
    return b != null &&
        (a.latitude - b.latitude).abs() < 0.000001 &&
        (a.longitude - b.longitude).abs() < 0.000001;
  }

  void adjustPrice(int delta) {
    if (stage != RideStage.estimate || loadingFareEstimate || offeredPrice <= 0) {
      return;
    }
    offeredPrice = FarePolicy.normalize(
      offeredPrice + delta,
      minimum: fareEstimate?.minPrice ?? FarePolicy.minRwf,
    );
    notifyListeners();
  }

  void retryFareEstimate() {
    if (loadingFareEstimate || pickup == null || dropoff == null) return;
    startEstimate();
  }

  Future<void> confirmOffer() async {
    if (loadingFareEstimate || offeredPrice <= 0) {
      fareEstimateError = 'Wait for the current fare before sending the offer.';
      notifyListeners();
      return;
    }
    stage = RideStage.offering;
    counterOffers = const [];
    bidError = null;
    agreedFare = 0;
    lastOfferMissed = false;
    driversNotified = 0;
    lastOfferHadRiders = false;
    _ticker?.cancel();
    offerTimer = Duration.zero;
    _matchTimer?.cancel();
    notifyListeners();
    final api = _tripApi;
    final from = pickup;
    final to = dropoff;
    if (api == null || from == null || to == null) {
      return;
    }
    try {
      final created = await api.createRequest(
        pickup: from,
        dropoff: to,
        offeredPrice: offeredPrice,
        suggestedPrice: fareEstimate?.suggestedPrice ?? offeredPrice,
        passengerName: passengerName,
      );
      liveRequestId = created.requestId;
      if (created.offeredPrice > 0) {
        offeredPrice = created.offeredPrice;
      }
      driversNotified = created.candidateCount;
      lastOfferHadRiders = created.candidateCount > 0;
      if (created.offerTtlSec > 0) {
        _startTimer(Duration(seconds: created.offerTtlSec));
      }
      notifyListeners();
      if (liveRequestId != null && liveRequestId!.isNotEmpty) {
        await _realtime.subscribe('request:$liveRequestId');
      }
    } catch (_) {
      stage = RideStage.estimate;
      notifyListeners();
    }
  }

  Future<void> acceptCounterOffer(RideBid bid) async {
    final requestId = liveRequestId;
    final api = _tripApi;
    if (bidBusy || requestId == null || requestId.isEmpty || api == null) {
      return;
    }
    bidBusy = true;
    bidError = null;
    notifyListeners();
    try {
      final assignment = await api.acceptBid(
        requestId: requestId,
        bidId: bid.bidId,
        driverName: bid.driverName,
        vehiclePlate: bid.vehiclePlate,
        driverRating: bid.driverRating,
      );
      final driverId = assignment.driverId.isEmpty
          ? bid.driverId
          : assignment.driverId;
      agreedFare = assignment.fare > 0 ? assignment.fare : bid.price;
      liveRideId = assignment.rideId.isEmpty ? liveRideId : assignment.rideId;
      liveRideStatus = 'matched';
      matchedDriver = MatchedDriver(
        name: assignment.driverName.isNotEmpty
            ? assignment.driverName
            : (bid.driverName.isNotEmpty ? bid.driverName : bid.driverLabel),
        plate: assignment.vehiclePlate.isNotEmpty
            ? assignment.vehiclePlate
            : bid.vehiclePlate,
        rating: assignment.driverRating > 0
            ? assignment.driverRating
            : bid.driverRating,
        avatarUrl: assignment.driverAvatarUrl ?? bid.driverAvatarUrl,
      );
      driverPhone = assignment.driverPhone.isNotEmpty
          ? assignment.driverPhone
          : bid.driverPhone;
      counterOffers = const [];
      unawaited(_realtime.unsubscribe('request:$requestId'));
      showMatch(driverId: driverId, fare: agreedFare);
    } catch (_) {
      bidError = 'That offer is no longer available. Choose another one.';
      counterOffers = counterOffers
          .where((item) => item.bidId != bid.bidId)
          .toList(growable: false);
      notifyListeners();
    } finally {
      bidBusy = false;
      notifyListeners();
    }
  }

  Future<void> counterBack(RideBid bid, int price) async {
    final requestId = liveRequestId;
    final api = _tripApi;
    if (bidBusy || requestId == null || requestId.isEmpty || api == null) {
      return;
    }
    bidBusy = true;
    bidError = null;
    notifyListeners();
    try {
      await api.counterBid(
        requestId: requestId,
        bidId: bid.bidId,
        price: FarePolicy.normalize(price),
      );
      counterOffers = counterOffers
          .where((item) => item.bidId != bid.bidId)
          .toList(growable: false);
      bidError = 'Counter offer sent. Waiting for the driver.';
    } catch (_) {
      bidError = 'Could not send your counter offer. Please try again.';
    } finally {
      bidBusy = false;
      notifyListeners();
    }
  }

  Future<void> rejectCounterOffer(RideBid bid) async {
    final requestId = liveRequestId;
    final api = _tripApi;
    if (bidBusy || requestId == null || requestId.isEmpty || api == null) {
      return;
    }
    bidBusy = true;
    bidError = null;
    notifyListeners();
    try {
      await api.rejectBid(requestId: requestId, bidId: bid.bidId);
      counterOffers = counterOffers
          .where((item) => item.bidId != bid.bidId)
          .toList(growable: false);
    } catch (_) {
      bidError = 'Could not remove that offer. Please try again.';
    } finally {
      bidBusy = false;
      notifyListeners();
    }
  }

  void showMatch({String? driverId, int? fare}) {
    stage = RideStage.matched;
    liveRideStatus = 'matched';
    if (fare != null && fare > 0) agreedFare = fare;
    _ticker?.cancel();
    _matchTimer?.cancel();
    if (driverId != null && driverId.isNotEmpty) {
      focusedDriverId = driverId;
    } else if (_tracked.isNotEmpty) {
      focusedDriverId = _tracked.keys.first;
    }
    counterOffers = const [];
    final rideId = liveRideId;
    if (rideId != null && rideId.isNotEmpty) {
      unawaited(_realtime.subscribe('ride:$rideId'));
    }
    unawaited(_refreshEta());
    notifyListeners();
  }

  void goToPayment() {
    stage = RideStage.payment;
    notifyListeners();
  }

  /// Opens a support ticket for the current ride (or general help).
  /// Returns the ticket id on success, or null if support is unavailable / failed.
  Future<String?> requestHelp({
    required String subject,
    String? body,
    String category = 'ride',
  }) async {
    final api = _supportApi;
    if (api == null) return null;
    try {
      final created = await api.createTicket(
        subject: subject.trim(),
        body: body?.trim(),
        rideId: liveRideId ?? liveRequestId,
        category: category,
        userName: passengerName.isEmpty ? null : passengerName,
      );
      final id = created.ticketId.trim();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  void selectPayment(String method) {
    paymentMethod = method;
    notifyListeners();
  }

  void confirmPayment() {
    if (tripKm <= 0 && pickup != null && dropoff != null) {
      tripKm = _routingService.kilometers(pickup!, dropoff!) * 1.25;
    }
    final now = DateTime.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final body =
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    recordNumber = 'RDN-$yy-${body.substring(0, 6)}';
    stage = RideStage.success;
    notifyListeners();
  }

  void setRating(int value) {
    rating = value;
    notifyListeners();
  }

  void setRatingComment(String value) {
    ratingComment = value;
    notifyListeners();
  }

  Future<String?> createTripShareLink() async {
    final rideId = liveRideId;
    final api = _tripApi;
    if (sharingTrip || rideId == null || rideId.isEmpty || api == null) {
      return null;
    }
    sharingTrip = true;
    shareError = null;
    notifyListeners();
    try {
      return await api.createShareLink(rideId);
    } catch (_) {
      shareError = 'Could not create the trip sharing link.';
      return null;
    } finally {
      sharingTrip = false;
      notifyListeners();
    }
  }

  Future<void> submitRating() async {
    final rideId = liveRideId;
    final api = _tripApi;
    if (rideId == null || rideId.isEmpty || api == null || rating < 1) return;
    ratingBusy = true;
    ratingError = null;
    sharingTrip = false;
    shareError = null;
    notifyListeners();
    try {
      await api.rateRide(
        rideId,
        rating: rating,
        comment: ratingComment,
      );
      resetToHome();
    } catch (_) {
      ratingError = 'Could not submit your rating. Please try again.';
      ratingBusy = false;
      notifyListeners();
    }
  }

  void resetToHome() {
    final rideId = liveRideId;
    if (rideId != null && rideId.isNotEmpty) {
      unawaited(_realtime.unsubscribe('ride:$rideId'));
    }
    _ticker?.cancel();
    _matchTimer?.cancel();
    dropoff = null;
    pickCandidate = null;
    routePoints = const [];
    routeAlternatives = const [];
    routeSteps = const [];
    offeredPrice = 0;
    fareEstimate = null;
    loadingFareEstimate = false;
    fareEstimateError = null;
    agreedFare = 0;
    counterOffers = const [];
    bidError = null;
    rating = 0;
    ratingComment = '';
    ratingBusy = false;
    ratingError = null;
    paymentMethod = 'Cash';
    searchQuery = '';
    recordNumber = '';
    tripKm = 0;
    tripDurationMin = 0;
    routeMethod = '';
    liveRequestId = null;
    liveRideId = null;
    liveRideStatus = '';
    matchedDriver = null;
    driverPhone = '';
    focusedDriverId = null;
    _pickupFollowsGps = true;
    stage = RideStage.route;
    notifyListeners();
    unawaited(_refreshNearby());
  }

  Future<void> rebook({
    required GeoPlace pickup,
    required GeoPlace dropoff,
  }) async {
    this.pickup = pickup;
    this.dropoff = dropoff;
    pickCandidate = null;
    locationPromptNeeded = false;
    locating = false;
    _pickupFollowsGps = false;
    stage = RideStage.preview;
    notifyListeners();
    await _startLive();
    await _refreshRoute();
  }

  void cancelRide() {
    _ticker?.cancel();
    _matchTimer?.cancel();
    unawaited(_cancelLiveRequest());
    dropoff = null;
    pickCandidate = null;
    routePoints = const [];
    routeAlternatives = const [];
    routeSteps = const [];
    _pickupFollowsGps = true;
    lastOfferMissed = false;
    lastOfferHadRiders = false;
    stage = RideStage.route;
    notifyListeners();
  }

  void _offerTimedOut() {
    if (stage != RideStage.offering) return;
    lastOfferMissed = true;
    unawaited(_cancelLiveRequest());
    _ticker?.cancel();
    offerTimer = Duration.zero;
    counterOffers = const [];
    bidError = null;
    stage = RideStage.estimate;
    offerTimer = Duration.zero;
    notifyListeners();
  }

  Future<void> _cancelLiveRequest() async {
    final id = liveRequestId;
    final api = _tripApi;
    liveRequestId = null;
    liveRideId = null;
    if (id == null || id.isEmpty || api == null) return;
    unawaited(_realtime.unsubscribe('request:$id'));
    try {
      await api.cancelRequest(id);
    } catch (_) {}
  }

  Future<void> _refreshRoute() async {
    final from = pickup;
    final to = dropoff;
    if (from == null || to == null) {
      _routeGen++;
      _routingService.cancelInFlight();
      routePoints = const [];
      routeAlternatives = const [];
      routeSteps = const [];
      tripKm = 0;
      tripDurationMin = 0;
      routeMethod = '';
      notifyListeners();
      return;
    }

    final gen = ++_routeGen;

    // Soft ETA numbers for the sheet only — never draw a straight-line
    // provisional polyline (that flashes before OSRM finishes).
    final quick = _routingService.estimateQuick(from, to);
    loadingRoute = true;
    tripKm = quick.distanceKm;
    tripDurationMin = quick.durationMin;
    routeMethod = '';
    routePoints = const [];
    routeAlternatives = const [];
    routeSteps = const [];
    notifyListeners();

    try {
      final result = await _routingService.route(from, to);
      if (gen != _routeGen) return;
      routePoints = result.points;
      routeAlternatives = [for (final alt in result.alternatives) alt.points];
      routeSteps = result.steps;
      tripKm = result.distanceKm;
      tripDurationMin = result.durationMin;
      routeMethod = result.method;
    } catch (_) {
      if (gen != _routeGen) return;
      // Only fall back to a straight line if OSRM truly failed.
      routePoints = quick.points;
      routeMethod = quick.method;
    }
    if (gen != _routeGen) return;
    loadingRoute = false;
    notifyListeners();
    await _refreshNearby();
  }

  void _startTimer(Duration duration) {
    offerTimer = duration;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (offerTimer.inSeconds <= 1) {
        timer.cancel();
        offerTimer = Duration.zero;
        if (stage == RideStage.offering) {
          _offerTimedOut();
          return;
        }
        notifyListeners();
        return;
      }
      offerTimer -= const Duration(seconds: 1);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _routingService.cancelInFlight();
    _ticker?.cancel();
    _matchTimer?.cancel();
    _searchDebounce?.cancel();
    _interp?.cancel();
    _pingTimer?.cancel();
    unawaited(_gpsSub?.cancel());
    unawaited(_wsSub?.cancel());
    _nameDebounce?.cancel();
    super.dispose();
  }
}

LatLng _lerp(LatLng a, LatLng b, double t) {
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
}

double _metersBetween(LatLng a, LatLng b) {
  const earth = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final x =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a.latitude * math.pi / 180) *
          math.cos(b.latitude * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earth * math.asin(math.sqrt(x));
}
