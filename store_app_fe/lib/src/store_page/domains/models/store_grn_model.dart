class GrnItemModel {
  final String indentId;
  final String indentNumber;
  final String itemId;
  final String itemName;
  final String itemCode;
  final String category;
  final String unit;
  final int orderedQty;
  final int receivedQty;
  final double unitPrice;
  final double totalPrice;
  final bool isPutawayComplete;
  final int putawayQty;

  const GrnItemModel({
    required this.indentId,
    required this.indentNumber,
    required this.itemId,
    required this.itemName,
    this.itemCode = '',
    this.category = '',
    this.unit = '',
    required this.orderedQty,
    required this.receivedQty,
    required this.unitPrice,
    required this.totalPrice,
    this.isPutawayComplete = false,
    this.putawayQty = 0,
  });

  factory GrnItemModel.fromJson(Map<String, dynamic> json) {
    return GrnItemModel(
      indentId: json['indentId']?.toString() ?? '',
      indentNumber: json['indentNumber']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      itemCode: json['itemCode']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      orderedQty: (json['orderedQty'] as num?)?.toInt() ?? 0,
      receivedQty: (json['receivedQty'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      isPutawayComplete: json['isPutawayComplete'] == true,
      putawayQty: (json['putawayQty'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'indentId': indentId,
      'indentNumber': indentNumber,
      'itemId': itemId,
      'itemName': itemName,
      'itemCode': itemCode,
      'category': category,
      'unit': unit,
      'orderedQty': orderedQty,
      'receivedQty': receivedQty,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'isPutawayComplete': isPutawayComplete,
      'putawayQty': putawayQty,
    };
  }
}

class GrnTimelineModel {
  final String action;
  final String title;
  final String description;
  final String actorName;
  final DateTime? timestamp;

  const GrnTimelineModel({
    required this.action,
    required this.title,
    this.description = '',
    this.actorName = 'System',
    this.timestamp,
  });

  factory GrnTimelineModel.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final rawTs = json['timestamp'];
    if (rawTs != null) {
      if (rawTs is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(rawTs);
      } else {
        dt = DateTime.tryParse(rawTs.toString());
      }
    }
    return GrnTimelineModel(
      action: json['action']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      actorName: json['actorName']?.toString() ?? 'System',
      timestamp: dt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'title': title,
      'description': description,
      'actorName': actorName,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
}

class StoreGrnModel {
  final String id;
  final String grnNumber;
  final String status; // 'PENDING_APPROVAL' | 'APPROVED' | 'REJECTED' | 'RECEIVED'
  final String imageUrl;
  final String remarks;
  final List<GrnItemModel> items;
  final int totalItems;
  final int totalQuantity;
  final double totalValue;
  final String submittedByName;
  final String approvedByName;
  final DateTime? approvedAt;
  final String rejectedByName;
  final DateTime? rejectedAt;
  final String rejectionReason;
  final List<GrnTimelineModel> timeline;
  final DateTime? createdAt;

  const StoreGrnModel({
    required this.id,
    required this.grnNumber,
    required this.status,
    this.imageUrl = '',
    this.remarks = '',
    this.items = const [],
    this.totalItems = 0,
    this.totalQuantity = 0,
    this.totalValue = 0.0,
    this.submittedByName = '',
    this.approvedByName = '',
    this.approvedAt,
    this.rejectedByName = '',
    this.rejectedAt,
    this.rejectionReason = '',
    this.timeline = const [],
    this.createdAt,
  });

  factory StoreGrnModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsList = (rawItems is List)
        ? rawItems
            .whereType<Map>()
            .map((e) => GrnItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <GrnItemModel>[];

    final rawTimeline = json['timeline'];
    final timelineList = (rawTimeline is List)
        ? rawTimeline
            .whereType<Map>()
            .map((e) => GrnTimelineModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <GrnTimelineModel>[];

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.tryParse(v.toString());
    }

    String extractActor(dynamic v) {
      if (v == null) return '';
      if (v is Map) return v['name']?.toString() ?? '';
      return v.toString();
    }

    return StoreGrnModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      grnNumber: json['grnNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING_APPROVAL',
      imageUrl: json['imageUrl']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
      items: itemsList,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? itemsList.length,
      totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0.0,
      submittedByName: extractActor(json['submittedBy']),
      approvedByName: extractActor(json['approvedBy']),
      approvedAt: parseDate(json['approvedAt']),
      rejectedByName: extractActor(json['rejectedBy']),
      rejectedAt: parseDate(json['rejectedAt']),
      rejectionReason: json['rejectionReason']?.toString() ?? '',
      timeline: timelineList,
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'grnNumber': grnNumber,
      'status': status,
      'imageUrl': imageUrl,
      'remarks': remarks,
      'items': items.map((e) => e.toJson()).toList(),
      'totalItems': totalItems,
      'totalQuantity': totalQuantity,
      'totalValue': totalValue,
      'submittedBy': {'name': submittedByName},
      'approvedBy': {'name': approvedByName},
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectedBy': {'name': rejectedByName},
      'rejectedAt': rejectedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'timeline': timeline.map((e) => e.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
