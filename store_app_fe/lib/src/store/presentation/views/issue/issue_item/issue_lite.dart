// lib/features/store/controllers/item_issues_by_item_controller.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../components/socket_manager.dart';

/// Shape you’ll render in the UI (keep it light)
class IssueLite {
  final String id; // _id
  final String issNo; // e.g. "ISS-2025-0001"
  final int approved; // approvedQty for this item
  final int issued; // issuedQty for this item
  final int remaining; // approved - issued

  IssueLite({
    required this.id,
    required this.issNo,
    required this.approved,
    required this.issued,
    required this.remaining,
  });

  static IssueLite fromMapForItem(Map<String, dynamic> doc, String itemId) {
    final id = (doc['_id'] ?? doc['id'] ?? '').toString();
    final issNo = (doc['issNo'] ?? '').toString();
    // Find that item’s line in this issue
    final lines = (doc['lines'] as List?) ?? const [];
    int approved = 0, issued = 0;
    for (final raw in lines) {
      final l = raw as Map<String, dynamic>;
      final lid = (l['itemId'] ?? '').toString();
      if (lid == itemId) {
        approved = _toInt(l['approvedQty']);
        issued = _toInt(l['issuedQty']);
        break;
      }
    }
    final remaining = approved - issued;
    return IssueLite(
      id: id,
      issNo: issNo,
      approved: approved,
      issued: issued,
      remaining: remaining,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }
}

/// Stream of APPROVED issues that contain [itemId] and remaining > 0.
final itemIssuesByItemStreamProvider = StreamProvider.autoDispose
    .family<List<IssueLite>, String>((ref, itemId) async* {
      final socketManager = ref.watch(socketProvider);
      final socket = socketManager.getSocket();

      final controller = StreamController<List<IssueLite>>(sync: true);

      void request() {
        // Tell server: “give me issues for this item”
        socket.emit('issue:listByItem', {'itemId': itemId});
      }

      // Handle response
      void onResponse(dynamic data) {
        // Expect: List of issue docs (status APPROVED) that include this item
        if (data is List) {
          final list = <IssueLite>[];
          for (final e in data) {
            final m = (e as Map).cast<String, dynamic>();
            // Build only if there’s remaining
            final lite = IssueLite.fromMapForItem(m, itemId);
            if (lite.remaining > 0) list.add(lite);
          }
          controller.add(list);
        } else if (data is Map<String, dynamic>) {
          // Some servers return a single issue doc
          final lite = IssueLite.fromMapForItem(data, itemId);
          controller.add(lite.remaining > 0 ? [lite] : <IssueLite>[]);
        }
      }

      // Kick off
      request();

      // Listen to that channel
      socket.on('issue:listByItem', onResponse);

      // Yield current (might be empty until server responds)
      yield const <IssueLite>[];

      // Forward every update
      await for (final list in controller.stream) {
        yield list;
      }

      ref.onDispose(() {
        socket.off('issue:listByItem', onResponse);
        controller.close();
      });
    });
