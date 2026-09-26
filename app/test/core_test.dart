import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taksi_al/core/format.dart';
import 'package:taksi_al/core/places.dart';
import 'package:taksi_al/core/strings.dart';
import 'package:taksi_al/models/models.dart';
import 'package:taksi_al/screens/common/payment_widgets.dart';
import 'package:taksi_al/screens/owner/car_form_screen.dart';
import 'package:taksi_al/services/pricing.dart';
import 'package:taksi_al/widgets/car_art.dart';

void main() {
  group('Rental pricing', () {
    test('days are started 24-hour periods, at least one', () {
      final s = DateTime(2026, 10, 1, 10);
      expect(rentalDays(s, s.add(const Duration(days: 3))), 3);
      expect(rentalDays(s, s.add(const Duration(days: 3, hours: 2))), 4);
      expect(rentalDays(s, s.add(const Duration(hours: 5))), 1);
      expect(rentalDays(s, s), 1);
    });

    test('short rental: price x days', () {
      final q = Pricing.quote(perDay: 3000, days: 3, deposit: 20000);
      expect(q.base, 9000);
      expect(q.longStayDiscount, 0);
      expect(q.total, 9000);
      expect(q.deposit, 20000);
    });

    test('7+ days get 10% off, 28+ days get 20% off', () {
      expect(Pricing.quote(perDay: 3000, days: 7, deposit: 0).total, 18900);
      expect(Pricing.quote(perDay: 3000, days: 28, deposit: 0).total, 67200);
    });

    test('promo, delivery and rounding match the server formula', () {
      // Same case as supabase/tests/rental_flow_test.sql: 3 x 2900, -20%, +500.
      final q = Pricing.quote(
        perDay: 2900,
        days: 3,
        deposit: 20000,
        deliveryFee: 500,
        promoPercent: 20,
      );
      expect(q.total, 7500);
      expect(q.promoDiscount, 1740);
    });

    test('offers can go down to 70% of the listed price', () {
      expect(Pricing.minOffer(3000), 2100);
      expect(Pricing.minOffer(11000), 7700);
    });
  });

  group('Formatting', () {
    test('money uses Albanian thousands separator', () {
      expect(money(0), '0 L');
      expect(money(950), '950 L');
      expect(money(1250), '1.250 L');
      expect(money(1234567), '1.234.567 L');
    });

    test('Albanian phone numbers normalise to E.164', () {
      expect(normalizeAlbanianPhone('069 123 4567'), '+355691234567');
      expect(normalizeAlbanianPhone('+355 68 123 4567'), '+355681234567');
      expect(normalizeAlbanianPhone('00355671234567'), '+355671234567');
      expect(normalizeAlbanianPhone('04 222 3333'), isNull);
      expect(normalizeAlbanianPhone('12345'), isNull);
    });
  });

  group('Places', () {
    test('search ignores Albanian diacritics', () {
      expect(
        AlbanianPlaces.search('skenderbej').first.name,
        'Sheshi Skënderbej',
      );
      expect(AlbanianPlaces.search('rinas').first.name, contains('Aeroporti'));
      expect(AlbanianPlaces.search('durres'), isNotEmpty);
    });

    test('city lookup', () {
      expect(AlbanianPlaces.cityFor(const LatLng(41.3275, 19.8187)), 'Tiranë');
      expect(AlbanianPlaces.cityFor(const LatLng(40.4661, 19.4914)), 'Vlorë');
    });
  });

  group('Validation', () {
    test('card numbers', () {
      expect(luhnValid('4242424242424242'), isTrue);
      expect(luhnValid('4242424242424241'), isFalse);
      expect(cardBrand('4242'), 'Visa');
      expect(cardBrand('5555'), 'Mastercard');
      expect(cardBrand('3782'), 'American Express');
    });

    test('Albanian plates', () {
      expect(validPlate('AA 123 BB'), isTrue);
      expect(validPlate('ab123cd'), isTrue);
      expect(validPlate('TR 1234 A'), isTrue);
      expect(validPlate('123'), isFalse);
    });
  });

  group('Translations', () {
    test('Albanian and English have the same keys', () {
      expect(Strings.sq.keys.toSet(), Strings.en.keys.toSet());
    });

    test('every key used in the code exists', () {
      final used = <String>{};
      // tr('key', ...) and keys chosen in ternaries / lists / switches.
      final direct = RegExp(r"""tr\(\s*'([a-z][a-z0-9_]*)'""");
      final indirect = RegExp(
        r"""(?:\?\s*|:\s*|=>\s*\(?|\[\s*|,\s*)'([a-z][a-z0-9]*_[a-z0-9_]*)'""",
      );
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.endsWith('strings.dart')) {
          continue;
        }
        final src = f.readAsStringSync();
        used.addAll(direct.allMatches(src).map((m) => m.group(1)!));
        for (final m in indirect.allMatches(src)) {
          final k = m.group(1)!;
          if (Strings.en.containsKey(k) ||
              RegExp(
                r'^(reason|quick|doc|color|st|status|sort|fuel|cat|step|err)_',
              ).hasMatch(k)) {
            used.add(k);
          }
        }
      }
      // Keys built at runtime.
      for (final c in Pricing.categories) {
        used.add(c.nameKey);
      }
      used.addAll(Fuel.values.map((f) => 'fuel_${f.name}'));
      used.addAll(BookingStatus.values.map((s) => 'status_${s.name}'));
      used.addAll([
        'sort_distance',
        'sort_priceLow',
        'sort_priceHigh',
        'sort_rating',
      ]);
      final missing = used.where((k) => !Strings.sq.containsKey(k)).toList()
        ..sort();
      expect(missing, isEmpty, reason: 'Missing translations: $missing');
    });
  });

  test('car drawings pick a body style from the listing', () {
    CarShape shape(String cat, String make, String model, [int seats = 5]) =>
        shapeForListing(
          categoryId: cat,
          make: make,
          model: model,
          seats: seats,
        );
    expect(shape('economy', 'Volkswagen', 'Golf 7'), CarShape.hatch);
    expect(shape('economy', 'Skoda', 'Octavia'), CarShape.sedan);
    expect(shape('suv', 'Hyundai', 'Tucson'), CarShape.suv);
    expect(shape('luxury', 'BMW', 'X5'), CarShape.suv);
    expect(shape('luxury', 'Mercedes-Benz', 'E 220d'), CarShape.sedan);
    expect(shape('luxury', 'Porsche', '911'), CarShape.sport);
    expect(shape('van', 'Mercedes-Benz', 'Vito', 8), CarShape.van);
  });
}
