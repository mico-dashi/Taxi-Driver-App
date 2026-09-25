import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../core/places.dart';
import '../models/models.dart';
import 'backend.dart';
import 'pricing.dart';
import 'routing_service.dart';

/// A fully simulated backend. Drivers drive around the user, answer ride
/// requests with (sometimes higher) offers, drive to the pickup and complete
/// the trip; in driver mode, fake passengers send requests. Nothing leaves the
/// phone, so this is ideal for sales demos and for development.
class DemoBackend implements Backend {
  DemoBackend({RoutingService? routing, this.speed = 1.0, int seed = 7})
    : _routing = routing ?? RoutingService(),
      _rng = math.Random(seed) {
    _pool = _makePool(AppConfig.defaultCenter);
    _seedHistory();
  }

  /// >1 makes every simulated delay shorter (used by tests).
  final double speed;
  final RoutingService _routing;
  final math.Random _rng;

  Duration _d(int ms) =>
      Duration(milliseconds: math.max(1, (ms / speed).round()));

  UserProfile? _user;
  var _idSeq = 0;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${++_idSeq}';

  late List<Driver> _pool;
  LatLng _poolCenter = AppConfig.defaultCenter;

  final _requests = <String, RideRequest>{};
  final _offers = <String, List<RideOffer>>{};
  final _offerCtrls = <String, StreamController<List<RideOffer>>>{};
  final _requestTimers = <String, List<Timer>>{};

  final _rides = <String, Ride>{};
  final _rideCtrls = <String, StreamController<Ride>>{};
  final _rideTimers = <String, List<Timer>>{};
  final _history = <Ride>[];

  final _messages = <String, List<ChatMessage>>{};
  final _msgCtrls = <String, StreamController<List<ChatMessage>>>{};
  var _replyIndex = 0;

  // Driver mode.
  Vehicle? _vehicle;
  bool _online = false;
  LatLng _driverLoc = AppConfig.defaultCenter;
  Timer? _requestGenerator;
  final _incoming = <String, RideRequest>{};
  final _incomingCtrl = StreamController<List<RideRequest>>.broadcast();
  final _driverRideCtrl = StreamController<Ride?>.broadcast();
  String? _driverRideId;
  final _driverCompleted = <Ride>[];

  @override
  bool get isDemo => true;

  @override
  String get currentUserId => _user?.id ?? 'demo-user';

  // ================================================================== auth

  static const _prefsUser = 'demo_user';
  static const _prefsVehicle = 'demo_vehicle';

