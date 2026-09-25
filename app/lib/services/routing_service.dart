import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../models/models.dart';

class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _cache = <String, RouteInfo>{};

  /// Driving route between two points. Falls back to an estimated route when
  /// the routing server is unreachable, so booking never gets stuck.
  Future<RouteInfo> route(LatLng from, LatLng to) async {
    final key =
        '${from.latitude},${from.longitude}-${to.latitude},${to.longitude}';
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final uri = Uri.parse(
        '${AppConfig.routingUrl}/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = body['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final coords = (r['geometry']['coordinates'] as List)
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();
          final info = RouteInfo(
            points: coords,
            distanceKm: (r['distance'] as num) / 1000,
            durationMin: (r['duration'] as num) / 60,
          );
          _cache[key] = info;
          return info;
        }
      }
    } catch (_) {
      // Fall through to the estimate.
    }
    return estimate(from, to);
  }

  /// Straight-line distance x 1.3 road factor at ~30 km/h city speed, drawn
  /// as an L-shaped path so it still looks like driving.
  static RouteInfo estimate(LatLng from, LatLng to) {
    const d = Distance();
    final straight = d.as(LengthUnit.Meter, from, to) / 1000;
    final roadKm = straight * 1.3;
    final speed = roadKm > 20 ? 60.0 : 30.0;
    final corner = LatLng(from.latitude, to.longitude);
    return RouteInfo(
      points: [from, corner, to],
      distanceKm: roadKm,
      durationMin: math.max(1, roadKm / speed * 60),
    );
  }

  /// Rough pickup ETA in minutes at city speed (~25 km/h).
  static int etaMinutes(LatLng from, LatLng to) {
    const d = Distance();
    final km = d.as(LengthUnit.Meter, from, to) / 1000 * 1.3;
    return math.max(1, (km / 25 * 60).round());
  }

  /// Point at [fraction] (0..1) of the way along [points].
  static LatLng pointAlong(List<LatLng> points, double fraction) {
    if (points.isEmpty) return AppConfig.defaultCenter;
    if (points.length == 1 || fraction <= 0) return points.first;
    if (fraction >= 1) return points.last;
    const d = Distance();
    final seg = <double>[];
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final l = d.as(LengthUnit.Meter, points[i], points[i + 1]);
      seg.add(l);
      total += l;
    }
    if (total == 0) return points.first;
    var target = total * fraction;
    for (var i = 0; i < seg.length; i++) {
      if (target <= seg[i] && seg[i] > 0) {
        final t = target / seg[i];
        final a = points[i];
        final b = points[i + 1];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      target -= seg[i];
    }
    return points.last;
  }

  /// Compass bearing in degrees from [a] to [b].
  static double bearing(LatLng a, LatLng b) {
    final lat1 = a.latitudeInRad;
    final lat2 = b.latitudeInRad;
    final dLon = b.longitudeInRad - a.longitudeInRad;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
