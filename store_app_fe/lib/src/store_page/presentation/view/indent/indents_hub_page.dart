import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../controllers/stock_refill_request_controller.dart';
import '../../../controllers/indent_draft_controller.dart';
import '../new_store_home_page.dart';
import 'store_indent_consolidation_page.dart';
import 'indent_drafts_page.dart';
import '../receive/stock_refill_requests_list_view.dart';

/* ---------------- Palette ---------------- */
const _ink900 = Color(0xFF282321);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

class _IndentTabSpec {
  final int key;
  final String label;
  final String shortLabel;
  final IconData icon;
  final int badgeCount;
  final Widget Function() builder;

  const _IndentTabSpec({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.badgeCount,
    required this.builder,
  });
}

class IndentsHubPage extends ConsumerStatefulWidget {
  const IndentsHubPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<IndentsHubPage> createState() => _IndentsHubPageState();
}

class _IndentsHubPageState extends ConsumerState<IndentsHubPage> {
  int? _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(pendingStoreConsolidationCountProvider);
        ref.read(indentDraftControllerProvider.notifier).fetchDrafts();
        ref.invalidate(pendingRefillRequestsCountProvider);
      }
    });
  }

  void _onTabSelected(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);

    // Refresh active section data when switched
    if (index == 0) {
      ref.invalidate(pendingStoreConsolidationProvider);
      ref.invalidate(pendingStoreConsolidationCountProvider);
    } else if (index == 1) {
      ref.read(indentDraftControllerProvider.notifier).fetchDrafts();
    } else if (index == 2) {
      ref.invalidate(refillRequestsListProvider);
      ref.invalidate(pendingRefillRequestsCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final canConsolidation = user?.canIndentConsolidation ?? false;
    final canDraft = user?.canIndentDraft ?? false;
    final canHistory = user?.canIndentHistory ?? false;

    final pendingConsolidationCount =
        ref.watch(pendingStoreConsolidationCountProvider).value ?? 0;
    final draftCount =
        ref.watch(indentDraftControllerProvider).items.length;
    final pendingRefillCount =
        ref.watch(pendingRefillRequestsCountProvider).value ?? 0;

    final availableTabs = <_IndentTabSpec>[];

    if (canConsolidation) {
      availableTabs.add(
        _IndentTabSpec(
          key: 0,
          label: 'Store Consolidation',
          shortLabel: 'Consolidation',
          icon: Icons.hub_outlined,
          badgeCount: pendingConsolidationCount,
          builder: () => const StoreIndentConsolidationPage(
            key: ValueKey('store_indent_consolidation'),
            isEmbedded: true,
          ),
        ),
      );
    }

    if (canDraft) {
      availableTabs.add(
        _IndentTabSpec(
          key: 1,
          label: 'Indent Cart',
          shortLabel: 'Cart',
          icon: Icons.post_add_rounded,
          badgeCount: draftCount,
          builder: () => const IndentDraftsPage(
            key: ValueKey('indent_drafts_page'),
            isEmbedded: true,
          ),
        ),
      );
    }

    if (canHistory) {
      availableTabs.add(
        _IndentTabSpec(
          key: 2,
          label: 'Submitted Indents',
          shortLabel: 'Submitted',
          icon: Icons.assignment_outlined,
          badgeCount: pendingRefillCount,
          builder: () => const StockRefillRequestsListView(
            key: ValueKey('submitted_indents_list'),
            isSubmittedIndentsSection: true,
            initialStatusFilter: 'ALL',
          ),
        ),
      );
    }

    if (availableTabs.isEmpty) {
      return Container(
        color: _surface,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: _surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 36, color: _ink900),
            ),
            const SizedBox(height: 16),
            const Text(
              'Indent Section Access Restricted',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You do not have permission to access Consolidation, Drafts, or History.\nContact Super Admin to assign Indent roles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _ink600),
            ),
          ],
        ),
      );
    }

    // Ensure selected tab is valid among available tabs
    final activeSpec = availableTabs.firstWhere(
      (t) => t.key == _selectedTab,
      orElse: () => availableTabs.first,
    );
    final activeKey = activeSpec.key;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              // Top Segmented Pill Bar (Mobile Optimized with zero pixel overflow)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _surfaceAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stroke),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 520;
                    return Row(
                      children: [
                        for (int i = 0; i < availableTabs.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          _buildTabButton(
                            index: availableTabs[i].key,
                            icon: availableTabs[i].icon,
                            label: isNarrow
                                ? availableTabs[i].shortLabel
                                : availableTabs[i].label,
                            badgeCount: availableTabs[i].badgeCount,
                            isNarrow: isNarrow,
                            isSelected: activeKey == availableTabs[i].key,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

              // Embedded Content (Lazy-loaded, fast, memory-optimized, zero unmount conflicts)
              Expanded(
                child: activeSpec.builder(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required int badgeCount,
    required bool isNarrow,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.symmetric(
            vertical: isNarrow ? 7 : 8,
            horizontal: isNarrow ? 3 : 6,
          ),
          decoration: BoxDecoration(
            color: isSelected ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isNarrow ? 14 : 16,
                color: isSelected ? _ink900 : _ink600,
              ),
              SizedBox(width: isNarrow ? 3 : 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? _ink900 : _ink600,
                    fontWeight: FontWeight.w800,
                    fontSize: isNarrow ? 11.5 : 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount > 0) ...[
                SizedBox(width: isNarrow ? 3 : 5),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 4 : 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: _ink900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      color: _surface,
                      fontSize: isNarrow ? 9 : 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
