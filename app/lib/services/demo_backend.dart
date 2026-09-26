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

/// A fully simulated backend. Owners answer booking requests (accepting, or
/// counter-offering when the renter offers less); in owner mode, simulated
/// renters send requests for your cars. Nothing leaves the phone, so this is
/// ideal for sales demos and for development.
class DemoBackend implements Backend {
  DemoBackend({this.speed = 1.0, int seed = 7}) : _rng = math.Random(seed) {
    _cars.addAll(_seedCars());
    _seedHistory();
  }

  /// >1 makes every simulated delay shorter (used by tests).
  final double speed;
  final math.Random _rng;

  Duration _d(int ms) =>
      Duration(milliseconds: math.max(1, (ms / speed).round()));

  UserProfile? _user;
  var _idSeq = 0;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${++_idSeq}';

  final _cars = <Car>[];
  final _bookings = <String, Booking>{};
  final _bookingCtrls = <String, StreamController<Booking>>{};
  final _ownerCtrl = StreamController<List<Booking>>.broadcast();
  final _timers = <Timer>[];

  final _messages = <String, List<ChatMessage>>{};
  final _msgCtrls = <String, StreamController<List<ChatMessage>>>{};
  var _replyIndex = 0;
  Timer? _renterGenerator;

  @override
  bool get isDemo => true;

  @override
  String get currentUserId => _user?.id ?? 'demo-user';

  void _later(int ms, void Function() f) => _timers.add(Timer(_d(ms), f));

  // ================================================================== auth

  static const _prefsUser = 'demo_user';
  static const _prefsCars = 'demo_my_cars';

