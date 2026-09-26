import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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
    await _loadCategories();
    if (_db.auth.currentUser == null) return null;
    return _loadProfile();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _db.from('car_categories').select().eq('active', true);
      if (rows.isEmpty) return;
      Pricing.categories = [
        for (final r in rows)
          CarCategory(
            id: r['id'] as String,
            nameKey: 'cat_${r['id']}',
            suggestedPerDay: r['suggested_per_day'] as int,
            suggestedDeposit: r['suggested_deposit'] as int,
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
      role: r['role'] == 'owner' ? UserRole.owner : UserRole.renter,
      rating: (r['rating'] as num).toDouble(),
    );
  }

  @override
  Future<void> sendOtp(String contact) => _guard(
    () => contact.contains('@')
        ? _db.auth.signInWithOtp(
            email: contact,
            // Until the email template shows the 6-digit code, Supabase's
            // default email holds a login link: on the web it brings the
            // user back to this page, signed in.
            emailRedirectTo: kIsWeb
                ? '${Uri.base.origin}${Uri.base.path}'
                : null,
          )
        : _db.auth.signInWithOtp(phone: contact),
  );

  @override
  Future<UserProfile> verifyOtp(String contact, String code) =>
      _guard(() async {
        if (contact.contains('@')) {
          await _db.auth.verifyOTP(
            type: OtpType.email,
            email: contact,
            token: code,
          );
        } else {
          await _db.auth.verifyOTP(
            type: OtpType.sms,
            phone: contact,
            token: code,
          );
        }
        return _loadProfile();
      });

  @override
  Future<UserProfile> saveProfile({
    required String name,
    required UserRole role,
    String? phone,
  }) => _guard(() async {
    await _db
        .from('profiles')
        .update({
          'full_name': name,
          'role': role.name,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        })
        .eq('id', currentUserId);
    return _loadProfile();
  });

  @override
  Future<void> signOut() => _db.auth.signOut();

  // ================================================================ mapping

  static Car carFromRow(
    Map<String, dynamic> r, {
    Map<String, dynamic>? owner,
  }) => Car(
    id: r['id'] as String,
    ownerId: r['owner_id'] as String,
    ownerName: (r['owner_name'] ?? owner?['full_name'] ?? '') as String,
    ownerRating: ((r['owner_rating'] ?? owner?['rating'] ?? 5) as num)
        .toDouble(),
    ownerPhone: (owner?['phone'] ?? '') as String,
    make: r['make'] as String,
    model: r['model'] as String,
    year: r['year'] as int,
    plate: r['plate'] as String,
    colorValue: (r['color'] as num).toInt(),
    categoryId: r['category_id'] as String,
    transmission: Transmission.values.byName(r['transmission'] as String),
    fuel: Fuel.values.byName(r['fuel'] as String),
    seats: r['seats'] as int,
    pricePerDay: r['price_per_day'] as int,
    deposit: r['deposit'] as int,
    location: Place(
      r['loc_name'] as String,
      (r['loc_subtitle'] ?? '') as String,
      LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()),
    ),
    delivery: r['delivery'] as bool,
    deliveryFee: r['delivery_fee'] as int,
    minDays: r['min_days'] as int,
    kmPerDay: r['km_per_day'] as int,
    description: (r['description'] ?? '') as String,
    rating: ((r['rating'] ?? 5) as num).toDouble(),
    trips: (r['trips'] ?? 0) as int,
    listed: (r['listed'] ?? true) as bool,
    photos: [for (final p in (r['photos'] as List? ?? const [])) p as String],
  );

  static Map<String, dynamic> _carToRow(Car c) => {
    'make': c.make,
    'model': c.model,
    'year': c.year,
    'plate': c.plate.toUpperCase(),
    'color': c.colorValue,
    'category_id': c.categoryId,
    'transmission': c.transmission.name,
    'fuel': c.fuel.name,
    'seats': c.seats,
    'price_per_day': c.pricePerDay,
    'deposit': c.deposit,
    'loc_name': c.location.name,
    'loc_subtitle': c.location.subtitle,
    'lat': c.location.point.latitude,
    'lng': c.location.point.longitude,
    'delivery': c.delivery,
    'delivery_fee': c.deliveryFee,
    'min_days': c.minDays,
    'km_per_day': c.kmPerDay,
    'description': c.description,
    'listed': c.listed,
    'photos': c.photos,
  };

  Future<Map<String, Map<String, dynamic>>> _profiles(
    Iterable<String> ids,
  ) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await _db.from('profiles').select().inFilter('id', list);
    return {for (final r in rows) r['id'] as String: r};
  }

  Future<List<Booking>> _bookingsFromRows(
    List<Map<String, dynamic>> rows,
  ) async {
    final people = await _profiles([
      for (final r in rows) ...[
        r['renter_id'] as String,
        r['owner_id'] as String,
      ],
    ]);
    return [
      for (final r in rows)
        if (r['cars'] != null)
          Booking(
            id: r['id'] as String,
            car: carFromRow(
              r['cars'] as Map<String, dynamic>,
              owner: people[r['owner_id']],
            ),
            renterId: r['renter_id'] as String,
            renterName: (people[r['renter_id']]?['full_name'] ?? '') as String,
            renterRating: ((people[r['renter_id']]?['rating'] ?? 5) as num)
                .toDouble(),
            renterPhone: (people[r['renter_id']]?['phone'] ?? '') as String,
            start: DateTime.parse(r['start_at'] as String).toLocal(),
            end: DateTime.parse(r['end_at'] as String).toLocal(),
            offeredPerDay: r['offered_per_day'] as int,
            counterPerDay: r['counter_per_day'] as int?,
            agreedPerDay: r['agreed_per_day'] as int?,
            status: BookingStatus.values.byName(r['status'] as String),
            pickup: Pickup.values.byName(r['pickup'] as String),
            deliveryAddress: (r['delivery_address'] ?? '') as String,
            payment: PaymentType.values.byName(r['payment'] as String),
            note: (r['note'] ?? '') as String,
            promoPercent: (r['promo_percent'] ?? 0) as int,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            rating: r['rating'] as int?,
            cancelReason: r['cancel_reason'] as String?,
          ),
    ];
  }

  Future<Booking?> _loadBooking(String id) async {
    final rows = await _db.from('bookings').select('*, cars(*)').eq('id', id);
    final list = await _bookingsFromRows(rows);
    return list.isEmpty ? null : list.first;
  }

  // ============================================================== renter

  @override
  Future<List<Car>> searchCars({
    required LatLng near,
    required DateTime start,
    required DateTime end,
    String? categoryId,
  }) => _guard(() async {
    final rows = await _db.rpc(
      'search_cars',
      params: {
        'p_lat': near.latitude,
        'p_lng': near.longitude,
        'p_start': start.toUtc().toIso8601String(),
        'p_end': end.toUtc().toIso8601String(),
        'p_radius_km': AppConfig.searchRadiusKm,
        'p_category': categoryId,
      },
    ) as List;
    return [for (final r in rows) carFromRow(r as Map<String, dynamic>)];
  });

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
  }) => _guard(() async {
    final id = await _db.rpc(
      'request_booking',
      params: {
        'p_car': car.id,
        'p_start': start.toUtc().toIso8601String(),
        'p_end': end.toUtc().toIso8601String(),
        'p_offered': offeredPerDay,
        'p_pickup': pickup.name,
        'p_payment': payment.name,
        'p_address': deliveryAddress,
        'p_note': note,
        'p_promo': promoCode,
      },
    ) as String;
    return (await _loadBooking(id))!;
  });

  @override
  Future<void> acceptCounter(String bookingId) =>
      _guard(() => _db.rpc('accept_counter', params: {'p_id': bookingId}));

  @override
  Future<int> promoDiscount(String code) async {
    try {
      return await _db.rpc('apply_promo', params: {'p_code': code.trim()})
          as int;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================== shared

  @override
  Stream<Booking> watchBooking(String bookingId) => _db
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('id', bookingId)
      .asyncMap((_) => _loadBooking(bookingId))
      .where((b) => b != null)
      .map((b) => b!);

  @override
  Future<List<Booking>> myRentals() => _guard(() async {
    final rows = await _db
        .from('bookings')
        .select('*, cars(*)')
        .eq('renter_id', currentUserId)
        .order('created_at', ascending: false)
        .limit(100);
    return _bookingsFromRows(rows);
  });

  @override
  Future<void> cancelBooking(String bookingId, String reason) => _guard(
    () => _db.rpc(
      'cancel_booking',
      params: {'p_id': bookingId, 'p_reason': reason},
    ),
  );

  @override
  Future<void> markPickedUp(String bookingId) =>
      _guard(() => _db.rpc('mark_picked_up', params: {'p_id': bookingId}));

  @override
  Future<void> markReturned(String bookingId) =>
      _guard(() => _db.rpc('mark_returned', params: {'p_id': bookingId}));

  @override
  Future<void> rateBooking(
    String bookingId, {
    required int stars,
    String comment = '',
  }) => _guard(
    () => _db.rpc(
      'rate_booking',
      params: {'p_id': bookingId, 'p_stars': stars, 'p_comment': comment},
    ),
  );

  @override
  Stream<List<ChatMessage>> watchMessages(String bookingId) => _db
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('booking_id', bookingId)
      .order('created_at')
      .map(
        (rows) => [
          for (final r in rows)
            ChatMessage(
              id: r['id'] as String,
              threadId: bookingId,
              senderId: r['sender_id'] as String,
              text: r['body'] as String,
              sentAt: DateTime.parse(r['created_at'] as String).toLocal(),
            ),
        ],
      );

  @override
  Future<void> sendMessage(String bookingId, String text) => _guard(
    () => _db.from('messages').insert({
      'booking_id': bookingId,
      'sender_id': currentUserId,
      'body': text,
    }),
  );

  // =============================================================== owner

  @override
  Future<List<Car>> myCars() => _guard(() async {
    final rows = await _db
        .from('cars')
        .select()
        .eq('owner_id', currentUserId)
        .order('created_at');
    return [for (final r in rows) carFromRow(r)];
  });

  /// Whether an admin has approved this car (unapproved cars are hidden).
  Future<bool> carApproved(String carId) async {
    final r = await _db
        .from('cars')
        .select('approved')
        .eq('id', carId)
        .maybeSingle();
    return (r?['approved'] ?? false) as bool;
  }

  @override
  Future<Car> saveCar(Car car) => _guard(() async {
    final row = _carToRow(car);
    final saved = car.id.isEmpty
        ? await _db
              .from('cars')
              .insert({...row, 'owner_id': currentUserId})
              .select()
              .single()
        : await _db.from('cars').update(row).eq('id', car.id).select().single();
    return carFromRow(saved);
  });

  @override
  Future<String> uploadCarPhoto(Uint8List jpeg) => _guard(() async {
    final path = '$currentUserId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final bucket = _db.storage.from('car-photos');
    await bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    return bucket.getPublicUrl(path);
  });

  @override
  Future<void> setListed(String carId, bool listed) =>
      _guard(() => _db.from('cars').update({'listed': listed}).eq('id', carId));

  @override
  Stream<List<Booking>> watchOwnerBookings() => _db
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('owner_id', currentUserId)
      .order('created_at')
      .asyncMap((rows) async {
        if (rows.isEmpty) return <Booking>[];
        final full = await _db
            .from('bookings')
            .select('*, cars(*)')
            .inFilter('id', [for (final r in rows) r['id'] as String])
            .order('created_at', ascending: false);
        return _bookingsFromRows(full);
      });

  Future<void> _respond(String id, String action, [int? price]) => _guard(
    () => _db.rpc(
      'respond_booking',
      params: {'p_id': id, 'p_action': action, 'p_price': price},
    ),
  );

  @override
  Future<void> acceptBooking(String bookingId) => _respond(bookingId, 'accept');

  @override
  Future<void> declineBooking(String bookingId) =>
      _respond(bookingId, 'decline');

  @override
  Future<void> counterBooking(String bookingId, int perDay) =>
      _respond(bookingId, 'counter', perDay);

  @override
  Future<OwnerEarnings> earnings() => _guard(() async {
    final rows = await _db.rpc('owner_earnings') as List;
    final e = rows.isEmpty
        ? const <String, dynamic>{}
        : rows.first as Map<String, dynamic>;
    final recentRows = await _db
        .from('bookings')
        .select('*, cars(*)')
        .eq('owner_id', currentUserId)
        .eq('status', 'completed')
        .order('end_at', ascending: false)
        .limit(20);
    return OwnerEarnings(
      thisMonth: ((e['this_month'] ?? 0) as num).toInt(),
      allTime: ((e['all_time'] ?? 0) as num).toInt(),
      rentalsThisMonth: ((e['rentals_this_month'] ?? 0) as num).toInt(),
      bookedDaysThisMonth: ((e['days_this_month'] ?? 0) as num).toInt(),
      recent: await _bookingsFromRows(recentRows),
    );
  });

  @override
  void dispose() {}
}
