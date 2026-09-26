import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';
import 'glass.dart' show BrandLogo;

/// Body styles the side-view drawing knows.
enum CarShape { hatch, sedan, sport, suv, van }

const _suvModels = [
  'x1',
  'x3',
  'x5',
  'x6',
  'q3',
  'q5',
  'q7',
  'gle',
  'glc',
  'gla',
  'tucson',
  'sportage',
  'rav4',
  'duster',
  'renegade',
  'tiguan',
  'qashqai',
  'kodiaq',
  'range',
  'cayenne',
  'macan',
  'touareg',
  'santa',
  'cr-v',
  'kuga',
  'captur',
];
const _sedanModels = [
  'octavia',
  'passat',
  'corolla',
  'jetta',
  'superb',
  'e 220',
  'e220',
  'c 200',
  'c200',
  'a4',
  'a6',
  '3 series',
  '5 series',
  '320',
  '520',
  'elantra',
  'accent',
  'insignia',
  'camry',
  'mondeo',
  's-class',
  'e-class',
  'c-class',
];
const _sportModels = ['911', 'amg gt', 'm4', 'tt', 'mustang', 'gt86', 'z4'];

/// Picks a body style from the listing (category first, model as a hint).
CarShape shapeFor(Car car) => shapeForListing(
  categoryId: car.categoryId,
  make: car.make,
  model: car.model,
  seats: car.seats,
);

CarShape shapeForListing({
  required String categoryId,
  String make = '',
  String model = '',
  int seats = 5,
}) {
  final m = '$make $model'.toLowerCase();
  if (categoryId == 'van' || seats >= 7) return CarShape.van;
  if (_sportModels.any(m.contains)) return CarShape.sport;
  if (categoryId == 'suv' || _suvModels.any(m.contains)) return CarShape.suv;
  if (_sedanModels.any(m.contains)) return CarShape.sedan;
  if (categoryId == 'luxury') return CarShape.sport;
  return CarShape.hatch;
}

/// Key points of a body style, in a 200 × 80 box (car faces right).
class _Spec {
  const _Spec({
    required this.rearX,
    required this.frontX,
    required this.deckY,
    required this.glassRearX,
    required this.roofRearX,
    required this.roofY,
    required this.roofFrontX,
    required this.screenX,
    required this.hoodY,
    required this.noseY,
    required this.beltY,
    required this.wheelR,
    required this.rearWheelX,
    required this.frontWheelX,
    this.pillars = 1,
  });

  final double rearX, frontX, deckY, glassRearX, roofRearX, roofY;
  final double roofFrontX, screenX, hoodY, noseY, beltY;
  final double wheelR, rearWheelX, frontWheelX;
  final int pillars;

  static const ground = 78.0;
  double get wheelY => ground - wheelR;
  double get sillY => wheelY + 1;
}

const _specs = {
  CarShape.hatch: _Spec(
    rearX: 10,
    frontX: 192,
    deckY: 33,
    glassRearX: 15,
    roofRearX: 40,
    roofY: 14,
    roofFrontX: 100,
    screenX: 138,
    hoodY: 38,
    noseY: 46,
    beltY: 35,
    wheelR: 17,
    rearWheelX: 43,
    frontWheelX: 157,
  ),
  CarShape.sedan: _Spec(
    rearX: 4,
    frontX: 196,
    deckY: 35,
    glassRearX: 38,
    roofRearX: 74,
    roofY: 15,
    roofFrontX: 112,
    screenX: 146,
    hoodY: 38,
    noseY: 46,
    beltY: 36,
    wheelR: 17,
    rearWheelX: 42,
    frontWheelX: 159,
  ),
  CarShape.sport: _Spec(
    rearX: 4,
    frontX: 198,
    deckY: 36,
    glassRearX: 22,
    roofRearX: 84,
    roofY: 20,
    roofFrontX: 104,
    screenX: 142,
    hoodY: 42,
    noseY: 50,
    beltY: 40,
    wheelR: 18,
    rearWheelX: 42,
    frontWheelX: 161,
  ),
  CarShape.suv: _Spec(
    rearX: 8,
    frontX: 194,
    deckY: 30,
    glassRearX: 12,
    roofRearX: 28,
    roofY: 8,
    roofFrontX: 112,
    screenX: 142,
    hoodY: 32,
    noseY: 38,
    beltY: 31,
    wheelR: 19,
    rearWheelX: 45,
    frontWheelX: 156,
    pillars: 2,
  ),
  CarShape.van: _Spec(
    rearX: 5,
    frontX: 195,
    deckY: 10,
    glassRearX: 6,
    roofRearX: 9,
    roofY: 6,
    roofFrontX: 138,
    screenX: 170,
    hoodY: 38,
    noseY: 44,
    beltY: 31,
    wheelR: 16,
    rearWheelX: 38,
    frontWheelX: 160,
    pillars: 3,
  ),
};

