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

/// Interactive Training Sandbox for Feature F5:
/// Finding Items & Shelf Locators (Inventory Navigation).
///
/// Replicates the authentic layout of [FindItemPage] with dual navigation sidebars,
/// live keyword/SKU search input, instant matching item selection,
/// precise warehouse bin coordinates (Building B -> Ground Floor -> Room 1 -> Rack R-12 -> Shelf S-03),
/// real-time available stock verification (28 PCS Available), and smart single/multi-location allocation
/// without altering live database records.
class ItemLocatorSimulatorScreen extends ConsumerStatefulWidget {
  const ItemLocatorSimulatorScreen({super.key});

  @override
  ConsumerState<ItemLocatorSimulatorScreen> createState() =>
      _ItemLocatorSimulatorScreenState();
}

class _ItemLocatorSimulatorScreenState
    extends ConsumerState<ItemLocatorSimulatorScreen>
    with SingleTickerProviderStateMixin {
  // Guided Walkthrough Steps:
  // 1 = Store Locator Tool (Find Item Navigation Tab)
  // 2 = Search by Name or SKU (findItemSearchBarKey)
  // 3 = Precise Location Coordinates (firstFindItemLocationKey)
  // 4 = Check Stock Before Walking (firstFindItemStockPillKey)
  int _currentStep = 1;
  static const int _totalSteps = 4;

  // Search & Qty state
  final TextEditingController _searchCtrl = TextEditingController(text: 'BEARING 6204');
  final TextEditingController _qtyCtrl = TextEditingController();
  int? _requiredQty;

  // Selected item state (Initial resolved item is Ball Bearing 6204)
  bool _isItemSelected = true;
  bool _isQrScanModalOpen = false;

  // Sample Mock Item Data
  final String _itemName = 'Deep Groove Ball Bearing 6204 - 2RS';
  final String _itemCode = 'BRG-6204-2RS';
  final String _category = 'Bearings & Bushings';
  final String _unit = 'PCS';
  final int _totalAvailable = 28;
  final String _building = 'Building B (Heavy Machine Bay)';
  final String _floor = 'Ground Floor';
  final String _room = 'Room 1 (Main Spares Store)';
  final String _rack = 'Rack R-12';
  final String _shelf = 'Shelf S-03';

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
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _resetScenario() {
    setState(() {
      _currentStep = 1;
      _searchCtrl.text = 'BEARING 6204';
      _qtyCtrl.clear();
      _requiredQty = null;
      _isItemSelected = true;
      _isQrScanModalOpen = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sandbox reset to initial state.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  void _goToNextStep() {
    setState(() {
      if (_currentStep < _totalSteps) {
        _currentStep++;
      } else {
        _handleFinishTour();
      }
    });
  }

  void _goToPreviousStep() {
    setState(() {
      if (_currentStep > 1) {
        _currentStep--;
      }
    });
  }

  void _handleOpenQrPlacard() {
    setState(() {
      _isQrScanModalOpen = true;
    });
  }

  void _handleFinishTour() {
    showSimulatorCompletionDialog(
      context: context,
      tourTitle: 'F5: Finding Items & Shelf Locators (Inventory Navigation)',
      description:
          'You mastered the Store Locator tool: searching any part by name or code, inspecting exact multi-level warehouse coordinates ($_building -> $_room -> $_rack -> $_shelf), and verifying unreserved available stock ($_totalAvailable PCS) before walking to the physical store!',
      onReplay: _resetScenario,
      onGoToLive: () {
        Navigator.pop(context); // Close simulator
        ref.read(guidedTourControllerProvider).requestSection('find_item');
      },
    );
  }

  String _getStepLabel() {
    switch (_currentStep) {
      case 1:
        return 'Store Locator Tool';
      case 2:
        return 'Search by Name or SKU';
      case 3:
        return 'Precise Location Coordinates';
      case 4:
        return 'Check Stock Before Walking';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreWalkthroughSimulatorShell(
      title: 'Store Item Locator & Bin Coordinates',
      currentStepLabel: _getStepLabel(),
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onExit: () => Navigator.pop(context),
      onReset: _resetScenario,
      child: Stack(
        children: [
          _buildRealStoreShellLayout(context),
          if (_isQrScanModalOpen) _buildShelfQrPlacardModal(),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW: Full Authentic Store App Layout (Matching FindItemPage)
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

                  // Inner Navigation Sidebar (Dashboard, Items, Find Item [Spotlight Step 1], Places)
                  _buildInnerStoreNav(),
                  const SizedBox(width: 12),

                  // Main Find Item Content Area
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
        // 1. Header Card
        _buildFindItemHeaderCard(),
        const SizedBox(height: 10),

        // 2. Scrollable Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coachmark for active step
                _buildActiveStepCoachmark(),
                const SizedBox(height: 12),

                // Search Bar Card (Spotlight for Step 2)
                _buildSearchBarCard(),
                const SizedBox(height: 14),

                // Main Locator Workspace (Matching items list on left & coordinates card on right)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth >= 760;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel: Matching Items
                          Expanded(
                            flex: 4,
                            child: _buildMatchingItemsListSection(),
                          ),
                          const SizedBox(width: 14),

                          // Right Panel: Coordinates & Stock Details (Spotlight for Steps 3 & 4)
                          Expanded(
                            flex: 5,
                            child: _buildLocationAndStockDetailSection(),
                          ),
                        ],
                      );
                    }

                    // Mobile / narrow layout
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLocationAndStockDetailSection(),
                        const SizedBox(height: 14),
                        _buildMatchingItemsListSection(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /* =========================================================================
     COACHMARK BANNER: Active Guidance Card
     ========================================================================= */

  Widget _buildActiveStepCoachmark() {
    String title = '';
    String message = '';
    IconData icon = Icons.info_outline_rounded;

    switch (_currentStep) {
      case 1:
        title = 'Step 1 of 4: Store Locator Tool';
        message =
            'Access "Find Item" to quickly locate any spare part, tool, or consumable across all store rooms. Notice "Find Item" is highlighted in the navigation bar.';
        icon = Icons.saved_search_rounded;
        break;
      case 2:
        title = 'Step 2 of 4: Search by Name or SKU';
        message =
            'Type any part name or SKU code in the highlighted search bar. Live matches will instantly appear with current warehouse stock levels.';
        icon = Icons.search_rounded;
        break;
      case 3:
        title = 'Step 3 of 4: Precise Location Coordinates';
        message =
            'Inspect the highlighted Location Coordinates card: $_building • $_room • $_rack • $_shelf. Walk directly to the exact shelf bin without asking warehouse staff.';
        icon = Icons.place_rounded;
        break;
      case 4:
        title = 'Step 4 of 4: Check Stock Before Walking';
        message =
            'Notice the highlighted Stock Pill: "$_totalAvailable PCS Available". Always verify that unreserved stock exists before walking across the plant to retrieve the item.';
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentAmberBorder.withValues(alpha: 0.5), width: 1.4),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Icon(icon, color: const Color(0xFFB45309), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Step $_currentStep / $_totalSteps',
                        style: const TextStyle(
                          color: _accentAmberBorder,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: _ink700,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (_currentStep > 1) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink700,
                          side: const BorderSide(color: _stroke),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _goToPreviousStep,
                        icon: const Icon(Icons.arrow_back, size: 14),
                        label: const Text('Previous', style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentAmber,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _goToNextStep,
                      icon: Icon(
                        _currentStep == _totalSteps ? Icons.check_circle_outline : Icons.arrow_forward,
                        size: 14,
                      ),
                      label: Text(
                        _currentStep == _totalSteps ? 'Finish Walkthrough' : 'Next Step ➔',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     TOP TOOLBAR: Find Item Title & Quick Helpers
     ========================================================================= */

  Widget _buildFindItemHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(10),
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
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_searching_rounded, size: 16, color: _ink900),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Physical Store Item Locator',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: _ink900),
            tooltip: 'Reset Search',
            onPressed: _resetScenario,
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     SEARCH BAR CARD: Instant Part/SKU Search (Spotlight Step 2)
     ========================================================================= */

  Widget _buildSearchBarCard() {
    final bool isHighlighted = _currentStep == 2;

    Widget cardBody = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? _accentAmberBorder : _stroke,
          width: isHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isHighlighted)
            const BoxShadow(
              color: Color(0x55F59E0B),
              blurRadius: 14,
              spreadRadius: 2,
            )
          else
            const BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isHighlighted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _pulseScale,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _accentAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'SPOTLIGHT: Type any part name or SKU to view real-time shelf location.',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _goToNextStep,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accentAmber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Next ➔',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              const Icon(Icons.search_rounded, size: 22, color: _ink600),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {}),
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search item by name or code (e.g. BEARING 6204)...',
                    hintStyle: TextStyle(color: _ink500, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: _ink600),
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _isItemSelected = false;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: cardBody,
      );
    }
    return cardBody;
  }

  /* =========================================================================
     MATCHING ITEMS SECTION: Left Panel List
     ========================================================================= */

  Widget _buildMatchingItemsListSection() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: _ink900),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Matching Catalog Items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '1 found',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: _ink700),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: _stroke),

          // Primary Item Match Card
          InkWell(
            onTap: () => setState(() => _isItemSelected = true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isItemSelected ? _accentMint.withValues(alpha: 0.25) : _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isItemSelected ? _ink900 : _stroke,
                  width: _isItemSelected ? 1.6 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isItemSelected ? _ink900 : _surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isItemSelected ? Icons.check_rounded : Icons.precision_manufacturing_rounded,
                      color: _isItemSelected ? Colors.white : _ink900,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_itemCode • $_category',
                          style: const TextStyle(color: _ink600, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Text(
                      '$_totalAvailable $_unit',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     LOCATION & STOCK DETAIL SECTION: Right Panel (Spotlight Steps 3 & 4)
     ========================================================================= */

  Widget _buildLocationAndStockDetailSection() {
    final bool highlightLocation = _currentStep == 3;
    final bool highlightStock = _currentStep == 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Item Header Overview Card
        _buildItemSummaryCard(highlightStock),
        const SizedBox(height: 12),

        // 2. Required Quantity Fulfillment Calculator
        _buildQuantityFulfillmentCalculator(),
        const SizedBox(height: 12),

        // 3. Storage Coordinates & Shelf Location Card (Spotlight Step 3)
        _buildStorageCoordinatesCard(highlightLocation),
      ],
    );
  }

  Widget _buildItemSummaryCard(bool isHighlighted) {
    Widget content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? _accentAmberBorder : _stroke,
          width: isHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isHighlighted)
            const BoxShadow(
              color: Color(0x55F59E0B),
              blurRadius: 14,
              spreadRadius: 2,
            )
          else
            const BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHighlighted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _accentAmber,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'SPOTLIGHT: Real-Time Available Stock Balance',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 440;

              final infoColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Part SKU: $_itemCode • Unit: $_unit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _ink600, fontSize: 12),
                  ),
                ],
              );

              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Text(
                      '$_totalAvailable $_unit Available',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoColumn,
                    const SizedBox(height: 8),
                    badge,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: infoColumn),
                  const SizedBox(width: 8),
                  badge,
                ],
              );
            },
          ),
        ],
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

  Widget _buildQuantityFulfillmentCalculator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          final labelRow = const Row(
            children: [
              Icon(Icons.calculate_outlined, size: 20, color: _ink700),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Required Qty Calculator:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _ink900),
                ),
              ),
            ],
          );

          final inputRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 75,
                height: 34,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  onChanged: (v) {
                    setState(() {
                      _requiredQty = int.tryParse(v.trim());
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Qty',
                    hintStyle: const TextStyle(color: _ink500, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    filled: true,
                    fillColor: _surfaceAlt.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  _requiredQty == null
                      ? 'Fulfillable'
                      : (_requiredQty! <= _totalAvailable
                          ? 'Single Bin OK'
                          : 'Stock Low'),
                  style: TextStyle(
                    color: _requiredQty != null && _requiredQty! > _totalAvailable
                        ? const Color(0xFFC62828)
                        : const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelRow,
                const SizedBox(height: 8),
                inputRow,
              ],
            );
          }

          return Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 20, color: _ink700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Required Qty Calculator:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _ink900),
                ),
              ),
              const SizedBox(width: 8),
              inputRow,
            ],
          );
        },
      ),
    );
  }

  /* =========================================================================
     STORAGE COORDINATES CARD: Multi-Level Coordinates (Spotlight Step 3)
     ========================================================================= */

  Widget _buildStorageCoordinatesCard(bool isHighlighted) {
    Widget cardBody = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? _accentAmberBorder : _stroke,
          width: isHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isHighlighted)
            const BoxShadow(
              color: Color(0x55F59E0B),
              blurRadius: 14,
              spreadRadius: 2,
            )
          else
            const BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isHighlighted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _pulseScale,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _accentAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'SPOTLIGHT: Walk directly to this room, rack, and shelf bin.',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.place_rounded, color: Color(0xFF047857), size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Verified Bin Coordinates',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CONFIRMED BIN',
                  style: TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w900,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Breadcrumb Coordinates Flow
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: Column(
              children: [
                _buildCoordinateBreadcrumb(
                  level: 'FACILITY BUILDING',
                  value: _building,
                  icon: Icons.domain_rounded,
                ),
                const SizedBox(height: 8),
                _buildCoordinateBreadcrumb(
                  level: 'FLOOR LEVEL',
                  value: _floor,
                  icon: Icons.layers_rounded,
                ),
                const SizedBox(height: 8),
                _buildCoordinateBreadcrumb(
                  level: 'STORAGE ROOM',
                  value: _room,
                  icon: Icons.meeting_room_rounded,
                ),
                const SizedBox(height: 8),
                _buildCoordinateBreadcrumb(
                  level: 'RACK IDENTIFIER',
                  value: '$_rack (Aisle 02 - Mechanical Spares)',
                  icon: Icons.storage_rounded,
                ),
                const SizedBox(height: 8),
                _buildCoordinateBreadcrumb(
                  level: 'SHELF BIN CODE',
                  value: '$_shelf (Bin 03 - Eye Level)',
                  icon: Icons.view_in_ar_rounded,
                  isTarget: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Button: Inspect Shelf QR Placard
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _handleOpenQrPlacard,
            icon: const Icon(Icons.qr_code_2_rounded, size: 16),
            label: const Text('Inspect Shelf QR Placard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: cardBody,
      );
    }
    return cardBody;
  }

  Widget _buildCoordinateBreadcrumb({
    required String level,
    required String value,
    required IconData icon,
    bool isTarget = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isTarget ? const Color(0xFFD97706) : _ink600),
        const SizedBox(width: 8),
        Text(
          '$level:',
          style: TextStyle(
            color: isTarget ? const Color(0xFF92400E) : _ink600,
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isTarget ? const Color(0xFF92400E) : _ink900,
              fontWeight: isTarget ? FontWeight.w900 : FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }



  /* =========================================================================
     MODAL 2: Shelf QR Placard Preview (STRICTLY NO BARCODES)
     ========================================================================= */

  Widget _buildShelfQrPlacardModal() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFB45309), size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shelf Bin QR Placard',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Scan with Store App to Verify Item',
                            style: TextStyle(color: _ink600, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink900),
                      onPressed: () => setState(() => _isQrScanModalOpen = false),
                    ),
                  ],
                ),
                const Divider(height: 20, color: _stroke),

                Center(
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$_rack • $_shelf',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: CustomPaint(
                            painter: _LocatorQrPainter(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _itemCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _itemName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => setState(() => _isQrScanModalOpen = false),
                  child: const Text('Dismiss Placard', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* =========================================================================
     SIDEBAR NAVIGATION: Authentic Desktop Dual Navigation
     ========================================================================= */

  Widget _buildOuterStoreNav() {
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 14),
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
      child: Column(
        children: [
          _buildOuterNavItem(icon: Icons.move_to_inbox_rounded, label: 'Receive', isActive: false),
          const SizedBox(height: 16),
          _buildOuterNavItem(icon: Icons.outbox_rounded, label: 'Issue', isActive: false),
          const SizedBox(height: 16),
          _buildOuterNavItem(icon: Icons.assignment_return_rounded, label: 'Return', isActive: false),
        ],
      ),
    );
  }

  Widget _buildOuterNavItem({required IconData icon, required String label, required bool isActive}) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive ? _ink900 : _surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? _ink900 : _stroke),
          ),
          child: Icon(icon, color: isActive ? Colors.white : _ink700, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? _ink900 : _ink600,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInnerStoreNav() {
    final bool highlightFindItem = _currentStep == 1;

    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInnerNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', isActive: false),
          const SizedBox(height: 6),
          _buildInnerNavItem(icon: Icons.inventory_2_rounded, label: 'Items Catalog', isActive: false),
          const SizedBox(height: 6),
          _buildInnerNavItem(
            icon: Icons.location_searching_rounded,
            label: 'Find Item',
            isActive: true,
            isHighlighted: highlightFindItem,
          ),
          const SizedBox(height: 6),
          _buildInnerNavItem(icon: Icons.warehouse_rounded, label: 'Places / Racks', isActive: false),
        ],
      ),
    );
  }

  Widget _buildInnerNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isHighlighted = false,
  }) {
    Widget item = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? _accentAmber
            : (isActive ? _ink900 : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        border: isHighlighted
            ? Border.all(color: _accentAmberBorder, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: (isActive || isHighlighted) ? Colors.white : _ink700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: (isActive || isHighlighted) ? Colors.white : _ink900,
                fontWeight: (isActive || isHighlighted) ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    if (isHighlighted) {
      return ScaleTransition(
        scale: _pulseScale,
        child: item,
      );
    }
    return item;
  }

  Widget _buildMobileBottomNav() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _stroke),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.dashboard_outlined, color: _ink600, size: 22),
          Icon(Icons.inventory_2_rounded, color: _ink600, size: 22),
          Icon(Icons.location_searching_rounded, color: _ink900, size: 24),
          Icon(Icons.warehouse_rounded, color: _ink600, size: 22),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------------------------
   CUSTOM PAINTER: High-Resolution 2D QR Code Matrix for Shelf Locator
   (STRICTLY 2D QR CODE, NO LINEAR BARCODES)
   -------------------------------------------------------------------------- */
