// lib/analytics/providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/constants.dart';
import '../repositories/dashboard_api.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  // TODO: change to your API base URL
  return ApiClient(Constants.socketUrl);
});

class Kpis {
  final int totalItems, totalPlaces, openReceivings, openIssues;
  final num stockOnHand, todayReceived, todayIssued;
  Kpis({
    required this.totalItems,
    required this.totalPlaces,
    required this.openReceivings,
    required this.openIssues,
    required this.stockOnHand,
    required this.todayReceived,
    required this.todayIssued,
  });
  factory Kpis.fromJson(Map<String, dynamic> j) => Kpis(
    totalItems: j['totalItems'] ?? 0,
    totalPlaces: j['totalPlaces'] ?? 0,
    openReceivings: j['openReceivings'] ?? 0,
    openIssues: j['openIssues'] ?? 0,
    stockOnHand: j['stockOnHand'] ?? 0,
    todayReceived: j['todayReceived'] ?? 0,
    todayIssued: j['todayIssued'] ?? 0,
  );
}

class TrendPoint {
  final String day;
  final num receive, issue, scrap;
  TrendPoint({
    required this.day,
    required this.receive,
    required this.issue,
    required this.scrap,
  });
  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
    day: j['day'] as String,
    receive: j['receive'] ?? 0,
    issue: j['issue'] ?? 0,
    scrap: j['scrap'] ?? 0,
  );
}

class StatusCount {
  final String status;
  final int count;
  StatusCount({required this.status, required this.count});
  factory StatusCount.fromJson(Map<String, dynamic> j) =>
      StatusCount(status: j['status'] ?? '', count: j['count'] ?? 0);
}

class PlaceUtilRow {
  final String name, code;
  final num totalQty, issuedQty, available;
  PlaceUtilRow({
    required this.name,
    required this.code,
    required this.totalQty,
    required this.issuedQty,
    required this.available,
  });
  factory PlaceUtilRow.fromJson(Map<String, dynamic> j) => PlaceUtilRow(
    name: j['name'] ?? '',
    code: j['code'] ?? '',
    totalQty: j['totalQty'] ?? 0,
    issuedQty: j['issuedQty'] ?? 0,
    available: j['available'] ?? 0,
  );
}

final kpiProvider = FutureProvider<Kpis>((ref) async {
  final api = ref.watch(apiClientProvider);
  return Kpis.fromJson(await api.getKpis());
});

final dateRangeProvider = StateProvider<Tuple2<DateTime, DateTime>>((ref) {
  final now = DateTime.now();
  final from = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6)); // last 7 days
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return Tuple2(from, to);
});

class Tuple2<A, B> {
  final A item1;
  final B item2;
  const Tuple2(this.item1, this.item2);
}

