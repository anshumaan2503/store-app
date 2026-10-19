// lib/src/store/controllers/issue_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/socket_manager.dart';
import '../../components/utils.dart';

import '../domains/models/issue_models.dart'; // you created earlier
import '../domains/models/store_issue_model.dart';
import '../domains/repositories/issue_repository.dart';

@immutable
class IssueItemQuery {
  final String? search;
  final String itemId;
  final String? createdBy;

  const IssueItemQuery({this.search, required this.itemId, this.createdBy});

  Map<String, dynamic> toMap() => {
    'search': search,
    'itemId': itemId,
    'createdBy': createdBy,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssueItemQuery &&
          other.search == search &&
          other.itemId == itemId &&
          other.createdBy == createdBy;

  @override
  int get hashCode => Object.hash(search, itemId, createdBy);
}

@immutable
class IssueQuery {
  final int page; // 1-based
  final int limit;
  final String search;
  final String sort;
  final String? createdBy;
  final String? tab;

  const IssueQuery({
    required this.page,
    required this.limit,
    required this.search,
    required this.sort,
    this.createdBy,
    this.tab,
  });

  Map<String, dynamic> toMap() => {
    'page': page,
    'limit': limit,
    'search': search,
    'sort': sort,
    'createdBy': createdBy,
    if (tab != null && tab!.isNotEmpty) 'tab': tab,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssueQuery &&
          other.page == page &&
          other.limit == limit &&
          other.search == search &&
          other.sort == sort &&
          other.createdBy == createdBy &&
          other.tab == tab;

  @override
  int get hashCode => Object.hash(page, limit, search, sort, createdBy, tab);
}

@immutable
class PagedIssue {
  final List<IssueModel> rows;
  final int total;
  final int page;
  final int limit;

  const PagedIssue({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });

  static PagedIssue empty(IssueQuery q) =>
      PagedIssue(rows: const [], total: 0, page: q.page, limit: q.limit);

  factory PagedIssue.fromWs(Map<String, dynamic> m, IssueQuery q) {
    final rawRows = (m['rows'] is List) ? (m['rows'] as List) : const [];

    // meta can be {page,limit,total,...} OR total at root depending on backend
    final meta =
        (m['meta'] is Map) ? Map<String, dynamic>.from(m['meta']) : null;

    final page = meta != null ? _toInt(meta['page']) : _toInt(m['page']);
    final limit = meta != null ? _toInt(meta['limit']) : _toInt(m['limit']);
    final total = meta != null ? _toInt(meta['total']) : _toInt(m['total']);

    return PagedIssue(
      rows:
          rawRows
              .whereType<Map>()
              .map((e) => IssueModel.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
      total: total,
      page: page == 0 ? q.page : page,
      limit: limit == 0 ? q.limit : limit,
    );
  }
}

@immutable
class IssueListQueryUi {
  final String search;
  final int page;
  final int limit;

  const IssueListQueryUi({
    required this.search,
    required this.page,
    required this.limit,
  });

