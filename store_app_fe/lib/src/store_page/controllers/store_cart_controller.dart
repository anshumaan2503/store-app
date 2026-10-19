import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:store_app/src/auth/domains/providers/uid_provider.dart';
import 'package:store_app/src/auth/shared/providers/auth_model_provider.dart';
import 'package:store_app/src/auth/shared/repositories/shared_preference_repository.dart';
import '../../components/constants.dart';
import '../../components/socket_manager.dart';
import '../domains/models/store_items_model.dart';

class StoreCartItem {
  final String id;
  final String itemName;
  final String itemCode;
  final String unit;
  final String imageUrl;
  final int quantity;
  final int stockAvailableQuantity;
  final String? rackId;
  final String? categoryId;
  final String? categoryLabel;
  final DateTime addedAt;

  // Dynamic configuration synced from MongoDB backend
  static Duration activeTimeout = const Duration(minutes: 5);
  static bool activeTimeoutEnabled = true;

  // Fallback getter for legacy references
  static Duration get cartItemTimeout => activeTimeout;

  StoreCartItem({
    required this.id,
    required this.itemName,
    required this.itemCode,
    required this.unit,
    this.imageUrl = '',
    required this.quantity,
    required this.stockAvailableQuantity,
    this.rackId,
    this.categoryId,
    this.categoryLabel,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  bool get isExpired =>
      activeTimeoutEnabled &&
      DateTime.now().difference(addedAt) >= activeTimeout;

  Duration get remainingTime {
    if (!activeTimeoutEnabled) return const Duration(hours: 99);
    final diff = activeTimeout - DateTime.now().difference(addedAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  String get remainingFormatted {
    if (!activeTimeoutEnabled) return 'No expiry';
    final rem = remainingTime;
    final m = rem.inMinutes;
    final s = rem.inSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Quantity that can be fulfilled immediately from available stock (Issue Request)
  int get availableForIssue =>
      stockAvailableQuantity <= 0
          ? 0
          : (quantity <= stockAvailableQuantity ? quantity : stockAvailableQuantity);

  /// Quantity that exceeds current stock and moves to Indent Requirement (Indent Review)
  int get shortfallForIndent =>
      (quantity - availableForIssue).clamp(0, quantity);

  /// True if this item has any units that must be indented
  bool get hasShortfall => shortfallForIndent > 0;

  /// True if 100% of this item is out of stock and will be routed to Indent Review
  bool get isEntirelyIndent => availableForIssue == 0 && shortfallForIndent > 0;

  StoreCartItem copyWith({
    String? id,
    String? itemName,
    String? itemCode,
    String? unit,
    String? imageUrl,
    int? quantity,
    int? stockAvailableQuantity,
    String? rackId,
    String? categoryId,
    String? categoryLabel,
    DateTime? addedAt,
  }) {
    return StoreCartItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      stockAvailableQuantity: stockAvailableQuantity ?? this.stockAvailableQuantity,
      rackId: rackId ?? this.rackId,
      categoryId: categoryId ?? this.categoryId,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'itemCode': itemCode,
      'unit': unit,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'stockAvailableQuantity': stockAvailableQuantity,
      'rackId': rackId,
      'categoryId': categoryId,
      'categoryLabel': categoryLabel,
      'addedAt': addedAt.millisecondsSinceEpoch,
    };
  }

  factory StoreCartItem.fromMap(Map<String, dynamic> map) {
    DateTime parsedAddedAt = DateTime.now();
    final rawAdded = map['addedAt'];
    if (rawAdded != null) {
      if (rawAdded is int) {
        parsedAddedAt = DateTime.fromMillisecondsSinceEpoch(rawAdded);
      } else if (rawAdded is String) {
        final asInt = int.tryParse(rawAdded);
        if (asInt != null) {
          parsedAddedAt = DateTime.fromMillisecondsSinceEpoch(asInt);
        } else {
          parsedAddedAt = DateTime.tryParse(rawAdded) ?? DateTime.now();
        }
      }
    }

    return StoreCartItem(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      itemName: (map['itemName'] ?? '').toString(),
      itemCode: (map['itemCode'] ?? '').toString(),
      unit: (map['unit'] ?? 'PCS').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      quantity: int.tryParse((map['quantity'] ?? 1).toString()) ?? 1,
      stockAvailableQuantity: int.tryParse((map['stockAvailableQuantity'] ?? 0).toString()) ?? 0,
      rackId: map['rackId']?.toString(),
      categoryId: map['categoryId']?.toString(),
      categoryLabel: map['categoryLabel']?.toString(),
      addedAt: parsedAddedAt,
    );
  }

  factory StoreCartItem.fromStoreItem(StoreItemsModel item, {int quantity = 1}) {
    return StoreCartItem(
      id: item.id,
      itemName: item.itemName,
      itemCode: item.itemCode,
      unit: item.unit.isEmpty ? 'PCS' : item.unit,
      imageUrl: item.imageUrl.toString().trim(),
      quantity: quantity,
      stockAvailableQuantity: item.stockAvailableQuantity,
      rackId: item.rackId.isNotEmpty ? item.rackId.first : null,
      categoryId: item.categoryId?.toString(),
      categoryLabel: item.categoryLabel,
      addedAt: DateTime.now(),
    );
  }
}

class StoreCartState {
  final List<StoreCartItem> items;
  final bool isLoading;

  const StoreCartState({
    this.items = const [],
    this.isLoading = false,
  });

  int get totalCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get lineCount => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  StoreCartItem? findById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  StoreCartState copyWith({
    List<StoreCartItem>? items,
    bool? isLoading,
  }) {
    return StoreCartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/* ---------------- Store Cart Configuration ---------------- */

class StoreCartConfig {
  final int cartTimeoutMinutes;
  final bool cartTimeoutEnabled;
  final int requestTimeoutDays;
  final bool requestTimeoutEnabled;
  final bool monthEndRevertEnabled;
  final bool indentApprovalRequired;
  final bool grnWorkflowEnabled;

  const StoreCartConfig({
    this.cartTimeoutMinutes = 5,
    this.cartTimeoutEnabled = true,
    this.requestTimeoutDays = 7,
    this.requestTimeoutEnabled = true,
    this.monthEndRevertEnabled = true,
    this.indentApprovalRequired = false,
    this.grnWorkflowEnabled = false,
  });

  Duration get timeoutDuration => Duration(minutes: cartTimeoutMinutes);
  Duration get requestTimeoutDuration => Duration(days: requestTimeoutDays);

  StoreCartConfig copyWith({
    int? cartTimeoutMinutes,
    bool? cartTimeoutEnabled,
    int? requestTimeoutDays,
    bool? requestTimeoutEnabled,
    bool? monthEndRevertEnabled,
    bool? indentApprovalRequired,
    bool? grnWorkflowEnabled,
  }) {
    return StoreCartConfig(
      cartTimeoutMinutes: cartTimeoutMinutes ?? this.cartTimeoutMinutes,
      cartTimeoutEnabled: cartTimeoutEnabled ?? this.cartTimeoutEnabled,
      requestTimeoutDays: requestTimeoutDays ?? this.requestTimeoutDays,
      requestTimeoutEnabled:
          requestTimeoutEnabled ?? this.requestTimeoutEnabled,
      monthEndRevertEnabled:
          monthEndRevertEnabled ?? this.monthEndRevertEnabled,
      indentApprovalRequired:
          indentApprovalRequired ?? this.indentApprovalRequired,
      grnWorkflowEnabled:
          grnWorkflowEnabled ?? this.grnWorkflowEnabled,
    );
  }

  factory StoreCartConfig.fromMap(Map<String, dynamic> map) {
    return StoreCartConfig(
      cartTimeoutMinutes:
          int.tryParse(map['cartTimeoutMinutes']?.toString() ?? '5') ?? 5,
      cartTimeoutEnabled: map['cartTimeoutEnabled'] == null
          ? true
          : (map['cartTimeoutEnabled'] == true ||
              map['cartTimeoutEnabled'].toString() == 'true'),
      requestTimeoutDays:
          int.tryParse(map['requestTimeoutDays']?.toString() ?? '7') ?? 7,
      requestTimeoutEnabled: map['requestTimeoutEnabled'] == null
          ? true
          : (map['requestTimeoutEnabled'] == true ||
              map['requestTimeoutEnabled'].toString() == 'true'),
      monthEndRevertEnabled: map['monthEndRevertEnabled'] == null
          ? true
          : (map['monthEndRevertEnabled'] == true ||
              map['monthEndRevertEnabled'].toString() == 'true'),
      indentApprovalRequired: map['indentApprovalRequired'] == true ||
          map['indentApprovalRequired'].toString() == 'true',
      grnWorkflowEnabled: map['grnWorkflowEnabled'] == true ||
          map['grnWorkflowEnabled'].toString() == 'true',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cartTimeoutMinutes': cartTimeoutMinutes,
      'cartTimeoutEnabled': cartTimeoutEnabled,
      'requestTimeoutDays': requestTimeoutDays,
      'requestTimeoutEnabled': requestTimeoutEnabled,
      'monthEndRevertEnabled': monthEndRevertEnabled,
      'indentApprovalRequired': indentApprovalRequired,
      'grnWorkflowEnabled': grnWorkflowEnabled,
    };
  }
}

final storeCartConfigProvider =
    StateNotifierProvider<StoreCartConfigNotifier, StoreCartConfig>((ref) {
  return StoreCartConfigNotifier(ref);
});

class StoreCartConfigNotifier extends StateNotifier<StoreCartConfig> {
  final Ref _ref;
  static const String _prefConfigKey = 'store_cart_config_v1';

  StoreCartConfigNotifier(this._ref) : super(const StoreCartConfig()) {
    _loadFromLocalCache();
    _initSocket();
    fetchConfig();
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final sp = _ref.read(spRepositoryProvider);
      final raw = await sp.getStringValue(_prefConfigKey);
      if (raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          final cfg = StoreCartConfig.fromMap(decoded);
          state = cfg;
          _syncActiveTimeout(cfg);
        }
      }
    } catch (_) {}
  }

  void _syncActiveTimeout(StoreCartConfig cfg) {
    StoreCartItem.activeTimeout = Duration(minutes: cfg.cartTimeoutMinutes);
    StoreCartItem.activeTimeoutEnabled = cfg.cartTimeoutEnabled;
  }

  void _handleConfigUpdated(dynamic data) {
    try {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final cfg = StoreCartConfig.fromMap(map);
        state = cfg;
        _syncActiveTimeout(cfg);
        _persistLocal(cfg);
        _ref.read(globalInCartProvider.notifier).refresh();
      }
    } catch (e) {
      debugPrint('[CartConfig] Error parsing socket config: $e');
    }
  }

  void _initSocket() {
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.off('store:cart:configUpdated', _handleConfigUpdated);
      socket.on('store:cart:configUpdated', _handleConfigUpdated);
      socket.emit('store:cart:getConfig', {});
    } catch (e) {
      debugPrint('[CartConfig] Socket attach error: $e');
    }
  }

  Future<void> fetchConfig() async {
    try {
      final url = Uri.parse('${Constants.socketUrl}/api/store/cart/config');
      final res =
          await http.get(url, headers: {'Content-Type': 'application/json'});
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['data'] is Map) {
          final cfg = StoreCartConfig.fromMap(
              Map<String, dynamic>.from(decoded['data']));
          state = cfg;
          _syncActiveTimeout(cfg);
          _persistLocal(cfg);
        }
      }
    } catch (_) {}
  }