  @override
  Future<UserProfile?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCars = prefs.getString(_prefsCars);
    if (rawCars != null) {
      try {
        final mine = [
          for (final j in jsonDecode(rawCars) as List)
            carFromJson(j as Map<String, dynamic>),
        ];
        _cars.removeWhere((c) => mine.any((m) => m.id == c.id));
        _cars.addAll(mine);
      } catch (_) {
        await prefs.remove(_prefsCars);
      }
    }
    final raw = prefs.getString(_prefsUser);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _user = UserProfile(
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: j['name'] as String,
        role: UserRole.values.byName(j['role'] as String),
      );
      _startRenterGenerator();
      return _user;
    } catch (_) {
      // Data saved by an older version of the app: start fresh.
      await prefs.remove(_prefsUser);
      return null;
    }
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
    _startRenterGenerator();
    return user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _renterGenerator?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUser);
  }

  // ============================================================ demo data

  static Car _car(
    int i,
    String owner,
    String make,
    String model,
    int year,
    String plate,
    int color,
    String category,
    Transmission t,
    Fuel f,
    int perDay,
    int placeIndex, {
    int seats = 5,
    bool delivery = false,
    int deliveryFee = 0,
    int minDays = 1,
    double rating = 4.8,
    int trips = 40,
    String description = '',
  }) {
    final landmark = AlbanianPlaces.all[placeIndex];
    // Park each car 150-400 m from the landmark so map pins don't overlap.
    final angle = i * 2.4;
    final metres = 150.0 + (i * 37) % 250;
    final p = Place(
      landmark.name,
      landmark.subtitle,
      LatLng(
        landmark.point.latitude + metres * math.cos(angle) / 111000,
        landmark.point.longitude +
            metres *
                math.sin(angle) /
                (111000 * math.cos(landmark.point.latitudeInRad)),
      ),
    );
    return Car(
      id: 'car-$i',
      ownerId: 'owner-$i',
      ownerName: owner,
      ownerPhone: '+3556912345${10 + i}',
      ownerRating: rating,
      make: make,
      model: model,
      year: year,
      plate: plate,
      colorValue: color,
      categoryId: category,
      transmission: t,
      fuel: f,
      seats: seats,
      pricePerDay: perDay,
      deposit: Pricing.byId(category).suggestedDeposit,
      location: p,
      delivery: delivery,
      deliveryFee: deliveryFee,
      minDays: minDays,
      description: description,
      rating: rating,
      trips: trips,
    );
  }

  static List<Car> _seedCars() => [
    _car(
      1,
      'Arben Hoxha',
      'Volkswagen',
      'Golf 7',
      2018,
      'AA 482 TR',
      0xFF3F4A5A,
      'economy',
      Transmission.manual,
      Fuel.diesel,
      3000,
      1,
      delivery: true,
      deliveryFee: 500,
      trips: 86,
      description: 'Makinë e mirëmbajtur, ideale për qytetin. Konsum i ulët.',
    ),
    _car(
      2,
      'Elira Kola',
      'Toyota',
      'Yaris Hybrid',
      2020,
      'AB 915 KL',
      0xFFE8E8EA,
      'economy',
      Transmission.automatic,
      Fuel.hybrid,
      3500,
      3,
      rating: 4.9,
      trips: 124,
      description:
          'Automatike dhe hibride, shumë ekonomike në trafikun e Tiranës.',
    ),
    _car(
      3,
      'Dritan Shehu',
      'Fiat',
      '500',
      2019,
      'AC 237 DS',
      0xFFD9453B,
      'economy',
      Transmission.manual,
      Fuel.petrol,
      2500,
      13,
      rating: 4.7,
      trips: 51,
    ),
    _car(
      4,
      'Besnik Leka',
      'Skoda',
      'Octavia',
      2019,
      'AA 118 BL',
      0xFF9AA3AE,
      'economy',
      Transmission.manual,
      Fuel.diesel,
      3200,
      4,
      trips: 67,
      description: 'Bagazh i madh, perfekte për udhëtime në jug.',
    ),
    _car(
      5,
      'Klajdi Muça',
      'Hyundai',
      'Tucson',
      2021,
      'AD 604 KM',
      0xFF1F5AA6,
      'suv',
      Transmission.automatic,
      Fuel.diesel,
      5500,
      14,
      delivery: true,
      deliveryFee: 800,
      trips: 38,
    ),
    _car(
      6,
      'Anxhela Gjoka',
      'Toyota',
      'RAV4 Hybrid',
      2022,
      'AB 777 AG',
      0xFFF4F4F4,
      'suv',
      Transmission.automatic,
      Fuel.hybrid,
      6500,
      6,
      rating: 5.0,
      trips: 29,
    ),
    _car(
      7,
      'Sokol Meta',
      'Dacia',
      'Duster 4x4',
      2020,
      'AC 350 SM',
      0xFF6E7B3A,
      'suv',
      Transmission.manual,
      Fuel.diesel,
      4200,
      2,
      delivery: true,
      deliveryFee: 0,
      trips: 93,
      description: 'E marr dhe e dorëzoj në aeroportin e Rinasit pa pagesë. 4x4 për malet.',
    ),
    _car(
      8,
      'Erion Dervishi',
      'Mercedes-Benz',
      'E 220d',
      2021,
      'AA 001 ED',
      0xFF16181D,
      'luxury',
      Transmission.automatic,
      Fuel.diesel,
      11000,
      1,
      minDays: 2,
      rating: 4.9,
      trips: 22,
    ),
    _car(
      9,
      'Genti Beqiri',
      'BMW',
      'X5',
      2022,
      'AB 560 GB',
      0xFF2C3E50,
      'luxury',
      Transmission.automatic,
      Fuel.diesel,
      15000,
      2,
      delivery: true,
      deliveryFee: 1500,
      minDays: 2,
      trips: 17,
    ),
    _car(
      10,
      'Mirela Duka',
      'Mercedes-Benz',
      'Vito',
      2019,
      'AD 212 MD',
      0xFFE9EBEF,
      'van',
      Transmission.manual,
      Fuel.diesel,
      7500,
      8,
      seats: 8,
      trips: 45,
      description: '8 vende, ideale për familje ose grupe.',
    ),
    _car(
      11,
      'Ilir Kapllani',
      'Opel',
      'Corsa',
      2018,
      'DR 311 IK',
      0xFF3B7DD8,
      'economy',
      Transmission.manual,
      Fuel.petrol,
      2600,
      16,
      trips: 58,
    ),
    _car(
      12,
      'Ermira Luli',
      'Kia',
      'Sportage',
      2021,
      'DR 902 EL',
      0xFF8C1C2B,
      'suv',
      Transmission.automatic,
      Fuel.diesel,
      5000,
      16,
      delivery: true,
      deliveryFee: 600,
      trips: 31,
    ),
    _car(
      13,
      'Luan Brahimi',
      'Renault',
      'Clio',
      2019,
      'VL 145 LB',
      0xFFF2F2F2,
      'economy',
      Transmission.manual,
      Fuel.diesel,
      2800,
      20,
      trips: 74,
    ),
    _car(
      14,
      'Marsela Tafa',
      'Jeep',
      'Renegade',
      2020,
      'SR 388 MT',
      0xFF4F6D3A,
      'suv',
      Transmission.automatic,
      Fuel.petrol,
      5200,
      22,
      trips: 26,
    ),
    _car(
      15,
      'Bledi Zeneli',
      'Fiat',
      'Panda',
      2017,
      'SR 074 BZ',
      0xFFF6C744,
      'economy',
      Transmission.manual,
      Fuel.petrol,
      2400,
      23,
      trips: 112,
    ),
  ];

  static const _renters = [
    ('Ardit Kola', 4.9),
    ('Ledia Marku', 4.8),
    ('Kejsi Bala', 5.0),
    ('Endri Hasa', 4.7),
    ('Megi Shkurti', 4.9),
    ('Alban Prifti', 4.6),
    ('Sara Dema', 5.0),
    ('Flori Tanushi', 4.8),
  ];

  void _seedHistory() {
    final now = DateTime.now();
    Booking past(int daysAgo, int carIndex, int days, int rating) {
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        10,
      ).subtract(Duration(days: daysAgo));
      final car = _cars[carIndex];
      return Booking(
        id: 'past-$daysAgo',
        car: car,
        renterId: 'demo-user',
        renterName: '',
        start: start,
        end: start.add(Duration(days: days)),
        offeredPerDay: car.pricePerDay,
        agreedPerDay: car.pricePerDay,
        status: BookingStatus.completed,
        payment: PaymentType.cash,
        createdAt: start.subtract(const Duration(days: 3)),
        rating: rating,
      );
    }

    for (final b in [past(12, 1, 3, 5), past(40, 6, 5, 5)]) {
      _bookings[b.id] = b;
    }
  }

  static bool _overlaps(Booking b, DateTime start, DateTime end) =>
      b.start.isBefore(end) && start.isBefore(b.end);

  bool _isFree(Car car, DateTime start, DateTime end, {String? ignore}) =>
      !_bookings.values.any(
        (b) =>
            b.id != ignore &&
            b.car.id == car.id &&
            b.isUpcomingOrActive &&
            _overlaps(b, start, end),
      );

  // ============================================================== renter

  @override
  Future<List<Car>> searchCars({
    required LatLng near,
    required DateTime start,
    required DateTime end,
    String? categoryId,
  }) async {
    await Future.delayed(_d(400));
    const d = Distance();
    final found =
        _cars
            .where(
              (c) =>
                  c.listed &&
                  c.ownerId != currentUserId &&
                  (categoryId == null || c.categoryId == categoryId) &&
                  d.as(LengthUnit.Kilometer, near, c.location.point) <=
                      AppConfig.searchRadiusKm &&
                  _isFree(c, start, end),
            )
            .toList()
          ..sort(
            (a, b) => d
                .as(LengthUnit.Meter, near, a.location.point)
                .compareTo(d.as(LengthUnit.Meter, near, b.location.point)),
          );
    return found;
  }

  @override
  Future<Booking> requestBooking({
    required Car car,
    required DateTime start,
    required DateTime end,
    required int offeredPerDay,
    required Pickup pickup,
    required PaymentType payment,
    String deliveryAddress = '',
    String note = '',
    String promoCode = '',
  }) async {
    await Future.delayed(_d(500));
    final promo = promoCode.isEmpty ? 0 : await promoDiscount(promoCode);
    if (car.ownerId == currentUserId) {
      throw const BackendException('own_car');
    }
    if (!end.isAfter(start)) throw const BackendException('invalid_dates');
    final booking = Booking(
      id: _id('bk'),
      car: car,
      renterId: currentUserId,
      renterName: _user?.name ?? '',
      renterPhone: _user?.phone ?? '',
      start: start,
      end: end,
      offeredPerDay: offeredPerDay,
      status: BookingStatus.requested,
      pickup: pickup,
      deliveryAddress: deliveryAddress,
      payment: payment,
      note: note,
      promoPercent: promo,
      createdAt: DateTime.now(),
    );
    if (booking.days < car.minDays) {
      throw const BackendException('min_days');
    }
    if (offeredPerDay < Pricing.minOffer(car.pricePerDay)) {
      throw const BackendException('offer_too_low');
    }
    if (!_isFree(car, start, end)) {
      throw const BackendException('car_unavailable');
    }
    _emit(booking);
    _simulateOwner(booking.id);
    return booking;
  }

  /// A simulated owner answers after a few seconds.
  void _simulateOwner(String bookingId) {
    _later(4000 + _rng.nextInt(3000), () {
      final b = _bookings[bookingId];
      if (b == null || b.status != BookingStatus.requested) return;
      final listed = b.car.pricePerDay;
      final ratio = b.offeredPerDay / listed;
      if (!_isFree(b.car, b.start, b.end, ignore: b.id)) {
        _emit(b.copyWith(status: BookingStatus.declined));
      } else if (ratio >= 1 || (ratio >= 0.9 && _rng.nextBool())) {
        _emit(
          b.copyWith(
            status: BookingStatus.confirmed,
            agreedPerDay: b.offeredPerDay,
          ),
        );
      } else {
        final counter = Pricing.roundDaily((b.offeredPerDay + listed) / 2);
        _emit(
          b.copyWith(
            status: BookingStatus.countered,
            counterPerDay: math.max(counter, b.offeredPerDay + 100),
          ),
        );
      }
    });
  }

  @override
  Future<void> acceptCounter(String bookingId) async {
    final b = _require(bookingId);
    if (b.status != BookingStatus.countered || b.renterId != currentUserId) {
      throw const BackendException('not_allowed');
    }
    if (!_isFree(b.car, b.start, b.end, ignore: b.id)) {
      _emit(b.copyWith(status: BookingStatus.expired));
      throw const BackendException('car_unavailable');
    }
    _emit(
      b.copyWith(
        status: BookingStatus.confirmed,
        agreedPerDay: b.counterPerDay,
      ),
    );
  }

  @override
  Future<int> promoDiscount(String code) async {
    final usedBefore = _bookings.values.any(
      (b) =>
          b.renterId == currentUserId &&
          b.status == BookingStatus.completed &&
          !b.id.startsWith('past-'),
    );
    return code.trim().toUpperCase() == AppConfig.promoCode && !usedBefore
        ? AppConfig.promoPercent
        : 0;
  }

  // ============================================================== shared

  Booking _require(String id) {
    final b = _bookings[id];
    if (b == null) throw const BackendException('not_found');
    return b;
  }

  bool _involvesMe(Booking b) =>
      b.renterId == currentUserId || b.car.ownerId == currentUserId;

  void _emit(Booking b) {
    _bookings[b.id] = b;
    final ctrl = _bookingCtrls[b.id];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(b);
    if (b.car.ownerId == currentUserId) _ownerCtrl.add(_ownerBookings());
  }

  List<Booking> _ownerBookings() =>
      _bookings.values.where((b) => b.car.ownerId == currentUserId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<Booking> watchBooking(String bookingId) async* {
    final b = _bookings[bookingId];
    if (b == null) return;
    yield b;
    yield* _bookingCtrls
        .putIfAbsent(bookingId, StreamController<Booking>.broadcast)
        .stream;
  }

  @override
  Future<List<Booking>> myRentals() async =>
      _bookings.values.where((b) => b.renterId == currentUserId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> cancelBooking(String bookingId, String reason) async {
    final b = _require(bookingId);
    if (!_involvesMe(b)) throw const BackendException('not_allowed');
    if (!(b.isOpen || b.status == BookingStatus.confirmed)) {
      throw const BackendException('cannot_cancel');
    }
    _emit(b.copyWith(status: BookingStatus.cancelled, cancelReason: reason));
  }

  @override
  Future<void> markPickedUp(String bookingId) async {
    final b = _require(bookingId);
    if (!_involvesMe(b)) throw const BackendException('not_allowed');
    if (b.status != BookingStatus.confirmed) {
      throw const BackendException('invalid_transition');
    }
    _emit(b.copyWith(status: BookingStatus.active));
  }

  @override
  Future<void> markReturned(String bookingId) async {
    final b = _require(bookingId);
    if (!_involvesMe(b)) throw const BackendException('not_allowed');
    if (b.status != BookingStatus.active) {
      throw const BackendException('invalid_transition');
    }
    _emit(b.copyWith(status: BookingStatus.completed));
  }

  @override
  Future<void> rateBooking(
    String bookingId, {
    required int stars,
    String comment = '',
  }) async {
    final b = _require(bookingId);
    if (b.status != BookingStatus.completed || b.renterId != currentUserId) {
      throw const BackendException('not_allowed');
    }
    _emit(b.copyWith(rating: stars));
  }

  static const _cannedReplies = [
    'Faleminderit! Makina do të jetë gati.',
    'Ju pres te adresa në orën e caktuar.',
    'Çelësat do t\'jua jap personalisht.',
    'Në rregull!',
  ];

  @override
  Stream<List<ChatMessage>> watchMessages(String bookingId) async* {
    final ctrl = _msgCtrls.putIfAbsent(
      bookingId,
      StreamController<List<ChatMessage>>.broadcast,
    );
    yield List.of(_messages[bookingId] ?? const []);
    yield* ctrl.stream;
  }

  @override
  Future<void> sendMessage(String bookingId, String text) async {
    _addMessage(bookingId, currentUserId, text);
    final b = _bookings[bookingId];
    if (b == null) return;
    final peer = b.renterId == currentUserId ? b.car.ownerId : b.renterId;
    final reply = _cannedReplies[_replyIndex++ % _cannedReplies.length];
    _later(2500, () => _addMessage(bookingId, peer, reply));
  }

  void _addMessage(String bookingId, String sender, String text) {
    final list = _messages.putIfAbsent(bookingId, () => []);
    list.add(
      ChatMessage(
        id: _id('msg'),
        threadId: bookingId,
        senderId: sender,
        text: text,
        sentAt: DateTime.now(),
      ),
    );
    _msgCtrls
        .putIfAbsent(bookingId, StreamController<List<ChatMessage>>.broadcast)
        .add(List.of(list));
  }

  // =============================================================== owner

  @override
  Future<List<Car>> myCars() async =>
      _cars.where((c) => c.ownerId == currentUserId).toList();

  @override
  Future<Car> saveCar(Car car) async {
    await Future.delayed(_d(300));
    final saved = car.id.isEmpty
        ? car.copyWith(
            id: _id('car'),
            ownerId: currentUserId,
            ownerName: _user?.name ?? '',
          )
        : car;
    _cars.removeWhere((c) => c.id == saved.id);
    _cars.add(saved);
    await _persistMyCars();
    _startRenterGenerator();
    return saved;
  }

  @override
  Future<void> setListed(String carId, bool listed) async {
    final i = _cars.indexWhere((c) => c.id == carId);
    if (i < 0 || _cars[i].ownerId != currentUserId) return;
    _cars[i] = _cars[i].copyWith(listed: listed);
    await _persistMyCars();
  }

  Future<void> _persistMyCars() async {
    final prefs = await SharedPreferences.getInstance();
    final mine = _cars.where((c) => c.ownerId == currentUserId);
    await prefs.setString(
      _prefsCars,
      jsonEncode([for (final c in mine) carToJson(c)]),
    );
  }

  /// Simulated renters send requests for the owner's listed cars.
  void _startRenterGenerator() {
    _renterGenerator?.cancel();
    if (_user?.role != UserRole.owner) return;
    _renterGenerator = Timer(_d(5000), _generateRequest);
  }

  void _generateRequest() {
    final mine = _cars
        .where((c) => c.ownerId == currentUserId && c.listed)
        .toList();
    final open = _ownerBookings().where((b) => b.isOpen).length;
    if (mine.isNotEmpty && open < 3) {
      final car = mine[_rng.nextInt(mine.length)];
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        10,
      ).add(Duration(days: 1 + _rng.nextInt(10)));
      final days = math.max(car.minDays, 2 + _rng.nextInt(6));
      final renter = _renters[_rng.nextInt(_renters.length)];
      const offers = [1.0, 1.0, 0.95, 0.9, 0.85];
      final delivery = car.delivery && _rng.nextBool();
      final booking = Booking(
        id: _id('bk'),
        car: car,
        renterId: 'renter-${_rng.nextInt(1000)}',
        renterName: renter.$1,
        renterRating: renter.$2,
        renterPhone: '+35568${1000000 + _rng.nextInt(8999999)}',
        start: start,
        end: start.add(Duration(days: days)),
        offeredPerDay: Pricing.roundDaily(
          car.pricePerDay * offers[_rng.nextInt(offers.length)],
        ),
        status: BookingStatus.requested,
        pickup: delivery ? Pickup.delivery : Pickup.atOwner,
        deliveryAddress: delivery
            ? 'Rruga e Kavajës ${1 + _rng.nextInt(120)}, Tiranë'
            : '',
        payment: _rng.nextInt(4) == 0 ? PaymentType.card : PaymentType.cash,
        note: _rng.nextBool()
            ? 'Përshëndetje! E dua për një udhëtim në jug.'
            : '',
        createdAt: DateTime.now(),
      );
      if (_isFree(car, booking.start, booking.end)) _emit(booking);
    }
    _renterGenerator = Timer(_d(12000 + _rng.nextInt(8000)), _generateRequest);
  }

  @override
  Stream<List<Booking>> watchOwnerBookings() async* {
    yield _ownerBookings();
    yield* _ownerCtrl.stream;
  }

  Booking _requireMine(String id) {
    final b = _require(id);
    if (b.car.ownerId != currentUserId) {
      throw const BackendException('not_allowed');
    }
    return b;
  }

  @override
  Future<void> acceptBooking(String bookingId) async {
    final b = _requireMine(bookingId);
    if (b.status != BookingStatus.requested) {
      throw const BackendException('not_allowed');
    }
    if (!_isFree(b.car, b.start, b.end, ignore: b.id)) {
      throw const BackendException('car_unavailable');
    }
    _emit(
      b.copyWith(
        status: BookingStatus.confirmed,
        agreedPerDay: b.offeredPerDay,
      ),
    );
  }

  @override
  Future<void> declineBooking(String bookingId) async {
    final b = _requireMine(bookingId);
    if (!b.isOpen) throw const BackendException('not_allowed');
    _emit(b.copyWith(status: BookingStatus.declined));
  }

  @override
  Future<void> counterBooking(String bookingId, int perDay) async {
    final b = _requireMine(bookingId);
    if (b.status != BookingStatus.requested) {
      throw const BackendException('not_allowed');
    }
    if (perDay <= b.offeredPerDay) {
      throw const BackendException('counter_too_low');
    }
    _emit(b.copyWith(status: BookingStatus.countered, counterPerDay: perDay));
    // The simulated renter usually accepts a fair counter-offer.
    _later(3000 + _rng.nextInt(2000), () {
      final cur = _bookings[bookingId];
      if (cur == null || cur.status != BookingStatus.countered) return;
      final fair = perDay <= cur.car.pricePerDay;
      if (_rng.nextDouble() < (fair ? 0.85 : 0.4) &&
          _isFree(cur.car, cur.start, cur.end, ignore: cur.id)) {
        _emit(
          cur.copyWith(status: BookingStatus.confirmed, agreedPerDay: perDay),
        );
      } else {
        _emit(
          cur.copyWith(
            status: BookingStatus.cancelled,
            cancelReason: 'renter_declined_counter',
          ),
        );
      }
    });
  }

  @override
  Future<OwnerEarnings> earnings() async {
    final now = DateTime.now();
    final done = _ownerBookings()
        .where((b) => b.status == BookingStatus.completed)
        .toList();
    final month = done.where(
      (b) => b.end.year == now.year && b.end.month == now.month,
    );
    int total(Iterable<Booking> list) =>
        list.fold(0, (s, b) => s + Pricing.quoteFor(b).total);
    return OwnerEarnings(
      thisMonth: total(month),
      allTime: total(done),
      rentalsThisMonth: month.length,
      bookedDaysThisMonth: month.fold(0, (s, b) => s + b.days),
      recent: done,
    );
  }

  @override
  void dispose() {
    _renterGenerator?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
  }
}