  Map<String, dynamic> toMap() => {
    'search': search,
    'page': page,
    'limit': limit,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssueListQueryUi &&
          other.search == search &&
          other.page == page &&
          other.limit == limit;

  @override
  int get hashCode => Object.hash(search, page, limit);
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime _toDate(dynamic v) {
  if (v is DateTime) return v;
  final s = (v ?? '').toString();
  return DateTime.tryParse(s) ?? DateTime.now();
}

/* ---------------- UI Models ---------------- */

class IssueLineUi {
  final String itemId;
  final String itemName;
  final int reqQty;
  final int approvedQty;
  final int approvedRejectQty;
  final int issuedRejectQty;
  final int issuedQty;

  // good returned
  final int returnedQty;

  // scrap
  final int scrapQty;

  const IssueLineUi({
    required this.itemId,
    required this.itemName,
    required this.reqQty,
    required this.approvedQty,
    required this.issuedQty,
    required this.approvedRejectQty,
    required this.issuedRejectQty,
    required this.returnedQty,
    required this.scrapQty,
  });

  int get remainingApprove =>
      (reqQty - approvedQty - approvedRejectQty).clamp(0, 1 << 30);
  int get remainingToIssue =>
      (approvedQty - issuedQty - issuedRejectQty).clamp(0, 1 << 30);

  // ✅ issued but not returned (good+scrap)
  int get remainingToReturn =>
      (issuedQty - returnedQty - scrapQty).clamp(0, 1 << 30);

  IssueLineUi copyWith({
    String? itemId,
    String? itemName,
    int? reqQty,
    int? approvedQty,
    int? issuedQty,
    int? returnedQty,
    int? approvedRejectQty,
    int? issuedRejectQty,
    int? scrapQty,
  }) {
    return IssueLineUi(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      reqQty: reqQty ?? this.reqQty,
      approvedQty: approvedQty ?? this.approvedQty,
      issuedQty: issuedQty ?? this.issuedQty,
      approvedRejectQty: approvedRejectQty ?? this.approvedRejectQty,
      issuedRejectQty: issuedRejectQty ?? this.issuedRejectQty,
      returnedQty: returnedQty ?? this.returnedQty,
      scrapQty: scrapQty ?? this.scrapQty,
    );
  }

  static String _idStr(dynamic v) {
    if (v == null) return '';
    if (v is Map && v['_id'] != null) return v['_id'].toString();
    return v.toString();
  }

  factory IssueLineUi.fromMap(Map<String, dynamic> m) {
    return IssueLineUi(
      itemId: _idStr(m['itemId']),
      itemName: (m['itemName'] ?? '').toString(),
      reqQty: _toInt(m['requestedQty']),
      approvedQty: _toInt(m['approvedQty']),
      issuedQty: _toInt(m['issuedQty']),
      approvedRejectQty: _toInt(m['approvedRejectQty']),
      issuedRejectQty: _toInt(m['issuedRejectQty']),
      returnedQty: _toInt(m['returnQty']),
      scrapQty: _toInt(m['scrapQty']),
    );
  }
}

class IssueCardUi {
  final String id;
  final String issNo;
  final String reason;
  final DateTime createdAt;
  final String status;
  final List<IssueLineUi> lines;

  const IssueCardUi({
    required this.id,
    required this.issNo,
    required this.reason,
    required this.createdAt,
    required this.status,
    required this.lines,
  });

  factory IssueCardUi.fromMap(Map<String, dynamic> m) {
    final rawLines = (m['lines'] is List) ? (m['lines'] as List) : const [];
    return IssueCardUi(
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      issNo: (m['issNo'] ?? '').toString(),
      reason: (m['reason'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      createdAt: _toDate(m['createdAt'] ?? m['created_at']),
      lines:
          rawLines
              .whereType<Map>()
              .map((e) => IssueLineUi.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
    );
  }
}

class IssueListMetaUi {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  const IssueListMetaUi({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory IssueListMetaUi.fromMap(Map<String, dynamic> m) {
    return IssueListMetaUi(
      page: _toInt(m['page']),
      limit: _toInt(m['limit']),
      total: _toInt(m['total']),
      totalPages: _toInt(m['totalPages']).clamp(1, 999999),
      hasNext: m['hasNext'] == true,
      hasPrev: m['hasPrev'] == true,
    );
  }
}

class IssuePagedUi {
  final List<IssueCardUi> rows;
  final IssueListMetaUi meta;

  const IssuePagedUi({required this.rows, required this.meta});

  factory IssuePagedUi.fromWsPayload(
    Map<String, dynamic> m,
    IssueListQueryUi q,
  ) {
    final rawRows = (m['rows'] is List) ? (m['rows'] as List) : const [];

    // ✅ Convert Map<dynamic,dynamic> -> Map<String,dynamic>
    final metaMap =
        (m['meta'] is Map)
            ? Map<String, dynamic>.from(m['meta'] as Map)
            : <String, dynamic>{};

    return IssuePagedUi(
      rows:
          rawRows
              .whereType<Map>()
              .map((e) => IssueCardUi.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
      meta:
          metaMap.isEmpty
              ? IssuePagedUi.empty(q).meta
              : IssueListMetaUi.fromMap(metaMap),
    );
  }

  static IssuePagedUi empty(IssueListQueryUi q) => IssuePagedUi(
    rows: const [],
    meta: IssueListMetaUi(
      page: q.page,
      limit: q.limit,
      total: 0,
      totalPages: 1,
      hasNext: false,
      hasPrev: q.page > 1,
    ),
  );
}

/// -----------------------------
///  A) WebSocket GET Providers
/// -----------------------------

// store_item_issue_controller.dart (add)

final pagedIssuesStreamProvider = StreamProvider.autoDispose
    .family<PagedIssue, IssueQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedIssue>(sync: true);

      debugPrint('WS -> emit store:issues:list ${query.toMap()}');

      late void Function(dynamic) handler;

      handler = (dynamic data) {
        debugPrint('WS <- store:issues:list dataType=${data.runtimeType}');
        try {
          if (data is! Map) return;
          final m = Map<String, dynamic>.from(data);

          // ✅ (Optional) ignore if backend sends other pages too
          final respPage = _toInt(m['page']);
          final respLimit = _toInt(m['limit']);
          if (respPage != 0 && respPage != query.page) return;
          if (respLimit != 0 && respLimit != query.limit) return;

          // Check tab isolation
          final respTab = m['tab']?.toString();
          if (query.tab != null &&
              query.tab!.isNotEmpty &&
              respTab != null &&
              respTab.isNotEmpty &&
              respTab != 'all' &&
              respTab != query.tab) {
            return;
          }

          final isBroadcast = m['isBroadcast'] == true;
          final respCreatedBy = m['createdBy']?.toString();

          // Invariant: User-filtered queries (query.createdBy != null) must NEVER
          // consume a global/generic broadcast or an issue payload for a different user.
          if (query.createdBy != null) {
            if (isBroadcast || (m.containsKey('createdBy') && respCreatedBy != query.createdBy)) {
              // When a global broadcast occurs, refresh user's own filtered list if on the affected page
              if (isBroadcast && (respPage == 0 || respPage == query.page)) {
                socket.emit('store:issues:list', query.toMap());
              }
              return;
            }
          } else {
            // Global / Admin query (query.createdBy == null):
            // Ignore any payload that is explicitly scoped to a specific user.
            if (respCreatedBy != null && respCreatedBy.isNotEmpty) {
              return;
            }
          }

          final rawRows = (m['rows'] is List) ? (m['rows'] as List) : const [];
          final rows =
              rawRows
                  .whereType<Map>()
                  .map((e) => IssueModel.fromJson(Map<String, dynamic>.from(e)))
                  .toList();

          controller.add(
            PagedIssue(
              rows: rows,
              total: _toInt(m['total'] ?? rows.length),
              page: respPage == 0 ? query.page : respPage,
              limit: respLimit == 0 ? query.limit : respLimit,
            ),
          );
        } catch (e, st) {
          debugPrint('pagedIssuesStreamProvider parse error: $e\n$st');
        }
      };

      socket.on('store:issues:list', handler);
      socket.emit('store:issues:list', query.toMap());

      ref.onDispose(() {
        socket.off('store:issues:list', handler);
        controller.close();
      });

      // ✅ ensures provider is not stuck in loading (same as your example)
      yield PagedIssue(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      yield* controller.stream;
    });

// final issueSourcesStreamProvider = StreamProvider.autoDispose.family<
//   IssuePagedUi,
//   IssueListQueryUi
// >((ref, q) {
//   final socket = ref.watch(socketProvider).getSocket();
//   final ctrl = StreamController<IssuePagedUi>();

//   final reqId =
//       '${DateTime.now().microsecondsSinceEpoch}-${q.page}-${q.limit}-${q.search.hashCode}';

//   bool settled = false;
//   Timer? timer;

//   late void Function(dynamic) handler;

//   void cleanup() {
//     if (settled) return;
//     settled = true;
//     timer?.cancel();
//     socket.off('store:issues:list', handler);
//   }

//   void emitEmpty() {
//     if (!ctrl.isClosed) ctrl.add(IssuePagedUi.empty(q));
//   }

//   bool _matchesQueryByMeta(Map<String, dynamic> m) {
//     if (m['meta'] is! Map) return false;
//     final meta = Map<String, dynamic>.from(m['meta'] as Map);
//     final mp = _toInt(meta['page']);
//     final ml = _toInt(meta['limit']);
//     return mp == q.page && ml == q.limit;
//   }

//   handler = (dynamic data) {
//     try {
//       if (data is! Map) return;

//       final m = Map<String, dynamic>.from(data as Map);

//       // Prefer reqId match, but allow meta match as fallback (prevents "prints but UI empty").
//       final incomingReqId = (m['reqId'] ?? '').toString().trim();
//       final reqIdMatches = incomingReqId.isNotEmpty && incomingReqId == reqId;
//       final metaMatches = _matchesQueryByMeta(m);

//       if (incomingReqId.isNotEmpty && !reqIdMatches && !metaMatches) {
//         return; // not for this page/limit
//       }

//       final ok = m['ok'] == true;
//       if (!ok) {
//         final msg = (m['message'] ?? 'Failed to load issues').toString();
//         if (!ctrl.isClosed) ctrl.addError(msg);
//         cleanup();
//         return;
//       }

//       final paged = IssuePagedUi.fromWsPayload(m, q);
//       if (!ctrl.isClosed) ctrl.add(paged);

//       cleanup();
//     } catch (e, st) {
//       debugPrint('issueSourcesStreamProvider handler error: $e\n$st');
//       emitEmpty();
//       cleanup();
//     }
//   };

//   socket.on('store:issues:list', handler);

//   socket.emit('store:issues:list', {'reqId': reqId, ...q.toMap()});

//   // Timeout fallback (keep 4s; your WS is fast so it will return earlier)
//   timer = Timer(const Duration(seconds: 4), () {
//     if (settled) return;
//     emitEmpty();
//     cleanup();
//   });

//   ref.onDispose(() {
//     timer?.cancel();
//     socket.off('store:issues:list', handler);
//     ctrl.close();
//   });

//   return ctrl.stream;
// });

/// GET: Issue sources for selected item (buckets + qty)
/// Backend must:
/// @SubscribeMessage('store:issueSources')
/// client.emit('store:issueSources', sourcesObject)
// final issueSourcesStreamProvider = StreamProvider.autoDispose
//     .family<IssueSourcesResponse?, String>((ref, itemId) {
//       final socket = ref.watch(socketProvider).getSocket();
//       final ctrl = StreamController<IssueSourcesResponse?>();

//       void handler(dynamic data) {
//         try {
//           if (data == null) return;

//           // Accept payload formats:
//           // 1) { ...sources }
//           // 2) { status: true, data: { ...sources } }
//           if (data is Map) {
//             final m = Map<String, dynamic>.from(data as Map);

//             final payload =
//                 (m['data'] is Map)
//                     ? Map<String, dynamic>.from(m['data'] as Map)
//                     : m;

//             // Basic guard: ensure it looks like sources response
//             if (payload.containsKey('buckets') ||
//                 payload.containsKey('itemNameId')) {
//               ctrl.add(IssueSourcesResponse.fromMap(payload));
//             }
//           }
//         } catch (e, st) {
//           debugPrint('store:issueSources handler error: $e\n$st');
//         }
//       }

//       // same request/response event name pattern (like your backend sample)
//       socket.on('store:issueSources', handler);
//       socket.emit('store:issueSources', {"itemId": itemId});

//       // prevent infinite loading: emit null quickly
//       ctrl.add(null);

//       ref.onDispose(() {
//         socket.off('store:issueSources', handler);
//         ctrl.close();
//       });

//       return ctrl.stream;
//     });

/// GET: Issue full details by id (includes allocations)
/// Backend must:
/// @SubscribeMessage('store:issueById')
/// client.emit('store:issueById', issueDoc)

final issueByIdItemAllDataStreamProvider = StreamProvider.autoDispose
    .family<List<IssueModel>, IssueItemQuery>((ref, itemQuery) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<IssueModel>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final issues = <IssueModel>[];
          for (var element in data) {
            if (element is Map) {
              issues.add(
                IssueModel.fromJson(Map<String, dynamic>.from(element)),
              );
            }
          }
          if (!ctrl.isClosed) ctrl.add(issues);
        } catch (e, st) {
          debugPrint('store:issueByIdItem handler error: $e\n$st');
        }
      }

      var dto = {
        "itemId": itemQuery.itemId,
        "createdBy": itemQuery.createdBy,
        "search": itemQuery.search,
      };

      socket.on('store:issueByIdItem', handler);
      socket.emit('store:issueByIdItem', dto);

      ref.onDispose(() {
        socket.off('store:issueByIdItem', handler);
        if (!ctrl.isClosed) ctrl.close();
      });

      return ctrl.stream;
    });

// final issueByIdItemStreamProvider = StreamProvider.autoDispose
//     .family<IssueModel, String>((ref, issueId) {
//       final socket = ref.watch(socketProvider).getSocket();
//       final ctrl = StreamController<IssueModel?>();

//       void handler(dynamic data) {
//         try {
//           // print(data);

//           if (data == null) return;

//           // Accept payload formats:
//           // 1) { ...issue }
//           // 2) { status: true, data: { ...issue } }
//           if (data is Map) {
//             final m = Map<String, dynamic>.from(data as Map);
//             final payload =
//                 (m['data'] is Map)
//                     ? Map<String, dynamic>.from(m['data'] as Map)
//                     : m;
//             print(payload);
//             if (payload.containsKey('_id') || payload.containsKey('issNo')) {
//               ctrl.add(IssueModel.fromJson(payload));
//             }
//           }
//         } catch (e, st) {
//           debugPrint('store:issueById handler error: $e\n$st');
//         }
//       }

//       socket.on('store:issueByIdItem', handler);
//       socket.emit('store:issueByIdItem', {"issueId": issueId});

//       ctrl.add(null);

//       ref.onDispose(() {
//         socket.off('store:issueByIdItem', handler);
//         ctrl.close();
//       });

//       return ctrl.stream;
//     });

/// -----------------------------
///  B) Controller (REST actions)
/// -----------------------------

final issueControllerProvider = Provider((ref) => IssueController(ref));

class IssueController extends StateNotifier<bool> {
  final Ref ref;
  IssueController(this.ref) : super(false);

  /// POST /issues/draft
  /// Returns DraftResult (contains issueId + chosenBucket)
  Future<IssueDraftResult?> createDraft(Map<String, dynamic> dto) async {
    state = true;

    IssueDraftResult? out;

    // final dto = <String, dynamic>{
    //   "itemId": itemId,
    //   "requestedQty": requestedQty,
    //   "createdBy": createdBy,
    //   "reason": reason,
    //   "remark": remark,
    //   if (subCategoryId != null && subCategoryId.trim().isNotEmpty)
    //     "subCategoryId": subCategoryId.trim(),
    // };

    final res = await ref.read(issueRepositoryProvider).createDraft(dto);

    res.fold((f) => showSnackBar(f.message), (data) {
      // allow both {status:true, ...} and direct response
      final payload =
          (data['data'] is Map)
              ? Map<String, dynamic>.from(data['data'])
              : data;

      out = IssueDraftResult.fromMap(payload);
      showSnackBar('Draft created: ${out!.issNo}');
    });

    state = false;
    return out;
  }

  /// PUT /issues/:id/approve
  Future<bool> approveIssue({
    required String issueId,
    required String approvedBy,
    int? approvedQty, // optional override
  }) async {
    state = true;

    bool ok = false;
    final dto = <String, dynamic>{
      "approvedBy": approvedBy,
      if (approvedQty != null) "approvedQty": approvedQty,
    };

    final res = await ref.read(issueRepositoryProvider).approve(issueId, dto);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = (data['status'] == true) || (data['ok'] == true) || true;
      showSnackBar(ok ? 'Approved' : 'Approve failed');
    });

    state = false;
    return ok;
  }

  /// POST /issues/:id/issue
  Future<bool> issueApproved({
    required String issueId,
    required String bucketCategoryId,
    required String issuedBy,
  }) async {
    state = true;

    bool ok = false;
    final dto = <String, dynamic>{
      "bucketCategoryId": bucketCategoryId,
      "issuedBy": issuedBy,
    };

    final res = await ref.read(issueRepositoryProvider).issue(issueId, dto);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = true;
      final issuedTotal = (data['issuedTotal'] ?? '').toString();
      showSnackBar('Issued: $issuedTotal');
    });

    state = false;
    return ok;
  }

