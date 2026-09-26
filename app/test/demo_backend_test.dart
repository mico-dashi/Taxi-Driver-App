import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taksi_al/core/config.dart';
import 'package:taksi_al/core/places.dart';
import 'package:taksi_al/models/models.dart';
import 'package:taksi_al/services/backend.dart';
import 'package:taksi_al/services/demo_backend.dart';
import 'package:taksi_al/services/pricing.dart';

Future<T> firstWhere<T>(Stream<T> s, bool Function(T) test) =>
    s.firstWhere(test).timeout(const Duration(seconds: 20));

DateTime _day(int inDays) {
  final n = DateTime.now().add(Duration(days: inDays));
  return DateTime(n.year, n.month, n.day, 10);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<DemoBackend> renter() async {
    final b = DemoBackend(speed: 50);
    await b.verifyOtp('+355691234567', AppConfig.demoOtp);
    await b.saveProfile(name: 'Alda Hoxha', role: UserRole.renter);
    return b;
  }

  test('login with the demo code; old taxi-era sessions are discarded', () async {
    SharedPreferences.setMockInitialValues({
      'demo_user':
          '{"id":"demo-user","phone":"+355691","name":"X","role":"passenger"}',
    });
    final b = DemoBackend(speed: 50);
    expect(await b.restoreSession(), isNull);
    await expectLater(
      b.verifyOtp('+355691234567', '000000'),
      throwsA(isA<BackendException>()),
    );
    await b.verifyOtp('+355691234567', AppConfig.demoOtp);
    await b.saveProfile(name: 'Alda Hoxha', role: UserRole.renter);
    expect((await DemoBackend().restoreSession())?.name, 'Alda Hoxha');
  });

  test('search finds free cars near the place, by category', () async {
    final b = await renter();
    final tirana = AlbanianPlaces.all[0].point;
    final all = await b.searchCars(near: tirana, start: _day(2), end: _day(5));
    expect(all.length, greaterThanOrEqualTo(8));
    expect(all.every((c) => c.location.name != 'Sarandë'), isTrue);
    final suv = await b.searchCars(
      near: tirana,
      start: _day(2),
      end: _day(5),
      categoryId: 'suv',
    );
    expect(suv, isNotEmpty);
    expect(suv.every((c) => c.categoryId == 'suv'), isTrue);
    final south = await b.searchCars(
      near: AlbanianPlaces.all[22].point,
      start: _day(2),
      end: _day(5),
    );
    expect(south.map((c) => c.location.name), contains('Ksamil'));
  });

  test('renter: low offer -> counter-offer -> accept -> pick up -> return -> review', () async {
    final b = await renter();
    final cars = await b.searchCars(
      near: AlbanianPlaces.all[0].point,
      start: _day(2),
      end: _day(5),
    );
    final car = cars.firstWhere((c) => c.minDays == 1);

    await expectLater(
      b.requestBooking(
        car: car,
        start: _day(2),
        end: _day(5),
        offeredPerDay: 100,
        pickup: Pickup.atOwner,
        payment: PaymentType.cash,
      ),
      throwsA(
        isA<BackendException>().having((e) => e.code, 'code', 'offer_too_low'),
      ),
    );

    final offer = Pricing.minOffer(car.pricePerDay);
    final booking = await b.requestBooking(
      car: car,
      start: _day(2),
      end: _day(5),
      offeredPerDay: offer,
      pickup: Pickup.atOwner,
      payment: PaymentType.cash,
      promoCode: 'qira20',
    );
    expect(booking.status, BookingStatus.requested);
    expect(booking.promoPercent, 20);

    final updates = b.watchBooking(booking.id).asBroadcastStream();
    final countered = await firstWhere(
      updates,
      (x) => x.status == BookingStatus.countered,
    );
    expect(countered.counterPerDay, greaterThan(offer));
    expect(countered.counterPerDay, lessThanOrEqualTo(car.pricePerDay));

    await b.acceptCounter(booking.id);
    final confirmed = await firstWhere(
      updates,
      (x) => x.status == BookingStatus.confirmed,
    );
    expect(confirmed.agreedPerDay, countered.counterPerDay);

    // The car is no longer offered for overlapping dates.
    final again = await b.searchCars(
      near: AlbanianPlaces.all[0].point,
      start: _day(3),
      end: _day(4),
    );
    expect(again.any((c) => c.id == car.id), isFalse);
    await expectLater(
      b.requestBooking(
        car: car,
        start: _day(4),
        end: _day(6),
        offeredPerDay: car.pricePerDay,
        pickup: Pickup.atOwner,
        payment: PaymentType.cash,
      ),
      throwsA(
        isA<BackendException>().having(
          (e) => e.code,
          'code',
          'car_unavailable',
        ),
      ),
    );

    await expectLater(
      b.markReturned(booking.id),
      throwsA(isA<BackendException>()),
    );
    await b.markPickedUp(booking.id);
    await expectLater(
      b.cancelBooking(booking.id, 'x'),
      throwsA(isA<BackendException>()),
    );
    await b.markReturned(booking.id);
    await b.rateBooking(booking.id, stars: 5, comment: 'Shumë mirë');

    final mine = await b.myRentals();
    final done = mine.firstWhere((x) => x.id == booking.id);
    expect(done.status, BookingStatus.completed);
    expect(done.rating, 5);
    expect(Pricing.quoteFor(done).promoDiscount, greaterThan(0));
    // First-rental promo is now used up.
    expect(await b.promoDiscount(AppConfig.promoCode), 0);

    final msgs = b.watchMessages(booking.id).asBroadcastStream();
    await b.sendMessage(booking.id, 'Faleminderit!');
    final convo = await firstWhere(msgs, (m) => m.length == 2);
    expect(convo[1].senderId, car.ownerId);
    b.dispose();
  });

  test(
    'renter: offer at the listed price is confirmed; minimum days enforced',
    () async {
      final b = await renter();
      final cars = await b.searchCars(
        near: AlbanianPlaces.all[0].point,
        start: _day(3),
        end: _day(4),
      );
      final twoDayCar = cars.firstWhere((c) => c.minDays == 2);
      await expectLater(
        b.requestBooking(
          car: twoDayCar,
          start: _day(3),
          end: _day(4),
          offeredPerDay: twoDayCar.pricePerDay,
          pickup: Pickup.atOwner,
          payment: PaymentType.card,
        ),
        throwsA(
          isA<BackendException>().having((e) => e.code, 'code', 'min_days'),
        ),
      );
      final car = cars.firstWhere((c) => c.minDays == 1 && c.delivery);
      final bk = await b.requestBooking(
        car: car,
        start: _day(3),
        end: _day(4),
        offeredPerDay: car.pricePerDay,
        pickup: Pickup.delivery,
        deliveryAddress: 'Rruga e Kavajës 10',
        payment: PaymentType.card,
      );
      final ok = await firstWhere(
        b.watchBooking(bk.id),
        (x) => x.status == BookingStatus.confirmed,
      );
      expect(ok.agreedPerDay, car.pricePerDay);
      expect(Pricing.quoteFor(ok).deliveryFee, car.deliveryFee);
      await b.cancelBooking(bk.id, 'reason_changed_plans');
      expect(
        (await b.myRentals()).firstWhere((x) => x.id == bk.id).status,
        BookingStatus.cancelled,
      );
      b.dispose();
    },
  );

  test(
    'owner: list a car, get requests, counter / accept, hand over, earn',
    () async {
      final b = DemoBackend(speed: 50);
      await b.verifyOtp('+355697777777', AppConfig.demoOtp);
      await b.saveProfile(name: 'Arben Hoxha', role: UserRole.owner);
      final car = await b.saveCar(
        Car(
          id: '',
          ownerId: '',
          ownerName: '',
          make: 'Volkswagen',
          model: 'Golf 7',
          year: 2018,
          plate: 'AA 482 TR',
          categoryId: 'economy',
          pricePerDay: 3000,
          deposit: 20000,
          location: AlbanianPlaces.all[1],
        ),
      );
      expect(car.id, isNotEmpty);
      expect((await b.myCars()).single.ownerName, 'Arben Hoxha');
      // Owners never see their own car in search.
      final search = await b.searchCars(
        near: AlbanianPlaces.all[1].point,
        start: _day(20),
        end: _day(22),
      );
      expect(search.any((c) => c.id == car.id), isFalse);

      final inbox = b.watchOwnerBookings().asBroadcastStream();
      var list = await firstWhere(
        inbox,
        (l) => l.where((x) => x.status == BookingStatus.requested).length >= 2,
      );
      final requests = list
          .where((x) => x.status == BookingStatus.requested)
          .toList();

      // Accept one; counter the other (renter usually accepts or walks away).
      await b.acceptBooking(requests[0].id);
      await expectLater(
        b.counterBooking(requests[1].id, requests[1].offeredPerDay),
        throwsA(
          isA<BackendException>().having(
            (e) => e.code,
            'code',
            'counter_too_low',
          ),
        ),
      );
      await b.counterBooking(requests[1].id, requests[1].offeredPerDay + 300);
      list = await firstWhere(
        inbox,
        (l) =>
            l.firstWhere((x) => x.id == requests[1].id).status !=
            BookingStatus.countered,
      );
      expect([
        BookingStatus.confirmed,
        BookingStatus.cancelled,
        BookingStatus.declined,
      ], contains(list.firstWhere((x) => x.id == requests[1].id).status));

      await b.markPickedUp(requests[0].id);
      await b.markReturned(requests[0].id);
      final e = await b.earnings();
      expect(
        e.allTime,
        greaterThanOrEqualTo(
          Pricing.quoteFor(
            requests[0].copyWith(agreedPerDay: requests[0].offeredPerDay),
          ).total,
        ),
      );
      expect(e.recent.map((x) => x.id), contains(requests[0].id));

      await b.setListed(car.id, false);
      expect((await b.myCars()).single.listed, isFalse);
      b.dispose();
    },
  );
}
