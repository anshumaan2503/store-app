import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:store_app/src/store_page/controllers/guided_tour_controller.dart';
import 'package:store_app/src/store_page/presentation/widgets/store_ui_state_widgets.dart';
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

/// Interactive Training Sandbox for Feature F6:
/// Item Issuing Request (Add to Cart & Submit Requisition).
///
/// Fully replicates the visual layout, background gradient, dual sidebars,
/// and header cards of the real [NewStoreHomePage] and [ItemsListPage].
class IssueRequestSimulatorScreen extends ConsumerStatefulWidget {
  const IssueRequestSimulatorScreen({super.key});

  @override
  ConsumerState<IssueRequestSimulatorScreen> createState() =>
      _IssueRequestSimulatorScreenState();
}

class _IssueRequestSimulatorScreenState
    extends ConsumerState<IssueRequestSimulatorScreen>
    with SingleTickerProviderStateMixin {
  // Step tracker:
  // 1 = Add to Cart (Item Card)
  // 2 = Open Cart (Header Cart Icon)
  // 3 = Enter Reason / Destination Machine
  // 4 = Submit Requisition
  int _currentStep = 1;
  static const int _totalSteps = 4;

  // In-memory demo state (isolated from real DB & Sockets)
  int _cartItemCount = 0;
  int _demoQuantity = 1;
  bool _isCartOpen = false;
  bool _isSubmitting = false;

  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

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
    _reasonCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _resetScenario() {
    setState(() {
      _currentStep = 1;
      _cartItemCount = 0;
      _demoQuantity = 1;
      _isCartOpen = false;
      _isSubmitting = false;
      _reasonCtrl.clear();
      _remarkCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sandbox reset to initial state.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  void _handleAddToCart() {
    if (_cartItemCount == 0) {
      setState(() {
        _cartItemCount = 1;
        _currentStep = 2;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Added 1x BEARING 6204 to Requisition Cart!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleOpenCart() {
    if (_cartItemCount > 0) {
      setState(() {
        _isCartOpen = true;
        _currentStep = 3;
      });
    }
  }

  void _handleCloseCart() {
    setState(() {
      _isCartOpen = false;
      if (_currentStep == 3 || _currentStep == 4) {
        _currentStep = 2;
      }
    });
  }

  void _handleSubmitRequest() async {
    setState(() {
      _isSubmitting = true;
    });

    // Simulate 600ms network request
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isCartOpen = false;
    });

    showSimulatorCompletionDialog(
      context: context,
      tourTitle: 'F6: Item Issuing Request (Add to Cart & Submit)',
      description:
          'You successfully practiced finding materials, adding items to your Requisition Cart, assigning destination machinery, and submitting tickets for manager approval without altering live stock.',
      onReplay: _resetScenario,
      onGoToLive: () {
        Navigator.pop(context); // Close simulator
        // Safely route to live Items page
        ref.read(guidedTourControllerProvider).requestSection('items');
      },
    );
  }

  String _getStepLabel() {
    switch (_currentStep) {
      case 1:
        return 'Tap Add to Cart icon on the item card';
      case 2:
        return 'Tap Cart icon in top header';
      case 3:
        return 'Enter Reason / Destination Machine';
      case 4:
        return 'Tap "Submit Request" in bottom bar';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreWalkthroughSimulatorShell(
      title: 'Item Issuing Request & Cart',
      currentStepLabel: _getStepLabel(),
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onExit: () => Navigator.pop(context),
      onReset: _resetScenario,
      child: _isCartOpen ? _buildCartView() : _buildRealStoreShellLayout(context),
    );
  }

  /* =========================================================================
     VIEW A: Full Real Store App Layout (Matching NewStoreHomePage & ItemsListPage)
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
                  // Outer Navigation Sidebar (Receive, Issue, Return)
                  _buildOuterStoreNav(),
                  const SizedBox(width: 12),

                  // Inner Navigation Sidebar (Dashboard, Items [Selected], Find Item, Places)
                  _buildInnerStoreNav(),
                  const SizedBox(width: 12),

                  // Main Items Content Area
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

        // 2. Scrollable Items Content
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
                        title: 'Step 1: Add Item to Requisition Cart',
                        message:
                            'Browse catalog materials and tap the "+ Add to Cart" icon button on the item card below to reserve it in your draft requisition.',
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Step 2 Coachmark (if on Step 2)
                    if (_currentStep == 2) ...[
                      _buildCoachmarkCard(
                        stepNumber: 2,
                        title: 'Step 2: Open Requisition Cart',
                        message:
                            'Great! The cart badge shows (1) item staged. Tap the Cart Icon in the top header bar to review your requisition before submitting.',
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Search & Category Filter Card (matches ItemsListPage _StoreSearchBar)
                    _buildRealSearchBarCard(),
                    const SizedBox(height: 12),

                    // Authentic Item Card (exact replica of ItemListCard)
                    _buildAuthenticItemListCard(),
                    const SizedBox(height: 14),

                    // Operational Guideline Note
                    _buildOperationalNotesCard(),
                  ],
                ),
              ),

              // Floating Action Button: Scan for Issue Request (matching real ItemsListPage)
              Positioned(
                bottom: 12,
                right: 12,
                child: FloatingActionButton.extended(
                  heroTag: 'sim_scan_fab',
                  elevation: 5,
                  backgroundColor: _ink900,
                  foregroundColor: _surface,
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text(
                    'Scan for Issue Request',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('In training: follow the highlighted walkthrough steps!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
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
          // Leading section icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: const Icon(
              Icons.list_alt_rounded,
              color: _ink900,
              size: 22,
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
                  'Items',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Inventory & Operations',
                  style: TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          // Real Trailing Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indent Review Icon Button (real app feature)
              Badge.count(
                count: 0,
                isLabelVisible: false,
                backgroundColor: const Color(0xFF2563EB),
                textColor: _surface,
                child: Tooltip(
                  message: 'Indent Review (0)',
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stroke),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: _ink900,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Real Requisition Cart Button with Badge (Target for Step 2)
              Badge.count(
                count: _cartItemCount,
                isLabelVisible: _cartItemCount > 0,
                backgroundColor: _ink900,
                textColor: _surface,
                child: Tooltip(
                  message: 'Requisition Cart ($_cartItemCount)',
                  child: InkWell(
                    key: GuidedTourController.requisitionCartHeaderKey,
                    borderRadius: BorderRadius.circular(12),
                    onTap: _handleOpenCart,
                    child: ScaleTransition(
                      scale: _currentStep == 2 ? _pulseScale : const AlwaysStoppedAnimation(1.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _currentStep == 2
                              ? const Color(0xFFF59E0B)
                              : (_cartItemCount > 0 ? const Color(0xFFEFF6FF) : _surface),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _currentStep == 2 ? const Color(0xFFD97706) : _stroke,
                            width: _currentStep == 2 ? 2.0 : 1.0,
                          ),
                          boxShadow: _currentStep == 2
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.50),
                                    blurRadius: 14,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          color: _currentStep == 2 ? Colors.white : _ink900,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Help & Support Button (Real icon)
              Container(
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
              const SizedBox(width: 8),

              // More 3-dots Menu Button (Real icon)
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

  /* ---------------- Real Sidebars (from NewStoreHomePage) ---------------- */

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

          // Outer Nav Items
          _buildOuterNavItem(Icons.inbox_rounded, 'Receive', false),
          const SizedBox(height: 8),
          _buildOuterNavItem(Icons.call_split_rounded, 'Issue', false),
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
          _buildInnerIconItem(Icons.list_alt_rounded, 'Items', true), // Items is Active!
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
          _buildMobileNavTab(Icons.list_alt_rounded, 'Items', true),
          _buildMobileNavTab(Icons.location_searching_rounded, 'Find Item', false),
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

  /* ---------------- Real Search Bar & Category Filter ---------------- */

  Widget _buildRealSearchBarCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Input Field
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDFE2D6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: const [
                Icon(Icons.search_rounded, color: _ink600, size: 19),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search item by name or code...',
                    style: TextStyle(
                      color: _ink500,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Category Dropdown Row (Simulated)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _stroke),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.category_outlined, size: 16, color: _ink700),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'All Categories (Mechanical, Electrical...)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ink900,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _ink700),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: const Text(
                  '1 Sample Item',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ---------------- Authentic Item Card (from ItemListCard) ---------------- */

  Widget _buildAuthenticItemListCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _stroke.withValues(alpha: 0.9),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 540;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thumbnail Container (48x48 rounded 14)
                  Container(
                    width: isNarrow ? 44 : 48,
                    height: isNarrow ? 44 : 48,
                    decoration: BoxDecoration(
                      color: _accentMint.withValues(alpha: .40),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _stroke),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: _ink900,
                      size: isNarrow ? 22 : 24,
                    ),
                  ),
                  SizedBox(width: isNarrow ? 8 : 12),

                  // 2. Details Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + Status Chip + Raise Indent Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text(
                                'DEEP GROOVE BALL BEARING 6204 - 2RS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Shortcut Icon
                            Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                              ),
                              child: const Icon(
                                Icons.post_add_rounded,
                                size: 15,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Real StockStatusChip
                            const StockStatusChip(
                              availableQty: 28,
                              minStock: 10,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Code + Category tags row
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Item Code Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _surfaceAlt,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _stroke),
                              ),
                              child: const Text(
                                'BRG-6204-SKF',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _ink900,
                                ),
                              ),
                            ),

                            // Min Stock Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFE0B2)),
                              ),
                              child: const Text(
                                'Min: 10',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            ),

                            // Category Label
                            const Text(
                              'Mechanical Spares',
                              style: TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),

                            // Unit
                            const Text(
                              '• PCS',
                              style: TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Stock Metrics Row
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // 1. Available Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xE8E8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 11,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    'Available: ${_cartItemCount > 0 ? 27 : 28}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. In Cart Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _cartItemCount > 0
                                    ? const Color(0xFFE3F2FD)
                                    : _surfaceAlt.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _cartItemCount > 0 ? const Color(0xFF90CAF9) : _stroke,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 11,
                                    color: _cartItemCount > 0 ? const Color(0xFF1565C0) : _ink700,
                                  ),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    'In Cart: $_cartItemCount',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: _cartItemCount > 0 ? FontWeight.w800 : FontWeight.w700,
                                      color: _cartItemCount > 0 ? const Color(0xFF1565C0) : _ink700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 3. Requested Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _surfaceAlt.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _stroke),
                              ),
                              child: const Text(
                                'Requested: 0',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: _ink700,
                                ),
                              ),
                            ),

                            // 4. Ready for Issue Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _surfaceAlt.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _stroke),
                              ),
                              child: const Text(
                                'Ready: 0',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: _ink700,
                                ),
                              ),
                            ),

                            // 5. Details Trigger Button
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _surfaceAlt.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _stroke),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_edu_rounded, size: 11, color: _ink700),
                                  SizedBox(width: 3.5),
                                  Text(
                                    'Details',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _ink700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Desktop Action Buttons
                  if (!isNarrow) ...[
                    const SizedBox(width: 8),
                    _buildAuthenticItemActionButtons(),
                  ],
                ],
              ),

              // Mobile screen action buttons placed below
              if (isNarrow) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 0.8),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildAuthenticItemActionButtons(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthenticItemActionButtons() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Real Add to Cart Button (The Step 1 Target)
        Tooltip(
          message: _cartItemCount > 0
              ? 'In Cart (1) — Click to practice adding'
              : 'Add to Requisition Cart',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: GuidedTourController.firstItemAddToCartKey,
              onTap: _handleAddToCart,
              borderRadius: BorderRadius.circular(10),
              child: ScaleTransition(
                scale: _currentStep == 1 ? _pulseScale : const AlwaysStoppedAnimation(1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _cartItemCount > 0
                        ? const Color(0xFFE8F5E9)
                        : (_currentStep == 1
                            ? const Color(0xFFF59E0B)
                            : _surfaceAlt.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _cartItemCount > 0
                          ? const Color(0xFFA5D6A7)
                          : (_currentStep == 1 ? const Color(0xFFD97706) : _stroke),
                      width: _currentStep == 1 ? 2.0 : 1.0,
                    ),
                    boxShadow: _currentStep == 1
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.50),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _cartItemCount > 0
                        ? Icons.shopping_cart_rounded
                        : Icons.add_shopping_cart_rounded,
                    color: _cartItemCount > 0
                        ? const Color(0xFF2E7D32)
                        : (_currentStep == 1 ? Colors.white : _ink900),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Real Auxiliary Action Buttons for exact visual fidelity
        _buildSampleActionButton(Icons.edit_outlined, 'Edit Item'),
        _buildSampleActionButton(Icons.qr_code_2_rounded, 'QR Code'),
        _buildSampleActionButton(Icons.location_searching_rounded, 'Find Location'),
        _buildSampleActionButton(Icons.currency_rupee_rounded, 'Rate History'),
      ],
    );
  }

  Widget _buildSampleActionButton(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _stroke),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: _ink900, size: 17),
      ),
    );
  }

  Widget _buildOperationalNotesCard() {
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
              Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 6),
              Text(
                'Key Operational Rule: Indents vs. Direct Issue',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '• Submitting a requisition reserves items in draft mode without altering live inventory ledger counts.\n'
            '• It routes a pending ticket to your department manager for authorization.\n'
            '• Storekeepers only issue parts physically after managerial approval is registered.',
            style: TextStyle(
              color: _ink700,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW B: Real Requisition Cart Screen Layout (matching StoreCartPage)
     ========================================================================= */

  Widget _buildCartView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Top App Bar of Cart
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(bottom: BorderSide(color: _stroke)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _handleCloseCart,
                  icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
                  tooltip: 'Back to Items Catalog',
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Requisition Cart ($_cartItemCount)',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'Review items before submitting requisition',
                        style: TextStyle(color: _ink600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Expiry Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 4),
                      Text(
                        '4:59',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cart Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Step 3 Coachmark (if on Step 3)
                      if (_currentStep == 3) ...[
                        _buildCoachmarkCard(
                          stepNumber: 3,
                          title: 'Step 3: Specify Destination Machine',
                          message:
                              'Specify which equipment requires this part (or tap the quick-sample button below), then proceed to submit.',
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Step 4 Coachmark (if on Step 4)
                      if (_currentStep == 4) ...[
                        _buildCoachmarkCard(
                          stepNumber: 4,
                          title: 'Step 4: Submit Requisition for Sign-off',
                          message:
                              'Tap "Submit Request" in the bottom checkout bar to complete your training. Real inventory will not be modified.',
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Real 5-minute Auto-expiry notice banner (matches StoreCartPage)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 16, color: Color(0xFFE65100)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Items in cart are held for 5 minutes. Submit your request before the timer expires or items will be auto-removed.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Section Header: Items to Request
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items to Request ($_cartItemCount)',
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Total: $_demoQuantity units',
                            style: const TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Real Cart Item Card (matches _buildCartItemCard in StoreCartPage)
                      _buildAuthenticCartItemCard(),
                      const SizedBox(height: 20),

                      // Real Request Details Form Card (matches StoreCartPage)
                      _buildAuthenticRequestDetailsCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Real Bottom Checkout Bar (matches StoreCartPage line 584)
          _buildAuthenticBottomCheckoutBar(),
        ],
      ),
    );
  }

  Widget _buildAuthenticCartItemCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentMint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 20,
                  color: _ink900,
                ),
              ),
              const SizedBox(width: 10),

              // Title & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEEP GROOVE BALL BEARING 6204 - 2RS',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _stroke),
                          ),
                          child: const Text(
                            'BRG-6204-SKF',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _ink900,
                            ),
                          ),
                        ),
                        const Text(
                          'Mechanical Spares',
                          style: TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const Text(
                          '• Main Store Room (Rack R-12)',
                          style: TextStyle(
                            color: _ink600,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _stroke),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        if (_demoQuantity > 1) {
                          setState(() => _demoQuantity--);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.remove, size: 14, color: _ink900),
                      ),
                    ),
                    Text(
                      '$_demoQuantity',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _ink900,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        if (_demoQuantity < 10) {
                          setState(() => _demoQuantity++);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.add, size: 14, color: _ink900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 8),

          // Available & Expiry row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF2E7D32)),
                  SizedBox(width: 4),
                  Text(
                    'Available: 28 PCS',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.access_time_rounded, size: 13, color: _ink600),
                  SizedBox(width: 4),
                  Text(
                    'Hold expires in 4:59',
                    style: TextStyle(color: _ink600, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticRequestDetailsCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 18, color: _ink900),
              const SizedBox(width: 8),
              const Text(
                'Request Details',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Quick Sample Pill
              InkWell(
                onTap: () {
                  setState(() {
                    _reasonCtrl.text = 'CNC Lathe Line 2 - Routine Maintenance';
                    _currentStep = 4;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _currentStep == 3 ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _currentStep == 3 ? const Color(0xFFF59E0B) : const Color(0xFFBFDBFE),
                      width: _currentStep == 3 ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    '⚡ Use Sample: "CNC Lathe Line 2"',
                    style: TextStyle(
                      color: _currentStep == 3 ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reason for Issue *
          TextFormField(
            controller: _reasonCtrl,
            onChanged: (val) {
              if (val.trim().isNotEmpty && _currentStep == 3) {
                setState(() => _currentStep = 4);
              }
            },
            style: const TextStyle(
              color: _ink900,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Reason for Issue *',
              labelStyle: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w700,
              ),
              hintText: 'e.g. Scheduled machine maintenance, replacement part',
              hintStyle: TextStyle(
                color: _ink600.withValues(alpha: 0.55),
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: _ink900),
              filled: true,
              fillColor: _surfaceAlt.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _currentStep == 3 ? const Color(0xFFF59E0B) : _stroke,
                  width: _currentStep == 3 ? 2.0 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _currentStep == 3 ? const Color(0xFFF59E0B) : _ink900,
                  width: 2.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Remark (Optional)
          TextFormField(
            controller: _remarkCtrl,
            style: const TextStyle(
              color: _ink900,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Remark (Optional)',
              labelStyle: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w700,
              ),
              hintText: 'e.g. Urgent priority, Line 2 production',
              hintStyle: TextStyle(
                color: _ink600.withValues(alpha: 0.55),
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(Icons.comment_outlined, color: _ink700),
              filled: true,
              fillColor: _surfaceAlt.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _ink900, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticBottomCheckoutBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(top: BorderSide(color: _stroke)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_cartItemCount Items ($_demoQuantity units)',
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Soft hold for 30m upon submission',
                    style: TextStyle(color: _ink600, fontSize: 11),
                  ),
                ],
              ),
            ),
            SizedBox(
              key: GuidedTourController.requisitionCartSubmitKey,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _currentStep == 4 ? const Color(0xFF059669) : _ink900,
                  foregroundColor: _surface,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: _currentStep == 4 ? 4.0 : 2.0,
                  shadowColor: _currentStep == 4 ? const Color(0xFF059669).withValues(alpha: 0.6) : null,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (_reasonCtrl.text.trim().isEmpty) {
                          _reasonCtrl.text = 'CNC Lathe Line 2 - Routine Maintenance';
                        }
                        _handleSubmitRequest();
                      },
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmitting ? 'Submitting Requisition...' : 'Submit Request',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* =========================================================================
     Instructional Coachmark Card
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
