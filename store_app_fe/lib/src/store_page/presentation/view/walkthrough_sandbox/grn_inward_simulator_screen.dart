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

/// Interactive Training Sandbox for Feature F4:
/// Receiving Items & Inwarding (Goods Received Note - GRN).
///
/// Replicates the authentic layout of [ReceivePagedListPage] with Section Tabs,
/// live-like inward receipts, Challan & PO logging, rack allocation, and
/// thermal QR sticker printing without mutating live MongoDB inventory.
class GrnInwardSimulatorScreen extends ConsumerStatefulWidget {
  const GrnInwardSimulatorScreen({super.key});

  @override
  ConsumerState<GrnInwardSimulatorScreen> createState() =>
      _GrnInwardSimulatorScreenState();
}

class _GrnInwardSimulatorScreenState
    extends ConsumerState<GrnInwardSimulatorScreen>
    with SingleTickerProviderStateMixin {
  // Guided Walkthrough Steps:
  // 1 = Tap "+ New Inward (GRN)" Button (Action in header)
  // 2 = Log Challan & PO Reference (Autofill CH-2026-9921)
  // 3 = Assign Storage Rack (Rack R-12, Shelf S-03)
  // 4 = Complete Inward & Generate Labels (Save & Thermal QR preview)
  int _currentStep = 1;
  static const int _totalSteps = 4;

  // Active top tab in Receive screen:
  // 0 = Stock Receipts, 1 = Indent Requests
  int _selectedTab = 0;

  // In-memory demo state
  bool _isModalOpen = false;
  bool _isChallanFilled = false;
  bool _isRackAssigned = false;
  bool _isSubmitting = false;
  bool _hasCompletedInward = false;

  // Form controllers
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _challanCtrl = TextEditingController();
  final TextEditingController _poCtrl = TextEditingController();
  final TextEditingController _supplierCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

  static const int _inwardQty = 25;
  static const int _initialStock = 10;
  String _selectedRack = '';

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
    _challanCtrl.dispose();
    _poCtrl.dispose();
    _supplierCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _resetScenario() {
    setState(() {
      _currentStep = 1;
      _selectedTab = 0;
      _isModalOpen = false;
      _isChallanFilled = false;
      _isRackAssigned = false;
      _isSubmitting = false;
      _hasCompletedInward = false;
      _selectedRack = '';
      _searchCtrl.clear();
      _challanCtrl.clear();
      _poCtrl.clear();
      _supplierCtrl.clear();
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

  void _handleOpenInwardModal() {
    setState(() {
      _isModalOpen = true;
      if (_currentStep == 1) {
        _currentStep = 2;
      }
    });
  }

  void _handleCloseInwardModal() {
    setState(() {
      _isModalOpen = false;
      if (_currentStep >= 2 && !_hasCompletedInward) {
        _currentStep = 1;
      }
    });
  }

  void _handleAutofillChallan() {
    setState(() {
      _challanCtrl.text = 'CH-2026-9921';
      _poCtrl.text = 'PO-2026-089';
      _supplierCtrl.text = 'SKF Bearings India Ltd';
      _isChallanFilled = true;
      if (_currentStep == 2) {
        _currentStep = 3;
      }
    });
  }

  void _handleSelectRack(String rackName) {
    setState(() {
      _selectedRack = rackName;
      _isRackAssigned = true;
      if (_currentStep == 3) {
        _currentStep = 4;
      }
    });
  }

  Future<void> _handleSaveInwardAndPrint() async {
    setState(() {
      _isSubmitting = true;
    });

    // Simulate 600ms ledger recording
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _hasCompletedInward = true;
      _isModalOpen = false;
    });

    // Render thermal QR barcode sticker preview dialog
    await _showThermalQrLabelPreviewDialog();

    if (!mounted) return;

    // Show completion dialog with replay and navigate to live
    showSimulatorCompletionDialog(
      context: context,
      tourTitle: 'F4: Receiving Items & Inwarding (GRN)',
      description:
          'You successfully logged delivery challan CH-2026-9921 from SKF Bearings India Ltd, assigned 25 units of Tapered Roller Bearing 32208 to Rack R-12 (Shelf S-03), and generated thermal QR stickers without altering live database records.',
      onReplay: _resetScenario,
      onGoToLive: () {
        Navigator.pop(context); // Close simulator
        // Safely route to live Receive section
        ref.read(guidedTourControllerProvider).requestSection('receive');
      },
    );
  }

  Future<void> _showThermalQrLabelPreviewDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x28000000),
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
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          color: Color(0xFF2E7D32),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Thermal QR Sticker Generated',
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '57mm Roll Format · Ready for Physical Tagging',
                              style: TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 57mm Thermal Label Preview Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Store Label Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'CENTRAL STORE INWARD',
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'GRN-2026-9921',
                              style: TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 14, thickness: 1),

                        // QR Matrix + Details Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // QR Graphic Box
                            Container(
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 74,
                                      color: _ink900,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      color: Colors.white,
                                      child: const Icon(
                                        Icons.inventory_2_rounded,
                                        size: 14,
                                        color: _ink900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Printed Metadata
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Tapered Roller Bearing 32208',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _ink900,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'SKU: BRG-32208-TRB',
                                    style: TextStyle(
                                      color: _ink700,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'LOC: R-12 (Shelf S-03)',
                                    style: TextStyle(
                                      color: Color(0xFF1B5E20),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'QTY: 25 PCS · CH: CH-2026-9921',
                                    style: TextStyle(
                                      color: _ink600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // QR Identification Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _stroke),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.qr_code_2_rounded, size: 14, color: _ink900),
                              SizedBox(width: 6),
                              Text(
                                'QR CODE: P0040.BRG-32208-TRB',
                                style: TextStyle(
                                  color: _ink900,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Button
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Preview Confirmed',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getStepLabel() {
    switch (_currentStep) {
      case 1:
        return 'Tap "+ New Inward (GRN)" button';
      case 2:
        return 'Log Challan & PO reference';
      case 3:
        return 'Assign destination storage rack';
      case 4:
        return 'Save Inward & print QR labels';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreWalkthroughSimulatorShell(
      title: 'Goods Inward (GRN) & Barcodes',
      currentStepLabel: _getStepLabel(),
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onExit: () => Navigator.pop(context),
      onReset: _resetScenario,
      child: _isModalOpen
          ? _buildInwardModalView()
          : _buildRealStoreShellLayout(context),
    );
  }

  /* =========================================================================
     VIEW A: Full Real Store App Layout (Matching ReceivePagedListPage)
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
                  // Outer Navigation Sidebar (Receive [Active], Issue, Return)
                  _buildOuterStoreNav(),
                  const SizedBox(width: 12),

                  // Inner Navigation Sidebar (Dashboard, Items, Find Item, Places)
                  _buildInnerStoreNav(),
                  const SizedBox(width: 12),

                  // Main Receive Content Area
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
                    title: 'Step 1: Initiate Goods Inward (GRN)',
                    message:
                        'Tap the highlighted "+ New Inward (GRN)" button below to log incoming supplier consignments or inter-plant transfers without altering live store records.',
                  ),
                  const SizedBox(height: 10),
                ],

                // 3. Top Tab Switcher: Stock Receipts vs Indent Requests
                _buildTopTabSwitcher(),
                const SizedBox(height: 10),

                // 4. Real Search, Refresh, Export & Inward Action Row
                _buildSearchAndActionCard(),
                const SizedBox(height: 12),

                // 5. Authentic Goods Receipt Cards
                if (_hasCompletedInward) ...[
                  _buildNewlyInwardedReceiptCard(),
                  const SizedBox(height: 10),
                ],
                _buildExistingReceiptCard(),
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

  /* ---------------- Real Header Card (matching Receive view) ---------------- */

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
              color: _accentMint.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: const Icon(
              Icons.inbox_rounded,
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
                  'Receive',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Goods Receipt & Inwarding (GRN)',
                  style: TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
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

          // Outer Nav Items: Receive is SELECTED
          _buildOuterNavItem(Icons.inbox_rounded, 'Receive', true),
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
          _buildMobileNavTab(Icons.inbox_rounded, 'Receive', true),
          _buildMobileNavTab(Icons.call_split_rounded, 'Issues', false),
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

  /* ---------------- Top Tab Switcher: Receipts vs Indent Requests ---------------- */

  Widget _buildTopTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? _surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 0
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
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 16,
                      color: _selectedTab == 0 ? _ink900 : _ink600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hasCompletedInward ? 'Stock Receipts (2)' : 'Stock Receipts (1)',
                      style: TextStyle(
                        color: _selectedTab == 0 ? _ink900 : _ink600,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? _surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 16,
                      color: _selectedTab == 1 ? _ink900 : _ink600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Indent Requests',
                      style: TextStyle(
                        color: _selectedTab == 1 ? _ink900 : _ink600,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- Real Search & Inward Action Row ---------------- */

  Widget _buildSearchAndActionCard() {
    final isStep1 = _currentStep == 1;

    return Card(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: MediaQuery.of(context).size.width < 600
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Search receive...',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(color: _ink900, fontSize: 13.5),
                        ),
                      ),
                      IconButton(
                        tooltip: "Refresh",
                        onPressed: () {},
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        color: _ink900,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        tooltip: "Download Excel",
                        onPressed: () {},
                        icon: const Icon(Icons.download_rounded, size: 20),
                        color: _ink900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildNewInwardActionButton(isStep1),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search receive...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(color: _ink900, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: "Refresh",
                    onPressed: () {},
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: _ink900,
                  ),
                  IconButton(
                    tooltip: "Download Excel",
                    onPressed: () {},
                    icon: const Icon(Icons.download_rounded, size: 20),
                    color: _ink900,
                  ),
                  const SizedBox(width: 8),

                  // Step 1 Spotlight: + New Inward Button
                  _buildNewInwardActionButton(isStep1),
                ],
              ),
      ),
    );
  }

  Widget _buildNewInwardActionButton(bool isStep1) {
    final btn = FilledButton.icon(
      key: GuidedTourController.receiveStockActionKey,
      onPressed: _handleOpenInwardModal,
      style: FilledButton.styleFrom(
        backgroundColor: isStep1 ? _accentAmber : _ink900,
        foregroundColor: Colors.white,
        elevation: isStep1 ? 4.0 : 1.0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isStep1 ? _accentAmberBorder : Colors.transparent,
            width: isStep1 ? 2.0 : 1.0,
          ),
        ),
        shadowColor: isStep1 ? _accentAmber.withValues(alpha: 0.55) : null,
      ),
      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
      label: const Text(
        '+ New Inward (GRN)',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );

    if (isStep1) {
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
          child: btn,
        ),
      );
    }
    return btn;
  }

  /* ---------------- Authentic Receipt Cards ---------------- */

  Widget _buildNewlyInwardedReceiptCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1010B981),
            blurRadius: 12,
            offset: Offset(0, 4),
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 24,
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
                            'Tapered Roller Bearing 32208',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildQtyBadge(25),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Print Thermal Sticker',
                          onPressed: _showThermalQrLabelPreviewDialog,
                          icon: const Icon(
                            Icons.qr_code_2_rounded,
                            size: 20,
                            color: _ink900,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildPillBadge('BRG-32208-TRB'),
                        _buildPillBadge('Rack R-12 (Shelf S-03)', icon: Icons.shelves),
                        _buildPillBadge('Main Store Room', icon: Icons.room_rounded),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: const Text(
                            'JUST NOW · GRN RECORDED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: const [
                Text(
                  'Supplier: SKF Bearings India Ltd',
                  style: TextStyle(
                    color: _ink700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Challan: CH-2026-9921',
                  style: TextStyle(
                    color: _ink700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingReceiptCard() {
    return Card(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: _ink700,
        collapsedIconColor: _ink700,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _accentMint.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: _ink900,
            size: 22,
          ),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deep Groove Ball Bearing 6205-2RS',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildPillBadge('BRG-6205-2RS'),
                      _buildPillBadge('Rack R-08', icon: Icons.shelves),
                      _buildPillBadge('Main Store Room', icon: Icons.room_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildQtyBadge(50),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(4.5),
              decoration: BoxDecoration(
                color: _surfaceAlt.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _stroke),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                size: 17,
                color: _ink900,
              ),
            ),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receipt Ledger Details',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Item Name', 'Deep Groove Ball Bearing 6205-2RS'),
                _buildDetailRow('Item Code', 'BRG-6205-2RS'),
                _buildDetailRow('Received Qty', '50 units'),
                _buildDetailRow('Rack Location', 'Rack R-08 (Shelf S-01)'),
                _buildDetailRow('Received By', 'Ashutosh Storekeeper'),
                _buildDetailRow('Received At', '15/10/2026 11:20 AM'),
                _buildDetailRow('Supplier Challan', 'CH-2026-8804 (NBC Bearings Ltd)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBadge(int qty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.add_circle_outline_rounded,
            size: 13,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(width: 4),
          Text(
            '+$qty',
            style: const TextStyle(
              color: Color(0xFF1B5E20),
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillBadge(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _ink700),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: _ink900,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: _ink600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink900,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
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
              Icon(Icons.verified_outlined, size: 18, color: Color(0xFF1B5E20)),
              SizedBox(width: 8),
              Text(
                'Inward Logistics Best Practices',
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
            '• Always cross-verify physical packet count with Supplier Challan before confirming.\n'
            '• Print and attach 57mm QR stickers onto carton bins immediately upon receipt.\n'
            '• Ensure destination rack assignment matches physical shelf coordinates.',
            style: TextStyle(color: _ink700, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW B: Goods Received Note (GRN) Inward Sheet / Modal Form
     ========================================================================= */

  Widget _buildInwardModalView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _stroke),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Modal Header Bar
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _accentMint.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _stroke),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
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
                              'Goods Receipt Note (GRN) Entry',
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Record incoming consignment & generate QR labels',
                              style: TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _handleCloseInwardModal,
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                        tooltip: 'Close Inward Form',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Step 2 Coachmark (if on Step 2)
                  if (_currentStep == 2) ...[
                    _buildCoachmarkCard(
                      stepNumber: 2,
                      title: 'Step 2: Log Challan & PO Reference',
                      message:
                          'Enter the delivery challan number, purchase order reference, and supplier name. Tap the highlighted "⚡ Autofill Sample Challan" button below to populate test data.',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Step 3 Coachmark (if on Step 3)
                  if (_currentStep == 3) ...[
                    _buildCoachmarkCard(
                      stepNumber: 3,
                      title: 'Step 3: Assign Destination Storage Rack',
                      message:
                          'Select the exact warehouse room and shelf rack where these goods will be stocked. Tap the highlighted "Rack R-12 (Shelf S-03)" selector below.',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Step 4 Coachmark (if on Step 4)
                  if (_currentStep == 4) ...[
                    _buildCoachmarkCard(
                      stepNumber: 4,
                      title: 'Step 4: Complete Inward & Generate Labels',
                      message:
                          'Tap the highlighted "Save Inward & Print Labels" button below to record stock into the ledger and generate thermal part barcode stickers.',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Card 1: Supplier & Challan Details
                  _buildChallanDetailsSection(),
                  const SizedBox(height: 14),

                  // Card 2: Material & Inward Quantity Details
                  _buildMaterialDetailsSection(),
                  const SizedBox(height: 14),

                  // Card 3: Storage Rack Allocation
                  _buildRackAllocationSection(),
                  const SizedBox(height: 14),

                  // Card 4: Verified Challan Attachment
                  _buildChallanAttachmentSection(),
                  const SizedBox(height: 18),

                  // Bottom Action Buttons
                  _buildModalActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* ---------------- Section 1: Challan Details ---------------- */

  Widget _buildChallanDetailsSection() {
    final isStep2 = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStep2 ? _accentAmberBorder : _stroke,
          width: isStep2 ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.description_outlined, size: 17, color: _ink900),
                  SizedBox(width: 8),
                  Text(
                    'Supplier & Delivery Challan',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              // Autofill sample button (Active on Step 2)
              _buildAutofillButton(isStep2),
            ],
          ),
          const SizedBox(height: 12),

          // Inputs Grid
          Row(
            children: [
              Expanded(
                child: _buildMockInputField(
                  label: 'Delivery Challan No *',
                  hint: 'e.g. CH-2026-9921',
                  controller: _challanCtrl,
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMockInputField(
                  label: 'Purchase Order (PO) *',
                  hint: 'e.g. PO-2026-089',
                  controller: _poCtrl,
                  icon: Icons.tag_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMockInputField(
            label: 'Supplier / Vendor Name *',
            hint: 'e.g. SKF Bearings India Ltd',
            controller: _supplierCtrl,
            icon: Icons.business_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildAutofillButton(bool isStep2) {
    final btn = FilledButton.icon(
      onPressed: _handleAutofillChallan,
      style: FilledButton.styleFrom(
        backgroundColor: isStep2 ? _accentAmber : _surfaceAlt,
        foregroundColor: isStep2 ? Colors.white : _ink900,
        elevation: isStep2 ? 3.0 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isStep2 ? _accentAmberBorder : _stroke,
            width: isStep2 ? 1.5 : 1.0,
          ),
        ),
      ),
      icon: Icon(
        Icons.bolt_rounded,
        size: 15,
        color: isStep2 ? Colors.white : const Color(0xFFD97706),
      ),
      label: Text(
        _isChallanFilled ? '✓ Challan Filled' : '⚡ Autofill: CH-2026-9921',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: isStep2 ? Colors.white : _ink900,
        ),
      ),
    );

    if (isStep2) {
      return ScaleTransition(
        scale: _pulseScale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _accentAmber.withValues(alpha: 0.50),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: btn,
        ),
      );
    }
    return btn;
  }

  Widget _buildMockInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _ink700,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _stroke),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: _ink600),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (v) {
                    if (v.isNotEmpty && _currentStep == 2) {
                      setState(() {
                        _isChallanFilled = true;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: _ink500, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    color: _ink900,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /* ---------------- Section 2: Material & Quantity ---------------- */

  Widget _buildMaterialDetailsSection() {
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
              Icon(Icons.inventory_2_outlined, size: 17, color: _ink900),
              SizedBox(width: 8),
              Text(
                'Consignment Item & Inward Quantity',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _accentMint.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(
                  Icons.settings_suggest_rounded,
                  color: _ink900,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tapered Roller Bearing 32208',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'SKU: BRG-32208-TRB · Category: Bearings & Transmission',
                      style: TextStyle(
                        color: _ink600,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Stock Calculation Pill
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildStatChip(
                          'Current Balance',
                          '$_initialStock PCS',
                          const Color(0xFF6B7280),
                          const Color(0xFFF3F4F6),
                        ),
                        _buildStatChip(
                          'Inwarding Today',
                          '+$_inwardQty PCS',
                          const Color(0xFF1B5E20),
                          const Color(0xFFE8F5E9),
                        ),
                        _buildStatChip(
                          'New Total Stock',
                          '${_initialStock + _inwardQty} PCS',
                          const Color(0xFF0D47A1),
                          const Color(0xFFE3F2FD),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color textCol, Color bgCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textCol.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: textCol,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textCol,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- Section 3: Storage Rack Allocation ---------------- */

  Widget _buildRackAllocationSection() {
    final isStep3 = _currentStep == 3;
    final isR12Selected = _selectedRack.contains('R-12') || _isRackAssigned;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isStep3 ? const Color(0xFFFFFBEB) : _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStep3 ? _accentAmberBorder : _stroke,
          width: isStep3 ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shelves, size: 17, color: _ink900),
              SizedBox(width: 8),
              Text(
                'Warehouse Storage Location *',
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
            'Assign the exact storage room and physical rack/shelf for fast item picking.',
            style: TextStyle(color: _ink600, fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Rack Options Row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              // Target Rack Option (Step 3 Target)
              _buildRackOptionPill(
                title: 'Rack R-12 (Shelf S-03)',
                room: 'Main Store Room',
                isSelected: isR12Selected,
                isHighlight: isStep3,
                onTap: () => _handleSelectRack('Rack R-12 (Shelf S-03)'),
              ),

              // Other rack options
              _buildRackOptionPill(
                title: 'Rack R-04 (Shelf S-01)',
                room: 'Main Store Room',
                isSelected: _selectedRack == 'Rack R-04 (Shelf S-01)',
                isHighlight: false,
                onTap: () => _handleSelectRack('Rack R-04 (Shelf S-01)'),
              ),
              _buildRackOptionPill(
                title: 'Rack R-09 (Shelf S-02)',
                room: 'Tool Crib Room',
                isSelected: _selectedRack == 'Rack R-09 (Shelf S-02)',
                isHighlight: false,
                onTap: () => _handleSelectRack('Rack R-09 (Shelf S-02)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRackOptionPill({
    required String title,
    required String room,
    required bool isSelected,
    required bool isHighlight,
    required VoidCallback onTap,
  }) {
    final pill = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlight
              ? _accentAmber
              : (isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFFAFAFA)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlight
                ? _accentAmberBorder
                : (isSelected ? const Color(0xFF2E7D32) : _stroke),
            width: isHighlight || isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.location_on_outlined,
              size: 16,
              color: isHighlight
                  ? Colors.white
                  : (isSelected ? const Color(0xFF2E7D32) : _ink700),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isHighlight
                        ? Colors.white
                        : (isSelected ? const Color(0xFF1B5E20) : _ink900),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  room,
                  style: TextStyle(
                    color: isHighlight
                        ? Colors.white.withValues(alpha: 0.85)
                        : _ink600,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isHighlight) {
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

  /* ---------------- Section 4: Verified Challan Attachment ---------------- */

  Widget _buildChallanAttachmentSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF0284C7),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Delivery Challan CH-2026-9921.pdf (Verified)',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Physical stamped receipt attached · 1.4 MB',
                  style: TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                SizedBox(width: 4),
                Text(
                  'ATTACHED',
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- Modal Action Buttons ---------------- */

  Widget _buildModalActionButtons() {
    final isStep4 = _currentStep == 4;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _handleCloseInwardModal,
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink700,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _stroke),
              ),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildSaveAndPrintButton(isStep4),
        ),
      ],
    );
  }

  Widget _buildSaveAndPrintButton(bool isStep4) {
    final btn = FilledButton.icon(
      onPressed: _isSubmitting ? null : _handleSaveInwardAndPrint,
      style: FilledButton.styleFrom(
        backgroundColor: isStep4 ? _accentAmber : const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: isStep4 ? 4.0 : 2.0,
        padding: const EdgeInsets.symmetric(vertical: 13),
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
          : const Icon(Icons.qr_code_2_rounded, size: 18),
      label: Text(
        _isSubmitting
            ? 'Recording Ledger...'
            : 'Save Inward & Print Labels ($_inwardQty PCS)',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