  /// POST /issues/:id/return
  Future<bool> returnAgainstAllocation({
    required String issueId,
    required String allocationId,
    required int qty,
  }) async {
    state = true;

    bool ok = false;
    final dto = <String, dynamic>{"allocationId": allocationId, "qty": qty};

    final res = await ref
        .read(issueRepositoryProvider)
        .returnAgainstAllocation(issueId, dto);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = (data['status'] == true) || (data['ok'] == true) || true;
      showSnackBar(ok ? 'Returned' : 'Return failed');
    });

    state = false;
    return ok;
  }

  Future<Map<String, dynamic>?> approveLine({
    required String issueId,
    required String itemId,
    required String approvedBy,
    int? approvedQty,
    int? approvedRejectQty,
    String mode = 'add', // add|set
  }) async {
    final dto = <String, dynamic>{
      'approvedBy': approvedBy,
      'mode': mode,
      if (approvedQty != null) 'approvedQty': approvedQty,
      if (approvedRejectQty != null) 'approvedRejectQty': approvedRejectQty,
    };

    final res = await ref
        .read(issueRepositoryProvider)
        .approveIssueLine(issueId, itemId, dto);

    Map<String, dynamic>? out;
    res.fold(
      (f) => showSnackBar(f.message),
      (data) => out = Map<String, dynamic>.from(data),
    );
    return out;
  }

