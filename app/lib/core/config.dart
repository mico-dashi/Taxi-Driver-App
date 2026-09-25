import 'package:latlong2/latlong.dart';

/// Everything a reseller needs to re-brand the app lives here.
///
/// Backend credentials are injected at build time so the same code can ship
/// to many taxi companies:
///
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_KEY=sb_publishable_...
///
/// When no credentials are given the app runs in **demo mode**: every driver,
/// offer and ride is simulated on the device, which is perfect for showing the
/// product to taxi drivers and companies.
class AppConfig {
  static const brandName = 'Taksi AL';
  static const brandTagline = 'Taksi e shpejtë, kudo në Shqipëri';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project's publishable (a.k.a. anon) key - safe to ship in the app.
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
  static bool get isDemo => supabaseUrl.isEmpty || supabaseKey.isEmpty;

  /// Card / Apple Pay / Google Pay need a payment provider (POK, a local
  /// bank's e-commerce gateway, Stripe via a foreign entity...). Until one is
  /// connected in live mode, only cash is offered. Demo mode shows them all.
  static bool get cardPaymentsEnabled =>
      isDemo || const bool.fromEnvironment('CARD_PAYMENTS');

  /// Map tiles. OpenStreetMap's public servers are fine for testing, but their
  /// usage policy forbids heavy commercial use: switch to MapTiler, Stadia or
  /// a self-hosted server before launch (only this line needs to change).
  static const tileUrl = String.fromEnvironment(
    'TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const userAgentPackage = 'al.taksi.taksi_al';

  /// Routing (OSRM compatible). Self-host OSRM with the Albania extract from
  /// Geofabrik for production.
  static const routingUrl = String.fromEnvironment(
    'ROUTING_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  /// Geocoding (Nominatim compatible), limited to Albania.
  static const geocodingUrl = String.fromEnvironment(
    'GEOCODING_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );
  static const countryCode = 'al';

  /// Sheshi Skënderbej, Tirana.
  static const defaultCenter = LatLng(41.3275, 19.8187);

  static const currencySymbol = 'L';
  static const phonePrefix = '+355';

  /// Emergency numbers in Albania.
  static const emergencyNumber = '112';
  static const policeNumber = '129';
  static const ambulanceNumber = '127';

  static const supportPhone = '+355690000000';
  static const supportEmail = 'support@taksi.al';

  /// First-ride promotion shown on the home screen.
  static const promoCode = 'TAKSI30';
  static const promoPercent = 30;

  /// How long a driver's offer stays on the passenger's screen.
  static const offerTimeoutSeconds = 15;

  /// How far (km) a ride request is broadcast to online drivers.
  static const searchRadiusKm = 6.0;

  /// Demo mode OTP code.
  static const demoOtp = '123456';
}
