import '../models/models.dart';

/// Rental pricing in Lekë. Owners set their own daily price; categories only
/// suggest a starting price. In live mode categories are loaded from the
/// `car_categories` table.
class Pricing {
  static const defaults = <CarCategory>[
    CarCategory(
      id: 'economy',
      nameKey: 'cat_economy',
      suggestedPerDay: 3000,
      suggestedDeposit: 20000,
      seats: 5,
    ),
    CarCategory(
      id: 'suv',
      nameKey: 'cat_suv',
      suggestedPerDay: 5500,
      suggestedDeposit: 40000,
      seats: 5,
    ),
    CarCategory(
      id: 'luxury',
      nameKey: 'cat_luxury',
      suggestedPerDay: 12000,
      suggestedDeposit: 100000,
      seats: 5,
    ),
    CarCategory(
      id: 'van',
      nameKey: 'cat_van',
      suggestedPerDay: 7000,
      suggestedDeposit: 50000,
      seats: 8,
    ),
  ];

  static List<CarCategory> categories = defaults;

  static CarCategory byId(String id) =>
      categories.firstWhere((c) => c.id == id, orElse: () => categories.first);

  /// 7+ days get 10% off, 28+ days get 20% off, as rental agencies do.
  static int discountPercent(int days) => days >= 28
      ? 20
      : days >= 7
      ? 10
      : 0;

  /// A renter may offer less than the listed price, but not below 70%.
  static const minOfferFraction = 0.7;

  static int minOffer(int listedPerDay) =>
      roundDaily(listedPerDay * minOfferFraction);

  static int roundDaily(num perDay) => ((perDay / 100).round() * 100).toInt();

  static RentalQuote quote({
    required int perDay,
    required int days,
    required int deposit,
    int deliveryFee = 0,
    int promoPercent = 0,
  }) {
    final base = perDay * days;
    final longStay = discountPercent(days);
    final afterLongStay = base * (100 - longStay) / 100;
    final promo = afterLongStay * promoPercent / 100;
    final rental = ((afterLongStay - promo) / 100).round() * 100;
    return RentalQuote(
      days: days,
      perDay: perDay,
      base: base,
      longStayDiscount: (base - afterLongStay).round(),
      promoDiscount: promo.round(),
      deliveryFee: deliveryFee,
      total: rental + deliveryFee,
      deposit: deposit,
    );
  }

  static RentalQuote quoteFor(Booking b) => quote(
    perDay: b.perDay,
    days: b.days,
    deposit: b.car.deposit,
    deliveryFee: b.pickup == Pickup.delivery ? b.car.deliveryFee : 0,
    promoPercent: b.promoPercent,
  );
}

class RentalQuote {
  final int days;
  final int perDay;
  final int base;
  final int longStayDiscount;
  final int promoDiscount;
  final int deliveryFee;

  /// What the renter pays for the rental (deposit not included).
  final int total;

  /// Refundable deposit held at pickup.
  final int deposit;

  const RentalQuote({
    required this.days,
    required this.perDay,
    required this.base,
    required this.longStayDiscount,
    required this.promoDiscount,
    required this.deliveryFee,
    required this.total,
    required this.deposit,
  });
}
