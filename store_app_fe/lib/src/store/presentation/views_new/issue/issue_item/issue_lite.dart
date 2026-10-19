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
    int approved = 0, issued = 0, remaining = 0;
    for (final raw in lines) {
      final l = raw as Map<String, dynamic>;
      final lid = (l['itemId'] ?? '').toString();
      if (lid == itemId) {
        approved = _toInt(l['requestedQty']);
        issued = _toInt(l['issuedQty']);
        remaining = _toInt(l['approvedQty']);
        break;
      }
    }
    // final  approved - issued;
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

// final itemIssuesByItemStreamProvider =
//     StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
//       SocketManager socketManager = ref.watch(socketProvider);
//       StreamController<List<Map<String, dynamic>>> storePlaceStream =
//           StreamController(sync: true);
//       List<Map<String, dynamic>> returnValue = [];
//       socketManager.getSocket().emit("issue:listByItem", {});
//       socketManager.getSocket().on("issue:listByItem", (data) {
//         returnValue = [];
//         for (var element in data) {
//           returnValue.add(element);
//         }
//         storePlaceStream.add(returnValue);
//       });

//       yield returnValue;
//       await for (final returnValue in storePlaceStream.stream) {
//         yield returnValue;
//       }
//     });

/// Stream of APPROVED issues that contain [itemId] and remaining > 0.
final itemIssuesByItemStreamProvider = StreamProvider.autoDispose
    .family<List<IssueLite>, String>((ref, itemId) async* {
      SocketManager socketManager = ref.watch(socketProvider);

      StreamController<List<IssueLite>> controller = StreamController(
        sync: true,
      );

      void request() {
        // Tell server: “give me issues for this item”
        socketManager.getSocket().emit('issue:listByItem', {'itemId': itemId});
      }

      final list = <IssueLite>[];
      // Handle response
      void onResponse(dynamic data) {
        print("data");
        print(data);
        // Expect: List of issue docs (status APPROVED) that include this item
        if (data is List) {
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
      socketManager.getSocket().on('issue:listByItem', onResponse);

      // Yield current (might be empty until server responds)
      yield list;

      // Forward every update
      await for (final list in controller.stream) {
        yield list;
      }

      ref.onDispose(() {
        socketManager.getSocket().off('issue:listByItem', onResponse);
        controller.close();
      });
    });
