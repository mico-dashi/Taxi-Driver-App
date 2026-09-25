import 'config.dart';

/// 1250 -> "1.250 L" (Albanian thousands separator is a dot).
String money(int lek) {
  final s = lek.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${lek < 0 ? '-' : ''}$buf ${AppConfig.currencySymbol}';
}

String km(double v) =>
    v < 10 ? '${v.toStringAsFixed(1)} km' : '${v.round()} km';

String minutes(num v) {
  final m = v.round().clamp(1, 100000);
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String dayMonth(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';

/// Accepts "069 123 4567", "+355691234567", "691234567"; returns E.164.
String? normalizeAlbanianPhone(String input) {
  var d = input.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+355')) d = d.substring(4);
  if (d.startsWith('00355')) d = d.substring(5);
  if (d.startsWith('0')) d = d.substring(1);
  // Albanian mobile numbers: 6X XXX XXXX (9 digits).
  if (!RegExp(r'^6[6-9]\d{7}$').hasMatch(d)) return null;
  return '${AppConfig.phonePrefix}$d';
}
