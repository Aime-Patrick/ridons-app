import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/services/geo_api.dart';
import '../../../../data/services/location_service.dart';
import '../../../../data/services/places_service.dart';
import '../../../../data/services/realtime_client.dart';
import '../../../../data/services/routing_service.dart';
import '../../../../data/services/trip_api.dart';
import '../../../../data/services/support_api.dart';
import '../../../../domain/models/geo_place.dart';
import '../../../../domain/models/live_driver.dart';
import '../../../../domain/models/ride_stage.dart';

class MatchedDriver {
  const MatchedDriver({
    required this.name,
    required this.plate,
    required this.rating,
  });

  final String name;
  final String plate;
  final double rating;
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
    SupportApi? supportApi,
    this.passengerName = '',
  }) : _tripApi = tripApi,
       _supportApi = supportApi;

  final LocationService _locationService;
  final PlacesService _placesService;
  final RoutingService _routingService;
  final GeoApi _geoApi;
  final RealtimeClient _realtime;
  final TripApi? _tripApi;
  final SupportApi? _supportApi;
  final String passengerName;

  MatchedDriver? matchedDriver;

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
  int offeredPrice = 1900;
  int driversViewing = 0;
  Duration offerTimer = const Duration(seconds: 60);
  String paymentMethod = 'Cash';
  bool loadingRoute = false;
  bool locating = false;
  int rating = 0;
  String searchQuery = '';
  String recordNumber = '';
  String? liveRequestId;
  String? liveRideId;
  bool lastOfferMissed = false;
  bool lastOfferHadRiders = false;
  double tripKm = 0;
  int tripDurationMin = 0;
  String routeMethod = '';
  int? etaMinutes;
  String? focusedDriverId;

  Timer? _ticker;
  Timer? _matchTimer;
  Timer? _searchDebounce;
  Timer? _nearbyPoll;
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
    final minutes = etaMinutes ?? (tripDurationMin > 0 ? tripDurationMin : null);
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

  String get receiptSummary {
    return 'Ridons $recordNumber\n'
        'Paid to the driver  $offeredPrice Rwf\n'
        '$pickupLabel → $dropoffLabel  $tripDistanceLabel\n'
        'Driver  $driverReceiptLabel';
  }

  String get pickupLabel => pickup?.name ?? 'My current location';
  String get dropoffLabel => dropoff?.name ?? '';
  bool get hasRoute =>
      pickup != null && dropoff != null && routePoints.length >= 2;

  String get timerLabel {
    final minutes = offerTimer.inMinutes;
    final seconds = offerTimer.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  LatLng? get userPoint {
    final fix = _lastFix;
    if (fix != null) {
      final gps = LatLng(fix.latitude, fix.longitude);
      if (_pickupFollowsGps && pickup != null) {
        final named = LatLng(pickup!.latitude, pickup!.longitude);
        if (_metersBetween(named, gps) < 160) return named;
      }
      return gps;
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
    final fresh = await _locationService.currentPosition();
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
    pickup = await _placesService.reverse(latitude, longitude);
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
    final position = await _locationService.currentPosition() ?? last;
    if (position != null) {
      _applyGps(position);
      locating = false;
      notifyListeners();
      if (!_pickupFollowsGps) return;
      pickup = await _placesService.reverse(
        position.latitude,
        position.longitude,
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
    _nearbyPoll?.cancel();
    _nearbyPoll = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_refreshNearby());
    });
    _interp?.cancel();
    _interp = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _interpolate();
    });
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_pingLocation());
    });
    _gpsSub?.cancel();
    _gpsSub = _locationService.positionStream().listen(
      (position) {
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
      },
      onError: (_) {},
    );
    await _refreshNearby();
    await _pingLocation();
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
    final speedMps =
        (fix != null && fix.speed.isFinite) ? math.max(0, fix.speed) : 0.0;
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
      _schedulePickupRename(position.latitude, position.longitude);
      return;
    }
    final meters = _metersBetween(
      LatLng(origin.latitude, origin.longitude),
      LatLng(position.latitude, position.longitude),
    );
    // GPS often sits on the carriageway while you are in the shop next to it.
    if (meters < 120) return;
    _schedulePickupRename(position.latitude, position.longitude);
  }

  void _schedulePickupRename(double lat, double lng) {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!_pickupFollowsGps) return;
      final named = await _placesService.reverse(lat, lng);
      if (!_pickupFollowsGps) return;
      pickup = named;
      notifyListeners();
    });
  }

  Future<void> _refreshNearby() async {
    final origin = userPoint ??
        (pickup == null
            ? null
            : LatLng(pickup!.latitude, pickup!.longitude));
    if (origin == null) return;
    final drivers = await _geoApi.nearby(
      lat: origin.latitude,
      lng: origin.longitude,
    );
    _applyNearby(drivers);
    if (stage != RideStage.offering) {
      driversViewing = nearbyDrivers.length;
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
    _tracked.removeWhere((id, _) => !seen.contains(id));
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
    if (message.event == 'location') {
      final id = (message.data['driverId'] ?? '').toString();
      final coords = message.data['coords'];
      if (id.isEmpty || coords is! List || coords.length < 2) return;
      final lat = (coords[0] as num?)?.toDouble();
      final lng = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) return;
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
      matchedDriver = MatchedDriver(
        name: '${message.data['driverName'] ?? ''}',
        plate: '${message.data['vehiclePlate'] ?? ''}',
        rating: (message.data['driverRating'] as num?)?.toDouble() ?? 0,
      );
      if (driverId.isNotEmpty && !_tracked.containsKey(driverId)) {
        focusedDriverId = driverId;
      }
      showMatch();
      return;
    }
    if (message.event == 'dispatch' && stage == RideStage.offering) {
      final count = (message.data['candidateCount'] as num?)?.toInt();
      if (count != null) {
        driversViewing = count;
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

  Future<void> _refreshEta() async {
    final origin = pickup;
    final tracked =
        focusedDriverId == null ? null : _tracked[focusedDriverId!];
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
    final origin = userPoint ??
        (pickup == null
            ? null
            : LatLng(pickup!.latitude, pickup!.longitude));
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
    if (tripKm > 0) {
      offeredPrice = _routingService.suggestFareFromKm(tripKm);
    } else if (pickup != null && dropoff != null) {
      offeredPrice = _routingService.suggestFare(pickup!, dropoff!);
    }
    stage = RideStage.estimate;
    _startTimer(const Duration(seconds: 60));
    notifyListeners();
  }

  void adjustPrice(int delta) {
    if (stage != RideStage.estimate) return;
    offeredPrice = (offeredPrice + delta).clamp(500, 50000);
    notifyListeners();
  }

  Future<void> confirmOffer() async {
    stage = RideStage.offering;
    lastOfferMissed = false;
    driversViewing = 0;
    lastOfferHadRiders = false;
    _startTimer(const Duration(seconds: 50));
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
        suggestedPrice: tripKm > 0
            ? _routingService.suggestFareFromKm(tripKm)
            : _routingService.suggestFare(from, to),
        passengerName: passengerName,
      );
      liveRequestId = created.requestId;
      driversViewing = created.candidateCount;
      lastOfferHadRiders = created.candidateCount > 0;
      notifyListeners();
      if (liveRequestId != null && liveRequestId!.isNotEmpty) {
        await _realtime.subscribe('request:$liveRequestId');
      }
    } catch (_) {
      stage = RideStage.estimate;
      notifyListeners();
    }
  }

  void showMatch() {
    stage = RideStage.matched;
    _ticker?.cancel();
    _matchTimer?.cancel();
    if (_tracked.isNotEmpty) {
      focusedDriverId = _tracked.keys.first;
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

  void resetToHome() {
    _ticker?.cancel();
    _matchTimer?.cancel();
    dropoff = null;
    pickCandidate = null;
    routePoints = const [];
    routeAlternatives = const [];
    routeSteps = const [];
    offeredPrice = 1900;
    rating = 0;
    paymentMethod = 'Cash';
    searchQuery = '';
    recordNumber = '';
    tripKm = 0;
    tripDurationMin = 0;
    routeMethod = '';
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
    stage = RideStage.estimate;
    _startTimer(const Duration(seconds: 60));
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
    if (stage == RideStage.estimate || stage == RideStage.preview) {
      offeredPrice = quick.suggestedFare;
    }
    notifyListeners();

    try {
      final result = await _routingService.route(from, to);
      if (gen != _routeGen) return;
      routePoints = result.points;
      routeAlternatives = [
        for (final alt in result.alternatives) alt.points,
      ];
      routeSteps = result.steps;
      tripKm = result.distanceKm;
      tripDurationMin = result.durationMin;
      routeMethod = result.method;
      if (stage == RideStage.estimate || stage == RideStage.preview) {
        offeredPrice = result.suggestedFare;
      }
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
    _nearbyPoll?.cancel();
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
  final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a.latitude * math.pi / 180) *
          math.cos(b.latitude * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earth * math.asin(math.sqrt(x));
}
