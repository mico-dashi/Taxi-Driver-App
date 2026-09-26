import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/places.dart';
import '../models/models.dart';

class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    'User-Agent': '${AppConfig.userAgentPackage} (${AppConfig.supportEmail})',
    'Accept-Language': 'sq,en',
  };

  /// Searches addresses in Albania. Local popular places come first, then
  /// results from the geocoder (if reachable).
  Future<List<Place>> search(String query) async {
    final local = AlbanianPlaces.search(query);
    if (query.trim().length < 3) return local;
    try {
      final uri = Uri.parse('${AppConfig.geocodingUrl}/search').replace(
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'countrycodes': AppConfig.countryCode,
          'limit': '8',
          'addressdetails': '1',
        },
      );
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return local;
      final list = jsonDecode(res.body) as List;
      final remote = list
          .map((e) => _toPlace(e as Map<String, dynamic>))
          .toList();
      final seen = local.map((p) => AlbanianPlaces.normalize(p.name)).toSet();
      return [
        ...local,
        ...remote.where((p) => seen.add(AlbanianPlaces.normalize(p.name))),
      ];
    } catch (_) {
      return local;
    }
  }

  /// Turns a GPS position into a human readable place.
  Future<Place> reverse(LatLng p) async {
    try {
      final uri = Uri.parse('${AppConfig.geocodingUrl}/reverse').replace(
        queryParameters: {
          'lat': '${p.latitude}',
          'lon': '${p.longitude}',
          'format': 'jsonv2',
          'zoom': '17',
          'addressdetails': '1',
        },
      );
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final place = _toPlace(jsonDecode(res.body) as Map<String, dynamic>);
        return Place(place.name, place.subtitle, p);
      }
    } catch (_) {}
    return Place(
      AlbanianPlaces.cityFor(p),
      '${p.latitude.toStringAsFixed(5)}, '
      '${p.longitude.toStringAsFixed(5)}',
      p,
    );
  }

  static Place _toPlace(Map<String, dynamic> e) {
    final addr = (e['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    final road = addr['road'] as String?;
    final number = addr['house_number'] as String?;
    final name = (e['name'] as String?)?.trim();
    final title = (name != null && name.isNotEmpty)
        ? name
        : [road, number].whereType<String>().join(' ');
    final city =
        addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'];
    final subtitle = [
      if (road != null && road != title) road,
      ?city,
    ].join(', ');
    return Place(
      title.isEmpty ? (e['display_name'] as String).split(',').first : title,
      subtitle,
      LatLng(double.parse('${e['lat']}'), double.parse('${e['lon']}')),
    );
  }
}
