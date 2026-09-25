import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// Everything the app needs from a server. Two implementations:
///  * [DemoBackend]     - simulated drivers/passengers, runs fully offline.
///  * [SupabaseBackend] - real accounts, realtime offers, live driver GPS.
abstract class Backend {
  bool get isDemo;

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

  // ----------------------------------------------------------- passenger
  /// Online drivers around [around], refreshed continuously.
  Stream<List<Driver>> watchNearbyDrivers(LatLng around);

  Future<RideRequest> createRequest({
    required Place pickup,
    required Place destination,
    required RouteInfo route,
    required String categoryId,
    required int offeredFare,
    required PaymentType payment,
  });

  /// Pending offers from drivers for this request.
  Stream<List<RideOffer>> watchOffers(String requestId);
  Future<void> declineOffer(RideOffer offer);
  Future<Ride> acceptOffer(RideOffer offer);
  Future<void> cancelRequest(String requestId);

  Stream<Ride> watchRide(String rideId);
  Future<void> cancelRide(String rideId, String reason);
  Future<void> rateRide(
    String rideId, {
    required int stars,
    int tip = 0,
    String comment = '',
  });

  /// Discount percent for a promo code (0 when invalid / already used).
  Future<int> promoDiscount(String code);

  /// Ride still in progress (e.g. after the app was closed), if any.
  Future<Ride?> activeRide();
  Future<List<Ride>> rideHistory();

  Stream<List<ChatMessage>> watchMessages(String rideId);
  Future<void> sendMessage(String rideId, String text);
  String get currentUserId;

  // -------------------------------------------------------------- driver
  Future<Vehicle?> myVehicle();
  Future<void> saveVehicle(Vehicle vehicle);
  Future<void> setOnline(bool online, LatLng location);
  Future<void> pushLocation(LatLng location, double heading);

  /// Open ride requests near the driver that match their vehicle category.
  Stream<List<RideRequest>> watchIncomingRequests(LatLng around);
  Future<void> sendOffer(RideRequest request, int price, int etaMinutes);

  /// Emits the ride once a passenger accepts this driver's offer.
  Stream<Ride?> watchDriverActiveRide();
  Future<void> updateRideStatus(String rideId, RideStatus status);
  Future<DriverEarnings> earnings();

  void dispose() {}
}

/// Errors with a translatable [code] (see `l10n.dart`, key `err_<code>`).
class BackendException implements Exception {
  const BackendException(this.code);
  final String code;

  @override
  String toString() => 'BackendException($code)';
}