final trendProvider = FutureProvider<List<TrendPoint>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final range = ref.watch(dateRangeProvider);
  final raw = await api.getTrend(range.item1, range.item2);
  return raw
      .map((e) => TrendPoint.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

final recStatusProvider = FutureProvider<List<StatusCount>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final raw = await api.getReceivingStatus();
  return raw
      .map((e) => StatusCount.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

final issStatusProvider = FutureProvider<List<StatusCount>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final raw = await api.getIssueStatus();
  return raw
      .map((e) => StatusCount.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

final placeUtilProvider = FutureProvider<List<PlaceUtilRow>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final raw = await api.getPlaceUtilization();
  return raw
      .map((e) => PlaceUtilRow.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

// in providers.dart
final itemMovementsProvider = FutureProvider<List<ItemMovement>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final range = ref.watch(dateRangeProvider);
  final raw = await api.getItemMovements(range.item1, range.item2);
  return raw
      .map((e) => ItemMovement.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

class ItemMovement {
  final String itemName, placeName, type, refNo, note;
  final num qty;
  final DateTime createdAt;

  ItemMovement({
    required this.itemName,
    required this.placeName,
    required this.qty,
    required this.type,
    required this.refNo,
    required this.note,
    required this.createdAt,
  });

  factory ItemMovement.fromJson(Map<String, dynamic> j) => ItemMovement(
    itemName: j['itemName'] ?? '',
    placeName: j['placeName'] ?? '',
    qty: j['qty'] ?? 0,
    type: j['type'] ?? '',
    refNo: j['refNo'] ?? '',
    note: j['note'] ?? '',
    createdAt: DateTime.parse(j['createdAt']),
  );
}

// import 'package:flutter/material.dart';

// Pretty palette (Material shades)
const chartColors = <Color>[
  Color(0xFF6C5CE7), // violet
  Color(0xFF00C2FF), // cyan
  Color(0xFFFF7675), // coral
  Color(0xFF55EFC4), // mint
  Color(0xFFFFC048), // amber
  Color(0xFF81ECEC), // aqua
  Color(0xFFA29BFE), // light violet
  Color(0xFFFFB8B8), // pink
  Color(0xFF74B9FF), // light blue
  Color(0xFF00D09C), // teal
];

class CategoryStock {
  final String category;
  final num total, available, issued, scrap;
  final int count;
  CategoryStock({
    required this.category,
    required this.total,
    required this.available,
    required this.issued,
    required this.scrap,
    required this.count,
  });
  factory CategoryStock.fromJson(Map<String, dynamic> j) => CategoryStock(
    category: j['category'] ?? '(Uncategorized)',
    total: j['totalStock'] ?? 0,
    available: j['available'] ?? 0,
    issued: j['issued'] ?? 0,
    scrap: j['scrap'] ?? 0,
    count: j['count'] ?? 0,
  );
}

class UserActivityRow {
  final String name, email;
  final int ops;
  final num receiveQty, issueQty;
  UserActivityRow({
    required this.name,
    required this.email,
    required this.ops,
    required this.receiveQty,
    required this.issueQty,
  });
  factory UserActivityRow.fromJson(Map<String, dynamic> j) => UserActivityRow(
    name: j['name'] ?? 'Unknown',
    email: j['email'] ?? '',
    ops: j['ops'] ?? 0,
    receiveQty: j['receiveQty'] ?? 0,
    issueQty: j['issueQty'] ?? 0,
  );
}

final categoryStockProvider = FutureProvider<List<CategoryStock>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final raw = await api.getCategoryStock();
  return raw
      .map((e) => CategoryStock.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

final categoryTrendProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final r = ref.watch(dateRangeProvider);
  return await api.getCategoryTrend(r.item1, r.item2);
});

final userActivityProvider = FutureProvider<List<UserActivityRow>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = ref.watch(dateRangeProvider);
  final raw = await api.getUserActivity(r.item1, r.item2, limit: 8);
  return raw
      .map((e) => UserActivityRow.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

final lowStockProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  return await api.getLowStock(threshold: 10);
});

final deadStockProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  return await api.getDeadStock(days: 60);
});

final heatmapProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return await api.getPlaceHeatmap();
});

final throughputReceivingProvider = FutureProvider<num>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = ref.watch(dateRangeProvider);
  return api.getThroughput('receiving', r.item1, r.item2);
});

final throughputIssueProvider = FutureProvider<num>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = ref.watch(dateRangeProvider);
  return api.getThroughput('issue', r.item1, r.item2);
});


class ItemMin {
  final String id;
  final String name;
  final String unit;
  ItemMin({required this.id, required this.name, required this.unit});
  factory ItemMin.fromJson(Map<String, dynamic> j) => ItemMin(
    id: (j['_id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    unit: (j['unit'] ?? '').toString(),
  );
}

class TopItemRow {
  final String itemId;
  final String name;
  final String unit;
  final num qty;
  TopItemRow({required this.itemId, required this.name, required this.unit, required this.qty});
  factory TopItemRow.fromJson(Map<String, dynamic> j) => TopItemRow(
    itemId: (j['itemId'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    unit: (j['unit'] ?? '').toString(),
    qty: (j['qty'] ?? 0) as num,
  );
}

final itemsMinProvider = FutureProvider<List<ItemMin>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getItemsMin();
  return data.map((e) => ItemMin.fromJson(e)).toList();
});

// user-selected item (default: first from list when loaded)
final selectedItemIdProvider = StateProvider<String?>((ref) => null);

final topIssuedProvider = FutureProvider<List<TopItemRow>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = ref.watch(dateRangeProvider);
  final data = await api.getTopItems(r.item1, r.item2, 'ISSUE', limit: 10);
  return data.map((e) => TopItemRow.fromJson(e)).toList();
});

final topReceivedProvider = FutureProvider<List<TopItemRow>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final r = ref.watch(dateRangeProvider);
  final data = await api.getTopItems(r.item1, r.item2, 'RECEIVE', limit: 10);
  return data.map((e) => TopItemRow.fromJson(e)).toList();
});

// item locations for the selected item
final itemLocationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final id = ref.watch(selectedItemIdProvider);
  if (id == null || id.isEmpty) return <Map<String, dynamic>>[];
  return await api.getItemLocations(id);
});
