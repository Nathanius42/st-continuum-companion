/// Number formatting for stats, without pulling in the intl package.
library;

/// 111700 → "111,700".
String thousands(num value) {
  final whole = value.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return out.toString();
}

/// 163.0 → "163", 184.8 → "184.8".
String trimmed(double value) => value == value.roundToDouble()
    ? thousands(value)
    : value.toStringAsFixed(1);

/// 0.4 → "0.4 s", 1.25 → "1.25 s", 10 → "10 s": short intervals, to the
/// hundredth.
String seconds(double value) {
  var s = value.toStringAsFixed(2);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return '$s s';
}

/// 239 → "3 min 59 s", 35 → "35 s".
String duration(double seconds) {
  final s = seconds.round();
  if (s < 60) return '$s s';
  final m = s ~/ 60, rest = s % 60;
  return rest == 0 ? '$m min' : '$m min $rest s';
}
