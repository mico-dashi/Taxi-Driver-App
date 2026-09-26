import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/brands.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../widgets/car_art.dart';
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
    final carWidth = (size.width * 0.96).clamp(260.0, 520.0);
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
          // Hero car with a red glow.
          Positioned(
            top: stageH * 0.56,
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
              child: Center(
                child: CarArt(
                  color: AppColors.primary,
                  shape: CarShape.sport,
                  width: carWidth,
                ),
              ),
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
                  const SizedBox(height: 20),
                  // Popular brands on the platform, as glass buttons.
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
                        for (final id in popularBrandIds.take(10))
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GlassBrand(
                              make: brandById(id)!.name,
                              size: 48,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
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
