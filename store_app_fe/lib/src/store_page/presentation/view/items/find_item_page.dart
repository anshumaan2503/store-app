import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/motion_widgets.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../domains/models/store_items_model.dart';
import '../../../controllers/guided_tour_controller.dart';

/* ---------------- Palette (matching Store design) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;
const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

const _shadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
];

class _AllocationItem {
  final Map<String, dynamic> location;
  final int takeQty;
  final int availableQty;

  const _AllocationItem({
    required this.location,
    required this.takeQty,
    required this.availableQty,
  });
}

class FindItemPage extends ConsumerStatefulWidget {
  const FindItemPage({
    super.key,
    this.isStandalone = false,
    this.initialItem,
    this.initialItemId,
    this.initialItemName,
    this.initialQuantity,
  });

  final bool isStandalone;
  final StoreItemsModel? initialItem;
  final String? initialItemId;
  final String? initialItemName;
  final int? initialQuantity;

  @override
  ConsumerState<FindItemPage> createState() => _FindItemPageState();
}

class _FindItemPageState extends ConsumerState<FindItemPage> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String _itemSearch = '';
  StoreItemsModel? _selectedItem;
  int? _requiredQty;
  String? _qtyError;
  bool _initialResolved = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _selectedItem = widget.initialItem;
      _searchCtrl.text = widget.initialItem!.itemName;
      _itemSearch = widget.initialItem!.itemName;
      _initialResolved = true;
    } else if (widget.initialItemName != null && widget.initialItemName!.trim().isNotEmpty) {
      _searchCtrl.text = widget.initialItemName!.trim();
      _itemSearch = widget.initialItemName!.trim();
    }
    if (widget.initialQuantity != null && widget.initialQuantity! > 0) {
      _requiredQty = widget.initialQuantity;
      _qtyCtrl.text = widget.initialQuantity.toString();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() {
      _itemSearch = v.trim();
    });
  }

  void _selectItem(StoreItemsModel item) {
    setState(() {
      _selectedItem = item;
      _initialResolved = true;
      _qtyCtrl.clear();
      _requiredQty = null;
      _qtyError = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItem = null;
      _initialResolved = true;
      _qtyCtrl.clear();
      _requiredQty = null;
      _qtyError = null;
    });
  }

  void _onQtyChanged(String v) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _requiredQty = null;
        _qtyError = null;
      });
      return;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      setState(() {
        _requiredQty = null;
        _qtyError = 'Enter a positive whole number (> 0)';
      });
      return;
    }

    setState(() {
      _requiredQty = parsed;
      _qtyError = null;
    });
  }

  int _getAvailQty(Map<String, dynamic> loc) {
    final v = loc['stockAvailableQuantity'] ?? loc['stockAvailable'] ?? 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /* ---------------- V3 Deterministic Multi-Location Allocation ---------------- */
  List<_AllocationItem>? _calculateMultiLocationAllocation({
    required List<Map<String, dynamic>> locations,
    required int requiredQty,
  }) {
    // 1. Usable locations with stock > 0
    final usable = locations.where((loc) => _getAvailQty(loc) > 0).toList();
    if (usable.isEmpty) return null;

    // 2. Sort descending by available quantity
    usable.sort((a, b) {
      final qA = _getAvailQty(a);
      final qB = _getAvailQty(b);
      if (qA != qB) return qB.compareTo(qA);
      final cA = (a['code'] ?? a['rackName'] ?? '').toString();
      final cB = (b['code'] ?? b['rackName'] ?? '').toString();
      return cA.compareTo(cB);
    });

    int totalStock = 0;
    for (final loc in usable) {
      totalStock += _getAvailQty(loc);
    }
    if (totalStock < requiredQty) return null;

    // 3. Search combinations of size k = 2, 3, ... (Fewest locations first)
    List<Map<String, dynamic>>? bestCombo;
    int minExcess = 999999999;

    bool isBetterTieBreak(
      List<Map<String, dynamic>> candidate,
      List<Map<String, dynamic>> currentBest,
    ) {
      for (int i = 0; i < candidate.length; i++) {
        final qA = _getAvailQty(candidate[i]);
        final qB = _getAvailQty(currentBest[i]);
        if (qA != qB) return qA > qB; // prefer larger individual quantity
      }
      for (int i = 0; i < candidate.length; i++) {
        final cA = (candidate[i]['code'] ?? candidate[i]['rackName'] ?? '').toString();
        final cB = (currentBest[i]['code'] ?? currentBest[i]['rackName'] ?? '').toString();
        final cmp = cA.compareTo(cB);
        if (cmp != 0) return cmp < 0;
      }
      return false;
    }

    void findCombinations(
      int startIndex,
      int targetK,
      List<Map<String, dynamic>> current,
      int currentSum,
    ) {
      if (current.length == targetK) {
        if (currentSum >= requiredQty) {
          final excess = currentSum - requiredQty;
          if (excess < minExcess) {
            minExcess = excess;
            bestCombo = List.from(current);
          } else if (excess == minExcess && bestCombo != null) {
            if (isBetterTieBreak(current, bestCombo!)) {
              bestCombo = List.from(current);
            }
          }
        }
        return;
      }

      final remainingSlots = targetK - current.length;
      if (startIndex + remainingSlots > usable.length) return;

      int maxPossibleSum = currentSum;
      for (int i = 0; i < remainingSlots; i++) {
        maxPossibleSum += _getAvailQty(usable[startIndex + i]);
      }
      if (maxPossibleSum < requiredQty) return;

      for (int i = startIndex; i <= usable.length - remainingSlots; i++) {
        final loc = usable[i];
        final qty = _getAvailQty(loc);
        current.add(loc);
        findCombinations(i + 1, targetK, current, currentSum + qty);
        current.removeLast();
      }
    }

    for (int k = 2; k <= usable.length; k++) {
      bestCombo = null;
      minExcess = 999999999;
      findCombinations(0, k, [], 0);
      if (bestCombo != null) {
        // Optimal combination with fewest locations k found!
        break;
      }
    }

    if (bestCombo == null) return null;

    // 4. Order selected locations by descending available quantity
    bestCombo!.sort((a, b) {
      final qA = _getAvailQty(a);
      final qB = _getAvailQty(b);
      if (qA != qB) return qB.compareTo(qA);
      final cA = (a['code'] ?? a['rackName'] ?? '').toString();
      final cB = (b['code'] ?? b['rackName'] ?? '').toString();
      return cA.compareTo(cB);
    });

    // 5. Allocate only the quantity needed from each location
    int remaining = requiredQty;
    final List<_AllocationItem> result = [];
    for (final loc in bestCombo!) {
      if (remaining <= 0) break;
      final avail = _getAvailQty(loc);
      final take = math.min(avail, remaining);
      if (take > 0) {
        result.add(_AllocationItem(
          location: loc,
          takeQty: take,
          availableQty: avail,
        ));
        remaining -= take;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialResolved &&
        _selectedItem == null &&
        widget.initialItemId != null &&
        widget.initialItemId!.isNotEmpty) {
      final itemOne = ref.watch(itemFindOneStreamProvider(widget.initialItemId!)).value;
      if (itemOne != null) {
        _selectedItem = itemOne;
        _initialResolved = true;
        if (_searchCtrl.text.isEmpty) {
          _searchCtrl.text = itemOne.itemName;
          _itemSearch = itemOne.itemName;
        }
      }
    }

    final itemsAv = ref.watch(
      itemPagedStreamProvider(
        ItemPagedQuery(
          page: 1,
          limit: 200,
          search: _itemSearch,
          sort: 'name',
        ),
      ),
    );

    final tourState = ref.watch(guidedTourStateProvider);
    final isF5TourActive = !tourState.isSessionDismissed &&
        tourState.steps.any((s) => s.featureId == 'f5_find_items');

    itemsAv.whenData((data) {
      if (isF5TourActive && _selectedItem == null && data.rows.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedItem == null) {
            setState(() {
              _selectedItem = data.rows.first;
              _initialResolved = true;
            });
          }
        });
      }
      if (!_initialResolved && _selectedItem == null) {
        if (widget.initialItemId != null && widget.initialItemId!.isNotEmpty) {
          for (final it in data.rows) {
            if (it.id == widget.initialItemId) {
              _selectedItem = it;
              _initialResolved = true;
              break;
            }
          }
        }
        if (!_initialResolved &&
            _selectedItem == null &&
            widget.initialItemName != null &&
            widget.initialItemName!.isNotEmpty) {
          for (final it in data.rows) {
            if (it.itemName.toLowerCase() == widget.initialItemName!.toLowerCase()) {
              _selectedItem = it;
              _initialResolved = true;
              break;
            }
          }
        }
      }
    });

    Widget content = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isInitialLoading = !_initialResolved &&
                            _selectedItem == null &&
                            widget.initialItemId != null &&
                            widget.initialItemId!.isNotEmpty &&
                            itemsAv.isLoading;
                        if (isInitialLoading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final isWide = constraints.maxWidth >= 720;
                        if (isWide && _selectedItem != null) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildMatchingItemsSection(itemsAv),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  child: _buildLocationsAndRecommendationSection(
                                    _selectedItem!,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        if (_selectedItem != null) {
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildLocationsAndRecommendationSection(
                                  _selectedItem!,
                                ),
                                const SizedBox(height: 16),
                                _buildMatchingItemsCollapsible(itemsAv),
                              ],
                            ),
                          );
                        }

                        return _buildMatchingItemsSection(itemsAv);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          leading: const Padding(
            padding: EdgeInsets.all(10),
            child: AppBackButton(),
          ),
          title: const Text(
            'Find Item',
            style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
        ),
        body: content,
      );
    }

    return content;
  }

  /* ---------------- Search Bar ---------------- */
  Widget _buildSearchBar() {
    return Container(
      key: GuidedTourController.findItemSearchBarKey,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _ink700, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Search item by name or code...',
                hintStyle: TextStyle(
                  color: _ink600,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: _ink600, size: 18),
              onPressed: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              },
              tooltip: 'Clear search',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  /* ---------------- Matching Items Section ---------------- */
  Widget _buildMatchingItemsSection(AsyncValue<ItemPagedResult> itemsAv) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: _ink900),
              const SizedBox(width: 8),
              const Text(
                'Select Item',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              itemsAv.maybeWhen(
                data: (data) => Text(
                  '${data.rows.length} found',
                  style: const TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 8),
          Expanded(
            child: itemsAv.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading items: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              data: (paged) {
                final rows = paged.rows;
                if (rows.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No items found',
                        style: TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final it = rows[i];
                    final isSelected = _selectedItem?.id == it.id;
                    return _buildItemCard(
                      it,
                      isSelected: isSelected,
                      isFirst: i == 0,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingItemsCollapsible(AsyncValue<ItemPagedResult> itemsAv) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, size: 18, color: _ink900),
              const SizedBox(width: 8),
              const Text(
                'Other Matching Items',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              itemsAv.maybeWhen(
                data: (data) => Text(
                  '${data.rows.length} items',
                  style: const TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 8),
          itemsAv.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (paged) {
              final rows = paged.rows;
              if (rows.isEmpty) {
                return const Text(
                  'No matching items',
                  style: TextStyle(color: _ink700),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rows.length > 5 ? 5 : rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final it = rows[i];
                  final isSelected = _selectedItem?.id == it.id;
                  return _buildItemCard(
                    it,
                    isSelected: isSelected,
                    isFirst: i == 0,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    StoreItemsModel it, {
    required bool isSelected,
    bool isFirst = false,
  }) {
    return InkWell(
      key: isFirst ? GuidedTourController.firstFindItemCardKey : null,
      onTap: () => _selectItem(it),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? _accentMint.withValues(alpha: 0.25) : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _ink900 : _stroke,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? _ink900 : _surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _stroke),
              ),
              child: Icon(
                isSelected ? Icons.check_rounded : Icons.inventory_2_outlined,
                color: isSelected ? Colors.white : _ink900,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.itemName,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Code: ${it.itemCode} • Unit: ${it.unit} • Avail: ${it.stockAvailableQuantity}',
                    style: const TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _ink600, size: 20),
          ],
        ),
      ),
    );
  }

  /* ---------------- Location and Recommendation Section ---------------- */
  Widget _buildLocationsAndRecommendationSection(StoreItemsModel item) {
    final racksAv = ref.watch(racksByItemFutureProvider(item.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Selected Item Summary Card
        _buildSelectedItemSummaryCard(item),

        const SizedBox(height: 12),

        // 2. Required Quantity Input Card
        _buildRequiredQuantityCard(item),

        const SizedBox(height: 14),

        // 3. Locations & Recommendations
        racksAv.when(
          loading: () => Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _stroke),
              boxShadow: _shadow,
            ),
            padding: const EdgeInsets.all(32),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _stroke),
              boxShadow: _shadow,
            ),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Failed to load locations: $e',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          data: (locations) {
            if (locations.isEmpty) {
              return Container(
                key: GuidedTourController.firstFindItemLocationKey,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: _surfaceAlt.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _stroke),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_rounded, size: 36, color: _ink600),
                    const SizedBox(height: 10),
                    const Text(
                      'No storage location found for this item.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      key: GuidedTourController.firstFindItemStockPillKey,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _stroke),
                      ),
                      child: Text(
                        'Total Available: ${item.stockAvailableQuantity} ${item.unit}',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            int totalAvailable = 0;
            for (final loc in locations) {
              totalAvailable += _getAvailQty(loc);
            }

            Widget? decisionWidget;
            Map<String, dynamic>? v2RecommendedLocation;
            List<_AllocationItem>? v3Allocation;
            final Map<String, int> allocatedMap = {};

            if (_requiredQty != null) {
              final req = _requiredQty!;
              final qualifyingSingle = locations.where((loc) => _getAvailQty(loc) >= req).toList();

              if (qualifyingSingle.isNotEmpty) {
                // Rule #1 & #2: Single location can fulfill -> V2 Smart Recommendation
                qualifyingSingle.sort((a, b) {
                  final qA = _getAvailQty(a);
                  final qB = _getAvailQty(b);
                  if (qA != qB) return qA.compareTo(qB); // smallest first
                  final cA = (a['code'] ?? a['rackName'] ?? '').toString();
                  final cB = (b['code'] ?? b['rackName'] ?? '').toString();
                  return cA.compareTo(cB);
                });

                v2RecommendedLocation = qualifyingSingle.first;
                decisionWidget = _buildSmartRecommendationCard(
                  bestLocation: v2RecommendedLocation,
                  requiredQty: req,
                );
              } else if (totalAvailable < req) {
                // Insufficient total stock across all locations
                decisionWidget = _buildInsufficientStockCard(
                  requiredQty: req,
                  totalAvailable: totalAvailable,
                );
              } else {
                // Rule #3: No single location can fulfill, but total stock >= required -> V3 Multi-Location Allocation
                v3Allocation = _calculateMultiLocationAllocation(
                  locations: locations,
                  requiredQty: req,
                );

                if (v3Allocation != null && v3Allocation.isNotEmpty) {
                  for (final item in v3Allocation) {
                    final id = (item.location['_id'] ?? item.location['code'] ?? '').toString();
                    allocatedMap[id] = item.takeQty;
                  }
                  decisionWidget = _buildSmartAllocationCard(
                    allocation: v3Allocation,
                    requiredQty: req,
                  );
                }
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (decisionWidget != null) ...[
                  decisionWidget,
                  const SizedBox(height: 14),
                ],
                _buildAllLocationsCard(
                  locations: locations,
                  item: item,
                  recommendedLocation: v2RecommendedLocation,
                  allocatedMap: allocatedMap,
                  requiredQty: _requiredQty,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /* ---------------- Selected Item Summary Card ---------------- */
  Widget _buildSelectedItemSummaryCard(StoreItemsModel item) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${item.itemCode}',
                      style: const TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unit: ${item.unit} • Total Available: ${item.stockAvailableQuantity}',
                      style: const TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _clearSelection,
                icon: const Icon(Icons.close_rounded, size: 16, color: _ink700),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                  foregroundColor: _ink700,
                  iconColor: _ink700,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ---------------- Required Quantity Input Card ---------------- */
  Widget _buildRequiredQuantityCard(StoreItemsModel item) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_outlined, size: 18, color: _ink900),
              const SizedBox(width: 8),
              const Text(
                'Required Quantity',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (_requiredQty != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accentMint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Need: $_requiredQty ${item.unit}',
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: _onQtyChanged,
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Enter quantity you need (e.g. 30)',
              hintStyle: const TextStyle(
                color: _ink600,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.numbers_rounded, color: _ink700, size: 20),
              suffixIcon: _qtyCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _qtyCtrl.clear();
                        _onQtyChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _surfaceAlt.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _ink900, width: 1.5),
              ),
              errorText: _qtyError,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- V2 Smart Recommendation Card (Single Location) ---------------- */
  Widget _buildSmartRecommendationCard({
    required Map<String, dynamic> bestLocation,
    required int requiredQty,
  }) {
    final rawRoom = (bestLocation['roomName'] ?? '').toString().trim();
    final rawRoomId = (bestLocation['roomId'] ?? '').toString().trim();
    final roomDisplay = rawRoom.isNotEmpty ? rawRoom : (rawRoomId.isNotEmpty ? 'Room $rawRoomId' : 'Room —');

    final rawCode = (bestLocation['code'] ?? '').toString().trim();
    final rawRack = (bestLocation['rackName'] ?? '').toString().trim();
    final rackDisplay = rawRack.isNotEmpty
        ? (rawCode.isNotEmpty && rawCode != rawRack ? '$rawRack ($rawCode)' : rawRack)
        : (rawCode.isNotEmpty ? rawCode : 'Rack —');

    final availQty = _getAvailQty(bestLocation);
    final isScrap = bestLocation['isScrap'] == true;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ink900, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _accentMint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _ink900,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Recommendation',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Single Best Location',
                      style: TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: const Text(
                  '✓ Can Fulfill',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.room_rounded, color: _ink900, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomDisplay,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.grid_view_rounded, size: 15, color: _ink600),
                          const SizedBox(width: 4),
                          Text(
                            rackDisplay,
                            style: const TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isScrap) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentPeach.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _stroke),
                    ),
                    child: const Text(
                      'Scrap Rack',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentMint.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _stroke),
                      ),
                      child: Text(
                        'Take: $requiredQty',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Available: $availQty',
                      style: const TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '✓ This location can fulfill your entire requested quantity ($requiredQty).',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ---------------- V3 Smart Allocation Card (Multi-Location) ---------------- */
  Widget _buildSmartAllocationCard({
    required List<_AllocationItem> allocation,
    required int requiredQty,
  }) {
    int totalAllocated = 0;
    for (final item in allocation) {
      totalAllocated += item.takeQty;
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ink900, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _accentMint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.alt_route_rounded,
                  color: _ink900,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Allocation',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Multi-Location Smart Allocation',
                      style: TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: const Text(
                  '✓ Can Fulfill',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 12),

          // Summary Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Required: $requiredQty',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Allocated: $totalAllocated / $requiredQty',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Locations: ${allocation.length}',
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Allocated locations list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allocation.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = allocation[i];
              return _buildAllocatedLocationRow(index: i + 1, item: item);
            },
          ),

          const SizedBox(height: 12),

          // Helper note
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '✓ Collect from these ${allocation.length} locations to fulfill your total request of $requiredQty.',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocatedLocationRow({
    required int index,
    required _AllocationItem item,
  }) {
    final loc = item.location;
    final rawRoom = (loc['roomName'] ?? '').toString().trim();
    final rawRoomId = (loc['roomId'] ?? '').toString().trim();
    final roomDisplay = rawRoom.isNotEmpty ? rawRoom : (rawRoomId.isNotEmpty ? 'Room $rawRoomId' : 'Room —');

    final rawCode = (loc['code'] ?? '').toString().trim();
    final rawRack = (loc['rackName'] ?? '').toString().trim();
    final rackDisplay = rawRack.isNotEmpty
        ? (rawCode.isNotEmpty && rawCode != rawRack ? '$rawRack ($rawCode)' : rawRack)
        : (rawCode.isNotEmpty ? rawCode : 'Rack —');

    final isScrap = loc['isScrap'] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: _ink900,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.room_rounded, size: 16, color: _ink900),
                    const SizedBox(width: 4),
                    Text(
                      roomDisplay,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    if (isScrap) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentPeach.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Scrap',
                          style: TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 13, color: _ink600),
                    const SizedBox(width: 4),
                    Text(
                      rackDisplay,
                      style: const TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentMint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _stroke),
                ),
                child: Text(
                  'Take: ${item.takeQty}',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Available: ${item.availableQty}',
                style: const TextStyle(
                  color: _ink600,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ---------------- Insufficient Stock Card (Scenario 4 / 7) ---------------- */
  Widget _buildInsufficientStockCard({
    required int requiredQty,
    required int totalAvailable,
  }) {
    final shortBy = requiredQty - totalAvailable;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        boxShadow: _shadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFC62828),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Insufficient stock for the requested quantity.',
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Required: $requiredQty   •   Total Available: $totalAvailable   •   Short by: $shortBy',
            style: const TextStyle(
              color: Color(0xFFB71C1C),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- All Storage Locations Card (V1 Preserved) ---------------- */
  Widget _buildAllLocationsCard({
    required List<Map<String, dynamic>> locations,
    required StoreItemsModel item,
    Map<String, dynamic>? recommendedLocation,
    Map<String, int>? allocatedMap,
    int? requiredQty,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, color: _ink900, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where is this item?',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'All Storage Locations (${locations.length})',
                    style: const TextStyle(
                      color: _ink600,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: _ink700),
                tooltip: 'Refresh locations',
                onPressed: () {
                  ref.invalidate(racksByItemFutureProvider(item.id));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: locations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final loc = locations[i];
              final id = (loc['_id'] ?? loc['code'] ?? '').toString();

              final isV2Rec = recommendedLocation != null &&
                  ((loc['_id'] != null && loc['_id'] == recommendedLocation['_id']) ||
                      (loc['code'] != null && loc['code'] == recommendedLocation['code']));

              final int? takeQty = allocatedMap?[id];
              final bool isV3Alloc = takeQty != null;

              return _buildLocationCard(
                loc,
                isRecommended: isV2Rec,
                isAllocated: isV3Alloc,
                takeQty: isV2Rec ? requiredQty : takeQty,
                isFirst: i == 0,
              );
            },
          ),
        ],
      ),
    );
  }

  /* ---------------- Single Location Card ---------------- */
  Widget _buildLocationCard(
    Map<String, dynamic> loc, {
    bool isRecommended = false,
    bool isAllocated = false,
    int? takeQty,
    bool isFirst = false,
  }) {
    final rawRoom = (loc['roomName'] ?? '').toString().trim();
    final rawRoomId = (loc['roomId'] ?? '').toString().trim();
    final roomDisplay = rawRoom.isNotEmpty ? rawRoom : (rawRoomId.isNotEmpty ? 'Room $rawRoomId' : 'Room —');

    final rawCode = (loc['code'] ?? '').toString().trim();
    final rawRack = (loc['rackName'] ?? '').toString().trim();
    final rackDisplay = rawRack.isNotEmpty
        ? (rawCode.isNotEmpty && rawCode != rawRack ? '$rawRack ($rawCode)' : rawRack)
        : (rawCode.isNotEmpty ? rawCode : 'Rack —');

    final availQty = _getAvailQty(loc);
    final isScrap = loc['isScrap'] == true;
    final isHighlighted = isRecommended || isAllocated;

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted ? _accentMint.withValues(alpha: 0.15) : _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? _ink900 : _stroke,
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.room_rounded, color: _ink900, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  key: isFirst ? GuidedTourController.firstFindItemLocationKey : null,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          roomDisplay,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _ink900,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ] else if (isAllocated && takeQty != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ALLOCATED (Take: $takeQty)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.grid_view_rounded, size: 14, color: _ink600),
                        const SizedBox(width: 4),
                        Text(
                          rackDisplay,
                          style: const TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isScrap) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentPeach.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Text(
                    'Scrap Rack',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    key: isFirst ? GuidedTourController.firstFindItemStockPillKey : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHighlighted ? _surface : _surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _stroke),
                    ),
                    child: Text(
                      'Available: $availQty',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (takeQty != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Take: $takeQty',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
