import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taksi_al/app.dart';
import 'package:taksi_al/services/demo_backend.dart';
import 'package:taksi_al/services/geocoding_service.dart';
import 'package:taksi_al/state/app_state.dart';

void main() {
  testWidgets('renter: login -> search -> car -> offer -> request sent', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final offline = MockClient((_) async => http.Response('offline', 503));
    final backend = DemoBackend(speed: 20);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(
          backend: backend,
          geocoding: GeocodingService(client: offline),
        ),
        child: const TaxiApp(),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '069 123 4567');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    // Two modes, like "passenger / driver" in the taxi version.
    expect(find.text('Find a car to rent'), findsOneWidget);
    expect(find.text('I have a car for rent'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Alda Hoxha');
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Home: search card, promo, cars nearby.
    expect(find.text('Search cars'), findsOneWidget);
    expect(find.textContaining('20% off'), findsOneWidget);
    expect(find.text('Pick-up'), findsWidgets);
    expect(find.textContaining('/day'), findsWidgets);

    await tester.tap(find.text('Search cars'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cars available'), findsOneWidget);
    expect(find.text('Golf 7 · 2018'), findsOneWidget);

    await tester.tap(find.text('Golf 7 · 2018'));
    await tester.pumpAndSettle();
    expect(find.text('Arben Hoxha'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('RENTAL TERMS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Return at the same level'), findsOneWidget);
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    // Dates -> Payment -> Offer.
    expect(find.text('When do you need the car?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('How would you like to pay?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your offer'), findsWidgets);
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining("Below the owner's"), findsOneWidget);
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    // The simulated owner answers the lower offer with a counter-offer.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('sent you a counter-offer'), findsOneWidget);
    await tester.tap(find.textContaining('Accept ·'));
    await tester.pumpAndSettle();
    expect(find.text('Booking confirmed!'), findsOneWidget);
    expect(find.text('I picked up the car'), findsOneWidget);

    // Nothing is left running after the test.
    backend.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('owner: list a car -> request arrives -> accept', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final offline = MockClient((_) async => http.Response('offline', 503));
    final backend = DemoBackend(speed: 20);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(
          backend: backend,
          geocoding: GeocodingService(client: offline),
        ),
        child: const TaxiApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '068 555 1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Arben Hoxha');
    await tester.tap(find.text('I have a car for rent'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Add your first car'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add car'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add car').last);
    await tester.pumpAndSettle();

    Future<void> fill(String label, String value) async {
      await tester.enterText(find.widgetWithText(TextField, label), value);
    }

    await fill('Make', 'Volkswagen');
    await fill('Model', 'Golf 7');
    await fill('Year', '2018');
    await fill('Plate number', 'AA 482 TR');
    await tester.scrollUntilVisible(
      find.text('Choose where the car is parked'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Choose where the car is parked'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose where the car is parked'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blloku'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Publish car'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Publish car'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish car'));
    await tester.pumpAndSettle();
    expect(find.text('Volkswagen Golf 7 · 2018'), findsOneWidget);

    // Back to the requests inbox; a simulated renter sends a request.
    await tester.tap(find.text('Requests'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('NEW REQUESTS'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Accept').first);
    await tester.pumpAndSettle();
    expect(find.text('UPCOMING HANDOVERS'), findsOneWidget);

    backend.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
