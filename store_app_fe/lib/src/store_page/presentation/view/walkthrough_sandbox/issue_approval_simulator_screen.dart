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

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

const _accentAmber = Color(0xFFF59E0B);
const _accentAmberBorder = Color(0xFFD97706);

/// Interactive Training Sandbox for Feature F7:
/// Accepting Indents & GRN Approval Workflow.
///
/// Complete realistic replication of:
/// 1. Issues section with Ready, History, and Submitted Indents tabs.
/// 2. Header action bar with Search, Run EOD Scheduler, GRN Cart (N), and GRN Notes.
/// 3. Queuing incoming replenishment indents to the GRN Cart.
/// 4. Reviewing Verified Quantities & Purchase Rates in the GRN Cart bottom sheet.
/// 5. Submitting the GRN Note and granting managerial sign-off approval in GRN Notes.
class IssueApprovalSimulatorScreen extends ConsumerStatefulWidget {
  const IssueApprovalSimulatorScreen({super.key});

  @override
  ConsumerState<IssueApprovalSimulatorScreen> createState() =>
      _IssueApprovalSimulatorScreenState();
}

class _IssueApprovalSimulatorScreenState
    extends ConsumerState<IssueApprovalSimulatorScreen>
    with SingleTickerProviderStateMixin {
  // 7 Guided Walkthrough Steps:
  // 1 = Tap "Submitted Indents" Tab
  // 2 = Tap "Add to GRN" on pending indent card
  // 3 = Tap "GRN Cart (1)" in header action bar
  // 4 = Verify quantity & price in GRN Cart, then tap "Submit GRN for Approval"
  // 5 = Tap "GRN Notes" in header action bar
  // 6 = Tap "GRN-20261018-0001" card in GRN Notes list
  // 7 = Tap "Approve GRN" button in detail sheet
  int _currentStep = 1;
  static const int _totalSteps = 7;

  // Active section tab:
  // 0 = Ready for Issue & Active
  // 1 = Issue History
  // 2 = Submitted Indents (Target for Step 1)
  int _selectedTab = 0;

  // In-memory demo state (isolated from real DB)
  bool _inGrnCart = false;
  bool _isGrnCartOpen = false;
  bool _hasSubmittedGrn = false;
  bool _isGrnNotesOpen = false;
  bool _isGrnDetailOpen = false;
  bool _isGrnApproved = false;
  bool _isSubmitting = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _verifiedQtyCtrl = TextEditingController(text: '10');
  final TextEditingController _purchaseRateCtrl = TextEditingController(text: '450.00');
  final TextEditingController _grnRemarksCtrl =
      TextEditingController(text: 'Received via V-Trans Express, invoice # INV-9812');

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
    _verifiedQtyCtrl.dispose();
    _purchaseRateCtrl.dispose();
    _grnRemarksCtrl.dispose();
    super.dispose();
  }

  void _resetScenario() {
    setState(() {
      _currentStep = 1;
      _selectedTab = 0;
      _inGrnCart = false;
      _isGrnCartOpen = false;
      _hasSubmittedGrn = false;
      _isGrnNotesOpen = false;
      _isGrnDetailOpen = false;
      _isGrnApproved = false;
      _isSubmitting = false;
      _searchCtrl.clear();
      _verifiedQtyCtrl.text = '10';
      _purchaseRateCtrl.text = '450.00';
      _grnRemarksCtrl.text = 'Received via V-Trans Express, invoice # INV-9812';
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
      if (_currentStep == 1 && index == 2) {
        _currentStep = 2;
      }
    });
  }

  void _handleAddToGrn() {
    setState(() {
      _inGrnCart = true;
      if (_currentStep == 2) {
        _currentStep = 3;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('SKF 6205 Deep Groove Ball Bearing added to GRN Cart'),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Open Cart',
          textColor: Colors.white,
          onPressed: _handleOpenGrnCart,
        ),
      ),
    );
  }

  void _handleOpenGrnCart() {
    setState(() {
      _isGrnCartOpen = true;
      if (_currentStep == 3) {
        _currentStep = 4;
      }
    });
  }

  void _handleCloseGrnCart() {
    setState(() {
      _isGrnCartOpen = false;
      if (_currentStep == 4 && !_hasSubmittedGrn) {
        _currentStep = 3;
      }
    });
  }

  void _handleSubmitGrn() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isGrnCartOpen = false;
      _hasSubmittedGrn = true;
      if (_currentStep == 4) {
        _currentStep = 5;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GRN #GRN-20261018-0001 submitted and awaiting approval!'),
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleOpenGrnNotes() {
    setState(() {
      _isGrnNotesOpen = true;
      if (_currentStep == 5) {
        _currentStep = 6;
      }
    });
  }

  void _handleCloseGrnNotes() {
    setState(() {
      _isGrnNotesOpen = false;
      if (_currentStep == 6) {
        _currentStep = 5;
      }
    });
  }

  void _handleSelectGrnCard() {
    setState(() {
      _isGrnNotesOpen = false;
      _isGrnDetailOpen = true;
      if (_currentStep == 6) {
        _currentStep = 7;
      }
    });
  }

  void _handleCloseGrnDetail() {
    setState(() {
      _isGrnDetailOpen = false;
      if (_currentStep == 7 && !_isGrnApproved) {
        _currentStep = 6;
        _isGrnNotesOpen = true;
      }
    });
  }

  void _handleApproveGrn() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isGrnApproved = true;
      _isGrnDetailOpen = false;
    });

    showSimulatorCompletionDialog(
      context: context,
      tourTitle: 'Indent Acceptance & GRN Approval Complete! 🎉',
      description:
          'You successfully navigated to Submitted Indents, queued requisition #IND-20261018-0012 to the GRN Cart, verified incoming count (10 pcs) and purchase rate (₹450/unit), logged GRN #GRN-20261018-0001, and granted final managerial sign-off approval!',
      onReplay: _resetScenario,
      onGoToLive: () {
        Navigator.pop(context);
        ref.read(guidedTourControllerProvider).requestSection('issue');
      },
    );
  }

  String _getStepLabel() {
    switch (_currentStep) {
      case 1:
        return 'Tap "Submitted Indents" tab';
      case 2:
        return 'Tap "Add to GRN" on indent card';
      case 3:
        return 'Tap "GRN Cart (1)" in header action bar';
      case 4:
        return 'Verify quantity & price, tap "Submit GRN"';
      case 5:
        return 'Tap "GRN Notes" in header action bar';
      case 6:
        return 'Tap "GRN-20261018-0001" in notes list';
      case 7:
        return 'Tap "Approve GRN" to grant sign-off';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreWalkthroughSimulatorShell(
      title: 'Accepting Indents & GRN Approval',
      currentStepLabel: _getStepLabel(),
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onExit: () => Navigator.pop(context),
      onReset: _resetScenario,
      child: _isGrnDetailOpen
          ? _buildGrnDetailApprovalSheetModal()
          : (_isGrnNotesOpen
              ? _buildGrnNotesListModal()
              : (_isGrnCartOpen
                  ? _buildGrnCartSheetModal()
                  : _buildRealStoreShellLayout(context))),
    );
  }

  /* =========================================================================
     VIEW A: Full Real Store App Shell Layout (Matching IssuesListPage)
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
                  _buildOuterStoreNav(),
                  const SizedBox(width: 12),
                  _buildInnerStoreNav(),
                  const SizedBox(width: 12),
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
        // 1. Real Header Card (matching _HeaderCard in NewStoreHomePage)
        _buildRealStoreHeaderCard(),
        const SizedBox(height: 10),

        // 2. Scrollable Content Area
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step 1 Coachmark (if on Step 1)
                    if (_currentStep == 1) ...[
                      _buildCoachmarkCard(
                        stepNumber: 1,
                        title: 'Step 1: Open Submitted Indents Queue',
                        message:
                            'Tap the highlighted "Submitted Indents" tab below to view incoming procurement requisitions.',
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Step 2 Coachmark (if on Step 2)
                    if (_currentStep == 2) ...[
                      _buildCoachmarkCard(
                        stepNumber: 2,
                        title: 'Step 2: Add Indent to GRN Batch',
                        message:
                            'Tap the highlighted green "Add to GRN" button on the indent card below to queue it for goods receipt inspection.',
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Step 3 Coachmark (if on Step 3)
                    if (_currentStep == 3) ...[
                      _buildCoachmarkCard(
                        stepNumber: 3,
                        title: 'Step 3: Open GRN Cart',
                        message:
                            'Notice the GRN Cart badge updated to 1. Tap the highlighted "GRN Cart (1)" button in the header action row to review counts and rates.',
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Step 5 Coachmark (if on Step 5)
                    if (_currentStep == 5) ...[
                      _buildCoachmarkCard(
                        stepNumber: 5,
                        title: 'Step 5: Open Goods Receipt Notes',
                        message:
                            'Your receipt note has been created. Tap the highlighted "GRN Notes" button in the header to review pending notes waiting for approval.',
                      ),
                      const SizedBox(height: 10),
                    ],

                    // 3. Section Tab Bar (matching IssuesListPage)
                    _buildSectionTabBar(),
                    const SizedBox(height: 10),

                    // 4. Tab Content
                    if (_selectedTab == 2 || _currentStep >= 2) ...[
                      _buildSubmittedIndentsSection(),
                    ] else ...[
                      _buildReadyTabPlaceholder(),
                    ],
                  ],
                ),
              ),

              // Floating Scan Button (bottom right matching user screenshot)
              Positioned(
                bottom: 14,
                right: 14,
                child: FloatingActionButton.extended(
                  onPressed: () {},
                  backgroundColor: _ink900,
                  foregroundColor: Colors.white,
                  elevation: 5,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text(
                    'Scan for Issue Request',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
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
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: _ink900, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: const Icon(
              Icons.alt_route_rounded,
              color: _ink900,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Issue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _ink900,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Inventory & Operations',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _ink600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Action icons matching screenshot
          Badge(
            label: const Text('2', style: TextStyle(fontSize: 10)),
            backgroundColor: const Color(0xFFF59E0B),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: _ink900, size: 20),
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: _ink900, size: 20),
            onPressed: () {},
            visualDensity: VisualDensity.compact,
          ),
          if (MediaQuery.of(context).size.width >= 550) ...[
            IconButton(
              icon: const Icon(Icons.assignment_outlined, color: _ink900, size: 20),
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: _ink900, size: 20),
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: _ink900, size: 20),
            onPressed: () {},
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /* ---------------- Navigation Sidebars (Matching StoreShell) ---------------- */

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
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Store',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  /* ---------------- Section Tab Bar (matching IssuesListPage) ---------------- */

  Widget _buildSectionTabBar() {
    final isStep1 = _currentStep == 1;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          // Tab 0: Ready for Issue & Active
          Expanded(
            child: _buildTabButton(
              index: 0,
              title: 'Ready for Issue & Active',
              subtitle: 'Awaiting approval / counter',
              icon: Icons.outbox_rounded,
              isSelected: _selectedTab == 0 && !isStep1,
              activeColor: const Color(0xFF5E35B1),
              activeBgColor: const Color(0xFFEDE7F6),
              isHighlighted: false,
            ),
          ),
          const SizedBox(width: 4),

          // Tab 1: Issue History
          Expanded(
            child: _buildTabButton(
              index: 1,
              title: 'Issue History',
              subtitle: 'All completed issues',
              icon: Icons.history_edu_rounded,
              isSelected: _selectedTab == 1,
              activeColor: const Color(0xFF00796B),
              activeBgColor: const Color(0xFFE0F2F1),
              isHighlighted: false,
            ),
          ),
          const SizedBox(width: 4),

          // Tab 2: Submitted Indents (TARGET FOR STEP 1)
          Expanded(
            child: _buildTabButton(
              index: 2,
              title: 'Submitted Indents',
              subtitle: 'Approver review & verify',
              icon: Icons.assignment_turned_in_rounded,
              isSelected: _selectedTab == 2 || isStep1,
              activeColor: const Color(0xFFE65100),
              activeBgColor: const Color(0xFFFFF3E0),
              isHighlighted: isStep1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
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
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isSelected ? activeBgColor : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: isHighlighted
                      ? Colors.white
                      : (isSelected ? activeColor : _ink600),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isHighlighted
                            ? Colors.white
                            : (isSelected ? activeColor : _ink700),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isHighlighted
                            ? Colors.white.withValues(alpha: 0.9)
                            : (isSelected ? _ink700 : _ink600),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  /* ---------------- Submitted Indents View (Matching User Screenshot) ---------------- */

  Widget _buildSubmittedIndentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search & GRN Header Card
        _buildSearchAndGrnActionCard(),
        const SizedBox(height: 12),

        // Indent Card or Empty State
        if (!_isGrnApproved) ...[
          _buildAuthenticIndentCard(),
        ] else ...[
          _buildEmptyIndentsState(),
        ],
      ],
    );
  }

  Widget _buildSearchAndGrnActionCard() {
    final isStep3 = _currentStep == 3;
    final isStep5 = _currentStep == 5;
    final grnCount = _inGrnCart && !_hasSubmittedGrn ? 1 : 0;

    return Card(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Search Input + Refresh + EOD + GRN Cart + GRN Notes
            if (MediaQuery.of(context).size.width < 680) ...[
              // Mobile Row 1: Search + Refresh
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: _surfaceAlt.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _stroke),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: _ink600),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Search indents...',
                              style: TextStyle(color: _ink500, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded, color: _ink900, size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Mobile Row 2: Action Buttons (Scrollable so never overflows)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF512DA8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.nightlight_round, size: 14, color: Colors.white),
                      label: const Text(
                        'Run EOD Scheduler',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildGrnCartHeaderButton(isStep3, grnCount),
                    const SizedBox(width: 6),
                    _buildGrnNotesHeaderButton(isStep5),
                  ],
                ),
              ),
            ] else ...[
              // Desktop Row: Everything in one clean line
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: _surfaceAlt.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _stroke),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: _ink600),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Search indents by number, item, reason...',
                              style: TextStyle(color: _ink500, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded, color: _ink900, size: 20),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),

                  // Run EOD Scheduler Button (matching screenshot)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF512DA8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.nightlight_round, size: 14, color: Colors.white),
                    label: const Text(
                      'Run EOD Scheduler',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // GRN Cart Button (TARGET FOR STEP 3)
                  _buildGrnCartHeaderButton(isStep3, grnCount),
                  const SizedBox(width: 4),

                  // GRN Notes Button (TARGET FOR STEP 5)
                  _buildGrnNotesHeaderButton(isStep5),
                ],
              ),
            ],
            const Divider(height: 14, color: _stroke),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('All Statuses', false),
                  const SizedBox(width: 8),
                  _buildChip('Pending', true, check: true),
                  const SizedBox(width: 8),
                  _buildChip('Approved', false),
                  const SizedBox(width: 8),
                  _buildChip('Rejected', false),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Source Filter Chips (matching screenshot)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('All Sources (${_isGrnApproved ? 0 : 1})', true, check: true),
                  const SizedBox(width: 8),
                  _buildChip('🤖 Auto Refill (0)', false),
                  const SizedBox(width: 8),
                  _buildChip('👤 Requester Indents (${_isGrnApproved ? 0 : 1})', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrnCartHeaderButton(bool isHighlighted, int count) {
    final btn = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: isHighlighted ? _accentAmber : const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isHighlighted
              ? const BorderSide(color: _accentAmberBorder, width: 2)
              : BorderSide.none,
        ),
        elevation: isHighlighted ? 4 : 0,
      ),
      onPressed: _handleOpenGrnCart,
      icon: const Icon(Icons.assignment_turned_in_outlined, size: 15, color: Colors.white),
      label: Text(
        'GRN Cart ($count)',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: btn,
      );
    }
    return btn;
  }

  Widget _buildGrnNotesHeaderButton(bool isHighlighted) {
    final btn = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: isHighlighted ? Colors.white : const Color(0xFF1565C0),
        backgroundColor: isHighlighted ? _accentAmber : Colors.transparent,
        iconColor: isHighlighted ? Colors.white : const Color(0xFF1565C0),
        side: BorderSide(
          color: isHighlighted ? _accentAmberBorder : const Color(0xFF90CAF9),
          width: isHighlighted ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _handleOpenGrnNotes,
      icon: const Icon(Icons.receipt_long_outlined, size: 15),
      label: const Text(
        'GRN Notes',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: btn,
      );
    }
    return btn;
  }

  Widget _buildChip(String label, bool isSelected, {bool check = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? _ink900 : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (check && isSelected) ...[
            const Icon(Icons.check, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : _ink700,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- Authentic Indent Card (Replicating stock_refill_requests_list_view) ---------------- */

  Widget _buildAuthenticIndentCard() {
    final isStep2 = _currentStep == 2;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Icon + Title + Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: const Icon(
                  Icons.precision_manufacturing_rounded,
                  color: Color(0xFFE65100),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SKF 6205 Deep Groove Ball Bearing',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _ink900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'IND-20261018-0012',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                        const Text(
                          'Code: SKF-BRG-6205',
                          style: TextStyle(fontSize: 11, color: _ink600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stock balance container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Flexible(
                  child: Text(
                    'Balance Stock (at request):',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ink600),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Avail: 2  |  Total: 12',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _ink900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Metadata row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: const [
              Text(
                'Requested: 10 PCS  •  CNC Milling Unit 02',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink700),
              ),
              Text(
                'By: Rahul Sharma (Operator)',
                style: TextStyle(fontSize: 11.5, color: _ink600),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action buttons: Edit Qty, Reject, and ADD TO GRN (TARGET FOR STEP 2)
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE65100),
                  side: const BorderSide(color: Color(0xFFFFB74D)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 15),
                label: const Text('Edit Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  side: const BorderSide(color: Color(0xFFEF9A9A)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              // Add to GRN Button
              _buildAddToGrnButton(isStep2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddToGrnButton(bool isHighlighted) {
    if (_inGrnCart) {
      return OutlinedButton.icon(
        onPressed: _handleOpenGrnCart,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2E7D32),
          side: const BorderSide(color: Color(0xFF81C784)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2E7D32)),
        label: const Text('In GRN Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      );
    }

    final btn = ElevatedButton.icon(
      onPressed: _handleAddToGrn,
      style: ElevatedButton.styleFrom(
        backgroundColor: isHighlighted ? _accentAmber : const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: isHighlighted ? 4 : 1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isHighlighted
              ? const BorderSide(color: _accentAmberBorder, width: 2)
              : BorderSide.none,
        ),
      ),
      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
      label: const Text(
        'Add to GRN',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: btn,
      );
    }
    return btn;
  }

  Widget _buildEmptyIndentsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inbox_outlined, size: 48, color: _ink600),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Indent requests found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'All submitted requisitions have been verified & approved into inventory.',
            style: TextStyle(fontSize: 12, color: _ink600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReadyTabPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 42, color: _ink600),
          SizedBox(height: 12),
          Text(
            'Ready for Issue & Active',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink900),
          ),
          SizedBox(height: 4),
          Text(
            'No physical dispatches pending counter pickup.\nTap "Submitted Indents" tab above to review incoming requisitions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ink600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     MODAL 1: GRN Cart Bottom Sheet (Step 4 - Matching GrnCartSheet)
     ========================================================================= */

  Widget _buildGrnCartSheetModal() {
    final isStep4 = _currentStep == 4;

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top drag pill
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Sheet Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_outlined,
                          color: Color(0xFF2E7D32),
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
                                const Expanded(
                                  child: Text(
                                    'GRN Cart (Goods Receipt)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _ink900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '1',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Recheck physical quantities, rates & upload invoice/challan',
                              style: TextStyle(fontSize: 11, color: _ink600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _ink700),
                        onPressed: _handleCloseGrnCart,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _stroke),

                // Sheet Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Step 4 Coachmark
                        if (isStep4) ...[
                          _buildCoachmarkCard(
                            stepNumber: 4,
                            title: 'Step 4: Verify Rates & Submit GRN',
                            message:
                                'Confirm the verified count (10 units) and purchase rate (₹450/unit). Tap the highlighted "Submit GRN for Approval" button.',
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Item Card in GRN Cart
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _stroke),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SKF 6205 Deep Groove Ball Bearing',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _ink900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Indent #IND-20261018-0012  •  Ordered: 10 PCS',
                                style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),

                              // Inputs row
                              LayoutBuilder(
                                builder: (context, boxConstraints) {
                                  final isTight = boxConstraints.maxWidth < 420;

                                  final fields = Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Verified Qty',
                                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _ink700),
                                            ),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              height: 38,
                                              child: TextField(
                                                controller: _verifiedQtyCtrl,
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                                decoration: InputDecoration(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Purchase Rate (₹)',
                                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _ink700),
                                            ),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              height: 38,
                                              child: TextField(
                                                controller: _purchaseRateCtrl,
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                                decoration: InputDecoration(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );

                                  final lineTotal = Column(
                                    crossAxisAlignment: isTight ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                    children: const [
                                      Text(
                                        'Line Total',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _ink700),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '₹4,500.00',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ],
                                  );

                                  if (isTight) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        fields,
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: lineTotal,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: fields),
                                      const SizedBox(width: 12),
                                      lineTotal,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Delivery Challan Photo Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2E7D32), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Challan: CH-2026-9812 (SKF India)',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ink900),
                                    ),
                                    Text(
                                      'Attached bill scan verified & ready for audit',
                                      style: TextStyle(fontSize: 11, color: _ink600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Attached',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Summary Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Verified: 10 units',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _ink900),
                              ),
                              Text(
                                'Total Value: ₹4,500.00',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Submit GRN Button (TARGET FOR STEP 4)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: _buildSubmitGrnButton(isStep4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitGrnButton(bool isHighlighted) {
    final btn = ElevatedButton.icon(
      onPressed: _isSubmitting ? null : _handleSubmitGrn,
      style: ElevatedButton.styleFrom(
        backgroundColor: isHighlighted ? _accentAmber : const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isHighlighted
              ? const BorderSide(color: _accentAmberBorder, width: 2)
              : BorderSide.none,
        ),
        elevation: isHighlighted ? 6 : 1,
      ),
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.send_rounded, size: 18),
      label: Text(
        _isSubmitting ? 'Submitting GRN...' : 'Submit GRN for Approval (1 items)',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: btn,
      );
    }
    return btn;
  }

  /* =========================================================================
     MODAL 2: Goods Receipt Notes (GRN) List Modal (Step 6)
     ========================================================================= */

  Widget _buildGrnNotesListModal() {
    final isStep6 = _currentStep == 6;

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Goods Receipt Notes (GRN)',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: _ink900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _ink900),
                      onPressed: _handleCloseGrnNotes,
                    ),
                  ],
                ),
                const Divider(color: _stroke),
                const SizedBox(height: 8),

                // Step 6 Coachmark
                if (isStep6) ...[
                  _buildCoachmarkCard(
                    stepNumber: 6,
                    title: 'Step 6: Open GRN Inspection Sheet',
                    message:
                        'Tap on the highlighted GRN card #GRN-20261018-0001 below to review invoice details and sign off.',
                  ),
                  const SizedBox(height: 12),
                ],

                Expanded(
                  child: ListView(
                    children: [
                      _buildGrnNoteCard(isStep6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrnNoteCard(bool isHighlighted) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isHighlighted ? _accentAmber : _surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHighlighted ? _accentAmberBorder : _stroke,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: _handleSelectGrnCard,
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'GRN-20261018-0001',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isHighlighted ? Colors.white : _ink900,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PENDING APPROVAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isHighlighted ? Colors.white : const Color(0xFFE65100),
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '1 items • Total: ₹4,500.00 • By Issue Approver',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isHighlighted ? Colors.white.withValues(alpha: 0.9) : _ink600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isHighlighted ? Colors.white : _ink700,
        ),
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: card,
      );
    }
    return card;
  }

  /* =========================================================================
     MODAL 3: GRN Detail Approval Sheet (Step 7 - Matching GrnDetailApprovalSheet)
     ========================================================================= */

  Widget _buildGrnDetailApprovalSheetModal() {
    final isStep7 = _currentStep == 7;

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top drag pill
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF1565C0),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Goods Receipt Note Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _ink900,
                              ),
                            ),
                            Text(
                              'GRN-20261018-0001 • Managerial Verification',
                              style: TextStyle(fontSize: 11, color: _ink600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _ink700),
                        onPressed: _handleCloseGrnDetail,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _stroke),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Step 7 Coachmark
                        if (isStep7) ...[
                          _buildCoachmarkCard(
                            stepNumber: 7,
                            title: 'Step 7: Grant Managerial GRN Sign-off',
                            message:
                                'Inspect the verified quantity (10 units) and total valuation (₹4,500.00). Tap the highlighted green "Approve GRN" button to finalize receipt.',
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Metadata Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _stroke),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Status: PENDING APPROVAL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                  Text(
                                    'Challan: CH-2026-9812',
                                    style: TextStyle(fontSize: 11.5, color: _ink600),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Vendor: SKF Bearings India Ltd  •  PO: PO-2026-089',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, color: _ink700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Line items list
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _stroke),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SKF 6205 Deep Groove Ball Bearing',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _ink900),
                                    ),
                                    Text(
                                      '10 PCS @ ₹450.00 / unit',
                                      style: TextStyle(fontSize: 11.5, color: _ink600),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '₹4,500.00',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.5,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Total Valuation Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Authorized Total Valuation:',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ink900),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '₹4,500.00',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons: Reject vs Approve (TARGET FOR STEP 7)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC62828),
                            side: const BorderSide(color: Color(0xFFEF9A9A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reject GRN', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildApproveGrnButton(isStep7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApproveGrnButton(bool isHighlighted) {
    final btn = ElevatedButton.icon(
      onPressed: _isSubmitting ? null : _handleApproveGrn,
      style: ElevatedButton.styleFrom(
        backgroundColor: isHighlighted ? _accentAmber : const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isHighlighted
              ? const BorderSide(color: _accentAmberBorder, width: 2)
              : BorderSide.none,
        ),
        elevation: isHighlighted ? 6 : 1,
      ),
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.check_circle_rounded, size: 18),
      label: Text(
        _isSubmitting ? 'Approving...' : 'Approve GRN',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: btn,
      );
    }
    return btn;
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
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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
