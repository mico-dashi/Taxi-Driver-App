import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';

/// App-wide state: who is logged in, language, where the user is, saved
/// payment methods and recent places.
class AppState extends ChangeNotifier {
  AppState({
    required this.backend,
    GeocodingService? geocoding,
    LocationService? location,
  }) : geocoding = geocoding ?? GeocodingService(),
       location = location ?? LocationService();

  final Backend backend;
  final GeocodingService geocoding;
  final LocationService location;

  UserProfile? user;
  String lang = 'sq';
  LatLng here = AppConfig.defaultCenter;
  Place? herePlace;
  List<Place> recents = [];
  List<PaymentMethod> paymentMethods = [PaymentMethod.cash];
  String selectedPaymentId = PaymentMethod.cash.id;
  Place? homePlace;
  Place? workPlace;
  int promoPercent = 0;
  String? promoCode;
  Set<String> favorites = {};

  bool isFavorite(String carId) => favorites.contains(carId);

  Future<void> toggleFavorite(String carId) async {
    favorites = {...favorites};
    if (!favorites.remove(carId)) favorites.add(carId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFavorites, favorites.toList());
  }

  PaymentMethod get selectedPayment => paymentMethods.firstWhere(
    (m) => m.id == selectedPaymentId,
    orElse: () => PaymentMethod.cash,
  );

  bool get isOwner => user?.role == UserRole.owner;

  /// The renter's current search: where and when they need a car.
  Place? searchPlace;
  late DateTime searchStart = _defaultStart();
  late DateTime searchEnd = searchStart.add(const Duration(days: 3));

  static DateTime _defaultStart() {
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day, AppConfig.defaultPickupHour);
  }

  Place get effectiveSearchPlace =>
      searchPlace ?? herePlace ?? Place('Tiranë', '', here);

  void setSearch({Place? place, DateTime? start, DateTime? end}) {
    if (place != null) searchPlace = place;
    if (start != null) searchStart = start;
    if (end != null) searchEnd = end;
    if (!searchEnd.isAfter(searchStart)) {
      searchEnd = searchStart.add(const Duration(days: 1));
    }
    notifyListeners();
  }

  static const _kLang = 'lang';
  static const _kRecents = 'recents';
  static const _kPayments = 'payment_methods';
  static const _kSelectedPayment = 'selected_payment';
  static const _kHome = 'place_home';
  static const _kWork = 'place_work';
  static const _kPromo = 'promo_code';
  static const _kFavorites = 'favorites';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    lang = prefs.getString(_kLang) ?? 'sq';
    favorites = (prefs.getStringList(_kFavorites) ?? const []).toSet();
    recents = _decodePlaces(prefs.getString(_kRecents));
    final pm = prefs.getString(_kPayments);
    if (pm != null) {
      paymentMethods = [
        PaymentMethod.cash,
        for (final j in jsonDecode(pm) as List)
          PaymentMethod.fromJson(j as Map<String, dynamic>),
      ];
    }
    selectedPaymentId =
        prefs.getString(_kSelectedPayment) ?? PaymentMethod.cash.id;
    homePlace = _decodePlace(prefs.getString(_kHome));
    workPlace = _decodePlace(prefs.getString(_kWork));
    try {
      user = await backend.restoreSession();
    } catch (_) {
      user = null;
    }
    final code = prefs.getString(_kPromo);
    if (code != null && user != null) await applyPromo(code, persist: false);
    notifyListeners();
    refreshLocation();
  }

  Future<void> refreshLocation() async {
    here = await location.current();
    notifyListeners();
    herePlace = await geocoding.reverse(here);
    notifyListeners();
  }

  Future<void> setLang(String value) async {
    lang = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, value);
  }

  void setUser(UserProfile? value) {
    user = value;
    notifyListeners();
  }

  Future<void> signOut() async {
    await backend.signOut();
    user = null;
    notifyListeners();
  }

  Future<void> addRecent(Place place) async {
    recents = [place, ...recents.where((p) => p != place)].take(5).toList();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRecents,
      jsonEncode(recents.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> setSavedPlace({
    required bool home,
    required Place? place,
  }) async {
    if (home) {
      homePlace = place;
    } else {
      workPlace = place;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = home ? _kHome : _kWork;
    if (place == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(place.toJson()));
    }
  }

  Future<void> addPaymentMethod(PaymentMethod m) async {
    paymentMethods = [...paymentMethods.where((p) => p.id != m.id), m];
    await selectPayment(m.id);
    await _savePayments();
  }

  Future<void> removePaymentMethod(String id) async {
    if (id == PaymentMethod.cash.id) return;
    paymentMethods = paymentMethods.where((p) => p.id != id).toList();
    if (selectedPaymentId == id) selectedPaymentId = PaymentMethod.cash.id;
    notifyListeners();
    await _savePayments();
  }

  Future<void> selectPayment(String id) async {
    selectedPaymentId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedPayment, id);
  }

  Future<void> _savePayments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPayments,
      jsonEncode(
        paymentMethods
            .where((m) => m.type != PaymentType.cash)
            .map((m) => m.toJson())
            .toList(),
      ),
    );
  }

  /// Returns the discount percent (0 if the code is invalid).
  Future<int> applyPromo(String code, {bool persist = true}) async {
    final percent = await backend.promoDiscount(code);
    promoPercent = percent;
    promoCode = percent > 0 ? code.trim().toUpperCase() : null;
    notifyListeners();
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      if (promoCode != null) {
        await prefs.setString(_kPromo, promoCode!);
      } else {
        await prefs.remove(_kPromo);
      }
    }
    return percent;
  }

  /// Promo codes are single use: clear after a completed ride.
  Future<void> consumePromo() async {
    promoPercent = 0;
    promoCode = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPromo);
  }

  static List<Place> _decodePlaces(String? raw) {
    if (raw == null) return [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          Place.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  static Place? _decodePlace(String? raw) {
    if (raw == null) return null;
    try {
      return Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
