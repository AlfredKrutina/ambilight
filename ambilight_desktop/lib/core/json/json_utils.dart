/// Defensive JSON casting matching Python `json.load` loose typing.

int asInt(Object? v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double asDouble(Object? v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
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