  Future<Map<String, dynamic>?> approveBulk({
    required String issueId,
    required String approvedBy,
    List<Map<String, dynamic>>? lines, // optional
  }) async {
    final dto = <String, dynamic>{
      'approvedBy': approvedBy,
      if (lines != null && lines.isNotEmpty) 'lines': lines,
    };

    final res = await ref
        .read(issueRepositoryProvider)
        .approveIssueBulk(issueId, dto);

    Map<String, dynamic>? out;
    res.fold(
      (f) => showSnackBar(f.message),
      (data) => out = Map<String, dynamic>.from(data),
    );
    return out;
  }

  Future<bool> revertApproval({
    required String issueId,
    required String revertedBy,
    String? reason,
  }) async {
    state = true;
    final dto = <String, dynamic>{
      'revertedBy': revertedBy,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    final res = await ref
        .read(issueRepositoryProvider)
        .revertApproval(issueId, dto);

    bool ok = false;
    res.fold(
      (f) => showSnackBar(f.message),
      (data) {
        ok = (data['status'] == true) || (data['ok'] == true);
        showSnackBar(ok ? 'Approval reverted successfully' : 'Revert failed');
      },
    );

    state = false;
    return ok;
  }

  Future<bool> rejectIssue({
    required String issueId,
    required String rejectedBy,
    String? reason,
  }) async {
    state = true;
    final dto = <String, dynamic>{
      'rejectedBy': rejectedBy,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    final res = await ref
        .read(issueRepositoryProvider)
        .rejectIssue(issueId, dto);

    bool ok = false;
    res.fold(
      (f) => showSnackBar(f.message),
      (data) {
        ok = (data['status'] == true) || (data['ok'] == true);
        showSnackBar(ok ? 'Request rejected successfully' : 'Reject failed');
      },
    );

    state = false;
    return ok;
  }

  Future<Map<String, dynamic>?> issueLine({
    required String issueId,
    required String itemId,
    required String rackId,
    required String issuedBy,
    required int qty,
    required int issuedRejectQty,
  }) async {
    final res = await ref
        .read(issueRepositoryProvider)
        .issueLine(
          issueId: issueId,
          itemId: itemId,
          rackId: rackId,
          issuedBy: issuedBy,
          qty: qty,
          issuedRejectQty: issuedRejectQty,
        );

    Map<String, dynamic>? out;
    res.fold(
      (f) => showSnackBar(f.message),
      (data) => out = Map<String, dynamic>.from(data),
    );
    return out;
  }

  Future<Map<String, dynamic>?> issueBulk({
    required String issueId,
    required String issuedBy,
    required List<Map<String, dynamic>> lines,
  }) async {
    final res = await ref
        .read(issueRepositoryProvider)
        .issueBulk(issueId: issueId, issuedBy: issuedBy, lines: lines);
    Map<String, dynamic>? out;
    res.fold(
      (f) => showSnackBar(f.message),
      (data) => out = Map<String, dynamic>.from(data),
    );
    return out;
  }

  String _formatReturnErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('senior not found') || lower.contains('division')) {
      return 'Division Authorization Error: You do not have authorization for this issue division.';
    }
    if (lower.contains('exceeds remaining') || lower.contains('exceed')) {
      return 'Return Qty Error: Return quantity exceeds available issued quantity.';
    }
    if (lower.contains('rack')) {
      return 'Rack Error: Invalid or missing rack selection for return.';
    }
    return raw;
  }

