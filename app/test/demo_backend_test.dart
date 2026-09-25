import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taksi_al/core/config.dart';
import 'package:taksi_al/core/places.dart';
import 'package:taksi_al/models/models.dart';
import 'package:taksi_al/services/backend.dart';
import 'package:taksi_al/services/demo_backend.dart';
import 'package:taksi_al/services/routing_service.dart';

/// Routing server "offline" -> estimated routes, no network in tests.
RoutingService offlineRouting() =>
    RoutingService(client: MockClient((_) async => http.Response('down', 503)));

Future<T> firstWhere<T>(Stream<T> s, bool Function(T) test) =>
    s.firstWhere(test).timeout(const Duration(seconds: 20));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login with the demo code, wrong code is rejected', () async {
    final b = DemoBackend(routing: offlineRouting(), speed: 50);
    expect(await b.restoreSession(), isNull);
    await expectLater(
      b.verifyOtp('+355691234567', '000000'),
      throwsA(isA<BackendException>()),
    );
    final u = await b.verifyOtp('+355691234567', AppConfig.demoOtp);
    expect(u.name, isEmpty);
    final saved = await b.saveProfile(
      name: 'Alda Hoxha',
      role: UserRole.passenger,
    );
    expect(saved.firstName, 'Alda');
    // Session survives an app restart.
    final again = await DemoBackend(routing: offlineRouting()).restoreSession();
    expect(again?.name, 'Alda Hoxha');
  });

  test(
    'passenger: request -> offers -> decline -> accept -> ride completes',
    () async {
      final b = DemoBackend(routing: offlineRouting(), speed: 50);
      await b.verifyOtp('+355691234567', AppConfig.demoOtp);
      final pickup = AlbanianPlaces.all[1]; // Blloku
      final dest = AlbanianPlaces.all[4]; // TEG
      final route = RoutingService.estimate(pickup.point, dest.point);

      final drivers = await b.watchNearbyDrivers(pickup.point).first;
      expect(
        drivers.where((d) => d.vehicle.categoryId == 'standard'),
        isNotEmpty,
      );

      final req = await b.createRequest(
        pickup: pickup,
        destination: dest,
        route: route,
        categoryId: 'standard',
        offeredFare: 900,
        payment: PaymentType.cash,
      );
      final offers = b.watchOffers(req.id).asBroadcastStream();
      final first = (await firstWhere(offers, (o) => o.isNotEmpty)).first;
      expect(first.price, greaterThanOrEqualTo(900));
      expect(first.driver.vehicle.categoryId, 'standard');

      await b.declineOffer(first);
      final second = (await firstWhere(
        offers,
        (o) => o.any((x) => x.id != first.id),
      )).firstWhere((x) => x.id != first.id);

      final ride = await b.acceptOffer(second);
      expect(ride.status, RideStatus.driverOnTheWay);
      expect(ride.price, second.price);
      // Accepting twice is not possible.
      await expectLater(
        b.acceptOffer(second),
        throwsA(isA<BackendException>()),
      );

      final updates = b.watchRide(ride.id).asBroadcastStream();
      await firstWhere(updates, (r) => r.status == RideStatus.driverArrived);
      await firstWhere(updates, (r) => r.status == RideStatus.inProgress);
      final done = await firstWhere(
        updates,
        (r) => r.status == RideStatus.completed,
      );
      expect(done.driver.location, dest.point);

      await b.rateRide(ride.id, stars: 5, tip: 200);
      final history = await b.rideHistory();
      expect(history.first.id, ride.id);
      expect(history.first.rating, 5);
      expect(history.first.tip, 200);
      expect(await b.activeRide(), isNull);
      // First-ride promo is gone after a completed ride.
      expect(await b.promoDiscount(AppConfig.promoCode), 0);
      b.dispose();
    },
  );

  test('passenger can cancel a ride; chat gets a reply', () async {
    final b = DemoBackend(routing: offlineRouting(), speed: 50);
    await b.verifyOtp('+355691234567', AppConfig.demoOtp);
    expect(await b.promoDiscount('taksi30'), AppConfig.promoPercent);
    final pickup = AlbanianPlaces.all[0];
    final dest = AlbanianPlaces.all[2];
    final req = await b.createRequest(
      pickup: pickup,
      destination: dest,
      route: RoutingService.estimate(pickup.point, dest.point),
      categoryId: 'luxury',
      offeredFare: 5000,
      payment: PaymentType.card,
    );
    final offer = (await firstWhere(
      b.watchOffers(req.id),
      (o) => o.isNotEmpty,
    )).first;
    expect(offer.driver.vehicle.categoryId, 'luxury');
    final ride = await b.acceptOffer(offer);

    final msgs = b.watchMessages(ride.id).asBroadcastStream();
    await b.sendMessage(ride.id, 'Jam te hyrja');
    final convo = await firstWhere(msgs, (m) => m.length == 2);
    expect(convo[0].senderId, b.currentUserId);
    expect(convo[1].senderId, offer.driver.id);

    await b.cancelRide(ride.id, 'reason_changed_mind');
    expect((await b.rideHistory()).first.status, RideStatus.cancelled);
    expect(await b.activeRide(), isNull);
    b.dispose();
  });

  test(
    'driver: online -> request -> offer -> accepted -> complete -> earnings',
    () async {
      final b = DemoBackend(routing: offlineRouting(), speed: 50);
      await b.verifyOtp('+355697777777', AppConfig.demoOtp);
      await b.saveProfile(name: 'Arben Hoxha', role: UserRole.driver);
      await b.saveVehicle(
        const Vehicle(
          make: 'Mercedes-Benz',
          model: 'E 220d',
          plate: 'AA 482 TR',
          color: 'E zezë',
          categoryId: 'standard',
        ),
      );
      final before = await b.earnings();

      final rides = b.watchDriverActiveRide().asBroadcastStream();
      final requests = b
          .watchIncomingRequests(AppConfig.defaultCenter)
          .asBroadcastStream();
      await b.setOnline(true, AppConfig.defaultCenter);

      // Offer on requests (at the passenger's price) until one accepts.
      Ride? ride;
      final sub = requests.listen((list) {
        for (final r in list) {
          expect(r.categoryId, 'standard');
          b.sendOffer(r, r.offeredFare, 3);
        }
      });
      ride = await firstWhere(rides, (r) => r != null);
      await sub.cancel();
      expect(ride!.driver.name, 'Arben Hoxha');
      expect(ride.status, RideStatus.driverOnTheWay);

      await b.updateRideStatus(ride.id, RideStatus.driverArrived);
      await b.updateRideStatus(ride.id, RideStatus.inProgress);
      await b.updateRideStatus(ride.id, RideStatus.completed);
      await b.setOnline(false, AppConfig.defaultCenter);

      final after = await b.earnings();
      expect(after.tripsToday, before.tripsToday + 1);
      expect(after.today, before.today + ride.price);
      expect(after.recent.first.id, ride.id);
      b.dispose();
    },
  );
}
