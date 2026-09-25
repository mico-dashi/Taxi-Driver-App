import '../models/models.dart';

/// Default tariffs in Lekë. In live mode these are loaded from the
/// `fare_settings` table so the operator can change prices without an update.
class Pricing {
  static const defaults = <VehicleCategory>[
    VehicleCategory(
      id: 'standard',
      nameKey: 'cat_standard',
      baseFare: 300,
      perKm: 100,
      perMinute: 10,
      minFare: 400,
      seats: 4,
    ),
    VehicleCategory(
      id: 'luxury',
      nameKey: 'cat_luxury',
      baseFare: 600,
      perKm: 220,
      perMinute: 20,
      minFare: 1000,
      seats: 4,
    ),
    VehicleCategory(
      id: 'van',
      nameKey: 'cat_van',
      baseFare: 500,
      perKm: 160,
      perMinute: 15,
      minFare: 800,
      seats: 7,
    ),
  ];

  /// Replaced with the server's `fare_settings` in live mode.
  static List<VehicleCategory> categories = defaults;

  static VehicleCategory byId(String id) =>
      categories.firstWhere((c) => c.id == id, orElse: () => categories.first);

  /// 22:00–06:00 carries a 20% night surcharge, as is common in Albania.
  static bool isNight(DateTime t) => t.hour >= 22 || t.hour < 6;
  static const nightMultiplier = 1.2;

  /// Airport trips (to or from Rinas) have a fixed minimum.
  static const airportMinFare = 2500;

  static int estimate(
    VehicleCategory c,
    double km,
    double minutes, {
    DateTime? at,
    bool airport = false,
    int discountPercent = 0,
  }) {
    var fare = c.baseFare + c.perKm * km + c.perMinute * minutes;
    if (isNight(at ?? DateTime.now())) fare *= nightMultiplier;
    if (fare < c.minFare) fare = c.minFare.toDouble();
    if (airport && fare < airportMinFare) fare = airportMinFare.toDouble();
    if (discountPercent > 0) fare = fare * (100 - discountPercent) / 100;
    return roundFare(fare);
  }

  /// Fares are rounded to the nearest 50 L so cash change is easy.
  static int roundFare(num fare) => ((fare / 50).round() * 50).toInt();

  /// Quick counter-offer steps a driver can tap.
  static const counterSteps = [0, 100, 200, 500];
}
