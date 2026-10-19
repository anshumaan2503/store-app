import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:store_app/src/store_page/controllers/guided_tour_controller.dart';
import 'store_walkthrough_simulator_shell.dart';

/* ---------------- Palette & Design Tokens (Matching Real App) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _ink500 = Color(0xFF9E8F8C);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

const _accentAmber = Color(0xFFF59E0B);
const _accentAmberBorder = Color(0xFFD97706);

/// Interactive Training Sandbox for Feature F8:
/// Physical Item Issuance from Racks (Outward Dispatch).
///
/// Replicates the authentic layout of [IssuesListPage] with Section Tabs,
/// authorized ticket inspection, rack coordinates, simulated QR barcode verification,
/// and outward handover sign-off without modifying live MongoDB records.
class ItemDispatchSimulatorScreen extends ConsumerStatefulWidget {
  const ItemDispatchSimulatorScreen({super.key});

  @override
  ConsumerState<ItemDispatchSimulatorScreen> createState() =>
      _ItemDispatchSimulatorScreenState();
}

class _ItemDispatchSimulatorScreenState
    extends ConsumerState<ItemDispatchSimulatorScreen>
    with SingleTickerProviderStateMixin {
  // Guided Walkthrough Steps:
  // 1 = Tap "Ready for Issue" Tab (Awaiting physical counter pickup)
  // 2 = Inspect Shelf Coordinates (Rack R-04, Shelf S-02)
  // 3 = Scan QR to Verify Physical Pick (Simulated QR Scanner)
  // 4 = Confirm Dispatch & Handover (Deduct stock from ledger)
  int _currentStep = 1;
  static const int _totalSteps = 4;

  // Active section tab:
  // 0 = Ready for Issue & Active (Target for Step 1)
  // 1 = Issue History
  // 2 = Submitted Indents
  int _selectedTab = 2; // Starts on another tab so user taps Ready for Issue

  // In-memory demo state
  bool _hasLocatedShelf = false;
  bool _isScannerOpen = false;
  bool _isQrVerified = false;
  bool _isSubmitting = false;
  bool _isDispatched = false;

  final TextEditingController _searchCtrl = TextEditingController();

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.95, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetScenario() {
    setState(() {
      _currentStep = 1;
      _selectedTab = 2;
      _hasLocatedShelf = false;
      _isScannerOpen = false;
      _isQrVerified = false;
      _isSubmitting = false;
      _isDispatched = false;
      _searchCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sandbox reset to initial state.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  void _handleSelectTab(int index) {
    setState(() {
      _selectedTab = index;
      if (_currentStep == 1 && index == 0) {
        _currentStep = 2;
      }
    });
  }

  void _handleLocateShelfCoordinates() {
    setState(() {
      _hasLocatedShelf = true;
      if (_currentStep == 2) {
        _currentStep = 3;
      }
    });
  }

  void _handleOpenScanner() {
    setState(() {
      _isScannerOpen = true;
    });
  }

  void _handleCloseScanner() {
    setState(() {
      _isScannerOpen = false;
    });
  }

  void _handleSimulateScanSuccess() {
    setState(() {
      _isQrVerified = true;
      _isScannerOpen = false;
      if (_currentStep == 3) {
        _currentStep = 4;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ QR Code FLT-AF220 verified! Item matches pick ticket.'),
        backgroundColor: Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 2000),
      ),
    );
  }

  Future<void> _handleConfirmDispatch() async {
    setState(() {
      _isSubmitting = true;
    });

    // Simulate 600ms ledger write
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isDispatched = true;
    });

    // Show completion dialog with replay and navigate to live
    showSimulatorCompletionDialog(
      context: context,
      tourTitle: 'F8: Physical Item Issuance from Racks',
      description:
          'You successfully retrieved approved ticket REQ-2026-0881, verified physical bin coordinates (Rack R-04 / Shelf S-02), scanned and verified item QR code FLT-AF220 with the store QR scanner, and completed outward dispatch of 4 units without altering live inventory records.',
      onReplay: _resetScenario,
      onGoToLive: () {
        Navigator.pop(context); // Close simulator
        // Safely route to live Issues section
        ref.read(guidedTourControllerProvider).requestSection('issue');
      },
    );
  }

  String _getStepLabel() {
    switch (_currentStep) {
      case 1:
        return 'Tap "Ready for Issue" tab';
      case 2:
        return 'Locate shelf coordinates (Rack R-04)';
      case 3:
        return 'Scan item QR to verify accuracy';
      case 4:
        return 'Confirm dispatch & handover';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreWalkthroughSimulatorShell(
      title: 'Physical Item Issuance & Dispatch',
      currentStepLabel: _getStepLabel(),
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onExit: () => Navigator.pop(context),
      onReset: _resetScenario,
      child: Stack(
        children: [
          _buildRealStoreShellLayout(context),
          if (_isScannerOpen) _buildScannerOverlayView(),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW A: Full Real Store App Layout (Matching IssuesListPage)
     ========================================================================= */

  Widget _buildRealStoreShellLayout(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final bool showSidebar = (kIsWeb && w >= 980) || w >= 1100;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: showSidebar
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Outer Navigation Sidebar (Receive, Issue [Active], Return)
                  _buildOuterStoreNav(),
                  const SizedBox(width: 12),

                  // Inner Navigation Sidebar (Dashboard, Items, Find Item, Places)
                  _buildInnerStoreNav(),
                  const SizedBox(width: 12),

                  // Main Issues Content Area
                  Expanded(
                    child: _buildMainContentArea(context),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: _buildMainContentArea(context),
                  ),
                  _buildMobileBottomNav(),
                ],
              ),
      ),
    );
  }

  Widget _buildMainContentArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Real Header Card
        _buildRealStoreHeaderCard(),
        const SizedBox(height: 10),

        // 2. Scrollable Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step 1 Coachmark (if on Step 1)
                if (_currentStep == 1) ...[
                  _buildCoachmarkCard(
                    stepNumber: 1,
                    title: 'Step 1: Open Ready for Dispatch Queue',
                    message:
                        'Tap the highlighted "Ready for Issue" tab below to view approved requisitions waiting for storekeeper physical picking and counter handover.',
                  ),
                  const SizedBox(height: 10),
                ],

                // Step 2 Coachmark (if on Step 2)
                if (_currentStep == 2) ...[
                  _buildCoachmarkCard(
                    stepNumber: 2,
                    title: 'Step 2: Identify Pick Shelf Coordinates',
                    message:
                        'Inspect the material details below. The item is located in Main Store Room -> Rack R-04 (Shelf S-02). Tap the highlighted coordinates badge to proceed.',
                  ),
                  const SizedBox(height: 10),
                ],

                // Step 3 Coachmark (if on Step 3)
                if (_currentStep == 3) ...[
                  _buildCoachmarkCard(
                    stepNumber: 3,
                    title: 'Step 3: Scan QR to Verify Physical Pick',
                    message:
                        'Before handing goods to the technician, scan the box QR code to verify 100% picking accuracy. Tap the highlighted "Scan & Verify QR Code" button below.',
                  ),
                  const SizedBox(height: 10),
                ],

                // Step 4 Coachmark (if on Step 4)
                if (_currentStep == 4) ...[
                  _buildCoachmarkCard(
                    stepNumber: 4,
                    title: 'Step 4: Confirm Handover & Deduct Stock',
                    message:
                        'Item QR code FLT-AF220 verified! Tap the highlighted "Confirm Dispatch & Handover (4 PCS)" button to deduct units from the ledger and complete the issue.',
                  ),
                  const SizedBox(height: 10),
                ],

                // 3. Section Tab Bar (matching IssuesListPage line 150)
                _buildSectionTabBar(),
                const SizedBox(height: 10),

                // 4. Real Search & Filter Bar
                _buildSearchAndFilterBar(),
                const SizedBox(height: 12),

                // 5. Authentic Requisition Ticket Card or Empty Placeholder
                if (_selectedTab == 0 || _currentStep >= 2) ...[
                  _buildDispatchRequisitionCard(),
                ] else ...[
                  _buildSubmittedQueuePlaceholder(),
                ],
                const SizedBox(height: 14),

                // 6. Operational Guidelines Card
                _buildOperationalGuidelineCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /* ---------------- Real Header Card (from NewStoreHomePage) ---------------- */

  Widget _buildRealStoreHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Header Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accentPeach.withValues(alpha: .75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: const Icon(
              Icons.call_split_rounded,
              color: _ink900,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Issues',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Requisition Approvals & Physical Dispatch',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          // Real Trailing Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Help & Training Guide',
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: _ink900,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(Icons.more_vert, color: _ink900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ---------------- Dual Navigation Sidebars ---------------- */

  Widget _buildOuterStoreNav() {
    return Container(
      width: 170,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Store Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _accentMint.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: _ink900,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Store',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Outer Nav Items: Issue is SELECTED
          _buildOuterNavItem(Icons.inbox_rounded, 'Receive', false),
          const SizedBox(height: 8),
          _buildOuterNavItem(Icons.call_split_rounded, 'Issue', true),
          const SizedBox(height: 8),
          _buildOuterNavItem(Icons.reset_tv_rounded, 'Return', false),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildOuterNavItem(IconData icon, String label, bool selected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? _ink900 : _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? _ink900 : _stroke),
      ),
      child: Column(
        children: [
          Icon(icon, color: selected ? _surface : _ink700, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? _surface : _ink700,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerStoreNav() {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          _buildInnerIconItem(Icons.grid_view_rounded, 'Dashboard', false),
          const SizedBox(height: 10),
          _buildInnerIconItem(Icons.list_alt_rounded, 'Items', false),
          const SizedBox(height: 10),
          _buildInnerIconItem(Icons.location_searching_rounded, 'Find Item', false),
          const SizedBox(height: 10),
          _buildInnerIconItem(Icons.place_rounded, 'Places', false),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildInnerIconItem(IconData icon, String label, bool selected) {
    final bg = selected ? _ink900 : _surface;
    final fg = selected ? _surface : _ink700;
    final border = selected ? _ink900 : _stroke;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(top: BorderSide(color: _stroke)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavTab(Icons.grid_view_outlined, 'Dashboard', false),
          _buildMobileNavTab(Icons.list_alt_rounded, 'Items', false),
          _buildMobileNavTab(Icons.call_split_rounded, 'Issues', true),
          _buildMobileNavTab(Icons.place_rounded, 'Places', false),
        ],
      ),
    );
  }

  Widget _buildMobileNavTab(IconData icon, String label, bool selected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: selected ? _ink900 : _ink600, size: 22),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: selected ? _ink900 : _ink600,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /* ---------------- Section Tab Bar (matching IssuesListPage line 150) ---------------- */

  Widget _buildSectionTabBar() {
    final isStep1 = _currentStep == 1;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          // Tab 0: Ready for Issue & Active (TARGET FOR STEP 1)
          Expanded(
            child: _buildTabButton(
              key: isStep1 ? GuidedTourController.approvedRequestsTabKey : null,
              index: 0,
              title: 'Ready for Issue',
              subtitle: 'Awaiting counter (1)',
              icon: Icons.outbox_rounded,
              isSelected: _selectedTab == 0 || isStep1,
              activeColor: const Color(0xFF5E35B1),
              activeBgColor: const Color(0xFFEDE7F6),
              isHighlighted: isStep1,
            ),
          ),
          const SizedBox(width: 4),

          // Tab 1: Issue History
          Expanded(
            child: _buildTabButton(
              index: 1,
              title: 'Issue History',
              subtitle: 'Completed issues',
              icon: Icons.history_edu_rounded,
              isSelected: _selectedTab == 1 && !isStep1,
              activeColor: const Color(0xFF00796B),
              activeBgColor: const Color(0xFFE0F2F1),
              isHighlighted: false,
            ),
          ),
          const SizedBox(width: 4),

          // Tab 2: Submitted Indents
          Expanded(
            child: _buildTabButton(
              index: 2,
              title: 'Submitted Indents',
              subtitle: 'Approver review',
              icon: Icons.assignment_turned_in_rounded,
              isSelected: _selectedTab == 2 && !isStep1,
              activeColor: const Color(0xFFE65100),
              activeBgColor: const Color(0xFFFFF3E0),
              isHighlighted: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    Key? key,
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color activeBgColor,
    required bool isHighlighted,
  }) {
    final content = Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _handleSelectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isHighlighted
                ? _accentAmber
                : (isSelected ? _surface : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHighlighted
                  ? _accentAmberBorder
                  : (isSelected ? activeColor.withValues(alpha: 0.35) : Colors.transparent),
              width: isHighlighted ? 2.0 : 1.0,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: _accentAmber.withValues(alpha: 0.50),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ]
                : (isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : null),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isHighlighted
                    ? Colors.white
                    : (isSelected ? activeColor : _ink600),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isHighlighted
                            ? Colors.white
                            : (isSelected ? _ink900 : _ink700),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isHighlighted
                            ? Colors.white.withValues(alpha: 0.85)
                            : _ink500,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: content,
      );
    }
    return content;
  }

  /* ---------------- Real Search & Filter Bar ---------------- */

  Widget _buildSearchAndFilterBar() {
    return Card(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: _ink600),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search by ticket #, requester, or item...',
                  hintStyle: TextStyle(color: _ink500, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(color: _ink900, fontSize: 13),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _stroke),
              ),
              child: Row(
                children: const [
                  Icon(Icons.filter_list_rounded, size: 15, color: _ink900),
                  SizedBox(width: 6),
                  Text(
                    'All Departments',
                    style: TextStyle(
                      color: _ink900,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------- Authentic Requisition Ticket Card ---------------- */

  Widget _buildDispatchRequisitionCard() {
    final isStep2 = _currentStep == 2;
    final isStep3 = _currentStep == 3;
    final isStep4 = _currentStep == 4;

    return Card(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Avatar + Ticket ID + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _surfaceAlt.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: _ink900,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'REQ-2026-0881',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          _buildTicketStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'CNC Compressor Unit 3 - Air Leak Replacement',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Requested by Rahul Sharma (Mechanical Maintenance) · 2 hrs ago',
                        style: TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Milestone Audit Box
            _buildMilestoneAuditBox(),
            const SizedBox(height: 12),

            // Line Item Accordion / Shelf Picker
            _buildLineItemShelfBox(isStep2),
            const SizedBox(height: 14),

            // Action Buttons Row: Scan Verify (Step 3) & Confirm Dispatch (Step 4)
            _buildDispatchActionRow(isStep3, isStep4),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketStatusBadge() {
    if (_isDispatched) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD1C4E9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF5E35B1)),
            SizedBox(width: 4),
            Text(
              'DISPATCHED / CLOSED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5E35B1),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: const Text(
        'READY FOR ISSUE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _buildMilestoneAuditBox() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDispatched
                      ? 'Outward Dispatch Confirmed: 4 units handed over'
                      : 'Authorized by Management: 4 units rationed & approved',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  _isDispatched
                      ? 'Issued by Ashutosh Storekeeper · Just now · Ledger Updated'
                      : 'Awaiting storekeeper physical pick from Rack R-04',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- Step 2 Spotlight: Shelf Coordinates Box ---------------- */

  Widget _buildLineItemShelfBox(bool isStep2) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Requisition Items (1)',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Text(
                  '4 Units to Issue',
                  style: TextStyle(
                    color: Color(0xFF0284C7),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Item Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(
                  Icons.filter_alt_rounded,
                  color: _ink900,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Air Filter Element AF-220',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'SKU: FLT-AF220 · Category: Filtration Units',
                      style: TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Step 2 Spotlight Target: Pick Shelf Coordinates Pill
          _buildShelfCoordinatesPill(isStep2),
        ],
      ),
    );
  }

  Widget _buildShelfCoordinatesPill(bool isStep2) {
    final pill = InkWell(
      key: GuidedTourController.issueShelfCoordinatesKey,
      onTap: _handleLocateShelfCoordinates,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isStep2 ? _accentAmber : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isStep2 ? _accentAmberBorder : const Color(0xFF2E7D32),
            width: isStep2 ? 2.0 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.shelves,
              size: 18,
              color: isStep2 ? Colors.white : const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick Location: Main Store Room -> Rack R-04 (Shelf S-02)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isStep2 ? Colors.white : const Color(0xFF1B5E20),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _hasLocatedShelf
                        ? 'Physical bin confirmed · Stock available: 12 PCS'
                        : (isStep2
                            ? 'Tap to confirm physical shelf coordinates'
                            : 'Physical bin coordinates verified'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isStep2
                          ? Colors.white.withValues(alpha: 0.85)
                          : _ink600,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isStep2 ? Colors.white : _ink600,
            ),
          ],
        ),
      ),
    );

    if (isStep2) {
      return ScaleTransition(
        scale: _pulseScale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _accentAmber.withValues(alpha: 0.50),
                blurRadius: 14,
                spreadRadius: 3,
              ),
            ],
          ),
          child: pill,
        ),
      );
    }
    return pill;
  }

  /* ---------------- Step 3 & Step 4: Dispatch Action Row ---------------- */

  Widget _buildDispatchActionRow(bool isStep3, bool isStep4) {
    if (_isDispatched) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8B4FE)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF7E22CE), size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                '4 Units Issued & Handed Over Successfully',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF6B21A8),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final scanBtn = _buildScanVerifyButton(isStep3);
        final confirmBtn = _buildConfirmDispatchButton(isStep4);

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              scanBtn,
              const SizedBox(height: 8),
              confirmBtn,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: scanBtn),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: confirmBtn),
          ],
        );
      },
    );
  }

  Widget _buildScanVerifyButton(bool isStep3) {
    final btn = OutlinedButton.icon(
      key: GuidedTourController.issueScanVerifyKey,
      onPressed: _handleOpenScanner,
      style: OutlinedButton.styleFrom(
        backgroundColor: isStep3
            ? _accentAmber
            : (_isQrVerified ? const Color(0xFFE8F5E9) : _surface),
        foregroundColor: isStep3
            ? Colors.white
            : (_isQrVerified ? const Color(0xFF2E7D32) : _ink900),
        side: BorderSide(
          color: isStep3
              ? _accentAmberBorder
              : (_isQrVerified ? const Color(0xFFA5D6A7) : _stroke),
          width: isStep3 || _isQrVerified ? 2.0 : 1.0,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(
        _isQrVerified ? Icons.check_circle_rounded : Icons.qr_code_scanner_rounded,
        size: 18,
        color: isStep3
            ? Colors.white
            : (_isQrVerified ? const Color(0xFF2E7D32) : _ink900),
      ),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _isQrVerified ? 'QR Verified' : 'Scan & Verify',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: isStep3
                ? Colors.white
                : (_isQrVerified ? const Color(0xFF2E7D32) : _ink900),
          ),
        ),
      ),
    );

    if (isStep3) {
      return ScaleTransition(
        scale: _pulseScale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _accentAmber.withValues(alpha: 0.50),
                blurRadius: 14,
                spreadRadius: 3,
              ),
            ],
          ),
          child: btn,
        ),
      );
    }
    return btn;
  }

  Widget _buildConfirmDispatchButton(bool isStep4) {
    final btn = FilledButton.icon(
      key: GuidedTourController.issueConfirmDispatchKey,
      onPressed: (_isSubmitting || !_isQrVerified) ? null : _handleConfirmDispatch,
      style: FilledButton.styleFrom(
        backgroundColor: isStep4 ? _accentAmber : const Color(0xFF059669),
        disabledBackgroundColor: const Color(0xFFE5E7EB),
        foregroundColor: Colors.white,
        disabledForegroundColor: const Color(0xFF9CA3AF),
        elevation: isStep4 ? 4.0 : 1.0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isStep4 ? _accentAmberBorder : Colors.transparent,
            width: isStep4 ? 2.0 : 1.0,
          ),
        ),
        shadowColor: isStep4 ? _accentAmber.withValues(alpha: 0.55) : null,
      ),
      icon: _isSubmitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.local_shipping_rounded, size: 18),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _isSubmitting
              ? 'Updating Ledger...'
              : 'Confirm Handover (4 PCS)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );

    if (isStep4) {
      return ScaleTransition(
        scale: _pulseScale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _accentAmber.withValues(alpha: 0.50),
                blurRadius: 14,
                spreadRadius: 3,
              ),
            ],
          ),
          child: btn,
        ),
      );
    }
    return btn;
  }

  Widget _buildSubmittedQueuePlaceholder() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        children: const [
          Icon(Icons.inbox_outlined, size: 36, color: _ink600),
          SizedBox(height: 8),
          Text(
            'Submitted Queue Empty in Sandbox',
            style: TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Switch to "Ready for Issue" tab above to view approved requisitions.',
            style: TextStyle(color: _ink600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalGuidelineCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF1B5E20)),
              SizedBox(width: 8),
              Text(
                'Outward Dispatch Protocols',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Only authorized storekeepers can perform physical handover to requesters.\n'
            '• QR code scan verification prevents issuing wrong part variants or specs.\n'
            '• Confirming handover immediately logs timestamp, user ID, and deducts ledger stock.',
            style: TextStyle(color: _ink700, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW B: Interactive Simulated QR Code Camera Overlay
     ========================================================================= */

  Widget _buildScannerOverlayView() {
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _stroke),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: _ink900,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Store QR Code Scanner',
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Simulating optical camera detection',
                              style: TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _handleCloseScanner,
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Viewfinder Frame
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Target QR Code
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.qr_code_2_rounded,
                                        size: 72,
                                        color: _ink900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'FLT-AF220 · Air Filter AF-220',
                                    style: TextStyle(
                                      color: _ink900,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Align item QR sticker within viewfinder',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),

                        // Green Laser Scan Line
                        Positioned(
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tap to Scan Button
                  FilledButton.icon(
                    onPressed: _handleSimulateScanSuccess,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentAmber,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: _accentAmberBorder, width: 2),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text(
                      '📷 Scan & Verify Item QR Code',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* =========================================================================
     Instructional Coachmark Card (Warm Amber Theme)
     ========================================================================= */

  Widget _buildCoachmarkCard({
    required int stepNumber,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
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
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: Color(0xFFD97706),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF78350F),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