  Future<void> _persistLocal(StoreCartConfig cfg) async {
    try {
      final sp = _ref.read(spRepositoryProvider);
      await sp.setStringValue(_prefConfigKey, json.encode(cfg.toMap()));
    } catch (_) {}
  }

  Future<bool> updateConfig({
    required int minutes,
    required bool enabled,
    int? requestDays,
    bool? requestEnabled,
    bool? monthEndRevertEnabled,
    bool? indentApprovalRequired,
    bool? grnWorkflowEnabled,
    String? updatedBy,
  }) async {
    try {
      final url = Uri.parse('${Constants.socketUrl}/api/store/cart/config');
      final body = json.encode({
        'cartTimeoutMinutes': minutes,
        'cartTimeoutEnabled': enabled,
        if (requestDays != null) 'requestTimeoutDays': requestDays,
        if (requestEnabled != null) 'requestTimeoutEnabled': requestEnabled,
        if (monthEndRevertEnabled != null) 'monthEndRevertEnabled': monthEndRevertEnabled,
        if (indentApprovalRequired != null) 'indentApprovalRequired': indentApprovalRequired,
        if (grnWorkflowEnabled != null) 'grnWorkflowEnabled': grnWorkflowEnabled,
        if (updatedBy != null && updatedBy.isNotEmpty) 'updatedBy': updatedBy,
      });

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final cfg = StoreCartConfig(
          cartTimeoutMinutes: minutes,
          cartTimeoutEnabled: enabled,
          requestTimeoutDays: requestDays ?? state.requestTimeoutDays,
          requestTimeoutEnabled: requestEnabled ?? state.requestTimeoutEnabled,
          monthEndRevertEnabled:
              monthEndRevertEnabled ?? state.monthEndRevertEnabled,
          indentApprovalRequired:
              indentApprovalRequired ?? state.indentApprovalRequired,
          grnWorkflowEnabled:
              grnWorkflowEnabled ?? state.grnWorkflowEnabled,
        );
        state = cfg;
        _syncActiveTimeout(cfg);
        _persistLocal(cfg);
        return true;
      }
    } catch (e) {
      debugPrint('[CartConfig] Failed to update config: $e');
    }
    return false;
  }

  @override
  void dispose() {
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.off('store:cart:configUpdated', _handleConfigUpdated);
    } catch (_) {}
    super.dispose();
  }
}

