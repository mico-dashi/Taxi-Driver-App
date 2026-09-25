import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// Popular destinations across Albania. Used for suggestions and as an offline
/// fallback when the geocoding service is unreachable.
class AlbanianPlaces {
  static const all = <Place>[
    // Tirana
    Place('Sheshi Skënderbej', 'Qendër, Tiranë', LatLng(41.3275, 19.8187)),
    Place('Blloku', 'Rruga Pjetër Bogdani, Tiranë', LatLng(41.3197, 19.8150)),
    Place(
      'Aeroporti i Tiranës "Nënë Tereza"',
      'Rinas, Tiranë',
      LatLng(41.4147, 19.7206),
    ),
    Place(
      'Toptani Shopping Center',
      'Rruga Abdi Toptani, Tiranë',
      LatLng(41.3268, 19.8215),
    ),
    Place(
      'TEG - Tirana East Gate',
      'Autostrada Tiranë–Elbasan',
      LatLng(41.2994, 19.8594),
    ),
    Place(
      'Piramida e Tiranës',
      'Bulevardi Dëshmorët e Kombit',
      LatLng(41.3234, 19.8215),
    ),
    Place('Parku i Liqenit të Madh', 'Tiranë', LatLng(41.3140, 19.8230)),
    Place(
      'Stadiumi Air Albania',
      'Sheshi Italia, Tiranë',
      LatLng(41.3183, 19.8243),
    ),
    Place(
      'Terminali i Autobusëve',
      'Rruga Dritan Hoxha, Tiranë',
      LatLng(41.3355, 19.7870),
    ),
    Place(
      'QSUT "Nënë Tereza"',
      'Rruga e Dibrës, Tiranë',
      LatLng(41.3375, 19.8262),
    ),
    Place(
      'Universiteti i Tiranës',
      'Sheshi Nënë Tereza, Tiranë',
      LatLng(41.3170, 19.8205),
    ),
    Place('Pazari i Ri', 'Tiranë', LatLng(41.3308, 19.8252)),
    Place('Dajti Ekspres', 'Rruga e Dajtit, Tiranë', LatLng(41.3445, 19.8740)),
    Place('Kombinat', 'Tiranë', LatLng(41.3230, 19.7730)),
    Place(
      'Sky Tower',
      'Rruga Dëshmorët e 4 Shkurtit, Tiranë',
      LatLng(41.3253, 19.8163),
    ),
    Place(
      'Stacioni i Trenit Tiranë',
      'Kashar, Tiranë',
      LatLng(41.3525, 19.7475),
    ),
    // Durrës
    Place('Qendra e Durrësit', 'Durrës', LatLng(41.3231, 19.4414)),
    Place('Porti i Durrësit', 'Durrës', LatLng(41.3104, 19.4491)),
    Place('Amfiteatri i Durrësit', 'Durrës', LatLng(41.3129, 19.4467)),
    Place('Plazhi i Golemit', 'Golem, Kavajë', LatLng(41.2455, 19.5048)),
    // South
    Place('Lungomare Vlorë', 'Vlorë', LatLng(40.4545, 19.4868)),
    Place('Sheshi i Flamurit', 'Vlorë', LatLng(40.4666, 19.4897)),
    Place('Sarandë', 'Qendër, Sarandë', LatLng(39.8756, 20.0053)),
    Place('Ksamil', 'Sarandë', LatLng(39.7686, 20.0000)),
    Place('Butrinti', 'Sarandë', LatLng(39.7456, 20.0202)),
    Place('Himarë', 'Vlorë', LatLng(40.1017, 19.7447)),
    Place('Dhërmi', 'Himarë, Vlorë', LatLng(40.1528, 19.6389)),
    Place('Gjirokastër', 'Qendra historike', LatLng(40.0758, 20.1389)),
    // Center / North / East
    Place('Berat', 'Qendër, Berat', LatLng(40.7058, 19.9522)),
    Place('Elbasan', 'Qendër, Elbasan', LatLng(41.1125, 20.0822)),
    Place('Fier', 'Qendër, Fier', LatLng(40.7239, 19.5561)),
    Place('Korçë', 'Qendër, Korçë', LatLng(40.6186, 20.7808)),
    Place('Pogradec', 'Pogradec', LatLng(40.9025, 20.6525)),
    Place('Kalaja e Rozafës', 'Shkodër', LatLng(42.0475, 19.4933)),
    Place('Shkodër', 'Qendër, Shkodër', LatLng(42.0683, 19.5126)),
    Place('Lezhë', 'Qendër, Lezhë', LatLng(41.7836, 19.6436)),
    Place('Kukës', 'Qendër, Kukës', LatLng(42.0769, 20.4219)),
  ];

  /// Shown under "Suggested" in the Where-to sheet.
  static List<Place> get suggested => all.take(8).toList();

  static List<Place> search(String query) {
    final q = normalize(query);
    if (q.isEmpty) return suggested;
    return all
        .where((p) => normalize('${p.name} ${p.subtitle}').contains(q))
        .toList();
  }

  /// Lets people type "rinas" or "skenderbej" without Albanian letters.
  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll('ë', 'e')
      .replaceAll('ç', 'c')
      .replaceAll('"', '')
      .trim();

  /// Rough label for where the user is, e.g. "Tiranë".
  static String cityFor(LatLng p) {
    const d = Distance();
    Place? best;
    var bestKm = double.infinity;
    for (final place in all) {
      final km = d.as(LengthUnit.Kilometer, p, place.point);
      if (km < bestKm) {
        bestKm = km;
        best = place;
      }
    }
    if (best == null || bestKm > 40) return 'Shqipëri';
    final parts = best.subtitle.split(',');
    return parts.last.trim();
  }
}
