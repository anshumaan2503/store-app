import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  ApiClient(this.baseUrl);

  Uri _build(String path, {Map<String, String>? query}) =>
      Uri.parse('$baseUrl/$path').replace(queryParameters: query);

  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final uri = _build(path, query: query);
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    try {
      return jsonDecode(res.body);
    } catch (_) {
      final teaser =
          res.body.length > 120 ? '${res.body.substring(0, 120)}…' : res.body;
      throw Exception('Invalid JSON from $uri: $teaser');
    }
  }

  // ---- Strongly-typed helpers ----
  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, String>? query,
  }) async {
    final data = await _get(path, query: query);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> _getListMap(
    String path, {
    Map<String, String>? query,
  }) async {
    final data = await _get(path, query: query);
    final list = (data as List);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /* ------------------ Endpoints (typed) ------------------ */
  Future<Map<String, dynamic>> getKpis() => _getMap('api/analytics/kpis');

  Future<List<Map<String, dynamic>>> getTrend(DateTime from, DateTime to) =>
      _getListMap(
        'api/analytics/movements-trend',
        query: {'from': from.toIso8601String(), 'to': to.toIso8601String()},
      );

  Future<List<Map<String, dynamic>>> getReceivingStatus() =>
      _getListMap('api/analytics/receiving-status');

  Future<List<Map<String, dynamic>>> getIssueStatus() =>
      _getListMap('api/analytics/issue-status');

  Future<List<Map<String, dynamic>>> getPlaceUtilization() =>
      _getListMap('api/analytics/place-utilization');

  Future<List<Map<String, dynamic>>> getTopItems(
    DateTime from,
    DateTime to,
    String type, {
    int limit = 10,
  }) => _getListMap(
    'api/analytics/top-items',
    query: {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      'type': type,
      'limit': '$limit',
    },
  );

  Future<List<Map<String, dynamic>>> getItemMovements(
    DateTime from,
    DateTime to,
  ) => _getListMap(
    'api/analytics/item-movements',
    query: {'from': from.toIso8601String(), 'to': to.toIso8601String()},
  );

  Future<List<Map<String, dynamic>>> getCategoryStock() =>
      _getListMap('api/analytics/category-stock');

  Future<List<Map<String, dynamic>>> getCategoryTrend(
    DateTime from,
    DateTime to,
  ) => _getListMap(
    'api/analytics/category-trend',
    query: {'from': from.toIso8601String(), 'to': to.toIso8601String()},
  );

  Future<List<Map<String, dynamic>>> getUserActivity(
    DateTime from,
    DateTime to, {
    int limit = 10,
  }) => _getListMap(
    'api/analytics/user-activity',
    query: {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      'limit': '$limit',
    },
  );

  Future<List<Map<String, dynamic>>> getLowStock({int threshold = 10}) =>
      _getListMap(
        'api/analytics/low-stock',
        query: {'threshold': '$threshold'},
      );

  Future<List<Map<String, dynamic>>> getDeadStock({int days = 60}) =>
      _getListMap('api/analytics/dead-stock', query: {'days': '$days'});

  Future<List<Map<String, dynamic>>> getPlaceHeatmap() =>
      _getListMap('api/analytics/place-heatmap');

  // Future<Map<String, dynamic>> getThroughput(
  //   String kind,
  //   DateTime from,
  //   DateTime to,
  // ) async => Map<String, dynamic>.from(
  //   await _get(
  //     'api/analytics/throughput',
  //     query: {
  //       'kind': kind,
  //       'from': from.toIso8601String(),
  //       'to': to.toIso8601String(),
  //     },
  //   ),
  // );

 Future<num> getThroughput(
  String kind,
  DateTime from,
  DateTime to,
) async {
  final data = await _get('api/analytics/throughput', query: {
    'kind': kind,
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
  });
  // Endpoint returns: { "avgHours": <number> }
  final map = Map<String, dynamic>.from(data as Map);
  final v = map['avgHours'] ?? 0;
  return (v is num) ? v : num.tryParse(v.toString()) ?? 0;
}


// Add these methods:

Future<List<Map<String, dynamic>>> getItemsMin() =>
  _getListMap('api/analytics/items-min');

Future<List<Map<String, dynamic>>> getItemLocations(String itemId) =>
  _getListMap('api/analytics/item-locations/$itemId');

// You already have this:
// Future<List<Map<String, dynamic>>> getTopItems(DateTime from, DateTime to, String type, {int limit = 10}) => ...


}
