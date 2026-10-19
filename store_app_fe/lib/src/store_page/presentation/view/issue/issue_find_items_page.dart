import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/motion_widgets.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../domains/models/store_issue_model.dart';
import '../../widgets/store_ui_state_widgets.dart';
import '../items/find_item_page.dart';

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

/// Data model representing a sequenced item pick step ordered by room.
class _ItemPickStep {
  final IssueLine line;
  final List<Map<String, dynamic>> racks;
  final int minRoomNumber;
  final String primaryRoomName;
  final String primaryRackDisplay;
  final int totalAvailableStock;
  final bool isLocationAssigned;
  final List<String> allRooms;

  const _ItemPickStep({
    required this.line,
    required this.racks,
    required this.minRoomNumber,
    required this.primaryRoomName,
    required this.primaryRackDisplay,
    required this.totalAvailableStock,
    required this.isLocationAssigned,
    required this.allRooms,
  });
}

class IssueFindItemsPage extends ConsumerStatefulWidget {
  const IssueFindItemsPage({
    super.key,
    required this.issue,
  });

  final IssueModel issue;

  @override
  ConsumerState<IssueFindItemsPage> createState() => _IssueFindItemsPageState();
}

class _IssueFindItemsPageState extends ConsumerState<IssueFindItemsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_ItemPickStep> _pickSteps = [];
  final Set<String> _expandedItemIds = {};
  final Set<String> _pickedItemIds = {};

  @override
  void initState() {
    super.initState();
    _loadItemLocations();
  }

  /// Extracts the numeric room number from a string (e.g., 'Room 1' -> 1, 'Room 04' -> 4, 'RM0002' -> 2).
  /// If no digit sequence is found, returns 999900 so it's placed after numbered rooms.
  static int _extractRoomNumber(String? roomStr) {
    if (roomStr == null || roomStr.trim().isEmpty) return 999999;
    final match = RegExp(r'\d+').firstMatch(roomStr);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 999999;
    }
    return 999900;
  }

  static int _getRackStock(Map<String, dynamic> r) {
    final v = r['stockAvailableQuantity'] ?? r['stockAvailable'] ?? 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadItemLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<_ItemPickStep> loadedSteps = [];

      for (final line in widget.issue.lines) {
        List<Map<String, dynamic>> rawRacks = [];
        try {
          final fetched = await ref
              .read(storeRackControllerProvider)
              .getRacksByItem(line.itemId);
          rawRacks = fetched
              .where((e) => e != null)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (_) {
          rawRacks = [];
        }

        if (rawRacks.isEmpty) {
          loadedSteps.add(
            _ItemPickStep(
              line: line,
              racks: const [],
              minRoomNumber: 999999,
              primaryRoomName: 'Unassigned Location',
              primaryRackDisplay: 'No Rack Assigned',
              totalAvailableStock: 0,
              isLocationAssigned: false,
              allRooms: const [],
            ),
          );
          continue;
        }

        // Prioritize racks with available stock > 0 for optimal picking
        final racksWithStock = rawRacks.where((r) => _getRackStock(r) > 0).toList();
        final candidateRacks =
            racksWithStock.isNotEmpty ? racksWithStock : rawRacks;

        int minRoomNum = 999999;
        String bestRoomName = 'Unassigned';
        String bestRackDisplay = '';
        final Set<String> distinctRooms = {};

        for (final r in candidateRacks) {
          final rawRoom = (r['roomName'] ?? '').toString().trim();
          final rawCode = (r['code'] ?? r['rackName'] ?? '').toString().trim();
          final num = _extractRoomNumber(rawRoom);

          if (rawRoom.isNotEmpty) {
            distinctRooms.add(rawRoom);
          }

          if (num < minRoomNum) {
            minRoomNum = num;
            bestRoomName = rawRoom.isNotEmpty ? rawRoom : 'Room (Not Named)';
            bestRackDisplay = rawCode.isNotEmpty ? rawCode : 'Rack —';
          }
        }

        // Calculate total available stock across all racks
        int totalStock = 0;
        for (final r in rawRacks) {
          totalStock += _getRackStock(r);
        }

        loadedSteps.add(
          _ItemPickStep(
            line: line,
            racks: rawRacks,
            minRoomNumber: minRoomNum,
            primaryRoomName: bestRoomName,
            primaryRackDisplay: bestRackDisplay,
            totalAvailableStock: totalStock,
            isLocationAssigned: true,
            allRooms: distinctRooms.toList(),
          ),
        );
      }

      // Sort items in ascending order of room numbers (nearest room first)!
      // e.g. Room 1 before Room 4, Room 4 before Room 10.
      loadedSteps.sort((a, b) {
        if (a.minRoomNumber != b.minRoomNumber) {
          return a.minRoomNumber.compareTo(b.minRoomNumber);
        }
        final roomCmp = a.primaryRoomName
            .toLowerCase()
            .compareTo(b.primaryRoomName.toLowerCase());
        if (roomCmp != 0) return roomCmp;
        return a.line.itemName
            .toLowerCase()
            .compareTo(b.line.itemName.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _pickSteps = loadedSteps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load item locations: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleExpand(String itemId) {
    setState(() {
      if (_expandedItemIds.contains(itemId)) {
        _expandedItemIds.remove(itemId);
      } else {
        _expandedItemIds.add(itemId);
      }
    });
  }

  void _toggleExpandAll() {
    setState(() {
      if (_expandedItemIds.length == _pickSteps.length) {
        _expandedItemIds.clear();
      } else {
        _expandedItemIds.addAll(_pickSteps.map((s) => s.line.itemId));
      }
    });
  }

  void _togglePicked(String itemId) {
    setState(() {
      if (_pickedItemIds.contains(itemId)) {
        _pickedItemIds.remove(itemId);
      } else {
        _pickedItemIds.add(itemId);
      }
    });
  }

  void _openFullFinder(IssueLine line) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FindItemPage(
          isStandalone: true,
          initialItemId: line.itemId,
          initialItemName: line.itemName,
          initialQuantity: line.requestedQty > 0 ? line.requestedQty : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final allExpanded =
        _pickSteps.isNotEmpty && _expandedItemIds.length == _pickSteps.length;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find Items • ${issue.issNo}',
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const Text(
              'Room-Wise Sequence (Nearest First)',
              style: TextStyle(
                color: _ink600,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isLoading && _pickSteps.isNotEmpty)
            TextButton.icon(
              onPressed: _toggleExpandAll,
              icon: Icon(
                allExpanded
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                size: 16,
                color: _ink700,
              ),
              label: Text(
                allExpanded ? 'Collapse All' : 'Expand All',
                style: const TextStyle(
                  color: _ink700,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
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
              constraints: const BoxConstraints(maxWidth: 860),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Optimizing picking route by room order...',
              style: TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sorting items: Room 1 ➔ Room 2 ➔ Room 3...',
              style: TextStyle(
                color: _ink600,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadItemLocations,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: _ink900,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pickSteps.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No items to locate for this issue.',
            style: TextStyle(
              color: _ink700,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 12),
        _buildRouteSequenceHeader(),
        const SizedBox(height: 10),
        for (int i = 0; i < _pickSteps.length; i++) ...[
          _buildItemStepCard(index: i, step: _pickSteps[i]),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  /* ---------------- Header Summary Card ---------------- */
  Widget _buildHeaderCard() {
    final issue = widget.issue;
    final totalUnits = issue.lines.fold<int>(
      0,
      (sum, l) => sum + (l.requestedQty > 0 ? l.requestedQty : 0),
    );
    final pickedCount = _pickedItemIds.length;
    final totalCount = _pickSteps.length;

    // Collect unique room names in route order
    final List<String> roomRoute = [];
    for (final s in _pickSteps) {
      if (s.isLocationAssigned && !roomRoute.contains(s.primaryRoomName)) {
        roomRoute.add(s.primaryRoomName);
      }
    }

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: _ink900,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          issue.issNo,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: Text(
                            issue.status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Created by: ${issue.createdBy.isNotEmpty ? issue.createdBy : 'Store Requester'}',
                      style: const TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    if (issue.reason.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reason: ${issue.reason}',
                        style: const TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _ink900.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalCount ${totalCount == 1 ? 'Item' : 'Items'} • $totalUnits Units',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  if (pickedCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$pickedCount / $totalCount Picked',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (roomRoute.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: _stroke),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  size: 15,
                  color: Color(0xFFE65100),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Walk Path: ',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < roomRoute.length; i++) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFFCC80),
                              ),
                            ),
                            child: Text(
                              roomRoute[i],
                              style: const TextStyle(
                                color: Color(0xFFBF360C),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (i < roomRoute.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: _ink600,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /* ---------------- Route Sequence Bar ---------------- */
  Widget _buildRouteSequenceHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: const Row(
        children: [
          Icon(Icons.sort_rounded, size: 16, color: _ink700),
          SizedBox(width: 6),
          Text(
            'PICKING SEQUENCE (ASCENDING BY ROOM)',
            style: TextStyle(
              color: _ink700,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              letterSpacing: 0.5,
            ),
          ),
          Spacer(),
          Text(
            'Tap item to view location',
            style: TextStyle(
              color: _ink600,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- Item Pick Step Card ---------------- */
  Widget _buildItemStepCard({
    required int index,
    required _ItemPickStep step,
  }) {
    final line = step.line;
    final isExpanded = _expandedItemIds.contains(line.itemId);
    final isPicked = _pickedItemIds.contains(line.itemId);

    // Color theme based on room sequence
    final roomNumber = step.minRoomNumber;
    final isUnassigned = !step.isLocationAssigned || roomNumber >= 999990;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isPicked
            ? const Color(0xFFF1F8E9)
            : (isExpanded ? _surface : _surface.withValues(alpha: 0.95)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPicked
              ? const Color(0xFFA5D6A7)
              : (isExpanded ? _ink900 : _stroke),
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: isExpanded ? _shadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main clickable row
          InkWell(
            onTap: () => _toggleExpand(line.itemId),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Pick checkbox
                  IconButton(
                    onPressed: () => _togglePicked(line.itemId),
                    tooltip: isPicked ? 'Mark unpicked' : 'Mark picked',
                    icon: Icon(
                      isPicked
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isPicked ? const Color(0xFF2E7D32) : _ink600,
                      size: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 6),

                  // Route Sequence Pill (#1, #2, etc.)
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isPicked
                          ? const Color(0xFFC8E6C9)
                          : _ink900.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isPicked ? const Color(0xFF1B5E20) : _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Item Name & Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                line.itemName.isNotEmpty
                                    ? line.itemName
                                    : line.itemId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  decoration: isPicked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Room badge (e.g. Room 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isUnassigned
                                    ? const Color(0xFFFFEBEE)
                                    : const Color(0xFFEDE7F6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isUnassigned
                                      ? const Color(0xFFFFCDD2)
                                      : const Color(0xFFD1C4E9),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isUnassigned
                                        ? Icons.location_off_rounded
                                        : Icons.room_rounded,
                                    size: 11,
                                    color: isUnassigned
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFF5E35B1),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    step.primaryRoomName,
                                    style: TextStyle(
                                      color: isUnassigned
                                          ? const Color(0xFFC62828)
                                          : const Color(0xFF5E35B1),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Requested Quantity
                            Text(
                              'Pick: ${line.requestedQty} ${line.unit.isNotEmpty ? line.unit : 'unit(s)'}',
                              style: const TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Expand/Collapse Chevron Indicator
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _ink700,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Location Details (Visible when item is clicked)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildExpandedLocationDetails(step),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /* ---------------- Location Details Box ---------------- */
  Widget _buildExpandedLocationDetails(_ItemPickStep step) {
    final line = step.line;
    final racks = step.racks;

    return Container(
      decoration: const BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: _stroke)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_searching_rounded,
                size: 16,
                color: _ink900,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Location & Stock Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => _openFullFinder(line),
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: _ink900),
                label: const Text('Open Rack Finder'),
                style: TextButton.styleFrom(
                  foregroundColor: _ink900,
                  iconColor: _ink900,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (racks.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFC62828), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No rack location assigned yet for this item.',
                      style: TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            for (final r in racks) ...[
              _buildSingleRackCard(r, requiredQty: line.requestedQty),
              const SizedBox(height: 6),
            ],
          ],

          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Available across store: ${step.totalAvailableStock}',
                style: TextStyle(
                  color: step.totalAvailableStock >= line.requestedQty
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
              if (line.approvedQty > 0)
                Text(
                  'Approved: ${line.approvedQty}',
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleRackCard(
    Map<String, dynamic> rack, {
    required int requiredQty,
  }) {
    final room = (rack['roomName'] ?? '').toString().trim();
    final rackCode = (rack['code'] ?? '').toString().trim();
    final rackName = (rack['rackName'] ?? '').toString().trim();
    final availQty = _getRackStock(rack);
    final isScrap = rack['isScrap'] == true;

    final rackDisplay = rackName.isNotEmpty
        ? (rackCode.isNotEmpty && rackCode != rackName
            ? '$rackName ($rackCode)'
            : rackName)
        : (rackCode.isNotEmpty ? rackCode : 'Rack —');

    final canFulfill = availQty >= requiredQty && requiredQty > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canFulfill ? const Color(0xFFA5D6A7) : _stroke,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: canFulfill
                  ? const Color(0xFFE8F5E9)
                  : _ink900.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: canFulfill ? const Color(0xFF2E7D32) : _ink900,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      room.isNotEmpty ? room : 'Room —',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if (isScrap) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SCRAP',
                          style: TextStyle(
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Rack: $rackDisplay',
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: availQty > 0
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Avail: $availQty',
                  style: TextStyle(
                    color: availQty > 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              if (canFulfill) ...[
                const SizedBox(height: 2),
                const Text(
                  '✓ Can Fulfill',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