  @override
  Future<UserProfile?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsUser);
    final rawVehicle = prefs.getString(_prefsVehicle);
    if (rawVehicle != null) {
      final v = jsonDecode(rawVehicle) as Map<String, dynamic>;
      _vehicle = Vehicle(
        make: v['make'] as String,
        model: v['model'] as String,
        plate: v['plate'] as String,
        color: v['color'] as String,
        categoryId: v['categoryId'] as String,
        seats: v['seats'] as int,
      );
    }
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return _user = UserProfile(
      id: j['id'] as String,
      phone: j['phone'] as String,
      name: j['name'] as String,
      role: UserRole.values.byName(j['role'] as String),
    );
  }

  @override
  Future<void> sendOtp(String phone) => Future.delayed(_d(600));

  @override
  Future<UserProfile> verifyOtp(String phone, String code) async {
    await Future.delayed(_d(600));
    if (code != AppConfig.demoOtp) {
      throw const BackendException('invalid_code');
    }
    return _user = UserProfile(id: 'demo-user', phone: phone, name: '');
  }

  @override
  Future<UserProfile> saveProfile({
    required String name,
    required UserRole role,
  }) async {
    final user =
        (_user ?? const UserProfile(id: 'demo-user', phone: '', name: ''))
            .copyWith(name: name, role: role);
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsUser,
      jsonEncode({
        'id': user.id,
        'phone': user.phone,
        'name': user.name,
        'role': user.role.name,
      }),
    );
    return user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    await setOnline(false, _driverLoc);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUser);
  }

  // ============================================================= passenger

  static const _driverSeeds = <(String, Vehicle)>[
    (
      'Arben Hoxha',
      Vehicle(
        make: 'Mercedes-Benz',
        model: 'E 220d',
        plate: 'AA 482 TR',
        color: 'E zezë',
        categoryId: 'standard',
      ),
    ),
    (
      'Elira Kola',
      Vehicle(
        make: 'Toyota',
        model: 'Prius',
        plate: 'AB 915 KL',
        color: 'E bardhë',
        categoryId: 'standard',
      ),
    ),
    (
      'Dritan Shehu',
      Vehicle(
        make: 'Volkswagen',
        model: 'Golf 7',
        plate: 'AC 237 DS',
        color: 'Argjendi',
        categoryId: 'standard',
      ),
    ),
    (
      'Besnik Leka',
      Vehicle(
        make: 'Skoda',
        model: 'Octavia',
        plate: 'AA 118 BL',
        color: 'Gri',
        categoryId: 'standard',
      ),
    ),
    (
      'Klajdi Muça',
      Vehicle(
        make: 'Hyundai',
        model: 'Elantra',
        plate: 'AD 604 KM',
        color: 'Blu',
        categoryId: 'standard',
      ),
    ),
    (
      'Anxhela Gjoka',
      Vehicle(
        make: 'Mercedes-Benz',
        model: 'S 350',
        plate: 'AB 777 AG',
        color: 'E zezë',
        categoryId: 'luxury',
      ),
    ),
    (
      'Erion Dervishi',
      Vehicle(
        make: 'BMW',
        model: '740Li',
        plate: 'AA 001 ED',
        color: 'E zezë',
        categoryId: 'luxury',
      ),
    ),
    (
      'Sokol Meta',
      Vehicle(
        make: 'Audi',
        model: 'A8',
        plate: 'AC 350 SM',
        color: 'Gri e errët',
        categoryId: 'luxury',
      ),
    ),
    (
      'Genti Beqiri',
      Vehicle(
        make: 'Mercedes-Benz',
        model: 'Vito',
        plate: 'AB 560 GB',
        color: 'E bardhë',
        categoryId: 'van',
        seats: 7,
      ),
    ),
    (
      'Mirela Duka',
      Vehicle(
        make: 'Volkswagen',
        model: 'Transporter',
        plate: 'AD 212 MD',
        color: 'Argjendi',
        categoryId: 'van',
        seats: 7,
      ),
    ),
  ];

  List<Driver> _makePool(LatLng center) {
    return [
      for (var i = 0; i < _driverSeeds.length; i++)
        Driver(
          id: 'driver-$i',
          name: _driverSeeds[i].$1,
          phone: '+3556912345${(10 + i).toString()}',
          rating: 4.6 + _rng.nextInt(5) / 10,
          trips: 300 + _rng.nextInt(2500),
          vehicle: _driverSeeds[i].$2,
          location: _offset(center, 0.4 + _rng.nextDouble() * 2.2),
          heading: _rng.nextDouble() * 360,
        ),
    ];
  }

  LatLng _offset(LatLng c, double km) {
    final angle = _rng.nextDouble() * 2 * math.pi;
    final dLat = km * math.cos(angle) / 111.0;
    final dLng = km * math.sin(angle) / (111.0 * math.cos(c.latitudeInRad));
    return LatLng(c.latitude + dLat, c.longitude + dLng);
  }

  void _ensurePool(LatLng around) {
    const d = Distance();
    if (d.as(LengthUnit.Kilometer, _poolCenter, around) > 3) {
      _pool = _makePool(around);
      _poolCenter = around;
    }
  }

  @override
  Stream<List<Driver>> watchNearbyDrivers(LatLng around) {
    _ensurePool(around);
    late StreamController<List<Driver>> ctrl;
    Timer? timer;
    ctrl = StreamController<List<Driver>>(
      onListen: () {
        ctrl.add(List.of(_pool));
        timer = Timer.periodic(_d(2500), (_) {
          _pool = [for (final dr in _pool) _wander(dr)];
          ctrl.add(List.of(_pool));
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return ctrl.stream;
  }

  Driver _wander(Driver dr) {
    final next = _offset(dr.location, 0.02 + _rng.nextDouble() * 0.04);
    return dr.copyWith(
      location: next,
      heading: RoutingService.bearing(dr.location, next),
    );
  }

  @override
  Future<RideRequest> createRequest({
    required Place pickup,
    required Place destination,
    required RouteInfo route,
    required String categoryId,
    required int offeredFare,
    required PaymentType payment,
  }) async {
    _ensurePool(pickup.point);
    final req = RideRequest(
      id: _id('req'),
      passengerId: currentUserId,
      passengerName: _user?.name ?? '',
      pickup: pickup,
      destination: destination,
      route: route,
      categoryId: categoryId,
      offeredFare: offeredFare,
      payment: payment,
      createdAt: DateTime.now(),
    );
    _requests[req.id] = req;
    _offers[req.id] = [];
    _offerCtrls[req.id] = StreamController<List<RideOffer>>.broadcast();
    _requestTimers[req.id] = [];
    _scheduleOffer(req.id, 3500);
    return req;
  }

  void _scheduleOffer(String reqId, int delayMs) {
    final t = Timer(_d(delayMs), () {
      final req = _requests[reqId];
      if (req == null || req.status != RequestStatus.searching) return;
      final all = _offers[reqId]!;
      final pending = all
          .where((o) => o.status == OfferStatus.pending)
          .toList();
      final pendingIds = pending.map((o) => o.driver.id).toSet();
      final tried = all.map((o) => o.driver.id).toSet();
      var candidates = _pool
          .where(
            (d) =>
                d.vehicle.categoryId == req.categoryId && !tried.contains(d.id),
          )
          .toList();
      if (candidates.isEmpty) {
        candidates = _pool
            .where(
              (d) =>
                  d.vehicle.categoryId == req.categoryId &&
                  !pendingIds.contains(d.id),
            )
            .toList();
      }
      if (pending.length < 3 && candidates.isNotEmpty) {
        final driver = candidates[_rng.nextInt(candidates.length)];
        const bumps = [0, 0, 50, 100, 150, 200, 300];
        final offer = RideOffer(
          id: _id('offer'),
          requestId: reqId,
          driver: driver,
          price: req.offeredFare + bumps[_rng.nextInt(bumps.length)],
          etaMinutes: RoutingService.etaMinutes(
            driver.location,
            req.pickup.point,
          ),
          createdAt: DateTime.now(),
        );
        all.add(offer);
        _emitOffers(reqId);
        _requestTimers[reqId]!.add(
          Timer(_d(AppConfig.offerTimeoutSeconds * 1000), () {
            _setOfferStatus(offer, OfferStatus.expired);
          }),
        );
      }
      _scheduleOffer(reqId, 5000 + _rng.nextInt(4000));
    });
    _requestTimers[reqId]?.add(t);
  }

  void _emitOffers(String reqId) {
    final ctrl = _offerCtrls[reqId];
    if (ctrl == null || ctrl.isClosed) return;
    ctrl.add(_pendingOffers(reqId));
  }

  List<RideOffer> _pendingOffers(String reqId) => (_offers[reqId] ?? const [])
      .where((o) => o.status == OfferStatus.pending)
      .toList();

  void _setOfferStatus(RideOffer offer, OfferStatus status) {
    final list = _offers[offer.requestId];
    if (list == null) return;
    final i = list.indexWhere((o) => o.id == offer.id);
    if (i < 0 || list[i].status != OfferStatus.pending) return;
    final o = list[i];
    list[i] = RideOffer(
      id: o.id,
      requestId: o.requestId,
      driver: o.driver,
      price: o.price,
      etaMinutes: o.etaMinutes,
      createdAt: o.createdAt,
      status: status,
    );
    _emitOffers(offer.requestId);
  }

  @override
  Stream<List<RideOffer>> watchOffers(String requestId) async* {
    yield _pendingOffers(requestId);
    final ctrl = _offerCtrls[requestId];
    if (ctrl != null) yield* ctrl.stream;
  }

  @override
  Future<void> declineOffer(RideOffer offer) async =>
      _setOfferStatus(offer, OfferStatus.declined);

  void _closeRequest(String reqId, RequestStatus status) {
    final req = _requests[reqId];
    if (req == null) return;
    _requests[reqId] = RideRequest(
      id: req.id,
      passengerId: req.passengerId,
      passengerName: req.passengerName,
      pickup: req.pickup,
      destination: req.destination,
      route: req.route,
      categoryId: req.categoryId,
      offeredFare: req.offeredFare,
      payment: req.payment,
      createdAt: req.createdAt,
      status: status,
    );
    for (final t in _requestTimers.remove(reqId) ?? const <Timer>[]) {
      t.cancel();
    }
    _offerCtrls.remove(reqId)?.close();
  }

  @override
  Future<Ride> acceptOffer(RideOffer offer) async {
    final req = _requests[offer.requestId];
    if (req == null || req.status != RequestStatus.searching) {
      throw const BackendException('request_closed');
    }
    final current = _offers[offer.requestId]!.firstWhere(
      (o) => o.id == offer.id,
    );
    if (current.status != OfferStatus.pending) {
      throw const BackendException('offer_expired');
    }
    _setOfferStatus(offer, OfferStatus.accepted);
    _closeRequest(req.id, RequestStatus.accepted);
    final leg = await _routing.route(offer.driver.location, req.pickup.point);
    final ride = Ride(
      id: _id('ride'),
      request: _requests[req.id]!,
      driver: offer.driver,
      price: offer.price,
      status: RideStatus.driverOnTheWay,
      etaMinutes: offer.etaMinutes,
      createdAt: DateTime.now(),
    );
    _rides[ride.id] = ride;
    _rideCtrls[ride.id] = StreamController<Ride>.broadcast();
    _rideTimers[ride.id] = [];
    _runLeg(
      ride.id,
      leg,
      RideStatus.driverOnTheWay,
      onDone: () {
        _patchRide(
          ride.id,
          (r) => r.copyWith(
            status: RideStatus.driverArrived,
            etaMinutes: 0,
            progress: 1,
          ),
        );
        // The simulated driver waits a moment, then starts the trip.
        _rideTimers[ride.id]?.add(
          Timer(_d(8000), () => _startTrip(ride.id, autoComplete: true)),
        );
      },
    );
    return ride;
  }

  void _startTrip(String rideId, {required bool autoComplete}) {
    final ride = _rides[rideId];
    if (ride == null || ride.status == RideStatus.cancelled) return;
    final route = ride.request.route;
    _patchRide(
      rideId,
      (r) => r.copyWith(
        status: RideStatus.inProgress,
        progress: 0,
        etaMinutes: route.durationMin.ceil(),
      ),
    );
    _runLeg(
      rideId,
      route,
      RideStatus.inProgress,
      onDone: () {
        if (autoComplete) _completeRide(rideId);
      },
    );
  }

  void _completeRide(String rideId) {
    final ride = _patchRide(
      rideId,
      (r) =>
          r.copyWith(status: RideStatus.completed, progress: 1, etaMinutes: 0),
    );
    if (ride == null) return;
    _stopRideTimers(rideId);
    if (ride.id == _driverRideId) {
      _driverCompleted.insert(0, ride);
    } else {
      _history.insert(0, ride);
    }
  }

  /// Moves the driver along [leg] one step per second. Demo trips are
  /// compressed to 15–40 seconds so a full ride can be shown in a meeting.
  void _runLeg(
    String rideId,
    RouteInfo leg,
    RideStatus legStatus, {
    required void Function() onDone,
  }) {
    final totalTicks = (leg.durationMin * 3).clamp(15, 40).round();
    var tick = 0;
    final timer = Timer.periodic(_d(1000), (t) {
      final ride = _rides[rideId];
      if (ride == null || ride.status != legStatus) {
        t.cancel();
        return;
      }
      tick++;
      final p = (tick / totalTicks).clamp(0.0, 1.0);
      final pos = RoutingService.pointAlong(leg.points, p);
      final heading = pos == ride.driver.location
          ? ride.driver.heading
          : RoutingService.bearing(ride.driver.location, pos);
      _patchRide(
        rideId,
        (r) => r.copyWith(
          driver: r.driver.copyWith(location: pos, heading: heading),
          progress: p,
          etaMinutes: (leg.durationMin * (1 - p)).ceil(),
        ),
      );
      if (legStatus == RideStatus.driverOnTheWay && rideId == _driverRideId) {
        _driverLoc = pos;
      }
      if (tick >= totalTicks) {
        t.cancel();
        onDone();
      }
    });
    _rideTimers[rideId]?.add(timer);
  }

  Ride? _patchRide(String rideId, Ride Function(Ride) f) {
    final ride = _rides[rideId];
    if (ride == null) return null;
    final next = f(ride);
    _rides[rideId] = next;
    final ctrl = _rideCtrls[rideId];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(next);
    if (rideId == _driverRideId) _driverRideCtrl.add(next);
    return next;
  }

  void _stopRideTimers(String rideId) {
    for (final t in _rideTimers[rideId] ?? const <Timer>[]) {
      t.cancel();
    }
    _rideTimers[rideId]?.clear();
  }

  @override
  Future<void> cancelRequest(String requestId) async =>
      _closeRequest(requestId, RequestStatus.cancelled);

  @override
  Stream<Ride> watchRide(String rideId) async* {
    final ride = _rides[rideId];
    if (ride == null) return;
    yield ride;
    yield* _rideCtrls[rideId]!.stream;
  }

  @override
  Future<void> cancelRide(String rideId, String reason) async {
    _stopRideTimers(rideId);
    final ride = _patchRide(
      rideId,
      (r) => r.copyWith(status: RideStatus.cancelled, cancelReason: reason),
    );
    if (ride != null && ride.id != _driverRideId) _history.insert(0, ride);
  }

  @override
  Future<void> rateRide(
    String rideId, {
    required int stars,
    int tip = 0,
    String comment = '',
  }) async {
    _patchRide(rideId, (r) => r.copyWith(rating: stars, tip: tip));
    final i = _history.indexWhere((r) => r.id == rideId);
    if (i >= 0) _history[i] = _rides[rideId]!;
  }

  @override
  Future<int> promoDiscount(String code) async {
    final firstRide = _history.every((r) => r.id.startsWith('past-'));
    return code.trim().toUpperCase() == AppConfig.promoCode && firstRide
        ? AppConfig.promoPercent
        : 0;
  }

  @override
  Future<Ride?> activeRide() async {
    for (final r in _rides.values) {
      if (r.isActive && r.id != _driverRideId) return r;
    }
    return null;
  }

  @override
  Future<List<Ride>> rideHistory() async => List.of(_history);

  void _seedHistory() {
    Ride past(
      int daysAgo,
      int from,
      int to,
      int driver,
      int price,
      int rating,
    ) {
      final a = AlbanianPlaces.all[from];
      final b = AlbanianPlaces.all[to];
      final route = RoutingService.estimate(a.point, b.point);
      final d = _pool[driver];
      final at = DateTime.now().subtract(
        Duration(days: daysAgo, hours: 2 + driver),
      );
      return Ride(
        id: 'past-$daysAgo-$from',
        request: RideRequest(
          id: 'past-req-$daysAgo',
          passengerId: 'demo-user',
          passengerName: '',
          pickup: a,
          destination: b,
          route: route,
          categoryId: d.vehicle.categoryId,
          offeredFare: price,
          payment: PaymentType.cash,
          createdAt: at,
          status: RequestStatus.accepted,
        ),
        driver: d,
        price: price,
        status: RideStatus.completed,
        etaMinutes: 0,
        progress: 1,
        createdAt: at,
        rating: rating,
      );
    }

    _history.addAll([
      past(1, 1, 2, 0, 2500, 5),
      past(3, 0, 4, 2, 900, 5),
      past(6, 3, 12, 5, 1600, 4),
    ]);
  }

  // =================================================================== chat

  static const _cannedReplies = [
    'Në rregull, po vij!',
    'Jam afër, rreth 2 minuta.',
    'Ju pres te hyrja kryesore.',
    'Faleminderit!',
  ];

  @override
  Stream<List<ChatMessage>> watchMessages(String rideId) async* {
    final ctrl = _msgCtrls.putIfAbsent(
      rideId,
      StreamController<List<ChatMessage>>.broadcast,
    );
    yield List.of(_messages[rideId] ?? const []);
    yield* ctrl.stream;
  }

  @override
  Future<void> sendMessage(String rideId, String text) async {
    _addMessage(rideId, currentUserId, text);
    final ride = _rides[rideId];
    final peer = ride == null
        ? 'peer'
        : (ride.id == _driverRideId
              ? ride.request.passengerId
              : ride.driver.id);
    final reply = _cannedReplies[_replyIndex++ % _cannedReplies.length];
    Timer(_d(2500), () => _addMessage(rideId, peer, reply));
  }

  void _addMessage(String rideId, String sender, String text) {
    final list = _messages.putIfAbsent(rideId, () => []);
    list.add(
      ChatMessage(
        id: _id('msg'),
        rideId: rideId,
        senderId: sender,
        text: text,
        sentAt: DateTime.now(),
      ),
    );
    _msgCtrls
        .putIfAbsent(rideId, StreamController<List<ChatMessage>>.broadcast)
        .add(List.of(list));
  }

  // ================================================================= driver

  @override
  Future<Vehicle?> myVehicle() async => _vehicle;

  @override
  Future<void> saveVehicle(Vehicle vehicle) async {
    _vehicle = vehicle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsVehicle,
      jsonEncode({
        'make': vehicle.make,
        'model': vehicle.model,
        'plate': vehicle.plate,
        'color': vehicle.color,
        'categoryId': vehicle.categoryId,
        'seats': vehicle.seats,
      }),
    );
  }

  @override
  Future<void> setOnline(bool online, LatLng location) async {
    _online = online;
    _driverLoc = location;
    _requestGenerator?.cancel();
    if (online) {
      _requestGenerator = Timer(_d(2500), _generateRequest);
    } else {
      _incoming.clear();
      _incomingCtrl.add(const []);
    }
  }

  @override
  Future<void> pushLocation(LatLng location, double heading) async {
    if (_driverRideId == null) _driverLoc = location;
  }

  static const _streets = [
    'Rruga e Kavajës',
    'Rruga Myslym Shyri',
    'Bulevardi Zogu I',
    'Rruga e Durrësit',
    'Rruga Sami Frashëri',
    'Rruga Ismail Qemali',
    'Rruga e Elbasanit',
    'Rruga Frosina Plaku',
    'Rruga Budi',
  ];
  static const _passengers = [
    'Ardit K.',
    'Ledia M.',
    'Kejsi B.',
    'Endri H.',
    'Megi S.',
    'Alban P.',
    'Sara D.',
    'Flori T.',
  ];

  void _generateRequest() {
    if (!_online) return;
    if (_driverRideId == null && _incoming.length < 3) {
      final category = _vehicle?.categoryId ?? 'standard';
      final pickupPoint = _offset(_driverLoc, 0.3 + _rng.nextDouble() * 1.8);
      final pickup = Place(
        '${_streets[_rng.nextInt(_streets.length)]} ${1 + _rng.nextInt(120)}',
        AlbanianPlaces.cityFor(pickupPoint),
        pickupPoint,
      );
      final destinations = AlbanianPlaces.all.take(16).toList();
      final dest = destinations[_rng.nextInt(destinations.length)];
      final route = RoutingService.estimate(pickup.point, dest.point);
      final fare = Pricing.estimate(
        Pricing.byId(category),
        route.distanceKm,
        route.durationMin,
        airport: dest.name.contains('Aeroport'),
      );
      final req = RideRequest(
        id: _id('inreq'),
        passengerId: 'passenger-${_rng.nextInt(1000)}',
        passengerName: _passengers[_rng.nextInt(_passengers.length)],
        passengerRating: 4.5 + _rng.nextInt(6) / 10,
        pickup: pickup,
        destination: dest,
        route: route,
        categoryId: category,
        offeredFare: fare,
        payment: _rng.nextInt(4) == 0 ? PaymentType.card : PaymentType.cash,
        createdAt: DateTime.now(),
      );
      _incoming[req.id] = req;
      _incomingCtrl.add(_incoming.values.toList());
      Timer(_d(40000), () {
        if (_incoming.remove(req.id) != null) {
          _incomingCtrl.add(_incoming.values.toList());
        }
      });
    }
    _requestGenerator = Timer(_d(7000 + _rng.nextInt(5000)), _generateRequest);
  }

  @override
  Stream<List<RideRequest>> watchIncomingRequests(LatLng around) async* {
    yield _incoming.values.toList();
    yield* _incomingCtrl.stream;
  }

  @override
  Future<void> sendOffer(RideRequest request, int price, int etaMinutes) async {
    // Like the real server: the call returns at once, the passenger decides
    // a few seconds later. Accepted -> watchDriverActiveRide emits the ride;
    // otherwise the request just disappears from the incoming list.
    Timer(_d(2500 + _rng.nextInt(2000)), () async {
      if (!_incoming.containsKey(request.id) || _driverRideId != null) return;
      final generous = price <= request.offeredFare + 200;
      final accepted = _rng.nextDouble() < (generous ? 0.8 : 0.35);
      _incoming.remove(request.id);
      if (accepted) {
        final me = _user;
        final vehicle =
            _vehicle ??
            const Vehicle(
              make: 'Mercedes-Benz',
              model: 'E 220d',
              plate: 'AA 000 AA',
              color: 'E zezë',
              categoryId: 'standard',
            );
        final ride = Ride(
          id: _id('ride'),
          request: request,
          driver: Driver(
            id: currentUserId,
            name: me?.name ?? 'Shofer',
            phone: me?.phone ?? '',
            rating: 4.9,
            trips: 120 + _driverCompleted.length,
            vehicle: vehicle,
            location: _driverLoc,
          ),
          price: price,
          status: RideStatus.driverOnTheWay,
          etaMinutes: etaMinutes,
          createdAt: DateTime.now(),
        );
        _rides[ride.id] = ride;
        _rideCtrls[ride.id] = StreamController<Ride>.broadcast();
        _rideTimers[ride.id] = [];
        _driverRideId = ride.id;
        _driverRideCtrl.add(ride);
        _incoming.clear();
        _incomingCtrl.add(const []);
        final leg = await _routing.route(_driverLoc, request.pickup.point);
        _runLeg(ride.id, leg, RideStatus.driverOnTheWay, onDone: () {});
      } else {
        _incomingCtrl.add(_incoming.values.toList());
      }
    });
  }

  @override
  Stream<Ride?> watchDriverActiveRide() async* {
    yield _driverRideId == null ? null : _rides[_driverRideId];
    yield* _driverRideCtrl.stream;
  }

  @override
  Future<void> updateRideStatus(String rideId, RideStatus status) async {
    switch (status) {
      case RideStatus.driverArrived:
        _stopRideTimers(rideId);
        _patchRide(
          rideId,
          (r) => r.copyWith(
            status: RideStatus.driverArrived,
            progress: 1,
            etaMinutes: 0,
            driver: r.driver.copyWith(location: r.request.pickup.point),
          ),
        );
      case RideStatus.inProgress:
        _startTrip(rideId, autoComplete: false);
      case RideStatus.completed:
        _patchRide(
          rideId,
          (r) => r.copyWith(
            driver: r.driver.copyWith(location: r.request.destination.point),
          ),
        );
        _driverLoc = _rides[rideId]?.request.destination.point ?? _driverLoc;
        _completeRide(rideId);
        _driverRideId = null;
        _driverRideCtrl.add(null);
      case RideStatus.cancelled:
        await cancelRide(rideId, 'driver_cancelled');
        _driverRideId = null;
        _driverRideCtrl.add(null);
      case RideStatus.driverOnTheWay:
        break;
    }
  }

  @override
  Future<DriverEarnings> earnings() async {
    final now = DateTime.now();
    final today = _driverCompleted
        .where((r) => _sameDay(r.createdAt, now))
        .toList();
    final sessionToday = today.fold<int>(0, (s, r) => s + r.price + r.tip);
    final sessionAll = _driverCompleted.fold<int>(
      0,
      (s, r) => s + r.price + r.tip,
    );
    // Some history so the dashboard is not empty in a demo.
    return DriverEarnings(
      today: 4800 + sessionToday,
      week: 38650 + sessionAll,
      tripsToday: 6 + today.length,
      tripsWeek: 47 + _driverCompleted.length,
      onlineHoursToday: 5.5,
      recent: List.of(_driverCompleted),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _requestGenerator?.cancel();
    for (final list in _requestTimers.values) {
      for (final t in list) {
        t.cancel();
      }
    }
    for (final id in _rideTimers.keys.toList()) {
      _stopRideTimers(id);
    }
  }
}