/// Side view of a car in its own colour, drawn in code so every listing
/// has a good-looking "photo" even before owners upload real ones.
class CarSideView extends StatelessWidget {
  const CarSideView({
    super.key,
    required this.color,
    this.shape = CarShape.sedan,
    this.width = 200,
    this.redCalipers = false,
  });

  CarSideView.of(Car car, {super.key, this.width = 200})
    : color = Color(car.colorValue),
      shape = shapeFor(car),
      redCalipers = car.categoryId == 'luxury';

  final Color color;
  final CarShape shape;
  final double width;
  final bool redCalipers;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.4),
      painter: _CarSidePainter(color, shape, redCalipers),
    );
  }
}

class _CarSidePainter extends CustomPainter {
  _CarSidePainter(this.color, this.shape, this.redCalipers);

  final Color color;
  final CarShape shape;
  final bool redCalipers;

  @override
  void paint(Canvas canvas, Size size) {
    final s = _specs[shape]!;
    canvas.save();
    canvas.scale(size.width / 200);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromLTRB(
        s.rearX + 6,
        _Spec.ground - 5,
        s.frontX - 4,
        _Spec.ground + 3,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final body = _bodyPath(s);
    final bright = color.computeLuminance();
    final top = Color.lerp(color, Colors.white, bright > 0.6 ? 0.1 : 0.32)!;
    final bottom = Color.lerp(color, Colors.black, bright > 0.6 ? 0.35 : 0.55)!;
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, color, color, bottom],
          stops: const [0, 0.42, 0.62, 1],
        ).createShader(Rect.fromLTRB(0, s.roofY, 200, s.sillY)),
    );

    canvas.save();
    canvas.clipPath(body);
    // Rocker panel shade along the bottom.
    canvas.drawRect(
      Rect.fromLTRB(0, s.sillY - 7, 200, s.sillY + 2),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    // Shoulder highlight: a soft light line along the body side.
    final shoulder = s.beltY + 7;
    canvas.drawRect(
      Rect.fromLTRB(0, shoulder, 200, shoulder + 1.4),
      Paint()
        ..color = Colors.white.withValues(alpha: bright > 0.6 ? 0.5 : 0.22),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, shoulder + 1.4, 200, shoulder + 5),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.restore();

    _windows(canvas, s);
    _doors(canvas, s, bottom);
    _lights(canvas, s);
    _wheel(canvas, s.rearWheelX, s);
    _wheel(canvas, s.frontWheelX, s);

    canvas.restore();
  }

  Path _bodyPath(_Spec s) {
    final p = Path();
    final archR = s.wheelR + 2.5;
    // Rear bottom corner, up the tail to the deck.
    p.moveTo(s.rearX + 7, s.sillY);
    p.cubicTo(
      s.rearX + 1,
      s.sillY,
      s.rearX,
      s.deckY + 6,
      s.rearX + 2,
      s.deckY + 2,
    );
    p.quadraticBezierTo(s.rearX + 3, s.deckY, s.rearX + 8, s.deckY - 0.5);
    // Deck / tailgate to the rear glass.
    p.lineTo(s.glassRearX, s.deckY - 1.5);
    // Rear glass up to the roof.
    p.cubicTo(
      s.glassRearX + (s.roofRearX - s.glassRearX) * 0.55,
      s.deckY - 3,
      s.roofRearX - 6,
      s.roofY,
      s.roofRearX + 2,
      s.roofY,
    );
    // Roof with a slight crown.
    p.quadraticBezierTo(
      (s.roofRearX + s.roofFrontX) / 2,
      s.roofY - 1.5,
      s.roofFrontX,
      s.roofY + 0.5,
    );
    // Windscreen down to the hood.
    p.cubicTo(
      s.roofFrontX + 8,
      s.roofY + 2,
      s.screenX - 10,
      s.hoodY - 3,
      s.screenX,
      s.hoodY,
    );
    // Hood to the nose.
    p.cubicTo(
      s.screenX + 18,
      s.hoodY + 1.5,
      s.frontX - 12,
      s.hoodY + 3,
      s.frontX - 2,
      s.noseY,
    );
    // Front face down to the bumper.
    p.cubicTo(
      s.frontX + 1,
      s.noseY + 3,
      s.frontX + 1,
      s.sillY - 5,
      s.frontX - 5,
      s.sillY,
    );
    // Underside with wheel arches.
    _arch(p, s.frontWheelX, s.wheelY, archR, s.sillY);
    _arch(p, s.rearWheelX, s.wheelY, archR, s.sillY);
    p.close();
    return p;
  }

  static void _arch(Path p, double cx, double cy, double r, double sillY) {
    final a = math.asin(((sillY - cy) / r).clamp(-1.0, 1.0));
    p.lineTo(cx + r * math.cos(a), sillY);
    p.arcTo(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      a,
      -(math.pi + 2 * a),
      false,
    );
  }

  void _windows(Canvas canvas, _Spec s) {
    final inset = 2.6;
    final wr = s.glassRearX + (shape == CarShape.van ? 6 : 5);
    final rr = s.roofRearX + 3;
    final rf = s.roofFrontX - 1;
    final wb = s.screenX - 5;
    final top = s.roofY + inset;
    final glass = Path()
      ..moveTo(wr, s.beltY)
      ..cubicTo(wr + (rr - wr) * 0.45, s.beltY - 4, rr - 4, top, rr + 2, top)
      ..lineTo(rf - 1, top)
      ..cubicTo(rf + 6, top + 1, wb - 8, s.beltY - 5, wb, s.beltY)
      ..close();
    canvas.drawPath(
      glass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3F47), Color(0xFF0B0C0E)],
        ).createShader(Rect.fromLTRB(0, top, 200, s.beltY)),
    );
    canvas.save();
    canvas.clipPath(glass);
    // Sky reflection streak.
    canvas.drawPath(
      Path()
        ..moveTo(rr + 18, top)
        ..lineTo(rr + 34, top)
        ..lineTo(rr + 22, s.beltY)
        ..lineTo(rr + 8, s.beltY)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.09),
    );
    // Pillars in body colour.
    final pillar = Paint()..color = Color.lerp(color, Colors.black, 0.35)!;
    final span = rf - rr;
    for (var i = 1; i <= s.pillars; i++) {
      final x = rr + span * (i / (s.pillars + 1)) + (s.pillars == 1 ? 6 : 0);
      canvas.drawRect(Rect.fromLTRB(x, top - 2, x + 3.2, s.beltY + 1), pillar);
    }
    canvas.restore();
    // Chrome window line.
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _doors(Canvas canvas, _Spec s, Color shade) {
    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    final span = s.roofFrontX - s.roofRearX;
    final bx =
        s.roofRearX +
        span * (1 / (s.pillars + 1)) +
        (s.pillars == 1 ? 7.6 : 1.6);
    final frontDoor = s.screenX - 4;
    final bottom = s.sillY - 7;
    // Door cut lines.
    canvas.drawLine(Offset(bx, s.beltY + 1), Offset(bx + 1, bottom), line);
    canvas.drawLine(
      Offset(frontDoor, s.beltY + 1),
      Offset(frontDoor - 1, bottom),
      line,
    );
    if (shape != CarShape.sport && shape != CarShape.van) {
      final rearDoor = s.glassRearX + (bx - s.glassRearX) * 0.25 + 4;
      canvas.drawLine(
        Offset(rearDoor, s.beltY + 2),
        Offset(rearDoor + 3, bottom),
        line,
      );
    }
    // Door handles.
    final handle = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (final x in [bx - 12, frontDoor - 12]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, s.beltY + 5, 6, 1.6),
          const Radius.circular(1),
        ),
        handle,
      );
    }
    // Side mirror.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.screenX - 7, s.beltY - 4.5, 6, 3.6),
        const Radius.circular(1.6),
      ),
      Paint()..color = shade,
    );
  }

  void _lights(Canvas canvas, _Spec s) {
    // Headlight: a slim bright blade with a glow.
    final head = Path()
      ..moveTo(s.frontX - 14, s.noseY - 0.6)
      ..quadraticBezierTo(
        s.frontX - 5,
        s.noseY - 1.6,
        s.frontX - 1,
        s.noseY + 0.6,
      )
      ..lineTo(s.frontX - 2, s.noseY + 2.4)
      ..quadraticBezierTo(
        s.frontX - 8,
        s.noseY + 2,
        s.frontX - 14,
        s.noseY + 1.4,
      )
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..color = const Color(0xFFFFF7E0).withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    canvas.drawPath(head, Paint()..color = const Color(0xFFFFFBF0));
    // Tail light.
    final tailY = s.deckY + (shape == CarShape.van ? 22 : 3);
    final tail = RRect.fromRectAndRadius(
      Rect.fromLTWH(s.rearX + 1.4, tailY, 7, 3.4),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(
      tail,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.drawRRect(tail, Paint()..color = const Color(0xFFFF2233));
  }

  void _wheel(Canvas canvas, double cx, _Spec s) {
    final c = Offset(cx, s.wheelY);
    final r = s.wheelR;
    // Arch shadow and tyre.
    canvas.drawCircle(c, r + 1.8, Paint()..color = const Color(0xFF050505));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF151618));
    canvas.drawCircle(
      c,
      r - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.08),
    );
    // Rim.
    final rim = r * 0.66;
    canvas.drawCircle(
      c,
      rim,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4E7EB), Color(0xFF8B9097), Color(0xFF4D5157)],
        ).createShader(Rect.fromCircle(center: c, radius: rim)),
    );
    canvas.drawCircle(c, rim * 0.86, Paint()..color = const Color(0xFF1E2023));
    if (redCalipers) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rim * 0.62),
        -2.4,
        1.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rim * 0.28
          ..color = AppColors.primary,
      );
    }
    // Five spokes.
    final spoke = Paint()
      ..strokeWidth = rim * 0.2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFD9DCE0), Color(0xFF7A7F86)],
      ).createShader(Rect.fromCircle(center: c, radius: rim));
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * rim * 0.18,
        c + Offset(math.cos(a), math.sin(a)) * rim * 0.84,
        spoke,
      );
    }
    canvas.drawCircle(c, rim * 0.22, Paint()..color = const Color(0xFFBFC3C8));
    canvas.drawCircle(c, rim * 0.09, Paint()..color = const Color(0xFF2A2C30));
  }

  @override
  bool shouldRepaint(_CarSidePainter old) =>
      old.color != color ||
      old.shape != shape ||
      old.redCalipers != redCalipers;
}

