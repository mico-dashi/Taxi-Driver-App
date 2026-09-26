import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/l10n.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'screens/auth/welcome_screen.dart';
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
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
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
      backgroundColor: AppColors.background,
      body: Center(child: BrandLogo(size: 88, showName: true)),
    );
  }
}

/// Decides the first screen for a (possibly logged out) user.
Widget homeFor(UserProfile? user) {
  if (user == null) return const WelcomeScreen();
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
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: size * 0.4,
              ),
            ],
          ),
          child: Icon(
            Icons.directions_car_filled_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 18),
          const BrandName(fontSize: 32),
          const SizedBox(height: 6),
          const Text(
            AppConfig.brandTagline,
            style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
        ],
      ],
    );
  }
}

/// "Rent AL" with the AL in red.
class BrandName extends StatelessWidget {
  const BrandName({super.key, this.fontSize = 20});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final parts = AppConfig.brandName.split(' ');
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: AppColors.ink,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: parts.first),
          if (parts.length > 1)
            TextSpan(
              text: ' ${parts.skip(1).join(' ')}',
              style: const TextStyle(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
