import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// Everything the app needs from a server. Two implementations:
///  * [DemoBackend]     - simulated owners and renters, runs fully offline.
///  * [SupabaseBackend] - real accounts, realtime bookings and chat.
abstract class Backend {
  bool get isDemo;
  String get currentUserId;

  // ---------------------------------------------------------------- auth
  Future<UserProfile?> restoreSession();
  Future<void> sendOtp(String phone);

  /// Returns the profile; `name` is empty for brand new users.
  Future<UserProfile> verifyOtp(String phone, String code);
  Future<UserProfile> saveProfile({
    required String name,
    required UserRole role,
  });
  Future<void> signOut();

  // -------------------------------------------------------------- renter
  /// Listed cars near [near] that are free for the whole period.
  Future<List<Car>> searchCars({
    required LatLng near,
    required DateTime start,
    required DateTime end,
    String? categoryId,
  });

  /// Sends a booking request. [offeredPerDay] may be below the listed price
  /// (the owner can accept, decline or counter).
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
  });

  /// Renter accepts the owner's counter-offer.
  Future<void> acceptCounter(String bookingId);

  /// Discount percent for a promo code (0 when invalid / already used).
  Future<int> promoDiscount(String code);

  // ------------------------------------------------------------- shared
  Stream<Booking> watchBooking(String bookingId);

  /// Bookings where I am the renter (newest first).
  Future<List<Booking>> myRentals();
  Future<void> cancelBooking(String bookingId, String reason);

  /// Handover done: the renter has the car.
  Future<void> markPickedUp(String bookingId);

  /// The car is back with the owner.
  Future<void> markReturned(String bookingId);
  Future<void> rateBooking(
    String bookingId, {
    required int stars,
    String comment = '',
  });

  Stream<List<ChatMessage>> watchMessages(String bookingId);
  Future<void> sendMessage(String bookingId, String text);

  // --------------------------------------------------------------- owner
  Future<List<Car>> myCars();

  /// Creates (empty id) or updates a car listing; returns the saved car.
  Future<Car> saveCar(Car car);

  /// Stores a JPEG photo of an owner's car; returns the URL to save in
  /// [Car.photos].
  Future<String> uploadCarPhoto(Uint8List jpeg);
  Future<void> setListed(String carId, bool listed);

  /// All bookings for my cars, kept up to date.
  Stream<List<Booking>> watchOwnerBookings();
  Future<void> acceptBooking(String bookingId);
  Future<void> declineBooking(String bookingId);
  Future<void> counterBooking(String bookingId, int perDay);
  Future<OwnerEarnings> earnings();

  void dispose() {}
}

/// Errors with a translatable [code] (see `l10n.dart`, key `err_<code>`).
class BackendException implements Exception {
  const BackendException(this.code);
  final String code;

  @override
  String toString() => 'BackendException($code)';
}
