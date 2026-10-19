/// Defensive parsing utilities for Flutter Store models.
/// Prevents runtime [TypeError] exceptions during JSON deserialization when backend
/// numeric representations vary (int vs double vs string) or MongoDB ObjectIds vary
/// (String vs Map with $oid or nested _id).
library;

int? toInt(dynamic value, {int? defaultValue}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.isFinite ? value.toInt() : defaultValue;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsedInt = int.tryParse(value);
    if (parsedInt != null) return parsedInt;
    final parsedDouble = double.tryParse(value);
    if (parsedDouble != null && parsedDouble.isFinite) return parsedDouble.toInt();
  }
  return defaultValue;
}

double? toDouble(dynamic value, {double? defaultValue}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsedDouble = double.tryParse(value);
    if (parsedDouble != null) return parsedDouble;
  }
  return defaultValue;
}

String parseMongoId(dynamic map, [String defaultId = '']) {
  if (map == null) return defaultId;
  if (map is String) return map;
  if (map is Map) {
    if (map.containsKey('_id')) return parseMongoId(map['_id'], defaultId);
    if (map.containsKey('id')) return parseMongoId(map['id'], defaultId);
    if (map.containsKey(r'$oid')) return map[r'$oid']?.toString() ?? defaultId;
  }
  return defaultId;
}

String extractId(Map<String, dynamic>? map, {String defaultId = ''}) {
  if (map == null) return defaultId;
  if (map['_id'] != null) return parseMongoId(map['_id'], defaultId);
  if (map['id'] != null) return parseMongoId(map['id'], defaultId);
  return defaultId;
}
