import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// OpenStreetMap-based map used across the app.
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.controller,
    required this.center,
    this.zoom = 14.5,
    this.children = const [],
    this.onReady,
    this.interactive = true,
  });

  final MapController controller;
  final LatLng center;
  final double zoom;
  final List<Widget> children;
  final VoidCallback? onReady;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 6,
        maxZoom: 19,
        onMapReady: onReady,
        backgroundColor: const Color(0xFFEFEDE8),
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.tileUrl,
          userAgentPackageName: AppConfig.userAgentPackage,
          maxZoom: 19,
        ),
        ...children,
        // Credit required by the OpenStreetMap licence.
        Align(
          alignment: Alignment.topRight,
          child: IgnorePointer(
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              color: const Color(0xB3FFFFFF),
              child: const Text(
                '© OpenStreetMap',
                style: TextStyle(fontSize: 9, color: AppColors.inkSoft),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fits the camera to [points] with room for the UI on top and bottom.
void fitPoints(
  MapController controller,
  List<LatLng> points, {
  EdgeInsets padding = const EdgeInsets.fromLTRB(90, 130, 90, 330),
}) {
  if (points.isEmpty) return;
  if (points.length == 1) {
    controller.move(points.first, 15);
    return;
  }
  final bounds = LatLngBounds.fromPoints(points);
  // Avoid zooming in absurdly when both points are almost the same.
  if (bounds.north - bounds.south < 0.002 &&
      bounds.east - bounds.west < 0.002) {
    controller.move(bounds.center, 16);
    return;
  }
  controller.fitCamera(
    CameraFit.bounds(bounds: bounds, padding: padding, maxZoom: 16.5),
  );
}

Polyline routeLine(
  List<LatLng> points, {
  Color color = AppColors.primaryDark,
}) => Polyline(
  points: points,
  strokeWidth: 5,
  color: color,
  borderStrokeWidth: 2,
  borderColor: Colors.white,
);

Marker pinMarker(LatLng p, {required bool pickup, String? label}) => Marker(
  point: p,
  width: label == null ? 28 : 160,
  height: label == null ? 28 : 64,
  alignment: label == null ? Alignment.center : const Alignment(0, -0.3),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (label != null)
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 6),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: pickup ? AppColors.pickup : AppColors.destination,
            width: 7,
          ),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
        ),
      ),
    ],
  ),
);

/// Price pin for a car on the search map, like listing sites use.
Marker priceMarker(
  Car car, {
  required String label,
  bool selected = false,
  VoidCallback? onTap,
}) => Marker(
  point: car.location.point,
  width: 96,
  height: 44,
  alignment: const Alignment(0, -0.6),
  child: GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.border,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Color(car.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.inkFaint, width: 0.8),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _PinTailPainter(
            selected ? AppColors.ink : AppColors.surface,
          ),
        ),
      ],
    ),
  ),
);

class _PinTailPainter extends CustomPainter {
  _PinTailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

/// A car drawn from above, nose pointing up, in the car's own paint colour.
class CarTopView extends StatelessWidget {
  const CarTopView({
    super.key,
    required this.color,
    this.size = 50,
    this.angle = 0,
  });

  final Color color;

  /// Height in logical pixels (width is about half).
  final double size;

  /// Rotation in degrees (0 = nose up).
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: CustomPaint(
        size: Size(size * 0.52, size),
        painter: _CarPainter(body: color, highlight: false, taxiSign: false),
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  _CarPainter({
    required this.body,
    required this.highlight,
    required this.taxiSign,
  });

  final Color body;
  final bool highlight;
  final bool taxiSign;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final car = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.1, h * 0.04, w * 0.8, h * 0.92),
      topLeft: Radius.circular(w * 0.38),
      topRight: Radius.circular(w * 0.38),
      bottomLeft: Radius.circular(w * 0.26),
      bottomRight: Radius.circular(w * 0.26),
    );

    // Soft shadow under the car.
    canvas.drawRRect(
      car.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    if (highlight) {
      canvas.drawRRect(
        car.inflate(3),
        Paint()
          ..color = AppColors.pickup
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Wheels peeking out at the sides.
    final tyre = Paint()..color = const Color(0xFF15171B);
    for (final y in [h * 0.2, h * 0.72]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.04, y, w * 0.92, h * 0.12),
          const Radius.circular(2),
        ),
        tyre,
      );
    }

    // Body with a slight lengthwise shading.
    canvas.drawRRect(
      car,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(body, Colors.black, 0.12)!,
            Color.lerp(body, Colors.white, 0.18)!,
            Color.lerp(body, Colors.black, 0.12)!,
          ],
        ).createShader(car.outerRect),
    );

    // Side mirrors.
    final mirror = Paint()..color = Color.lerp(body, Colors.black, 0.25)!;
    canvas.drawOval(Rect.fromLTWH(0, h * 0.3, w * 0.16, h * 0.06), mirror);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.84, h * 0.3, w * 0.16, h * 0.06),
      mirror,
    );

    final glass = Paint()..color = const Color(0xFF2B3440);
    // Windshield.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.22, h * 0.36)
        ..quadraticBezierTo(w * 0.5, h * 0.25, w * 0.78, h * 0.36)
        ..lineTo(w * 0.72, h * 0.45)
        ..lineTo(w * 0.28, h * 0.45)
        ..close(),
      glass,
    );
    // Rear window.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, h * 0.74)
        ..lineTo(w * 0.72, h * 0.74)
        ..lineTo(w * 0.76, h * 0.82)
        ..quadraticBezierTo(w * 0.5, h * 0.87, w * 0.24, h * 0.82)
        ..close(),
      glass,
    );
    // Windshield shine.
    canvas.drawLine(
      Offset(w * 0.34, h * 0.35),
      Offset(w * 0.46, h * 0.31),
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // Roof and TAXI sign.
    final roof = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.26, h * 0.46, w * 0.48, h * 0.27),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(
      roof,
      Paint()..color = Color.lerp(body, Colors.white, 0.1)!,
    );
    if (taxiSign) {
      final sign = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.595),
        width: w * 0.42,
        height: h * 0.1,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(sign, const Radius.circular(2)),
        Paint()..color = AppColors.ink,
      );
      final text = TextPainter(
        text: const TextSpan(
          text: 'TAXI',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 4.6,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, sign.center - Offset(text.width / 2, text.height / 2));
    }

    // Headlights (front) and tail lights (back).
    final head = Paint()..color = const Color(0xFFFFF6D0);
    final tail = Paint()..color = const Color(0xFFE5484D);
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.07, w * 0.18, h * 0.05), head);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.62, h * 0.07, w * 0.18, h * 0.05),
      head,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.9, w * 0.18, h * 0.04),
        const Radius.circular(1),
      ),
      tail,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.64, h * 0.9, w * 0.18, h * 0.04),
        const Radius.circular(1),
      ),
      tail,
    );
  }

  @override
  bool shouldRepaint(_CarPainter old) =>
      old.body != body ||
      old.highlight != highlight ||
      old.taxiSign != taxiSign;
}
