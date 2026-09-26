import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/brands.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../widgets/design.dart';
import '../../widgets/glass.dart' show GlassBrand;
import 'login_screen.dart';

/// First screen for logged-out users: a hero car on a dark stage, a big
/// headline and a "slide to start" button, like a premium car app.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  // The car drives in from the left when the screen opens.
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _start() =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final stageH = (size.height * 0.52).clamp(300.0, 480.0);
    return Scaffold(
      body: Stack(
        children: [
          // Stage: foggy graphite gradient fading to black.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.45),
                  radius: 1.0,
                  colors: [
                    const Color(0xFF3A3D42),
                    const Color(0xFF17191B),
                    AppColors.background,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          // Giant "AL" behind the car.
          Positioned(
            top: stageH * 0.12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Transform.scale(
                  scaleY: 1.35,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ).createShader(r),
                    // Padding keeps the glyph edges inside the gradient.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'AL',
                        style: TextStyle(
                          fontSize: stageH * 0.5,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -stageH * 0.03,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Showroom wall of glass brand logos.
          Positioned(
            top: stageH * 0.5,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_intro.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(-size.width * 0.6 * (1 - t), 0),
                    child: child,
                  ),
                );
              },
              child: const _BrandWall(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      BrandLogo(size: 36),
                      SizedBox(width: 10),
                      BrandName(fontSize: 20),
                      Spacer(),
                      LanguageToggle(),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    context.tr('welcome_title'),
                    style: const TextStyle(
                      fontSize: 38,
                      height: 1.12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('welcome_subtitle'),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SlideAction(
                    label: context.tr('welcome_cta'),
                    icon: Icons.directions_car_filled_rounded,
                    onSubmit: _start,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two staggered rows of popular brands in glass, the middle ones larger.
class _BrandWall extends StatelessWidget {
  const _BrandWall();

  @override
  Widget build(BuildContext context) {
    Widget row(List<String> ids, List<double> sizes) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < ids.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GlassBrand(make: brandById(ids[i])!.name, size: sizes[i]),
          ),
      ],
    );
    return Column(
      children: [
        row(['toyota', 'mercedes', 'bmw', 'volkswagen'], [58, 74, 74, 58]),
        const SizedBox(height: 12),
        row(['audi', 'porsche', 'hyundai'], [62, 80, 62]),
        const SizedBox(height: 12),
        row(['kia', 'skoda', 'tesla', 'jeep'], [50, 58, 58, 50]),
      ],
    );
  }
}
