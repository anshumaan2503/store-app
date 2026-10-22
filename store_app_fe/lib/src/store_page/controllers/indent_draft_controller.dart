import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:store_app/src/auth/shared/providers/token_provider.dart';
import 'package:store_app/src/auth/shared/repositories/shared_preference_repository.dart';
import 'package:store_app/src/components/constants.dart';
import '../domains/models/indent_draft_model.dart';
import 'stock_refill_request_controller.dart';

class IndentDraftState {
  final List<IndentDraftItemModel> items;
  final bool isLoading;
  final String? error;

  const IndentDraftState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  int get totalCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get lineCount => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  IndentDraftItemModel? findById(String itemId) {
    for (final i in items) {
      if (i.itemId == itemId) return i;
    }
    return null;
  }

  bool containsItem(String itemId) => items.any((i) => i.itemId == itemId);

  IndentDraftState copyWith({
    List<IndentDraftItemModel>? items,
    bool? isLoading,
    String? error,
  }) {
    return IndentDraftState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final indentDraftControllerProvider =
    StateNotifierProvider<IndentDraftController, IndentDraftState>((ref) {
  return IndentDraftController(ref);
});

class IndentDraftController extends StateNotifier<IndentDraftState> {
  final Ref _ref;

  IndentDraftController(this._ref) : super(const IndentDraftState()) {
    fetchDrafts();
  }

  Future<String> _getToken() async {
    String token = _ref.read(authTokenProvider);
    if (token.isEmpty) {
      token = await _ref.read(spRepositoryProvider).getStringValue('authToken');
      if (token.isNotEmpty) {
        _ref.read(authTokenProvider.notifier).updateToken(token);
      }
    }
    return token;
  }

  Map<String, String> _buildHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetches unsubmitted indent drafts with real-time stock positions
  Future<void> fetchDrafts() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final token = await _getToken();
      final url = Uri.parse('${Constants.socketUrl}/api/store/indents/drafts');
      final res = await http.get(url, headers: _buildHeaders(token));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .whereType<Map>()
              .map((e) => IndentDraftItemModel.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          state = state.copyWith(items: list, isLoading: false);
          return;
        }
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('[IndentDraft] fetchDrafts error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Adds items to the requester's indent draft holding area (e.g. from Cart split)
  Future<bool> addDraftItems(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return true;
    try {
      state = state.copyWith(isLoading: true, error: null);
      final token = await _getToken();
      final url = Uri.parse('${Constants.socketUrl}/api/store/indents/drafts');
      final res = await http.post(
        url,
        headers: _buildHeaders(token),
        body: json.encode({'items': items}),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .whereType<Map>()
              .map((e) => IndentDraftItemModel.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          state = state.copyWith(items: list, isLoading: false);
          return true;
        }
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('[IndentDraft] addDraftItems error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
    return false;
  }

  /// Convenience method to add a single item to the indent draft cart
  Future<bool> addDraftItem({
    required String itemId,
    required int quantity,
    String? reason,
    String? itemName,
    String? itemCode,
    String? unit,
    String? imageUrl,
    String? indentType,
  }) async {
    return addDraftItems([
      {
        'itemId': itemId,
        'quantity': quantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (itemName != null && itemName.isNotEmpty) 'itemName': itemName,
        if (itemCode != null && itemCode.isNotEmpty) 'itemCode': itemCode,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (indentType != null && indentType.isNotEmpty) 'indentType': indentType,
      }
    ]);
  }

  /// Updates quantity or reason for a draft item
  Future<bool> updateQuantity(String itemId, int qty, {String? reason}) async {
    if (itemId.isEmpty) return false;
    try {
      final token = await _getToken();
      final url = Uri.parse('${Constants.socketUrl}/api/store/indents/drafts/$itemId');
      final res = await http.put(
        url,
        headers: _buildHeaders(token),
        body: json.encode({
          'quantity': qty,
          if (reason != null) 'reason': reason,
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .whereType<Map>()
              .map((e) => IndentDraftItemModel.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          state = state.copyWith(items: list);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[IndentDraft] updateQuantity error: $e');
    }
    return false;
  }

  /// Removes an item from the draft review list
  Future<bool> removeItem(String itemId) async {
    if (itemId.isEmpty) return false;
    try {
      final token = await _getToken();
      final url = Uri.parse('${Constants.socketUrl}/api/store/indents/drafts/$itemId');
      final res = await http.delete(url, headers: _buildHeaders(token));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .whereType<Map>()
              .map((e) => IndentDraftItemModel.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          state = state.copyWith(items: list);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[IndentDraft] removeItem error: $e');
    }
    return false;
  }

  /// Clears all draft items
  Future<bool> clearDrafts() async {
    try {
      final token = await _getToken();
      final url = Uri.parse('${Constants.socketUrl}/api/store/indents/drafts');
      final res = await http.delete(url, headers: _buildHeaders(token));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        state = state.copyWith(items: const []);
        return true;
      }
    } catch (e) {
      debugPrint('[IndentDraft] clearDrafts error: $e');
    }
    return false;
  }

  /// Combines selected draft items and submits them as ONE single Indent Requisition
  /// Status moves to PENDING (Approval Pending)
  Future<Map<String, dynamic>?> submitCombined({
    List<String>? itemIds,
    String? reason,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final token = await _getToken();
      final url = Uri.parse('${Constants.socketUrl}/api/store/indents/submit-combined');
      final res = await http.post(
        url,
        headers: _buildHeaders(token),
        body: json.encode({
          if (itemIds != null && itemIds.isNotEmpty) 'itemIds': itemIds,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['data'] is Map) {
          // Re-fetch remaining drafts
          await fetchDrafts();
          // Also trigger refresh on indent list provider so manager lists update
          try {
            _ref.invalidate(refillRequestsListProvider);
            _ref.invalidate(pendingRefillRequestsCountProvider);
          } catch (_) {}
          return Map<String, dynamic>.from(decoded['data']);
        }
      } else {
        final decoded = json.decode(res.body);
        final msg = decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Failed to submit combined indent';
        state = state.copyWith(isLoading: false, error: msg);
      }
    } catch (e) {
      debugPrint('[IndentDraft] submitCombined error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
    return null;
  }
}
