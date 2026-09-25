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
