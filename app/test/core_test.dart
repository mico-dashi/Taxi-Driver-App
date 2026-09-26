import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taksi_al/core/format.dart';
import 'package:taksi_al/core/places.dart';
import 'package:taksi_al/core/strings.dart';
import 'package:taksi_al/screens/booking/payment_widgets.dart';
import 'package:taksi_al/screens/driver/vehicle_screen.dart';
import 'package:taksi_al/services/pricing.dart';
import 'package:taksi_al/services/routing_service.dart';
import 'package:taksi_al/widgets/map_widgets.dart';

void main() {
  group('Pricing', () {
    final standard = Pricing.byId('standard');
    final day = DateTime(2026, 9, 25, 12);
    final night = DateTime(2026, 9, 25, 23);

    test('base + km + minutes, rounded to 50 L', () {
      // 300 + 100*5 + 10*12 = 920 -> 900
      expect(Pricing.estimate(standard, 5, 12, at: day), 900);
    });

    test('minimum fare applies to very short trips', () {
      expect(Pricing.estimate(standard, 0.3, 1, at: day), 400);
    });

    test('night surcharge is +20%', () {
      expect(
        Pricing.estimate(standard, 5, 12, at: night),
        1100,
      ); // 920*1.2=1104
    });

    test('airport minimum', () {
      expect(
        Pricing.estimate(standard, 3, 8, at: day, airport: true),
        Pricing.airportMinFare,
      );
    });

    test('promo discount', () {
      expect(
        Pricing.estimate(standard, 5, 12, at: day, discountPercent: 30),
        650,
      ); // 644
    });

    test('luxury costs more than standard', () {
      expect(
        Pricing.estimate(Pricing.byId('luxury'), 10, 20, at: day),
        greaterThan(Pricing.estimate(standard, 10, 20, at: day)),
      );
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
      expect(normalizeAlbanianPhone('691234567'), '+355691234567');
      expect(normalizeAlbanianPhone('04 222 3333'), isNull); // landline
      expect(normalizeAlbanianPhone('12345'), isNull);
    });

    test('minutes', () {
      expect(minutes(0.2), '1 min');
      expect(minutes(25), '25 min');
      expect(minutes(90), '1 h 30 min');
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

  group('Routing helpers', () {
    const a = LatLng(41.3275, 19.8187);
    const b = LatLng(41.4147, 19.7206);

    test('estimate is longer than a straight line', () {
      final r = RoutingService.estimate(a, b);
      expect(r.distanceKm, greaterThan(12));
      expect(r.durationMin, greaterThan(10));
      expect(r.points.first, a);
      expect(r.points.last, b);
    });

    test('pointAlong interpolates', () {
      expect(RoutingService.pointAlong([a, b], 0), a);
      expect(RoutingService.pointAlong([a, b], 1), b);
      final mid = RoutingService.pointAlong([a, b], 0.5);
      expect(mid.latitude, closeTo((a.latitude + b.latitude) / 2, 1e-3));
    });

    test('remainingRoute drops the part already driven', () {
      const route = [
        LatLng(41.30, 19.80),
        LatLng(41.31, 19.80),
        LatLng(41.32, 19.80),
        LatLng(41.33, 19.80),
      ];
      final rest = remainingRoute(route, const LatLng(41.315, 19.80));
      expect(rest.first, const LatLng(41.315, 19.80));
      expect(rest.skip(1), route.sublist(2));
      expect(remainingRoute(route, route.first).last, route.last);
    });

    test('bearing north is ~0 degrees', () {
      expect(
        RoutingService.bearing(a, const LatLng(41.5, 19.8187)),
        closeTo(0, 0.5),
      );
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
      final pattern = RegExp(
        r"""(?:tr\(\s*|\?\s*|:\s*|=>\s*\(?)'([a-z][a-z0-9_]*)'""",
      );
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.endsWith('strings.dart')) {
          continue;
        }
        for (final m in pattern.allMatches(f.readAsStringSync())) {
          final key = m.group(1)!;
          if (key.contains('_') || Strings.sq.containsKey(key)) used.add(key);
        }
      }
      // Keys built dynamically.
      for (final c in Pricing.categories) {
        used
          ..add(c.nameKey)
          ..add('${c.nameKey}_desc');
      }
      final ignore = {
        'demo_user',
        'demo_vehicle',
        'place_home',
        'place_work',
        'promo_code',
        'payment_methods',
        'selected_payment',
        'apple_pay',
        'google_pay',
        'driver_on_the_way',
        'driver_arrived',
        'in_progress',
        'full_name',
        'passenger_id',
        'driver_id',
        'category_id',
        'offer_id',
        'eta_minutes',
        'created_at',
        'ride_requests',
        'ride_offers',
        'driver_status',
        'fare_settings',
        'pickup_name',
        'pickup_subtitle',
        'pickup_lat',
        'pickup_lng',
        'dest_name',
        'dest_subtitle',
        'dest_lat',
        'dest_lng',
        'distance_km',
        'duration_min',
        'offered_fare',
        'base_fare',
        'per_km',
        'per_minute',
        'min_fare',
        'rating_count',
        'cancel_reason',
        'sender_id',
        'ride_id',
        'house_number',
        'display_name',
        'trips_today',
        'trips_week',
        'request_id',
        'is_online',
        'updated_at',
        'p_lat',
        'p_lng',
        'p_radius_km',
        'p_request_id',
        'p_offer_id',
        'p_ride_id',
        'p_status',
        'p_reason',
        'p_stars',
        'p_tip',
        'p_comment',
        'p_code',
        'p_price',
        'p_eta',
        'nearby_drivers',
        'request_offers',
        'decline_offer',
        'accept_offer',
        'cancel_request',
        'update_ride_status',
        'rate_ride',
        'apply_promo',
        'send_offer',
        'driver_earnings',
        'lang',
        'recents',
        'invalid_code',
        'request_closed',
        'offer_expired',
        'passenger_chose_another',
        'driver_cancelled',
        'past_req',
        'addressdetails',
        'countrycodes',
      };
      final missing =
          used
              .difference(ignore)
              .where((k) => !Strings.sq.containsKey(k))
              .toList()
            ..sort();
      expect(missing, isEmpty, reason: 'Missing translations: $missing');
    });
  });
}
