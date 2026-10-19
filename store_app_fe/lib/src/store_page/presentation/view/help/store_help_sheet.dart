import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/domains/models/auth_model.dart';
import '../../../controllers/guided_tour_controller.dart';
import '../walkthrough_sandbox/issue_request_simulator_screen.dart';
import '../walkthrough_sandbox/issue_approval_simulator_screen.dart';
import '../walkthrough_sandbox/grn_inward_simulator_screen.dart';
import '../walkthrough_sandbox/item_dispatch_simulator_screen.dart';
import '../walkthrough_sandbox/item_creation_simulator_screen.dart';
import '../walkthrough_sandbox/item_card_simulator_screen.dart';
import '../walkthrough_sandbox/rack_management_simulator_screen.dart';
import '../walkthrough_sandbox/item_locator_simulator_screen.dart';

/* ---------------- Palette & Design Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _ink500 = Color(0xFF9E8F8C);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFAF8F0);
const _stroke = Color(0xFFDFE1D6);

/// Helper function to open the Store Help Bottom Sheet.
void showStoreHelpSheet(
  BuildContext context, {
  ValueChanged<List<GuidedTourStep>>? onStartTour,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StoreHelpSheet(onStartTour: onStartTour),
  );
}

/// Dedicated Help Button placed in the Store header for every account.
class StoreHelpButton extends ConsumerWidget {
  final ValueChanged<List<GuidedTourStep>>? onStartTour;
  const StoreHelpButton({super.key, this.onStartTour});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: GuidedTourController.storeHelpButtonKey,
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: _surfaceAlt,
          onTap: () async {
            final user = ref.read(userFindOneDataStreamProvider).value;
            if (user != null) {
              final controller = ref.read(guidedTourControllerProvider);
              await controller.markMandatoryHelpCompleted(
                user.uid,
                dontShowAgain: controller.isMandatoryHelpDontShowAgain,
              );
            }
            if (context.mounted) {
              showStoreHelpSheet(context, onStartTour: onStartTour);
            }
          },
          child: const Tooltip(
            message: 'Help & Walkthrough Guides',
            child: Center(
              child: Icon(
                Icons.help_outline_rounded,
                color: _ink900,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Operational Lifecycle categories for walkthrough discovery.
enum _TourCategory {
  all,
  catalog,
  inward,
  outward,
}

/// Data model representing a single interactive walkthrough tour.
class _TourDef {
  final String code;
  final String title;
  final String operationalStage;
  final String summary;
  final String description;
  final int stepCount;
  final IconData icon;
  final _TourCategory category;
  final bool Function(AuthModel? user) isAvailable;
  final List<GuidedTourStep> Function() buildSteps;
  final WidgetBuilder? simulatorBuilder;

  const _TourDef({
    required this.code,
    required this.title,
    required this.operationalStage,
    required this.summary,
    required this.description,
    required this.stepCount,
    required this.icon,
    required this.category,
    required this.isAvailable,
    required this.buildSteps,
    this.simulatorBuilder,
  });
}

/// Master list of all 8 guided tours defined in the Walkthrough Specification.
final List<_TourDef> _kAllTours = [
  _TourDef(
    code: 'F1',
    title: 'Creating & Editing Items',
    operationalStage: 'Catalog Setup',
    summary: 'Master catalog setup, SKU units & editing (Sandbox)',
    description:
        'Guided tour covering master item creation (+ Add Item), part specifications, category filtering, shelf assignments, and editing.',
    stepCount: 5,
    icon: Icons.inventory_2_rounded,
    category: _TourCategory.catalog,
    simulatorBuilder: (_) => const ItemCreationSimulatorScreen(),
    isAvailable: (u) =>
        u?.isSuperAdmin == true ||
        (u?.appWorks.any((w) =>
                w.startsWith('storreceive') ||
                w.contains('storeitemadd') ||
                w.contains('storeadmin')) ??
            false),
    buildSteps: GuidedTourController.buildF1CreateAndEditItemSteps,
  ),
  _TourDef(
    code: 'F2',
    title: 'Understanding Item Cards & Stock',
    operationalStage: 'Master Data Discovery',
    summary: 'Real-time stock counts, rack tags & menu (Sandbox)',
    description:
        'Learn how to read Total, Issued, and Available stock pills, verify physical room/rack tags, and access item action menus.',
    stepCount: 4,
    icon: Icons.dashboard_customize_rounded,
    category: _TourCategory.catalog,
    isAvailable: (_) => true,
    buildSteps: GuidedTourController.buildF2ItemCardSteps,
    simulatorBuilder: (_) => const ItemCardSimulatorScreen(),
  ),
  _TourDef(
    code: 'F3',
    title: 'Managing Racks & Places',
    operationalStage: 'Facility Architecture',
    summary: 'Warehouse zones, shelf capacity & placards (Sandbox)',
    description:
        'Explore storage zones, configure warehouse rooms and racks, audit shelf occupancy, and print large-format QR rack placards.',
    stepCount: 4,
    icon: Icons.warehouse_rounded,
    category: _TourCategory.catalog,
    isAvailable: (u) =>
        u?.isSuperAdmin == true ||
        (u?.appWorks.any((w) =>
                w.contains('storeplaceadd') ||
                w.contains('storeplaceedit') ||
                w.startsWith('storreceive') ||
                w.contains('storeadmin')) ??
            false),
    buildSteps: GuidedTourController.buildF3RacksAndPlacesSteps,
    simulatorBuilder: (_) => const RackManagementSimulatorScreen(),
  ),
  _TourDef(
    code: 'F4',
    title: 'Receiving Items & Inwarding (GRN)',
    operationalStage: 'Inward Logistics',
    summary: 'GRN logs, challan entry & barcode printing (Sandbox)',
    description:
        'Walk through logging inward supplier consignments, recording challan and PO details, assigning destination racks, and printing QR stickers.',
    stepCount: 4,
    icon: Icons.move_to_inbox_rounded,
    category: _TourCategory.inward,
    simulatorBuilder: (_) => const GrnInwardSimulatorScreen(),
    isAvailable: (u) =>
        u?.isSuperAdmin == true ||
        (u?.appWorks.any((w) =>
                w.startsWith('storreceive') || w.contains('storeadmin')) ??
            false),
    buildSteps: GuidedTourController.buildF4ReceivingAndInwardSteps,
  ),
  _TourDef(
    code: 'F5',
    title: 'Finding Items & Shelf Locators',
    operationalStage: 'Inventory Navigation',
    summary: 'Instant search, rack coordinates & balance (Sandbox)',
    description:
        'Interactive Training Sandbox: Quickly locate any tool or spare part in the plant with exact Building, Room, and Shelf coordinates before walking to the warehouse.',
    stepCount: 4,
    icon: Icons.saved_search_rounded,
    category: _TourCategory.inward,
    simulatorBuilder: (_) => const ItemLocatorSimulatorScreen(),
    isAvailable: (_) => true,
    buildSteps: GuidedTourController.buildF5FindItemsSteps,
  ),
  _TourDef(
    code: 'F6',
    title: 'Item Issuing Request (Add to Cart & Submit)',
    operationalStage: 'Outward Requisition',
    summary: 'Add to cart, review requisition & submit (Sandbox)',
    description:
        'Interactive Training Sandbox: Practice selecting catalog materials, adding them to the Requisition Cart, reviewing draft lines, and submitting for approval with safe demo data.',
    stepCount: 4,
    icon: Icons.shopping_cart_checkout_rounded,
    category: _TourCategory.outward,
    isAvailable: (u) =>
        u?.isSuperAdmin == true ||
        (u?.appWorks.contains('storissueadd') ?? false),
    buildSteps: GuidedTourController.buildF6IndentRequestSteps,
    simulatorBuilder: (_) => const IssueRequestSimulatorScreen(),
  ),
  _TourDef(
    code: 'F7',
    title: 'Accepting Indents & GRN Approval',
    operationalStage: 'Inward & Indent Governance',
    summary: 'Submitted indents, GRN cart, rates & approval (Sandbox)',
    description:
        'Interactive Training Sandbox: Practice opening Submitted Indents, queuing requisitions into the GRN Cart, verifying received quantities and unit rates, and authorizing managerial GRN approval.',
    stepCount: 7,
    icon: Icons.fact_check_rounded,
    category: _TourCategory.outward,
    isAvailable: (u) =>
        u?.isSuperAdmin == true ||
        (u?.appWorks.contains('storissueapprove') ?? false),
    buildSteps: GuidedTourController.buildF7ApprovalGovernanceSteps,
    simulatorBuilder: (_) => const IssueApprovalSimulatorScreen(),
  ),
  _TourDef(
    code: 'F8',
    title: 'Physical Item Issuance from Racks',
    operationalStage: 'Outward Dispatch',
    summary: 'Pick tickets, verify QR & deduct stock (Sandbox)',
    description:
        'Retrieve approved tickets, locate pick shelf coordinates, scan barcodes to verify 100% pick accuracy, and record physical outward dispatch.',
    stepCount: 4,
    icon: Icons.local_shipping_rounded,
    category: _TourCategory.outward,
    simulatorBuilder: (_) => const ItemDispatchSimulatorScreen(),
    isAvailable: (u) =>
        u?.isSuperAdmin == true ||
        (u?.appWorks.contains('storissuefromstock') ?? false),
    buildSteps: GuidedTourController.buildF8PhysicalIssuanceSteps,
  ),
];

/// Clean, cohesive Help & Support modal sheet matching the app design system.
class StoreHelpSheet extends ConsumerStatefulWidget {
  final ValueChanged<List<GuidedTourStep>>? onStartTour;
  const StoreHelpSheet({super.key, this.onStartTour});

  @override
  ConsumerState<StoreHelpSheet> createState() => _StoreHelpSheetState();
}

class _StoreHelpSheetState extends ConsumerState<StoreHelpSheet> {
  _TourCategory _selectedCategory = _TourCategory.all;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getUserRoleLabel(AuthModel? user) {
    if (user == null) return 'Store User';
    if (user.isSuperAdmin) return 'Super Admin';

    final works = user.appWorks;
    final isReceiver = works.any((w) => w.startsWith('storreceive'));
    final isIssuer = works.contains('storissuefromstock');
    final isRequester = works.contains('storissueadd');
    final isApprover = works.contains('storissueapprove') ||
        works.any((w) => w.contains('approval') || w.contains('approve'));
    final isReturner = works.contains('storissuereturn');

    if (isReceiver && !isApprover && !isIssuer && !isRequester) {
      return 'Store Receiver';
    }
    if (isApprover) return 'Issue Approver';
    if (isIssuer) return 'Store Issuer / Dispatcher';
    if (isRequester) return 'Issue Requester';
    if (isReturner) return 'Store Returner';
    return 'Store Operations';
  }

  @override
  Widget build(BuildContext context) {
    final userAv = ref.watch(userFindOneDataStreamProvider);
    final user = userAv.value;
    final roleLabel = _getUserRoleLabel(user);

    // Filter tours by role availability
    final availableTours = _kAllTours.where((t) => t.isAvailable(user)).toList();

    // Filter by selected tab category
    final categoryFiltered = _selectedCategory == _TourCategory.all
        ? availableTours
        : availableTours.where((t) => t.category == _selectedCategory).toList();

    // Filter by search query
    final displayTours = _searchQuery.trim().isEmpty
        ? categoryFiltered
        : categoryFiltered.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                t.code.toLowerCase().contains(q) ||
                t.operationalStage.toLowerCase().contains(q) ||
                t.summary.toLowerCase().contains(q) ||
                t.description.toLowerCase().contains(q);
          }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle & Close Row
              _buildTopBar(context),

              // Scrollable Main Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  children: [
                    // Clean User Profile & Role Card
                    _buildUserCard(user, roleLabel, availableTours.length),

                    const SizedBox(height: 16),

                    // Section Title & Search Bar
                    _buildSectionHeader(),

                    const SizedBox(height: 12),

                    // Quick Category Filter Chips
                    _buildFilterChips(availableTours),

                    const SizedBox(height: 16),

                    // Walkthrough Tour Cards List
                    if (displayTours.isEmpty)
                      _buildEmptySearchState()
                    else
                      ...displayTours.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WalkthroughCard(
                            index: entry.key + 1,
                            tour: entry.value,
                            onStart: () {
                              Navigator.pop(context);
                              if (entry.value.simulatorBuilder != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: entry.value.simulatorBuilder!,
                                  ),
                                );
                              } else {
                                widget.onStartTour?.call(entry.value.buildSteps());
                              }
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Footer Tip
                    _buildFooterTip(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 14, 12),
      child: Column(
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _stroke,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // App themed header icon badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: _ink900,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Help & Support Center',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Interactive Guided Walkthroughs & Operational Manuals',
                      style: TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Reset Walkthrough & Onboarding',
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: _surfaceAlt,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: _stroke),
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, color: _ink700, size: 18),
                  onPressed: () async {
                    final user = ref.read(userFindOneDataStreamProvider).value;
                    if (user != null) {
                      await ref.read(guidedTourControllerProvider).resetTour(uid: user.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Walkthrough & onboarding status reset for this account.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _surfaceAlt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: _stroke),
                  ),
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.close_rounded, color: _ink700, size: 20),
                tooltip: 'Close Help',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _stroke),
        ],
      ),
    );
  }

  Widget _buildUserCard(AuthModel? user, String roleLabel, int tourCount) {
    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Store User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _ink900,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _stroke),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user?.isSuperAdmin == true
                                ? Icons.verified_user_rounded
                                : Icons.badge_outlined,
                            size: 11,
                            color: _ink700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            roleLabel,
                            style: const TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  user?.isSuperAdmin == true
                      ? 'Master Walkthrough Hub • All $tourCount guided tours available'
                      : 'Curated guidance active for $roleLabel operations',
                  style: const TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 430;

        final titleRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.explore_outlined, size: 18, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Interactive Walkthroughs',
              style: TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        );

        final searchField = SizedBox(
          height: 34,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 12, color: _ink900, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search tours...',
              hintStyle: const TextStyle(fontSize: 11.5, color: _ink500),
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: _ink600),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14, color: _ink600),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _surfaceAlt,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _ink900, width: 1.2),
              ),
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleRow,
              const SizedBox(height: 8),
              searchField,
            ],
          );
        }

        return Row(
          children: [
            titleRow,
            const Spacer(),
            SizedBox(
              width: 200,
              child: searchField,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChips(List<_TourDef> availableTours) {
    final countCatalog = availableTours.where((t) => t.category == _TourCategory.catalog).length;
    final countInward = availableTours.where((t) => t.category == _TourCategory.inward).length;
    final countOutward = availableTours.where((t) => t.category == _TourCategory.outward).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('All (${availableTours.length})', _TourCategory.all),
          const SizedBox(width: 6),
          _buildChip('Catalog & Places ($countCatalog)', _TourCategory.catalog),
          const SizedBox(width: 6),
          _buildChip('Inward GRN ($countInward)', _TourCategory.inward),
          const SizedBox(width: 6),
          _buildChip('Outward Issue ($countOutward)', _TourCategory.outward),
        ],
      ),
    );
  }

  Widget _buildChip(String label, _TourCategory category) {
    final isSelected = _selectedCategory == category;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedCategory = category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? _ink900 : _surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _ink900 : _stroke,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : _ink700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: _stroke),
            ),
            child: const Icon(Icons.search_off_rounded, size: 28, color: _ink500),
          ),
          const SizedBox(height: 12),
          Text(
            'No walkthrough matches "$_searchQuery"',
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try searching by part, stage, or select "All" category filter.',
            style: TextStyle(color: _ink600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterTip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _ink700, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tours guide you with interactive on-screen spotlights and arrows. You can tap highlighted items directly or press Skip anytime.',
              style: TextStyle(
                color: _ink700,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A clean, refined walkthrough card matching the app aesthetic.
class _WalkthroughCard extends StatefulWidget {
  final _TourDef tour;
  final VoidCallback onStart;
  final int index;

  const _WalkthroughCard({
    required this.tour,
    required this.onStart,
    required this.index,
  });

  @override
  State<_WalkthroughCard> createState() => _WalkthroughCardState();
}

class _WalkthroughCardState extends State<_WalkthroughCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tour;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered ? _ink700 : _stroke,
            width: _isHovered ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x06000000),
              blurRadius: _isHovered ? 8 : 4,
              offset: Offset(0, _isHovered ? 3 : 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onStart,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Row: Icon Badge + Code + Stage + Step Count
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clean App Themed Icon Badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _stroke),
                        ),
                        child: Icon(
                          t.icon,
                          color: _ink900,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stage Tag and Code
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _surfaceAlt,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _stroke),
                                  ),
                                  child: Text(
                                    '${widget.index}',
                                    style: const TextStyle(
                                      color: _ink900,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    t.operationalStage.toUpperCase(),
                                    style: const TextStyle(
                                      color: _ink600,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      letterSpacing: 0.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Step count badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _surfaceAlt,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _stroke),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.route_rounded,
                                        size: 11,
                                        color: _ink600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${t.stepCount} Steps',
                                        style: const TextStyle(
                                          color: _ink700,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Title
                            Text(
                              t.title,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Concise Summary / Description
                  Text(
                    t.description,
                    style: const TextStyle(
                      color: _ink700,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Action Row: Highlights & Start Button
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isTight = constraints.maxWidth < 320;
                      final summaryRow = Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 13,
                            color: _ink600,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              t.summary,
                              style: const TextStyle(
                                color: _ink600,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );

                      final startBtn = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _isHovered ? _ink700 : _ink900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              t.simulatorBuilder != null
                                  ? Icons.school_rounded
                                  : Icons.play_arrow_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t.simulatorBuilder != null
                                  ? 'Start Sandbox'
                                  : 'Start Tour',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (isTight) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summaryRow,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: startBtn,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: summaryRow),
                          const SizedBox(width: 8),
                          startBtn,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
