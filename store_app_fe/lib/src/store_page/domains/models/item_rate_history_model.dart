import 'package:store_app/src/common/utils/defensive_parsing.dart';

class ItemRateEntry {
  final String id;
  final DateTime? date;
  final double rate;
  final int qty;
  final double totalAmount;
  final String voucherNo;
  final String grnNo;
  final String receivedBy;
  final String remarks;
  final String diffFromPrevious;
  final double diffAmount;

  const ItemRateEntry({
    required this.id,
    this.date,
    required this.rate,
    required this.qty,
    required this.totalAmount,
    required this.voucherNo,
    this.grnNo = '',
    this.receivedBy = '',
    this.remarks = '',
    this.diffFromPrevious = '',
    this.diffAmount = 0.0,
  });

  factory ItemRateEntry.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    if (map['date'] != null) {
      parsedDate = DateTime.tryParse(map['date'].toString());
    }
    return ItemRateEntry(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      date: parsedDate,
      rate: toDouble(map['rate']) ?? 0.0,
      qty: toInt(map['qty']) ?? 0,
      totalAmount: toDouble(map['totalAmount']) ?? 0.0,
      voucherNo: (map['voucherNo'] ?? '').toString(),
      grnNo: (map['grnNo'] ?? '').toString(),
      receivedBy: (map['receivedBy'] ?? '').toString(),
      remarks: (map['remarks'] ?? '').toString(),
      diffFromPrevious: (map['diffFromPrevious'] ?? '').toString(),
      diffAmount: toDouble(map['diffAmount']) ?? 0.0,
    );
  }
}

class ItemRateStats {
  final double latestRate;
  final double previousRate;
  final double minRate;
  final double maxRate;
  final double avgRate;
  final double rateChange;

  const ItemRateStats({
    this.latestRate = 0.0,
    this.previousRate = 0.0,
    this.minRate = 0.0,
    this.maxRate = 0.0,
    this.avgRate = 0.0,
    this.rateChange = 0.0,
  });

  factory ItemRateStats.fromMap(Map<String, dynamic> map) {
    return ItemRateStats(
      latestRate: toDouble(map['latestRate']) ?? 0.0,
      previousRate: toDouble(map['previousRate']) ?? 0.0,
      minRate: toDouble(map['minRate']) ?? 0.0,
      maxRate: toDouble(map['maxRate']) ?? 0.0,
      avgRate: toDouble(map['avgRate']) ?? 0.0,
      rateChange: toDouble(map['rateChange']) ?? 0.0,
    );
  }
}

class ItemRateHistoryModel {
  final bool status;
  final String itemId;
  final String itemName;
  final String itemCode;
  final String unit;
  final double latestRate;
  final List<ItemRateEntry> rateHistory;
  final ItemRateStats stats;

  const ItemRateHistoryModel({
    required this.status,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.unit,
    required this.latestRate,
    required this.rateHistory,
    required this.stats,
  });

  factory ItemRateHistoryModel.fromMap(Map<String, dynamic> map) {
    final list = <ItemRateEntry>[];
    if (map['rateHistory'] is List) {
      for (final item in (map['rateHistory'] as List)) {
        if (item is Map<String, dynamic>) {
          list.add(ItemRateEntry.fromMap(item));
        }
      }
    }
    return ItemRateHistoryModel(
      status: map['status'] == true,
      itemId: (map['itemId'] ?? '').toString(),
      itemName: (map['itemName'] ?? '').toString(),
      itemCode: (map['itemCode'] ?? '').toString(),
      unit: (map['unit'] ?? '').toString(),
      latestRate: toDouble(map['latestRate']) ?? 0.0,
      rateHistory: list,
      stats: map['stats'] is Map<String, dynamic>
          ? ItemRateStats.fromMap(map['stats'] as Map<String, dynamic>)
          : const ItemRateStats(),
    );
  }
}
