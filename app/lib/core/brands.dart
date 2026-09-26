import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

import 'brand_data.dart';

export 'brand_data.dart' show BrandData, brandData;

/// Brands shown first in pickers and on the home screen: the makes most
/// often rented in Albania.
const popularBrandIds = [
  'volkswagen',
  'mercedes',
  'bmw',
  'audi',
  'toyota',
  'hyundai',
  'kia',
  'skoda',
  'renault',
  'dacia',
  'fiat',
  'opel',
  'ford',
  'peugeot',
  'jeep',
  'nissan',
  'porsche',
  'tesla',
];

final _byId = {for (final b in brandData) b.id: b};

BrandData? brandById(String id) => _byId[id];

String _plain(String s) => s
    .toLowerCase()
    .replaceAll('š', 's')
    .replaceAll('ë', 'e')
    .replaceAll('é', 'e')
    .replaceAll('ç', 'c')
    .trim();

/// Finds the brand for a free-text make such as "VW", "Mercedes-Benz" or
/// "Škoda". Returns null for makes without a logo.
BrandData? brandFor(String make) {
  final m = _plain(make);
  if (m.isEmpty) return null;
  for (final b in brandData) {
    for (final a in b.aliases) {
      final alias = _plain(a);
      if (m == alias || m.startsWith('$alias ') || m.startsWith('$alias-')) {
        return b;
      }
    }
  }
  return null;
}

final _paths = <String, Path>{};

/// The logo as a Flutter path in a 24 × 24 box.
Path brandPath(BrandData b) =>
    _paths.putIfAbsent(b.id, () => parseSvgPathData(b.path));
