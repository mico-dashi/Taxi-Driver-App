import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/brands.dart';
import '../core/theme.dart';

/// The app's backdrop: near-black with soft red and steel light blooms, so
/// the frosted glass on top has colour to refract.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          const Positioned.fill(child: _Blooms()),
          // Glass surfaces inside one page share one backdrop pass.
          Positioned.fill(child: BackdropGroup(child: child)),
        ],
      ),
    );
  }
}

class _Blooms extends StatelessWidget {
  const _Blooms();

  @override
  Widget build(BuildContext context) {
    Widget bloom(Alignment at, double radius, Color color) => Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: at,
            radius: radius,
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
    return IgnorePointer(
      child: Stack(
        children: [
          bloom(
            const Alignment(1.1, -1.05),
            0.95,
            AppColors.primary.withValues(alpha: 0.55),
          ),
          bloom(
            const Alignment(-1.2, -0.1),
            0.8,
            const Color(0xFF8E0310).withValues(alpha: 0.45),
          ),
          bloom(
            const Alignment(0.9, 0.75),
            0.75,
            const Color(0xFF5A0A12).withValues(alpha: 0.5),
          ),
          bloom(
            const Alignment(-0.6, 1.2),
            0.8,
            const Color(0xFF6F7885).withValues(alpha: 0.16),
          ),
          bloom(
            const Alignment(-0.2, -0.55),
            0.6,
            const Color(0xFF9AA4B2).withValues(alpha: 0.07),
          ),
        ],
      ),
    );
  }
}

/// Gives every page its own aurora backdrop, so the glass looks right and
/// pages never show through each other while they slide in.
class AuroraPageTransitionsBuilder extends PageTransitionsBuilder {
  const AuroraPageTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    AuroraBackground(child: child),
  );
}

/// Frosted "liquid glass": the backdrop is blurred and brightened, with a
/// light sheen from the top-left and a bright rim like a glass edge.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.circle = false,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.strength = 1,
    this.onTap,
    this.blur = 22,
    this.shadow = true,
    this.width,
    this.height,
    this.selected = false,
    this.grouped = false,
  });

  final Widget child;

  /// Share one backdrop pass with other glass in the page. Only for glass
  /// that sits directly on the page background (e.g. cards in a list).
  final bool grouped;
  final double radius;
  final bool circle;
  final EdgeInsetsGeometry padding;

  /// Optional colour mixed into the glass (e.g. red for the active tab).
  final Color? tint;

  /// 0.5 = subtle, 1 = normal, 1.6 = bright.
  final double strength;
  final VoidCallback? onTap;
  final double blur;
  final bool shadow;
  final double? width;
  final double? height;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final shape = circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final t = tint;
    final fill = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: t == null
          ? [
              Colors.white.withValues(alpha: 0.16 * strength),
              Colors.white.withValues(alpha: 0.05 * strength),
              Colors.white.withValues(alpha: 0.09 * strength),
            ]
          : [
              Color.lerp(t, Colors.white, 0.25)!.withValues(alpha: 0.75),
              t.withValues(alpha: 0.55),
              t.withValues(alpha: 0.7),
            ],
      stops: const [0, 0.55, 1],
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: content,
        ),
      );
    }
    final clipped = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: _backdrop(
        ui.ImageFilter.compose(
          outer: const ColorFilter.matrix(_brighten),
          inner: ui.ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
            tileMode: TileMode.mirror,
          ),
        ),
        CustomPaint(
          foregroundPainter: _RimPainter(
            shape: shape,
            selected: selected,
            tinted: t != null,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: fill),
            child: content,
          ),
        ),
      ),
    );
    return Container(
      width: width,
      height: height,
      decoration: shadow
          ? ShapeDecoration(
              shape: shape,
              shadows: [
                BoxShadow(
                  color: (t ?? Colors.black).withValues(
                    alpha: t == null ? 0.35 : 0.35,
                  ),
                  blurRadius: t == null ? 28 : 22,
                  offset: const Offset(0, 10),
                ),
              ],
            )
          : null,
      child: clipped,
    );
  }

  Widget _backdrop(ui.ImageFilter filter, Widget child) => grouped
      ? BackdropFilter.grouped(filter: filter, child: child)
      : BackdropFilter(filter: filter, child: child);

  // Slight lift in brightness and saturation of what is behind the glass.
  static const _brighten = <double>[
    1.12, 0, 0, 0, 8, //
    0, 1.12, 0, 0, 8,
    0, 0, 1.12, 0, 8,
    0, 0, 0, 1, 0,
  ];
}

/// Bright rim: strong at the top-left, fading, and catching light again at
/// the bottom-right, plus a soft inner highlight along the top edge.
class _RimPainter extends CustomPainter {
  _RimPainter({
    required this.shape,
    required this.selected,
    required this.tinted,
  });

  final ShapeBorder shape;
  final bool selected;
  final bool tinted;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outline = shape.getOuterPath(rect.deflate(0.6));
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.6 : 1.1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  AppColors.primaryLight,
                  AppColors.primary.withValues(alpha: 0.4),
                  AppColors.primaryLight.withValues(alpha: 0.8),
                ]
              : [
                  Colors.white.withValues(alpha: tinted ? 0.7 : 0.5),
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: tinted ? 0.35 : 0.22),
                ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
    // Specular sheen hugging the top edge.
    canvas.save();
    canvas.clipPath(shape.getOuterPath(rect));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: tinted ? 0.18 : 0.1),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.shape != shape || old.selected != selected || old.tinted != tinted;
}

/// A car brand's logo, in white by default (or the brand colour). Falls back
/// to the make's initials for brands without a logo.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.make,
    this.size = 24,
    this.color = Colors.white,
  });

  final String make;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final b = brandFor(make);
    if (b == null) {
      final words = make.trim().split(RegExp(r'[\s-]+'));
      final text = words.length > 1
          ? words.take(2).map((w) => w.isEmpty ? '' : w[0]).join()
          : make.characters.take(2).toString();
      return SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          child: Text(
            text.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ),
      );
    }
    return Semantics(
      label: b.name,
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(brandPath(b), color),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.path != path || old.color != color;
}

/// Brand logo in a round glass button, used for brand filters and badges.
class GlassBrand extends StatelessWidget {
  const GlassBrand({
    super.key,
    required this.make,
    this.size = 56,
    this.selected = false,
    this.onTap,
  });

  final String make;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Glass(
      circle: true,
      width: size,
      height: size,
      tint: selected ? AppColors.primary : null,
      selected: selected,
      onTap: onTap,
      shadow: false,
      child: Center(
        child: BrandLogo(make: make, size: size * 0.46),
      ),
    );
  }
}
