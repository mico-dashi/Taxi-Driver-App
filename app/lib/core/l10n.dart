import 'package:flutter/widgets.dart';

import '../services/backend.dart';
import 'strings.dart';

/// Albanian (default) and English. To add a language, add a map to
/// `strings.dart` and a button in the language picker.
class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.lang, required super.child});

  final String lang;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10nScope>()?.lang ?? 'sq';

  @override
  bool updateShouldNotify(L10nScope old) => old.lang != lang;
}

String translate(String lang, String key, [Map<String, String>? args]) {
  var s = Strings.byLang[lang]?[key] ?? Strings.byLang['en']![key] ?? key;
  args?.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

String errorCode(Object e) => e is BackendException ? e.code : 'generic';

extension L10nContext on BuildContext {
  String get lang => L10nScope.of(this);

  String tr(String key, [Map<String, String>? args]) =>
      translate(lang, key, args);

  /// Server errors come back as codes like `offer_expired`.
  String trError(String code) {
    final key = 'err_$code';
    final t = translate(lang, key);
    return t == key ? translate(lang, 'err_generic') : t;
  }
}

const _months = {
  'sq': [
    'Jan',
    'Shk',
    'Mar',
    'Pri',
    'Maj',
    'Qer',
    'Kor',
    'Gus',
    'Sht',
    'Tet',
    'Nën',
    'Dhj',
  ],
  'en': [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ],
};
const _weekdays = {
  'sq': ['Hën', 'Mar', 'Mër', 'Enj', 'Pre', 'Sht', 'Die'],
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
};

extension DateLabels on BuildContext {
  /// "Pre 3 Tet" / "Fri 3 Oct".
  String day(DateTime t) {
    final l = _months.containsKey(lang) ? lang : 'en';
    return '${_weekdays[l]![t.weekday - 1]} ${t.day} ${_months[l]![t.month - 1]}';
  }

  /// "Pre 3 Tet, 10:00".
  String dayTime(DateTime t) =>
      '${day(t)}, ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// "3 – 6 Tet" style range for compact cards.
  String dayRange(DateTime a, DateTime b) => '${day(a)} → ${day(b)}';
}
