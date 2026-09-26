import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/l10n.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/owner/owner_shell.dart';
import 'screens/renter/renter_shell.dart';
import 'state/app_state.dart';

class TaxiApp extends StatelessWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppState, String>((s) => s.lang);
    return MaterialApp(
      title: AppConfig.brandName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: Locale(lang),
      supportedLocales: const [Locale('sq'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => L10nScope(lang: lang, child: child!),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    await Future.wait([
      app.init(),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => homeFor(app.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(child: BrandLogo(size: 88, showName: true)),
    );
  }
}

/// Decides the first screen for a (possibly logged out) user.
Widget homeFor(UserProfile? user) {
  if (user == null) return const LoginScreen();
  if (user.name.trim().isEmpty) return const ProfileSetupScreen();
  return user.role == UserRole.owner ? const OwnerShell() : const RenterShell();
}

/// Replaces the whole navigation stack, e.g. after login or switching mode.
void goHome(BuildContext context) {
  final user = context.read<AppState>().user;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => homeFor(user)),
    (_) => false,
  );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64, this.showName = false});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Icon(
            Icons.car_rental_rounded,
            color: AppColors.primary,
            size: size * 0.6,
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 16),
          const Text(
            AppConfig.brandName,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            AppConfig.brandTagline,
            style: TextStyle(fontSize: 14, color: AppColors.ink),
          ),
        ],
      ],
    );
  }
}