/// Global In-Cart quantities aggregated across ALL departments and user accounts.
/// Maps item.id -> totalQuantityInAllCarts
final globalInCartProvider =
    StateNotifierProvider<GlobalInCartNotifier, Map<String, int>>((ref) {
  return GlobalInCartNotifier(ref);
});

class GlobalInCartNotifier extends StateNotifier<Map<String, int>> {
  final Ref _ref;

  GlobalInCartNotifier(this._ref) : super(const {}) {
    _initSocket();
    fetchGlobalTotals();
  }

  void _handleGlobalTotals(dynamic data) {
    try {
      if (data is Map) {
        final parsed = <String, int>{};
        data.forEach((k, v) {
          final id = k.toString();
          final qty = int.tryParse(v.toString()) ?? 0;
          if (qty > 0) parsed[id] = qty;
        });
        state = parsed;
      }
    } catch (e) {
      debugPrint('[GlobalInCart] Error parsing totals: $e');
    }
  }

  void _initSocket() {
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.off('store:cart:globalTotals', _handleGlobalTotals);
      socket.on('store:cart:globalTotals', _handleGlobalTotals);
      socket.emit('store:cart:getGlobalTotals', {});
    } catch (e) {
      debugPrint('[GlobalInCart] Socket attach error: $e');
    }
  }

  Future<void> fetchGlobalTotals() async {
    try {
      final url = Uri.parse('${Constants.socketUrl}/api/store/cart/global/totals');
      final res = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['data'] is Map) {
          _handleGlobalTotals(decoded['data']);
        }
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> fetchItemCartBreakdown(String itemId) async {
    if (itemId.isEmpty) return [];
    try {
      final url = Uri.parse('${Constants.socketUrl}/api/store/cart/item/$itemId/breakdown');
      final res = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = json.decode(res.body);
        if (decoded is Map && decoded['data'] is List) {
          return (decoded['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[GlobalInCart] fetchItemCartBreakdown error: $e');
    }
    return [];
  }

  void refresh() {
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.emit('store:cart:getGlobalTotals', {});
    } catch (_) {}
    fetchGlobalTotals();
  }

  /// Instantly drop items from global totals locally for zero-latency UI reactivity
  void clearImmediate(List<String> itemIds) {
    if (state.isEmpty || itemIds.isEmpty) return;
    final updated = Map<String, int>.from(state);
    for (final id in itemIds) {
      updated.remove(id);
    }
    state = updated;
  }

  @override
  void dispose() {
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.off('store:cart:globalTotals', _handleGlobalTotals);
    } catch (_) {}
    super.dispose();
  }
}

final itemCartBreakdownProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, itemId) async {
  return ref.read(globalInCartProvider.notifier).fetchItemCartBreakdown(itemId);
});

/// User-scoped cart provider. Reactively re-instantiates whenever active user/UID switches.
final storeCartProvider =
    StateNotifierProvider<StoreCartNotifier, StoreCartState>((ref) {
  final uidFromProvider = ref.watch(uidProvider);
  final auth = ref.watch(authModelProvider);
  final activeUid = uidFromProvider.isNotEmpty ? uidFromProvider : (auth?.uid ?? '');
  return StoreCartNotifier(ref, activeUid);
});

class StoreCartNotifier extends StateNotifier<StoreCartState> {
  final Ref _ref;
  String _currentUid;
  static const String _prefCartKeyPrefix = 'store_cart_v1_';
  Timer? _expiryTimer;

  StoreCartNotifier(this._ref, this._currentUid) : super(const StoreCartState()) {
    _ref.read(storeCartConfigProvider); // Eagerly attach config
    _initCart();
    _startExpiryTimer();
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      pruneExpiredItems();
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _detachSocket();
    super.dispose();
  }

  Future<void> _initCart() async {
    try {
      if (_currentUid.isEmpty) {
        final sp = _ref.read(spRepositoryProvider);
        final diskUid = await sp.getStringValue('uid');
        if (diskUid.isNotEmpty) {
          _currentUid = diskUid;
        }
      }
      if (_currentUid.isNotEmpty) {
        await loadCart(_currentUid);
        _attachSocket();
      }
    } catch (_) {}
  }

