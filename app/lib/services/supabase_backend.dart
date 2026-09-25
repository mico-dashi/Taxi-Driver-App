import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/models.dart';
import 'backend.dart';
import 'pricing.dart';

/// Live backend on Supabase (Postgres + Auth + Realtime).
/// Schema and server-side rules: `supabase/migrations/`.
class SupabaseBackend implements Backend {
  SupabaseBackend(this._db);

  final SupabaseClient _db;

  static Future<SupabaseBackend> create() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
    return SupabaseBackend(Supabase.instance.client);
  }

  @override
  bool get isDemo => false;

  @override
  String get currentUserId => _db.auth.currentUser?.id ?? '';

  /// Turns Postgres `raise exception 'code'` into a [BackendException].
  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      throw BackendException(e.message);
    } on AuthException catch (e) {
      throw BackendException(e.code ?? e.message);
    }
  }

  // ================================================================== auth

  @override
  Future<UserProfile?> restoreSession() async {
    await _loadFares();
    if (_db.auth.currentUser == null) return null;
    return _loadProfile();
  }

  Future<void> _loadFares() async {
    try {
      final rows = await _db.from('fare_settings').select().eq('active', true);
      if (rows.isEmpty) return;
      Pricing.categories = [
        for (final r in rows)
          VehicleCategory(
            id: r['category_id'] as String,
            nameKey: 'cat_${r['category_id']}',
            baseFare: r['base_fare'] as int,
            perKm: r['per_km'] as int,
            perMinute: r['per_minute'] as int,
            minFare: r['min_fare'] as int,
            seats: r['seats'] as int,
          ),
      ];
    } catch (_) {
      // Keep the built-in defaults.
    }
  }

  Future<UserProfile> _loadProfile() async {
    final r = await _db
        .from('profiles')
        .select()
        .eq('id', currentUserId)
        .single();
    return UserProfile(
      id: r['id'] as String,
      phone: (r['phone'] ?? '') as String,
      name: (r['full_name'] ?? '') as String,
      role: r['role'] == 'driver' ? UserRole.driver : UserRole.passenger,
      rating: (r['rating'] as num).toDouble(),
    );
  }

  @override
  Future<void> sendOtp(String phone) =>
      _guard(() => _db.auth.signInWithOtp(phone: phone));

  @override
  Future<UserProfile> verifyOtp(String phone, String code) => _guard(() async {
    await _db.auth.verifyOTP(type: OtpType.sms, phone: phone, token: code);
    return _loadProfile();
  });

  @override
  Future<UserProfile> saveProfile({
    required String name,
    required UserRole role,
  }) => _guard(() async {
    await _db
        .from('profiles')
        .update({'full_name': name, 'role': role.name})
        .eq('id', currentUserId);
    return _loadProfile();
  });

  @override
  Future<void> signOut() async {
    try {
      await _db
          .from('driver_status')
          .update({'is_online': false})
          .eq('driver_id', currentUserId);
    } catch (_) {}
    await _db.auth.signOut();
  }

  // ================================================================ mapping

  static Driver _driverFromRow(Map<String, dynamic> r) => Driver(
    id: r['driver_id'] as String,
    name: (r['full_name'] ?? '') as String,
    phone: (r['phone'] ?? '') as String,
    rating: ((r['rating'] ?? 5) as num).toDouble(),
    trips: ((r['trips'] ?? 0) as num).toInt(),
    vehicle: Vehicle(
      make: (r['make'] ?? '') as String,
      model: (r['model'] ?? '') as String,
      plate: (r['plate'] ?? '') as String,
      color: (r['color'] ?? '') as String,
      categoryId: (r['category_id'] ?? 'standard') as String,
      seats: ((r['seats'] ?? 4) as num).toInt(),
    ),
    location: LatLng(
      ((r['lat'] ?? AppConfig.defaultCenter.latitude) as num).toDouble(),
      ((r['lng'] ?? AppConfig.defaultCenter.longitude) as num).toDouble(),
    ),
    heading: ((r['heading'] ?? 0) as num).toDouble(),
  );

  static RideRequest _requestFromRow(
    Map<String, dynamic> r, {
    String passengerName = '',
    double passengerRating = 5,
  }) {
    final points = [
      for (final p in (r['route'] as List? ?? const []))
        LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];
    final pickup = Place(
      r['pickup_name'] as String,
      (r['pickup_subtitle'] ?? '') as String,
      LatLng(
        (r['pickup_lat'] as num).toDouble(),
        (r['pickup_lng'] as num).toDouble(),
      ),
    );
    final dest = Place(
      r['dest_name'] as String,
      (r['dest_subtitle'] ?? '') as String,
      LatLng(
        (r['dest_lat'] as num).toDouble(),
        (r['dest_lng'] as num).toDouble(),
      ),
    );
    return RideRequest(
      id: r['id'] as String,
      passengerId: r['passenger_id'] as String,
      passengerName: passengerName,
      passengerRating: passengerRating,
      pickup: pickup,
      destination: dest,
      route: RouteInfo(
        points: points.isEmpty ? [pickup.point, dest.point] : points,
        distanceKm: (r['distance_km'] as num).toDouble(),
        durationMin: (r['duration_min'] as num).toDouble(),
      ),
      categoryId: r['category_id'] as String,
      offeredFare: r['offered_fare'] as int,
      payment: PaymentType.values.byName(r['payment'] as String),
      createdAt: DateTime.parse(r['created_at'] as String),
      status: RequestStatus.values.byName(r['status'] as String),
    );
  }

  static const _rideStatus = {
    'driver_on_the_way': RideStatus.driverOnTheWay,
    'driver_arrived': RideStatus.driverArrived,
    'in_progress': RideStatus.inProgress,
    'completed': RideStatus.completed,
    'cancelled': RideStatus.cancelled,
  };

  static String _statusName(RideStatus s) =>
      _rideStatus.entries.firstWhere((e) => e.value == s).key;

  Future<Map<String, Driver>> _driversById(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final profiles = await _db.from('profiles').select().inFilter('id', list);
    final vehicles = await _db
        .from('vehicles')
        .select()
        .inFilter('driver_id', list);
    final status = await _db
        .from('driver_status')
        .select()
        .inFilter('driver_id', list);
    final out = <String, Driver>{};
    for (final p in profiles) {
      final id = p['id'] as String;
      final v = vehicles.firstWhere(
        (v) => v['driver_id'] == id,
        orElse: () => {},
      );
      final s = status.firstWhere(
        (s) => s['driver_id'] == id,
        orElse: () => {},
      );
      out[id] = _driverFromRow({
        ...v,
        ...s,
        'driver_id': id,
        'full_name': p['full_name'],
        'phone': p['phone'],
        'rating': p['rating'],
        'trips': p['rating_count'],
      });
    }
    return out;
  }

  Future<Map<String, UserProfile>> _passengersById(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await _db.from('profiles').select().inFilter('id', list);
    return {
      for (final r in rows)
        r['id'] as String: UserProfile(
          id: r['id'] as String,
          phone: (r['phone'] ?? '') as String,
          name: (r['full_name'] ?? '') as String,
          rating: (r['rating'] as num).toDouble(),
        ),
    };
  }

  Future<List<Ride>> _ridesFromRows(List<Map<String, dynamic>> rows) async {
    final drivers = await _driversById(
      rows.map((r) => r['driver_id'] as String),
    );
    final passengers = await _passengersById(
      rows.map((r) => r['passenger_id'] as String),
    );
    return [
      for (final r in rows)
        if (drivers[r['driver_id']] != null)
          Ride(
            id: r['id'] as String,
            request: _requestFromRow(
              r['ride_requests'] as Map<String, dynamic>,
              passengerName: passengers[r['passenger_id']]?.name ?? '',
              passengerRating: passengers[r['passenger_id']]?.rating ?? 5,
            ),
            driver: drivers[r['driver_id']]!,
            price: r['price'] as int,
            status: _rideStatus[r['status']]!,
            etaMinutes: 0,
            createdAt: DateTime.parse(r['created_at'] as String),
            rating: r['rating'] as int?,
            tip: (r['tip'] ?? 0) as int,
            cancelReason: r['cancel_reason'] as String?,
          ),
    ];
  }

  Future<Ride?> _loadRide(String rideId) async {
    final rows = await _db
        .from('rides')
        .select('*, ride_requests(*)')
        .eq('id', rideId);
    final rides = await _ridesFromRows(rows);
    return rides.isEmpty ? null : rides.first;
  }

  /// Progress / ETA from the driver's live position.
  static Ride _withLiveProgress(Ride ride) {
    const d = Distance();
    final target = ride.status == RideStatus.inProgress
        ? ride.request.destination.point
        : ride.request.pickup.point;
    final remainingKm =
        d.as(LengthUnit.Meter, ride.driver.location, target) / 1000 * 1.3;
    final totalKm = ride.status == RideStatus.inProgress
        ? math.max(ride.request.route.distanceKm, 0.1)
        : math.max(remainingKm, 3.0);
    final progress = switch (ride.status) {
      RideStatus.driverArrived || RideStatus.completed => 1.0,
      _ => (1 - remainingKm / totalKm).clamp(0.0, 1.0),
    };
    return ride.copyWith(
      progress: progress,
      etaMinutes: ride.status == RideStatus.driverArrived
          ? 0
          : (remainingKm / 25 * 60).ceil(),
    );
  }

  // ============================================================= passenger

  @override
  Stream<List<Driver>> watchNearbyDrivers(LatLng around) async* {
    while (true) {
      try {
        final rows = await _db.rpc(
          'nearby_drivers',
          params: {
            'p_lat': around.latitude,
            'p_lng': around.longitude,
            'p_radius_km': AppConfig.searchRadiusKm,
          },
        ) as List;
        yield [for (final r in rows) _driverFromRow(r as Map<String, dynamic>)];
      } catch (_) {
        // Temporary network issue - keep polling.
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  @override
  Future<RideRequest> createRequest({
    required Place pickup,
    required Place destination,
    required RouteInfo route,
    required String categoryId,
    required int offeredFare,
    required PaymentType payment,
  }) => _guard(() async {
    // Keep the stored route light: at most ~200 points.
    final step = math.max(1, route.points.length ~/ 200);
    final row = await _db
        .from('ride_requests')
        .insert({
          'passenger_id': currentUserId,
          'pickup_name': pickup.name,
          'pickup_subtitle': pickup.subtitle,
          'pickup_lat': pickup.point.latitude,
          'pickup_lng': pickup.point.longitude,
          'dest_name': destination.name,
          'dest_subtitle': destination.subtitle,
          'dest_lat': destination.point.latitude,
          'dest_lng': destination.point.longitude,
          'route': [
            for (var i = 0; i < route.points.length; i += step)
              [route.points[i].latitude, route.points[i].longitude],
            [route.points.last.latitude, route.points.last.longitude],
          ],
          'distance_km': route.distanceKm,
          'duration_min': route.durationMin,
          'category_id': categoryId,
          'offered_fare': offeredFare,
          'payment': payment.name,
        })
        .select()
        .single();
    return _requestFromRow(row);
  });

  @override
  Stream<List<RideOffer>> watchOffers(String requestId) {
    return _db
        .from('ride_offers')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .asyncMap((_) async {
          final rows = await _db.rpc(
            'request_offers',
            params: {'p_request_id': requestId},
          ) as List;
          return [
            for (final r in rows.cast<Map<String, dynamic>>())
              RideOffer(
                id: r['offer_id'] as String,
                requestId: requestId,
                driver: _driverFromRow(r),
                price: r['price'] as int,
                etaMinutes: r['eta_minutes'] as int,
                createdAt: DateTime.parse(r['created_at'] as String),
              ),
          ];
        });
  }

  @override
  Future<void> declineOffer(RideOffer offer) =>
      _guard(() => _db.rpc('decline_offer', params: {'p_offer_id': offer.id}));

  @override
  Future<Ride> acceptOffer(RideOffer offer) => _guard(() async {
    final rideId = await _db.rpc(
      'accept_offer',
      params: {'p_offer_id': offer.id},
    ) as String;
    final ride = await _loadRide(rideId);
    return _withLiveProgress(ride!);
  });

  @override
  Future<void> cancelRequest(String requestId) => _guard(
    () => _db.rpc('cancel_request', params: {'p_request_id': requestId}),
  );

  @override
  Stream<Ride> watchRide(String rideId) {
    late StreamController<Ride> ctrl;
    StreamSubscription<dynamic>? rideSub;
    StreamSubscription<dynamic>? locSub;
    Ride? current;

    void emit(Ride r) {
      current = r;
      if (!ctrl.isClosed) ctrl.add(_withLiveProgress(r));
    }

    ctrl = StreamController<Ride>(
      onListen: () async {
        final ride = await _loadRide(rideId);
        if (ride == null) return;
        emit(ride);
        rideSub = _db
            .from('rides')
            .stream(primaryKey: ['id'])
            .eq('id', rideId)
            .listen((rows) {
              if (rows.isEmpty || current == null) return;
              final r = rows.first;
              emit(
                current!.copyWith(
                  status: _rideStatus[r['status']],
                  rating: r['rating'] as int?,
                  tip: (r['tip'] ?? 0) as int,
                  cancelReason: r['cancel_reason'] as String?,
                ),
              );
            });
        locSub = _db
            .from('driver_status')
            .stream(primaryKey: ['driver_id'])
            .eq('driver_id', ride.driver.id)
            .listen((rows) {
              if (rows.isEmpty ||
                  current == null ||
                  rows.first['lat'] == null) {
                return;
              }
              final s = rows.first;
              emit(
                current!.copyWith(
                  driver: current!.driver.copyWith(
                    location: LatLng(
                      (s['lat'] as num).toDouble(),
                      (s['lng'] as num).toDouble(),
                    ),
                    heading: ((s['heading'] ?? 0) as num).toDouble(),
                  ),
                ),
              );
            });
      },
      onCancel: () {
        rideSub?.cancel();
        locSub?.cancel();
      },
    );
    return ctrl.stream;
  }

  @override
  Future<void> cancelRide(String rideId, String reason) => _guard(
    () => _db.rpc(
      'update_ride_status',
      params: {
        'p_ride_id': rideId,
        'p_status': 'cancelled',
        'p_reason': reason,
      },
    ),
  );

  @override
  Future<void> rateRide(
    String rideId, {
    required int stars,
    int tip = 0,
    String comment = '',
  }) => _guard(
    () => _db.rpc(
      'rate_ride',
      params: {
        'p_ride_id': rideId,
        'p_stars': stars,
        'p_tip': tip,
        'p_comment': comment,
      },
    ),
  );

  @override
  Future<int> promoDiscount(String code) async {
    try {
      return await _db.rpc('apply_promo', params: {'p_code': code.trim()})
          as int;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<Ride?> activeRide() async {
    final rows = await _db
        .from('rides')
        .select('*, ride_requests(*)')
        .eq('passenger_id', currentUserId)
        .inFilter('status', [
          'driver_on_the_way',
          'driver_arrived',
          'in_progress',
        ])
        .limit(1);
    final rides = await _ridesFromRows(rows);
    return rides.isEmpty ? null : _withLiveProgress(rides.first);
  }

  @override
  Future<List<Ride>> rideHistory() async {
    final rows = await _db
        .from('rides')
        .select('*, ride_requests(*)')
        .eq('passenger_id', currentUserId)
        .order('created_at', ascending: false)
        .limit(50);
    return _ridesFromRows(rows);
  }

  // =================================================================== chat

  @override
  Stream<List<ChatMessage>> watchMessages(String rideId) => _db
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('ride_id', rideId)
      .order('created_at')
      .map(
        (rows) => [
          for (final r in rows)
            ChatMessage(
              id: r['id'] as String,
              rideId: rideId,
              senderId: r['sender_id'] as String,
              text: r['body'] as String,
              sentAt: DateTime.parse(r['created_at'] as String).toLocal(),
            ),
        ],
      );

  @override
  Future<void> sendMessage(String rideId, String text) => _guard(
    () => _db.from('messages').insert({
      'ride_id': rideId,
      'sender_id': currentUserId,
      'body': text,
    }),
  );

  // ================================================================= driver

  Vehicle? _vehicle;

  @override
  Future<Vehicle?> myVehicle() async {
    final r = await _db
        .from('vehicles')
        .select()
        .eq('driver_id', currentUserId)
        .maybeSingle();
    if (r == null) return null;
    return _vehicle = Vehicle(
      make: r['make'] as String,
      model: r['model'] as String,
      plate: r['plate'] as String,
      color: (r['color'] ?? '') as String,
      categoryId: r['category_id'] as String,
      seats: r['seats'] as int,
    );
  }

  /// Whether an admin has approved the driver's vehicle / documents.
  Future<bool> vehicleApproved() async {
    final r = await _db
        .from('vehicles')
        .select('approved')
        .eq('driver_id', currentUserId)
        .maybeSingle();
    return (r?['approved'] ?? false) as bool;
  }

  @override
  Future<void> saveVehicle(Vehicle vehicle) => _guard(() async {
    _vehicle = vehicle;
    await _db.from('vehicles').upsert({
      'driver_id': currentUserId,
      'make': vehicle.make,
      'model': vehicle.model,
      'plate': vehicle.plate.toUpperCase(),
      'color': vehicle.color,
      'category_id': vehicle.categoryId,
      'seats': vehicle.seats,
    }, onConflict: 'driver_id');
  });

  @override
  Future<void> setOnline(bool online, LatLng location) => _guard(
    () => _db.from('driver_status').upsert({
      'driver_id': currentUserId,
      'is_online': online,
      'lat': location.latitude,
      'lng': location.longitude,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  @override
  Future<void> pushLocation(LatLng location, double heading) async {
    try {
      await _db
          .from('driver_status')
          .update({
            'lat': location.latitude,
            'lng': location.longitude,
            'heading': heading,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('driver_id', currentUserId);
    } catch (_) {
      // Next update will try again.
    }
  }

  @override
  Stream<List<RideRequest>> watchIncomingRequests(LatLng around) {
    const d = Distance();
    return _db
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'searching')
        .asyncMap((rows) async {
          final category = (_vehicle ?? await myVehicle())?.categoryId;
          final fresh = rows.where((r) {
            final created = DateTime.parse(r['created_at'] as String);
            final km =
                d.as(
                  LengthUnit.Meter,
                  around,
                  LatLng(
                    (r['pickup_lat'] as num).toDouble(),
                    (r['pickup_lng'] as num).toDouble(),
                  ),
                ) /
                1000;
            return r['category_id'] == category &&
                km <= AppConfig.searchRadiusKm &&
                DateTime.now().toUtc().difference(created.toUtc()).inMinutes <
                    3;
          }).toList();
          final passengers = await _passengersById(
            fresh.map((r) => r['passenger_id'] as String),
          );
          return [
            for (final r in fresh)
              _requestFromRow(
                r,
                passengerName: passengers[r['passenger_id']]?.name ?? '',
                passengerRating: passengers[r['passenger_id']]?.rating ?? 5,
              ),
          ];
        });
  }

  @override
  Future<void> sendOffer(RideRequest request, int price, int etaMinutes) =>
      _guard(
        () => _db.rpc(
          'send_offer',
          params: {
            'p_request_id': request.id,
            'p_price': price,
            'p_eta': etaMinutes,
          },
        ),
      );

  @override
  Stream<Ride?> watchDriverActiveRide() => _db
      .from('rides')
      .stream(primaryKey: ['id'])
      .eq('driver_id', currentUserId)
      .asyncMap((rows) async {
        final active = rows.where(
          (r) => const [
            'driver_on_the_way',
            'driver_arrived',
            'in_progress',
          ].contains(r['status']),
        );
        if (active.isEmpty) return null;
        return _loadRide(active.first['id'] as String);
      });

  @override
  Future<void> updateRideStatus(String rideId, RideStatus status) => _guard(
    () => _db.rpc(
      'update_ride_status',
      params: {'p_ride_id': rideId, 'p_status': _statusName(status)},
    ),
  );

  @override
  Future<DriverEarnings> earnings() => _guard(() async {
    final rows = await _db.rpc('driver_earnings') as List;
    final e = rows.isEmpty
        ? const <String, dynamic>{}
        : rows.first as Map<String, dynamic>;
    final recentRows = await _db
        .from('rides')
        .select('*, ride_requests(*)')
        .eq('driver_id', currentUserId)
        .eq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(20);
    return DriverEarnings(
      today: ((e['today'] ?? 0) as num).toInt(),
      week: ((e['week'] ?? 0) as num).toInt(),
      tripsToday: ((e['trips_today'] ?? 0) as num).toInt(),
      tripsWeek: ((e['trips_week'] ?? 0) as num).toInt(),
      onlineHoursToday: 0,
      recent: await _ridesFromRows(recentRows),
    );
  });

  @override
  void dispose() {}
}