/// A car on a dark "studio" floor: soft red glow behind, shadow and a faint
/// reflection underneath. Used for the hero images across the app.
class CarShowcase extends StatelessWidget {
  const CarShowcase({
    super.key,
    required this.car,
    required this.width,
    this.glow = true,
    this.reflection = true,
  });

  final Car car;
  final double width;
  final bool glow;
  final bool reflection;

  @override
  Widget build(BuildContext context) {
    return CarArt(
      color: Color(car.colorValue),
      shape: shapeFor(car),
      width: width,
      glow: glow,
      reflection: reflection,
      redCalipers: car.categoryId == 'luxury',
    );
  }
}

class CarArt extends StatelessWidget {
  const CarArt({
    super.key,
    required this.color,
    required this.shape,
    required this.width,
    this.glow = true,
    this.reflection = true,
    this.redCalipers = false,
  });

  final Color color;
  final CarShape shape;
  final double width;
  final bool glow;
  final bool reflection;
  final bool redCalipers;

  @override
  Widget build(BuildContext context) {
    final car = CarSideView(
      color: color,
      shape: shape,
      width: width,
      redCalipers: redCalipers,
    );
    final h = width * 0.4;
    return SizedBox(
      width: width,
      height: reflection ? h * 1.32 : h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (glow)
            Positioned(
              left: width * 0.1,
              right: width * 0.1,
              top: h * 0.05,
              height: h * 0.95,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.6,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.28),
                      AppColors.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          if (reflection)
            Positioned(
              left: 0,
              top: h * 0.955,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.13),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.42],
                ).createShader(r),
                child: Transform.flip(flipY: true, child: car),
              ),
            ),
          Positioned(left: 0, top: 0, child: car),
        ],
      ),
    );
  }
}

