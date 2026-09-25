import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';

class LocationService {
  LatLng? _last;
  LatLng get lastKnown => _last ?? AppConfig.defaultCenter;

  /// Current GPS position, or the default city center when permission is
  /// denied / GPS is off (the user can still type their pickup).
  Future<LatLng> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return lastKnown;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return lastKnown;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
      final p = LatLng(pos.latitude, pos.longitude);
      // Outside Albania (e.g. an emulator in California)? Use the demo center.
      if (!_inAlbania(p)) return lastKnown;
      return _last = p;
    } catch (_) {
      return lastKnown;
    }
  }

  /// Continuous updates for drivers who are online.
  Stream<LatLng> watch() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    ),
  ).map((p) => _last = LatLng(p.latitude, p.longitude));

  static bool _inAlbania(LatLng p) =>
      p.latitude > 39.6 &&
      p.latitude < 42.7 &&
      p.longitude > 19.2 &&
      p.longitude < 21.1;
}
