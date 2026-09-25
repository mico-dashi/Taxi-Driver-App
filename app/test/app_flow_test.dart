import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taksi_al/app.dart';
import 'package:taksi_al/services/demo_backend.dart';
import 'package:taksi_al/services/geocoding_service.dart';
import 'package:taksi_al/services/routing_service.dart';
import 'package:taksi_al/state/app_state.dart';

void main() {
  testWidgets('login -> code -> profile -> home -> where to', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final offline = MockClient((_) async => http.Response('offline', 503));
    final backend = DemoBackend(
      routing: RoutingService(client: offline),
      speed: 20,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(
          backend: backend,
          routing: RoutingService(client: offline),
          geocoding: GeocodingService(client: offline),
        ),
        child: const TaxiApp(),
      ),
    );

    // Splash -> login (Albanian by default).
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Mirë se vini!'), findsOneWidget);

    // Switch to English.
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome!'), findsOneWidget);

    // Invalid number is rejected.
    await tester.enterText(find.byType(TextField), '12345');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('valid Albanian mobile'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '069 123 4567');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.textContaining('+355691234567'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(find.text('What is your name?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Alda Hoxha');
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Home, like the video.
    expect(find.textContaining('Alda'), findsWidgets);
    expect(find.text('Where would you go?'), findsOneWidget);
    expect(find.text('AVAILABLE CARS'), findsOneWidget);
    expect(find.text('Book →'), findsWidgets);
    expect(find.textContaining('30% off'), findsOneWidget);

    // Apply the promo from the banner.
    await tester.tap(find.text('TAKSI30'));
    await tester.pumpAndSettle();
    expect(find.text('Code applied'), findsOneWidget);

    // Where to? sheet with Albanian suggestions.
    await tester.tap(find.text('Where would you go?'));
    await tester.pumpAndSettle();
    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Use current location'), findsOneWidget);
    expect(find.text('Sheshi Skënderbej'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'rinas');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aeroporti'), findsOneWidget);

    // Close the sheet and visit the other tabs.
    Navigator.of(tester.element(find.text('Where to?'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('PAST RIDES'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Alda Hoxha'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Become a driver'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Become a driver'), findsOneWidget);

    backend.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