final _dataUriCache = <String, Uint8List>{};

Uint8List _bytesOf(String dataUri) => _dataUriCache.putIfAbsent(
  dataUri,
  () => base64Decode(dataUri.substring(dataUri.indexOf(',') + 1)),
);

/// One car photo from a URL or a data: URI, cropped to fill its box.
class CarPhoto extends StatelessWidget {
  const CarPhoto(this.src, {super.key, this.fit = BoxFit.cover, this.fallback});

  final String src;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext c, Object e, StackTrace? s) =>
        fallback ?? const ColoredBox(color: Color(0xFF1A1B1D));
    if (src.startsWith('data:')) {
      return Image.memory(
        _bytesOf(src),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: error,
      );
    }
    return Image.network(
      src,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: error,
      loadingBuilder: (c, child, progress) =>
          progress == null ? child : const ColoredBox(color: Color(0x14FFFFFF)),
    );
  }
}

/// The car's cover image: its first photo when the owner uploaded one,
/// otherwise the drawing in the car's colour.
class CarImage extends StatelessWidget {
  const CarImage({
    super.key,
    required this.car,
    required this.width,
    this.height,
    this.reflection = false,
  });

  final Car car;
  final double width;
  final double? height;
  final bool reflection;

  @override
  Widget build(BuildContext context) {
    final drawing = SizedBox(
      width: double.infinity,
      height: height,
      child: CarPlaceholder.of(car),
    );
    if (car.photos.isEmpty) return drawing;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CarPhoto(car.photos.first, fallback: drawing),
    );
  }
}