  void _handleRemoteUpdate(dynamic data) {
    try {
      if (data is Map && data['userId'] == _currentUid) {
        final rawItems = data['items'];
        if (rawItems is List) {
          final now = DateTime.now();
          final remoteItems = rawItems
              .map((e) => StoreCartItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .where((item) =>
                  !StoreCartItem.activeTimeoutEnabled ||
                  now.difference(item.addedAt) < StoreCartItem.activeTimeout)
              .toList();
          state = state.copyWith(items: remoteItems);
          _persistLocal();
        }
      }
    } catch (e) {
      debugPrint('[Cart] Remote sync parse error: $e');
    }
  }

  void _attachSocket() {
    if (_currentUid.isEmpty) return;
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.off('store:cart:updated', _handleRemoteUpdate);
      socket.on('store:cart:updated', _handleRemoteUpdate);

      // Fetch cloud cart from MongoDB
      socket.emit('store:cart:get', {'userId': _currentUid});
    } catch (e) {
      debugPrint('[Cart] Socket attach error: $e');
    }
  }

  void _detachSocket() {
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.off('store:cart:updated', _handleRemoteUpdate);
    } catch (_) {}
  }

  void _broadcastSync() {
    if (_currentUid.isEmpty) return;
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.emit('store:cart:sync', {
        'userId': _currentUid,
        'items': state.items.map((e) => e.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('[Cart] Sync broadcast failed: $e');
    }
  }

  void _broadcastClear() {
    if (_currentUid.isEmpty) return;
    try {
      final socket = _ref.read(socketProvider).getSocket();
      socket.emit('store:cart:clear', {'userId': _currentUid});
    } catch (_) {}
  }

  Future<void> loadCart(String uid) async {
    if (uid.isEmpty) {
      state = const StoreCartState();
      return;
    }
    _currentUid = uid;
    try {
      // 1. Load local cache first for instant render
      final sp = _ref.read(spRepositoryProvider);
      final raw = await sp.getStringValue('$_prefCartKeyPrefix$uid');
      if (raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          final now = DateTime.now();
          final loadedItems = decoded
              .map((e) => StoreCartItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .where((item) =>
                  !StoreCartItem.activeTimeoutEnabled ||
                  now.difference(item.addedAt) < StoreCartItem.activeTimeout)
              .toList();
          state = state.copyWith(items: loadedItems);
        }
      }
    } catch (e) {
      debugPrint('[Cart] Failed to load local cart: $e');
    }
  }

  Future<void> _persistLocal() async {
    String uid = _currentUid;
    if (uid.isEmpty) {
      uid = _ref.read(uidProvider);
      if (uid.isEmpty) {
        uid = _ref.read(authModelProvider)?.uid ?? '';
      }
    }
    if (uid.isEmpty) return;
    try {
      final sp = _ref.read(spRepositoryProvider);
      final list = state.items.map((e) => e.toMap()).toList();
      await sp.setStringValue('$_prefCartKeyPrefix$uid', json.encode(list));
    } catch (e) {
      debugPrint('[Cart] Failed to persist local cart: $e');
    }
  }

  /// Removes any cart item that has been held for longer than configured timeout without submission
  void pruneExpiredItems() {
    if (!StoreCartItem.activeTimeoutEnabled) return; // Zero overhead when disabled
    if (state.items.isEmpty) return;
    final now = DateTime.now();
    final nonExpired = state.items.where((item) {
      return now.difference(item.addedAt) < StoreCartItem.activeTimeout;
    }).toList();

    if (nonExpired.length != state.items.length) {
      state = state.copyWith(items: nonExpired);
      _persistLocal();
      _broadcastSync();
    }
  }

  /// Adds a store item to the cart. If already present, increments quantity up to available stock.
  /// Returns `true` if added/updated, or `false` with a reason if stock exceeded.
  bool addItem(StoreItemsModel item, {int qty = 1, void Function(String message)? onStockError}) {
    if (qty <= 0) return false;

    pruneExpiredItems();

    final existingIndex = state.items.indexWhere((x) => x.id == item.id);
    final globalInCart = _ref.read(globalInCartProvider);
    final globalQty = globalInCart[item.id] ?? 0;
    final myCurrentQty = existingIndex >= 0 ? state.items[existingIndex].quantity : 0;
    final othersInCart = (globalQty - myCurrentQty).clamp(0, 999999);
    final effectiveAvailable = (item.stockAvailableQuantity - othersInCart).clamp(0, 999999);

    if (existingIndex >= 0) {
      final current = state.items[existingIndex];
      final newQty = current.quantity + qty;

      final updatedList = List<StoreCartItem>.from(state.items);
      updatedList[existingIndex] = current.copyWith(
        quantity: newQty,
        stockAvailableQuantity: effectiveAvailable,
        addedAt: DateTime.now(), // Refresh 5-minute window upon user adding more
      );
      state = state.copyWith(items: updatedList);
      _persistLocal();
      _broadcastSync();
      return true;
    } else {
      final newItem = StoreCartItem.fromStoreItem(item, quantity: qty).copyWith(
        stockAvailableQuantity: effectiveAvailable,
      );
      state = state.copyWith(items: [...state.items, newItem]);
      _persistLocal();
      _broadcastSync();
      return true;
    }
  }

  /// Direct add/merge for a StoreCartItem (useful from QR subparts/lines).
  bool addCartItem(StoreCartItem cartItem, {void Function(String message)? onStockError}) {
    if (cartItem.quantity <= 0) return false;

    pruneExpiredItems();

    final existingIndex = state.items.indexWhere((x) => x.id == cartItem.id);
    final globalInCart = _ref.read(globalInCartProvider);
    final globalQty = globalInCart[cartItem.id] ?? 0;
    final myCurrentQty = existingIndex >= 0 ? state.items[existingIndex].quantity : 0;
    final othersInCart = (globalQty - myCurrentQty).clamp(0, 999999);
    final effectiveAvailable = (cartItem.stockAvailableQuantity - othersInCart).clamp(0, 999999);

    if (existingIndex >= 0) {
      final current = state.items[existingIndex];
      final newQty = current.quantity + cartItem.quantity;

      final updatedList = List<StoreCartItem>.from(state.items);
      updatedList[existingIndex] = current.copyWith(
        quantity: newQty,
        stockAvailableQuantity: effectiveAvailable,
        addedAt: DateTime.now(), // Refresh 5-minute window
      );
      state = state.copyWith(items: updatedList);
      _persistLocal();
      _broadcastSync();
      return true;
    } else {
      final newItem = cartItem.copyWith(
        addedAt: DateTime.now(),
        stockAvailableQuantity: effectiveAvailable,
      );
      state = state.copyWith(items: [...state.items, newItem]);
      _persistLocal();
      _broadcastSync();
      return true;
    }
  }

  void updateQuantity(String itemId, int qty) {
    if (qty <= 0) {
      removeItem(itemId);
      return;
    }

    final idx = state.items.indexWhere((x) => x.id == itemId);
    if (idx >= 0) {
      final current = state.items[idx];
      final updatedList = List<StoreCartItem>.from(state.items);
      updatedList[idx] = current.copyWith(quantity: qty);
      state = state.copyWith(items: updatedList);
      _persistLocal();
      _broadcastSync();
    }
  }

  void increment(String itemId) {
    final idx = state.items.indexWhere((x) => x.id == itemId);
    if (idx >= 0) {
      final current = state.items[idx];
      final updatedList = List<StoreCartItem>.from(state.items);
      updatedList[idx] = current.copyWith(quantity: current.quantity + 1);
      state = state.copyWith(items: updatedList);
      _persistLocal();
      _broadcastSync();
    }
  }

  void decrement(String itemId) {
    final idx = state.items.indexWhere((x) => x.id == itemId);
    if (idx >= 0) {
      final current = state.items[idx];
      if (current.quantity > 1) {
        final updatedList = List<StoreCartItem>.from(state.items);
        updatedList[idx] = current.copyWith(quantity: current.quantity - 1);
        state = state.copyWith(items: updatedList);
        _persistLocal();
        _broadcastSync();
      } else {
        removeItem(itemId);
      }
    }
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((x) => x.id != itemId).toList(),
    );
    _persistLocal();
    _broadcastSync();
    _ref.read(globalInCartProvider.notifier).clearImmediate([itemId]);
  }

  Future<void> clearCart() async {
    final clearedIds = state.items.map((x) => x.id).toList();
    state = state.copyWith(items: const []);
    _persistLocal();
    _broadcastClear();

    // 1. Immediately drop these items from the in-memory global map
    _ref.read(globalInCartProvider.notifier).clearImmediate(clearedIds);

    // 2. Clear backend DB via REST API as a resilient fallback
    try {
      String uid = _currentUid;
      if (uid.isEmpty) {
        final sp = _ref.read(spRepositoryProvider);
        uid = await sp.getStringValue('uid') ?? '';
      }
      if (uid.isNotEmpty) {
        final url = Uri.parse('${Constants.socketUrl}/api/store/cart/clear');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'userId': uid}),
        );
      }
    } catch (_) {}

    // 3. Fetch latest global totals
    _ref.read(globalInCartProvider.notifier).refresh();
  }
}