  Future<Map<String, dynamic>?> returnLine({
    required String issueId,
    required String itemId,
    required String rackId,
    required String scrapRackId,
    required String returnedBy,
    required int goodQty,
    required int scrapQty,
  }) async {
    final res = await ref
        .read(issueRepositoryProvider)
        .returnLine(
          issueId: issueId,
          itemId: itemId,
          rackId: rackId,
          scrapRackId: scrapRackId,
          returnedBy: returnedBy,
          goodQty: goodQty,
          scrapQty: scrapQty,
        );
    Map<String, dynamic>? out;
    res.fold(
      (f) => showSnackBar(_formatReturnErrorMessage(f.message)),
      (data) => out = Map<String, dynamic>.from(data),
    );
    return out;
  }

  Future<Map<String, dynamic>?> returnBulk({
    required String issueId,
    required String returnedBy,
    required List<Map<String, dynamic>> lines,
  }) async {
    final res = await ref
        .read(issueRepositoryProvider)
        .returnBulk(issueId: issueId, returnedBy: returnedBy, lines: lines);
    Map<String, dynamic>? out;
    res.fold(
      (f) => showSnackBar(_formatReturnErrorMessage(f.message)),
      (data) => out = Map<String, dynamic>.from(data),
    );
    return out;
  }
}

final itemIssueBreakdownProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, itemId) async {
  if (itemId.isEmpty) return {'requested': [], 'readyForIssue': [], 'history': []};

  final res =
      await ref.read(issueRepositoryProvider).getItemIssueBreakdown(itemId);

  return res.fold(
    (f) async {
      try {
        final socket = ref.read(socketProvider).getSocket();
        final completer = Completer<Map<String, dynamic>>();
        void handler(dynamic data) {
          if (data is Map && data['itemId'] == itemId) {
            socket.off('store:issue:itemBreakdown', handler);
            if (!completer.isCompleted) {
              completer.complete({
                'requested': data['requested'] ?? [],
                'readyForIssue': data['readyForIssue'] ?? [],
                'history': data['history'] ?? [],
              });
            }
          }
        }

        socket.on('store:issue:itemBreakdown', handler);
        socket.emit('store:issue:itemBreakdown', {'itemId': itemId});

        return await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => {'requested': [], 'readyForIssue': [], 'history': []},
        );
      } catch (_) {
        return {'requested': [], 'readyForIssue': [], 'history': []};
      }
    },
    (data) {
      if (data['data'] is Map) {
        return Map<String, dynamic>.from(data['data']);
      }
      return {'requested': [], 'readyForIssue': [], 'history': []};
    },
  );
});