/// Stand-in until the owner uploads photos: the brand's logo glowing in
/// front of the model name in giant letters, tinted by the car's colour.
class CarPlaceholder extends StatelessWidget {
  const CarPlaceholder({
    super.key,
    required this.make,
    required this.model,
    required this.color,
    this.logoScale = 0.42,
  });

  CarPlaceholder.of(Car car, {super.key, this.logoScale = 0.42})
    : make = car.make,
      model = car.model,
      color = Color(car.colorValue);

  final String make;
  final String model;
  final Color color;

  /// Logo size as a share of the box's shorter side.
  final double logoScale;

  @override
  Widget build(BuildContext context) {
    final glow = Color.lerp(AppColors.primary, color, 0.3)!;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : 300.0;
        final h = box.maxHeight.isFinite ? box.maxHeight : w * 0.6;
        final logo = (h < w ? h : w) * logoScale;
        final word = model.trim().isEmpty ? make : model;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.05),
                  radius: 0.75,
                  colors: [
                    glow.withValues(alpha: 0.45),
                    glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            // Giant model name behind the logo.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.04),
              child: Center(
                child: FittedBox(
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ).createShader(r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        word.toUpperCase(),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 120,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: logo * 0.12,
                      sigmaY: logo * 0.12,
                    ),
                    child: BrandLogo(make: make, size: logo, color: glow),
                  ),
                  BrandLogo(make: make, size: logo),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
