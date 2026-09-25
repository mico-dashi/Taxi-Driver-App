import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap', style: TextStyle(fontSize: 10)),
          alignment: Alignment.topRight,
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

/// Taxi seen from above, rotated to its heading. Optional ETA bubble.
Marker carMarker(Driver d, {String? eta, bool highlight = false}) => Marker(
  point: d.location,
  width: 70,
  height: eta == null ? 40 : 64,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (eta != null)
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            eta,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      Transform.rotate(
        angle: d.heading * math.pi / 180,
        child: TaxiTopView(
          color: d.vehicle.categoryId == 'luxury'
              ? AppColors.ink
              : AppColors.primary,
          highlight: highlight,
        ),
      ),
    ],
  ),
);

class TaxiTopView extends StatelessWidget {
  const TaxiTopView({
    super.key,
    this.color = AppColors.primary,
    this.highlight = false,
  });

  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: highlight ? AppColors.pickup : Colors.white,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 5),
          Container(
            width: 12,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xAA1A2230),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          Container(
            width: 12,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xAA1A2230),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Rotating radar sweep drawn over the pickup while searching for drivers.
class RadarSweep extends StatefulWidget {
  const RadarSweep({super.key, this.size = 260});

  final double size;

  @override
  State<RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<RadarSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _RadarPainter(_c.value),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    for (final f in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(c, r * f, ring);
    }
    // Pulse.
    canvas.drawCircle(
      c,
      r * t,
      Paint()..color = AppColors.primary.withValues(alpha: 0.18 * (1 - t)),
    );
    // Sweep.
    final angle = t * 2 * math.pi;
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 2,
        colors: [
          AppColors.primary.withValues(alpha: 0),
          AppColors.primary.withValues(alpha: 0.45),
        ],
        transform: GradientRotation(angle - math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, angle - math.pi / 2, math.pi / 2, true, sweep);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}
