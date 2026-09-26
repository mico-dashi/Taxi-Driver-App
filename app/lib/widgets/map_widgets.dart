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

/// The part of [route] still ahead of [car]: the stretch already driven is
/// dropped, and the line starts exactly under the car.
List<LatLng> remainingRoute(List<LatLng> route, LatLng car) {
  if (route.length < 2) return route;
  const d = Distance();
  var best = 0;
  var bestMetres = double.infinity;
  for (var i = 0; i < route.length; i++) {
    final m = d.as(LengthUnit.Meter, route[i], car);
    if (m < bestMetres) {
      bestMetres = m;
      best = i;
    }
  }
  // If the car is already past the nearest vertex, start from the next one.
  if (best < route.length - 1) {
    final ahead = d.as(LengthUnit.Meter, car, route[best + 1]);
    final segment = d.as(LengthUnit.Meter, route[best], route[best + 1]);
    if (ahead < segment) best++;
  }
  return [car, ...route.sublist(best)];
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

/// Smoothly animated taxis. Each time [drivers] changes, every car glides
/// from where it is drawn now to its new position over [duration], turning
/// along the shortest arc, so cars never jump between GPS updates.
class SmoothCars extends StatefulWidget {
  const SmoothCars({
    super.key,
    required this.drivers,
    this.duration = const Duration(milliseconds: 1000),
    this.labelFor,
    this.highlight = const {},
  });

  final List<Driver> drivers;

  /// Should match how often positions arrive.
  final Duration duration;
  final String? Function(Driver driver)? labelFor;
  final Set<String> highlight;

  @override
  State<SmoothCars> createState() => _SmoothCarsState();
}

class _Pose {
  const _Pose(this.point, this.heading);
  final LatLng point;
  final double heading;
}

class _SmoothCarsState extends State<SmoothCars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  final _from = <String, _Pose>{};
  final _to = <String, _Pose>{};

  @override
  void initState() {
    super.initState();
    for (final d in widget.drivers) {
      _from[d.id] = _to[d.id] = _Pose(d.location, d.heading);
    }
    _anim.value = 1;
  }

  @override
  void didUpdateWidget(SmoothCars old) {
    super.didUpdateWidget(old);
    var moved = false;
    final ids = <String>{};
    for (final d in widget.drivers) {
      ids.add(d.id);
      final current = _poseOf(d.id);
      final target = _to[d.id];
      if (current == null || target == null) {
        _from[d.id] = _to[d.id] = _Pose(d.location, d.heading);
        continue;
      }
      if (target.point == d.location && target.heading == d.heading) continue;
      const dist = Distance();
      final metres = dist.as(LengthUnit.Meter, current.point, d.location);
      // Face the direction of travel; keep the old heading when parked.
      final heading = metres > 3
          ? _bearing(current.point, d.location)
          : (metres > 0.5 ? d.heading : current.heading);
      _from[d.id] = current;
      _to[d.id] = _Pose(d.location, heading);
      moved = true;
    }
    _from.removeWhere((id, _) => !ids.contains(id));
    _to.removeWhere((id, _) => !ids.contains(id));
    if (moved) {
      _anim.duration = widget.duration;
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  _Pose? _poseOf(String id) {
    final a = _from[id];
    final b = _to[id];
    if (a == null || b == null) return null;
    final t = _anim.value;
    // Turn a little faster than the car moves, like a real steering wheel.
    final turn = Curves.easeOut.transform(t);
    var delta = (b.heading - a.heading) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return _Pose(
      LatLng(
        a.point.latitude + (b.point.latitude - a.point.latitude) * t,
        a.point.longitude + (b.point.longitude - a.point.longitude) * t,
      ),
      a.heading + delta * turn,
    );
  }

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitudeInRad;
    final lat2 = b.latitudeInRad;
    final dLon = b.longitudeInRad - a.longitudeInRad;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => MarkerLayer(
        markers: [
          for (final d in widget.drivers)
            _marker(d, _poseOf(d.id) ?? _Pose(d.location, d.heading)),
        ],
      ),
    );
  }

  Marker _marker(Driver d, _Pose pose) {
    final label = widget.labelFor?.call(d);
    return Marker(
      point: pose.point,
      width: 72,
      height: label == null ? 52 : 78,
      alignment: label == null ? Alignment.center : const Alignment(0, 0.33),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Transform.rotate(
            angle: pose.heading * math.pi / 180,
            child: TaxiTopView(
              luxury: d.vehicle.categoryId == 'luxury',
              highlight: widget.highlight.contains(d.id),
            ),
          ),
        ],
      ),
    );
  }
}

/// A taxi drawn from above, nose pointing up (north).
class TaxiTopView extends StatelessWidget {
  const TaxiTopView({
    super.key,
    this.luxury = false,
    this.highlight = false,
    this.dimmed = false,
  });

  final bool luxury;
  final bool highlight;

  /// Grey car (e.g. a driver who is offline).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 50),
      painter: _TaxiPainter(
        body: dimmed
            ? const Color(0xFFB8BCC4)
            : (luxury ? const Color(0xFF1E2128) : AppColors.primary),
        highlight: highlight,
        taxiSign: !luxury && !dimmed,
      ),
    );
  }
}

class _TaxiPainter extends CustomPainter {
  _TaxiPainter({
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
  bool shouldRepaint(_TaxiPainter old) =>
      old.body != body ||
      old.highlight != highlight ||
      old.taxiSign != taxiSign;
}

/// Moves the camera smoothly instead of jumping.
class MapMover {
  MapMover(this.controller, TickerProvider vsync)
    : _anim = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 900),
      ) {
    _anim.addListener(_tick);
  }

  final MapController controller;
  final AnimationController _anim;
  LatLng? _fromCenter;
  LatLng? _toCenter;
  double _fromZoom = 0;
  double _toZoom = 0;

  void animateTo(LatLng center, double zoom) {
    final cam = controller.camera;
    _fromCenter = cam.center;
    _fromZoom = cam.zoom;
    _toCenter = center;
    _toZoom = zoom;
    _anim.forward(from: 0);
  }

  /// Animated version of [fitPoints].
  void fit(
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.fromLTRB(90, 130, 90, 330),
  }) {
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(points);
    if (points.length == 1 ||
        (bounds.north - bounds.south < 0.002 &&
            bounds.east - bounds.west < 0.002)) {
      animateTo(bounds.center, 16);
      return;
    }
    final target = CameraFit.bounds(
      bounds: bounds,
      padding: padding,
      maxZoom: 16.5,
    ).fit(controller.camera);
    animateTo(target.center, target.zoom);
  }

  void _tick() {
    final a = _fromCenter;
    final b = _toCenter;
    if (a == null || b == null) return;
    final t = Curves.easeInOut.transform(_anim.value);
    controller.move(
      LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
      _fromZoom + (_toZoom - _fromZoom) * t,
    );
  }

  void stop() => _anim.stop();

  void dispose() => _anim.dispose();
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
