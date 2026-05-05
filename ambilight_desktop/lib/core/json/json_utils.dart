/// Defensive JSON casting matching Python `json.load` loose typing.

bool _numericStringIsAbsent(String s) {
  final t = s.trim().toLowerCase();
  return t.isEmpty ||
      t == 'none' ||
      t == 'null' ||
      t == 'nan' ||
      t == '-' ||
      t == 'n/a';
}

int asInt(Object? v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) {
    if (!v.isFinite) return fallback;
    return v.round();
  }
  if (v is String) {
    final s = v.trim();
    if (_numericStringIsAbsent(s)) return fallback;
    return int.tryParse(s) ?? fallback;
  }
  return fallback;
}

double asDouble(Object? v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is double) {
    if (!v.isFinite) return fallback;
    return v;
  }
  if (v is int) return v.toDouble();
  if (v is String) {
    final s = v.trim().replaceAll(',', '.');
    if (_numericStringIsAbsent(s)) return fallback;
    final x = double.tryParse(s);
    if (x == null || !x.isFinite) return fallback;
    return x;
  }
  return fallback;
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  if (v is int) return v != 0;
  return fallback;
}

String asString(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

List<int> asRgb(Object? v, [List<int> fallback = const [255, 255, 255]]) {
  if (v is List) {
    final out = <int>[];
    for (final e in v.take(3)) {
      out.add(asInt(e));
    }
    while (out.length < 3) {
      out.add(0);
    }
    return out;
  }
  return List<int>.from(fallback);
}

Map<String, dynamic> asMap(Object? v) {
  if (v is Map<String, dynamic>) return Map<String, dynamic>.from(v);
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return {};
}

List<Map<String, dynamic>> asMapList(Object? v) {
  if (v is! List) return [];
  return v.map((e) => asMap(e)).toList();
}

/// Rekurzivně nahradí ne-konečná `double` (JSON encoder na ně spadne) a projde mapy/seznamy.
dynamic jsonSanitizeForEncode(dynamic v) {
  if (v == null || v is bool || v is String) return v;
  if (v is int) return v;
  if (v is double) return v.isFinite ? v : 0.0;
  if (v is List) {
    return v.map(jsonSanitizeForEncode).toList();
  }
  if (v is Map) {
    return v.map((k, dynamic val) => MapEntry(k.toString(), jsonSanitizeForEncode(val)));
  }
  return v;
}
