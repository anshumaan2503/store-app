// lib/src/sorting_jobs/domains/models/sorting_job_model.dart

class SortingJobModel {
  final String? id;

  final String itemId;
  final String itemName;
  final String? machineId;
  final String? machineName;

  /// created|started|stopped|restarted|completed
  final String status;

  /// Total count of selected bags (inputBags.length)
  final int totalInputQtyInBags;

  /// Sum of all inputBags.qtyInWt
  final double totalInputQtyInWt;

  /// Sum of all inputBags.transferQtyInWt
  final double totalTransferQtyInWt;

  final List<SortingJobInputBagRow> inputBags;

  final DateTime? createdAt;
  final DateTime? completedAt;

  SortingJobModel({
    this.id,
    required this.itemId,
    required this.itemName,
    this.machineId,
    this.machineName,
    required this.status,
    required this.totalInputQtyInBags,
    required this.totalInputQtyInWt,
    required this.totalTransferQtyInWt,
    required this.inputBags,
    this.createdAt,
    this.completedAt,
  });

  /// Remaining transfer weight for the whole job
  double get remainingJobWt => totalInputQtyInWt - totalTransferQtyInWt;

  factory SortingJobModel.fromMap(Map<String, dynamic> map) {
    return SortingJobModel(
      id: map['_id']?.toString() ?? map['id']?.toString(),
      itemId: (map['itemId'] ?? '').toString(),
      itemName: (map['itemName'] ?? '').toString(),
      machineId: map['machineId']?.toString(),
      machineName: map['machineName']?.toString(),
      status: (map['status'] ?? 'created').toString(),

      totalInputQtyInBags: _toInt(map['totalInputQtyInBags']),
      totalInputQtyInWt: _toDouble(map['totalInputQtyInWt']),
      totalTransferQtyInWt: _toDouble(map['totalTransferQtyInWt']),

      inputBags:
          ((map['inputBags'] ?? []) as List)
              .map(
                (e) => SortingJobInputBagRow.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),

      createdAt:
          map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString())
              : null,
      completedAt:
          map['completedAt'] != null
              ? DateTime.tryParse(map['completedAt'].toString())
              : null,
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class SortingJobInputBagRow {
  /// Optional (because schema says bagId?: ObjectId)
  final String? bagId;

  final String bagCode;

  /// Input weight taken from this bag at create time
  final double qtyInWt;

  /// Running transfer weight returned to this bag during complete steps
  final double transferQtyInWt;

  SortingJobInputBagRow({
    this.bagId,
    required this.bagCode,
    required this.qtyInWt,
    required this.transferQtyInWt,
  });

  double get remainingBagWt => qtyInWt - transferQtyInWt;

  factory SortingJobInputBagRow.fromMap(Map<String, dynamic> map) {
    return SortingJobInputBagRow(
      bagId: map['bagId']?.toString(),
      bagCode: (map['bagCode'] ?? '').toString(),
      qtyInWt: SortingJobModel._toDouble(map['qtyInWt']),
      transferQtyInWt: SortingJobModel._toDouble(map['transferQtyInWt']),
    );
  }
}