// Car <-> JSON for the demo's local storage.
Map<String, dynamic> carToJson(Car c) => {
  'id': c.id,
  'ownerId': c.ownerId,
  'ownerName': c.ownerName,
  'make': c.make,
  'model': c.model,
  'year': c.year,
  'plate': c.plate,
  'color': c.colorValue,
  'category': c.categoryId,
  'transmission': c.transmission.name,
  'fuel': c.fuel.name,
  'seats': c.seats,
  'pricePerDay': c.pricePerDay,
  'deposit': c.deposit,
  'location': c.location.toJson(),
  'delivery': c.delivery,
  'deliveryFee': c.deliveryFee,
  'minDays': c.minDays,
  'kmPerDay': c.kmPerDay,
  'description': c.description,
  'listed': c.listed,
};

Car carFromJson(Map<String, dynamic> j) => Car(
  id: j['id'] as String,
  ownerId: j['ownerId'] as String,
  ownerName: j['ownerName'] as String,
  make: j['make'] as String,
  model: j['model'] as String,
  year: j['year'] as int,
  plate: j['plate'] as String,
  colorValue: j['color'] as int,
  categoryId: j['category'] as String,
  transmission: Transmission.values.byName(j['transmission'] as String),
  fuel: Fuel.values.byName(j['fuel'] as String),
  seats: j['seats'] as int,
  pricePerDay: j['pricePerDay'] as int,
  deposit: j['deposit'] as int,
  location: Place.fromJson((j['location'] as Map).cast<String, dynamic>()),
  delivery: j['delivery'] as bool,
  deliveryFee: j['deliveryFee'] as int,
  minDays: j['minDays'] as int,
  kmPerDay: j['kmPerDay'] as int,
  description: j['description'] as String,
  listed: j['listed'] as bool,
);