class _LocatorQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBlack = Paint()..color = Colors.black..style = PaintingStyle.fill;

    // Corner QR Registration Eye 1 (Top-Left)
    _drawQrEye(canvas, const Offset(0, 0), 22, paintBlack);

    // Corner QR Registration Eye 2 (Top-Right)
    _drawQrEye(canvas, Offset(size.width - 22, 0), 22, paintBlack);

    // Corner QR Registration Eye 3 (Bottom-Left)
    _drawQrEye(canvas, Offset(0, size.height - 22), 22, paintBlack);

    // Simulated 2D QR Matrix Data Modules for BRG-6204-2RS
    const gridSize = 11;
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    final matrix = [
      [0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0],
      [0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0],
      [1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1],
      [0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0],
      [1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1],
      [0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0],
      [1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 1],
      [0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0],
      [0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0],
      [1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1],
      [0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0],
    ];

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if ((r < 3 && c < 3) || (r < 3 && c > 7) || (r > 7 && c < 3)) {
          continue;
        }
        if (matrix[r][c] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellW + 0.5, r * cellH + 0.5, cellW - 1, cellH - 1),
            paintBlack,
          );
        }
      }
    }
  }

  void _drawQrEye(Canvas canvas, Offset offset, double size, Paint paint) {
    canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, size, size), paint);
    final paintWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(offset.dx + 4, offset.dy + 4, size - 8, size - 8), paintWhite);
    canvas.drawRect(Rect.fromLTWH(offset.dx + 7, offset.dy + 7, size - 14, size - 14), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
