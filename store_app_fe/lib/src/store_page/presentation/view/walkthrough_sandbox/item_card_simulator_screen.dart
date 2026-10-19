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

/// Interactive Training Sandbox for Feature F2:
/// Understanding Item Cards & Inventory Stock Counts (Discovery).
///
/// Replicates the authentic layout of [ItemsListPage] and [ItemListCard] with dual navigation sidebars,
/// live search and category filter, stock count breakdown pills (Total / Available / Issued / In Cart),
/// physical rack location coordinates, and action buttons (QR Code, Cart, Location, Details)
/// without altering live database records.
class ItemCardSimulatorScreen extends ConsumerStatefulWidget {
  const ItemCardSimulatorScreen({super.key});

  @override
  ConsumerState<ItemCardSimulatorScreen> createState() =>
      _ItemCardSimulatorScreenState();
}

class _ItemCardSimulatorScreenState extends ConsumerState<ItemCardSimulatorScreen>
    with SingleTickerProviderStateMixin {
  // Guided Walkthrough Steps:
  // 1 = Instant Search & Filters (itemSearchBarKey)
  // 2 = Real-Time Stock Counts (firstItemStockMetricsKey)
  // 3 = Physical Rack Location & Coordinates
  // 4 = Item Operations & QR Code Menu (firstItemActionsKey)
  int _currentStep = 1;
  static const int _totalSteps = 4;

  // Active top tab in Catalog:
  // 0 = Good Items, 1 = Scrap Items
  int _selectedCatalogTab = 0;

  // Search & Filter state
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All Categories';

  // In-memory demo simulation state
  int _inCartQuantity = 0;
  bool _isBreakdownModalOpen = false;
  bool _isLocationModalOpen = false;
  bool _isQrModalOpen = false;
  bool _isRateHistoryModalOpen = false;

  // Sample Item Master Data
  final String _itemName = 'V-BELT B-64 (Heavy Duty Cogged)';
  final String _itemCode = 'BLT-B64-COG';
  final String _category = 'Belts & Transmission';
  final String _unit = 'PCS';
  final int _totalStock = 45;
  final int _issuedStock = 15;
  final int _baseAvailable = 30;
  final int _minStock = 10;
  final String _room = 'Room 1 (Main Store)';
  final String _rack = 'Rack R-08';
  final String _shelf = 'Shelf S-01';

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
      _selectedCatalogTab = 0;
      _searchCtrl.clear();
      _selectedCategory = 'All Categories';
      _inCartQuantity = 0;
      _isBreakdownModalOpen = false;
      _isLocationModalOpen = false;
      _isQrModalOpen = false;
      _isRateHistoryModalOpen = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sandbox reset to initial state.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  int get _effectiveAvailable => (_baseAvailable - _inCartQuantity).clamp(0, 999);

  bool get _itemMatchesSearch {
    if (_selectedCatalogTab == 1) return false; // Scrap items tab is empty in this demo
    final q = _searchCtrl.text.trim().toLowerCase();
    final matchesCategory = _selectedCategory == 'All Categories' ||
        _category.toLowerCase() == _selectedCategory.toLowerCase();
    if (!matchesCategory) return false;
    if (q.isEmpty) return true;
    return _itemName.toLowerCase().contains(q) ||
        _itemCode.toLowerCase().contains(q) ||
        _category.toLowerCase().contains(q);
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

  void _handleAddToCart() {
    if (_effectiveAvailable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available units are currently allocated to cart in this demo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _inCartQuantity++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added 1 $_unit of $_itemName to Requisition Cart (Sandbox)'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleOpenDetailsBreakdown() {
    setState(() {
      _isBreakdownModalOpen = true;
      if (_currentStep == 2) {
        // user actively inspected stock details in step 2
      }
    });
  }

  void _handleOpenLocationFinder() {
    setState(() {
      _isLocationModalOpen = true;
      if (_currentStep == 3) {
        // user actively opened location finder in step 3
      }
    });
  }

  void _handleOpenQrModal() {
    setState(() {
      _isQrModalOpen = true;
      if (_currentStep == 4) {
        // step 4 completed
      }
    });
  }

  void _handleFinishTour() {
    showSimulatorCompletionDialog(
      context: context,
      tourTitle: 'F2: Understanding Item Cards & Stock Counts',
      description:
          'You mastered reading item cards: Total physical stock (45 PCS), Available unreserved inventory (30 PCS), Issued plant consumption (15 PCS), bin coordinates (Room 1 / Rack R-08 / Shelf S-01), search filtering, and generating thermal QR stickers!',
      onReplay: _resetScenario,
      onGoToLive: () {
        Navigator.pop(context); // Close simulator
        ref.read(guidedTourControllerProvider).requestSection('items');
      },
    );
  }

  String _getStepLabel() {
    switch (_currentStep) {
      case 1:
        return 'Instant Search & Filters';
      case 2:
        return 'Real-Time Stock Counts';
      case 3:
        return 'Physical Rack Location';
      case 4:
        return 'Item Operations & QR Menu';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreWalkthroughSimulatorShell(
      title: 'Item Cards & Inventory Stock Counts',
      currentStepLabel: _getStepLabel(),
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onExit: () => Navigator.pop(context),
      onReset: _resetScenario,
      child: Stack(
        children: [
          _buildRealStoreShellLayout(context),
          if (_isBreakdownModalOpen) _buildStockBreakdownModal(),
          if (_isLocationModalOpen) _buildLocationFinderModal(),
          if (_isQrModalOpen) _buildQrStickerModal(),
          if (_isRateHistoryModalOpen) _buildRateHistoryModal(),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW: Full Authentic Store App Layout (Matching ItemsListPage)
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

                  // Inner Navigation Sidebar (Dashboard, Items [Active], Find Item, Places)
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
                // Coachmark for current step
                _buildActiveStepCoachmark(),
                const SizedBox(height: 12),

                // Search & Filter Card (Spotlight for Step 1)
                _buildSearchAndFilterCard(),
                const SizedBox(height: 14),

                // Item List Area
                if (_itemMatchesSearch)
                  _buildSampleItemCard()
                else
                  _buildEmptySearchState(),
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
        title = 'Step 1 of 4: Instant Search & Filter Bar';
        message =
            'Quickly find materials in the master catalog by typing part names, SKU codes, or filtering by category. Notice how the search bar is highlighted below.';
        icon = Icons.search_rounded;
        break;
      case 2:
        title = 'Step 2 of 4: Real-Time Stock Counts';
        message =
            'Look at the highlighted stock pills on the item card below: "Available: $_effectiveAvailable" is ready to requisition, "In Cart: $_inCartQuantity", and tap "Details" to see the full breakdown of 45 Total and 15 Issued units.';
        icon = Icons.analytics_outlined;
        break;
      case 3:
        title = 'Step 3 of 4: Physical Warehouse Coordinates';
        message =
            'Every item card displays its physical storage coordinates: "$_room • $_rack • $_shelf". Tap "Find Location" on the card to see the visual bin map.';
        icon = Icons.location_on_outlined;
        break;
      case 4:
        title = 'Step 4 of 4: Item Actions & QR Code Menu';
        message =
            'Each card provides instant action controls: add to cart (+), print a thermal QR sticker, or view pricing history. Tap the highlighted QR Code button to complete training.';
        icon = Icons.qr_code_2_rounded;
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
     TOP TOOLBAR: Good Items vs Scrap Items Tabs & Action Buttons
     ========================================================================= */

  Widget _buildRealStoreHeaderCard() {
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
          // Segmented Tabs: Good Items (1) vs Scrap Items (0)
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedCatalogTab = 0),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedCatalogTab == 0 ? _ink900 : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _selectedCatalogTab == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Good Items (1)',
                            style: TextStyle(
                              color: _selectedCatalogTab == 0 ? Colors.white : _ink700,
                              fontWeight: _selectedCatalogTab == 0 ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedCatalogTab = 1),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedCatalogTab == 1 ? _ink900 : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Scrap Items (0)',
                            style: TextStyle(
                              color: _selectedCatalogTab == 1 ? Colors.white : _ink700,
                              fontWeight: _selectedCatalogTab == 1 ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Action Toolbar Icons
          _buildToolbarButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Catalog',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Catalog refreshed (Sandbox)'),
                  duration: Duration(milliseconds: 900),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          _buildToolbarButton(
            icon: Icons.file_download_rounded,
            tooltip: 'Export Catalog Excel',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Excel export simulated in training sandbox.'),
                  duration: Duration(milliseconds: 1200),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke),
            ),
            child: Icon(icon, size: 18, color: _ink900),
          ),
        ),
      ),
    );
  }

  /* =========================================================================
     SEARCH & FILTER CARD (Spotlight for Step 1)
     ========================================================================= */

  Widget _buildSearchAndFilterCard() {
    final bool isHighlighted = _currentStep == 1;

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
          // Step 1 Callout Banner (if highlighted)
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
                      'SPOTLIGHT: Search by keyword or filter category. Try typing "Belt" below.',
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

          // Search Field
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: _ink600),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() {}),
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search item by name, code or keyword (e.g. Belt, B-64)...',
                      hintStyle: TextStyle(
                        color: _ink500,
                        fontSize: 12.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                    child: const Icon(Icons.close_rounded, size: 18, color: _ink600),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Category Dropdown Filter Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _surfaceAlt.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _stroke),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _ink700),
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'All Categories',
                          child: Text('All Categories'),
                        ),
                        DropdownMenuItem(
                          value: 'Belts & Transmission',
                          child: Text('Belts & Transmission'),
                        ),
                        DropdownMenuItem(
                          value: 'Bearings & Bushings',
                          child: Text('Bearings & Bushings'),
                        ),
                        DropdownMenuItem(
                          value: 'Electrical & Automation',
                          child: Text('Electrical & Automation'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedCategory = v);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink700,
                  side: const BorderSide(color: _stroke),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    _searchCtrl.clear();
                    _selectedCategory = 'All Categories';
                  });
                },
                icon: const Icon(Icons.clear_all_rounded, size: 14),
                label: const Text('Reset', style: TextStyle(fontSize: 11.5)),
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
     SAMPLE ITEM CARD: Replicating [ItemListCard]
     ========================================================================= */

  Widget _buildSampleItemCard() {
    final bool highlightStock = _currentStep == 2;
    final bool highlightLocation = _currentStep == 3;
    final bool highlightActions = _currentStep == 4;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (highlightStock || highlightLocation || highlightActions)
              ? _accentAmberBorder
              : _stroke,
          width: (highlightStock || highlightLocation || highlightActions) ? 1.8 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 540;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Image / Icon Container
                  Container(
                    width: isNarrow ? 44 : 52,
                    height: isNarrow ? 44 : 52,
                    decoration: BoxDecoration(
                      color: _accentMint.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _stroke),
                    ),
                    child: Icon(
                      Icons.precision_manufacturing_rounded,
                      color: _ink900,
                      size: isNarrow ? 22 : 26,
                    ),
                  ),
                  SizedBox(width: isNarrow ? 8 : 12),

                  // Title, Tags & Details Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item Name + Status Chip + Indent Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                _itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                  fontSize: isNarrow ? 14 : 15,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Indent Requisition Icon
                            Tooltip(
                              message: 'Raise Indent Request',
                              child: Container(
                                padding: const EdgeInsets.all(4),
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
                            ),
                            const SizedBox(width: 6),
                            // Stock Status Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA5D6A7)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 10, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 3),
                                  Text(
                                    'IN STOCK',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Code + Category + Units Row
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
                              child: Text(
                                _itemCode,
                                style: const TextStyle(
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
                              child: Text(
                                'Min: $_minStock',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            ),

                            // Category
                            Text(
                              _category,
                              style: const TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),

                            // Unit
                            Text(
                              '• $_unit',
                              style: const TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Stock Metrics Row (Spotlight for Step 2)
                        _buildStockMetricsRow(highlightStock),
                        const SizedBox(height: 10),

                        // Location Tag & Find Location (Spotlight for Step 3)
                        _buildLocationCoordinatesRow(highlightLocation),
                      ],
                    ),
                  ),

                  // Desktop action buttons on right side
                  if (!isNarrow) ...[
                    const SizedBox(width: 10),
                    _buildActionButtonsGroup(highlightActions),
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
                  child: _buildActionButtonsGroup(highlightActions),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /* =========================================================================
     STOCK METRICS ROW: Total, Available, In Cart, Details (Spotlight 2)
     ========================================================================= */

  Widget _buildStockMetricsRow(bool isHighlighted) {
    Widget content = Container(
      padding: isHighlighted ? const EdgeInsets.all(6) : EdgeInsets.zero,
      decoration: isHighlighted
          ? BoxDecoration(
              color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentAmberBorder, width: 1.5),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHighlighted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: _accentAmber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SPOTLIGHT: Real-Time Stock Balance Breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              // 1. Available Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xE8E8F5E9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 3.5),
                    Text(
                      'Available: $_effectiveAvailable',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. In Cart Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _inCartQuantity > 0 ? const Color(0xFFE3F2FD) : _surfaceAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _inCartQuantity > 0 ? const Color(0xFF90CAF9) : _stroke,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 11,
                      color: _inCartQuantity > 0 ? const Color(0xFF1565C0) : _ink700,
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      'In Cart: $_inCartQuantity',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: _inCartQuantity > 0 ? FontWeight.w800 : FontWeight.w700,
                        color: _inCartQuantity > 0 ? const Color(0xFF1565C0) : _ink700,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Plant Issued Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCE93D8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.outbox_rounded, size: 11, color: Color(0xFF7B1FA2)),
                    const SizedBox(width: 3.5),
                    Text(
                      'Issued to Plant: $_issuedStock',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7B1FA2),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Details Sheet Trigger
              Tooltip(
                message: 'View full department activity, plant issuance & inventory balance',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _handleOpenDetailsBreakdown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _surfaceAlt.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _stroke),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_edu_rounded, size: 12, color: _ink900),
                          SizedBox(width: 3.5),
                          Text(
                            'Details (Total: 45)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _ink900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

  /* =========================================================================
     LOCATION COORDINATES ROW: Room, Rack, Shelf (Spotlight 3)
     ========================================================================= */

  Widget _buildLocationCoordinatesRow(bool isHighlighted) {
    Widget content = Container(
      padding: isHighlighted ? const EdgeInsets.all(6) : const EdgeInsets.symmetric(vertical: 4),
      decoration: isHighlighted
          ? BoxDecoration(
              color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentAmberBorder, width: 1.5),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHighlighted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: _accentAmber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SPOTLIGHT: Physical Warehouse Coordinates',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              // Rack & Shelf Badge
              Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warehouse_rounded, size: 12, color: Color(0xFF334155)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$_room • $_rack • $_shelf',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Find Location Button
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _handleOpenLocationFinder,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_searching_rounded, size: 12, color: Color(0xFF047857)),
                      SizedBox(width: 4),
                      Text(
                        'Find Location Map',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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

  /* =========================================================================
     ACTION BUTTONS GROUP: Cart, QR Code, Rates, Specs (Spotlight 4)
     ========================================================================= */

  Widget _buildActionButtonsGroup(bool isHighlighted) {
    Widget content = Container(
      padding: isHighlighted ? const EdgeInsets.all(4) : EdgeInsets.zero,
      decoration: isHighlighted
          ? BoxDecoration(
              color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentAmberBorder, width: 1.5),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isHighlighted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: _accentAmber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SPOTLIGHT: Action Controls & QR Printing',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              // Add to Cart Button
              _ActionIconButton(
                icon: _inCartQuantity > 0
                    ? Icons.shopping_cart_rounded
                    : Icons.add_shopping_cart_rounded,
                tooltip: _inCartQuantity > 0
                    ? 'In Cart ($_inCartQuantity) — Click to add +1'
                    : 'Add to Requisition Cart',
                color: _inCartQuantity > 0 ? const Color(0xFFE8F5E9) : null,
                iconColor: _inCartQuantity > 0 ? const Color(0xFF2E7D32) : null,
                onTap: _handleAddToCart,
              ),

              // QR Code Print Button (Spotlight target)
              _ActionIconButton(
                icon: Icons.qr_code_2_rounded,
                tooltip: 'Print QR Sticker',
                color: isHighlighted ? const Color(0xFFFEF3C7) : null,
                iconColor: isHighlighted ? const Color(0xFFB45309) : null,
                onTap: _handleOpenQrModal,
              ),

              // Rate History Button
              _ActionIconButton(
                icon: Icons.currency_rupee_rounded,
                tooltip: 'Rate History',
                onTap: () {
                  setState(() => _isRateHistoryModalOpen = true);
                },
              ),

              // Edit Specifications Button
              _ActionIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit Specifications',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Specification editing covered in Tour F1.'),
                      duration: Duration(milliseconds: 1400),
                    ),
                  );
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
        child: content,
      );
    }
    return content;
  }

  Widget _buildEmptySearchState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: _ink500),
          const SizedBox(height: 12),
          Text(
            _selectedCatalogTab == 1
                ? 'No scrap items found in demo catalog.'
                : 'No items match "${_searchCtrl.text}".',
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () {
              setState(() {
                _selectedCatalogTab = 0;
                _searchCtrl.clear();
                _selectedCategory = 'All Categories';
              });
            },
            icon: const Icon(Icons.restore_rounded, size: 16),
            label: const Text('Reset Search & Tab'),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     MODAL 1: Stock Activity Breakdown Sheet
     ========================================================================= */

  Widget _buildStockBreakdownModal() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Color(0xFF1D4ED8), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stock Breakdown & Activity',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$_itemName ($_itemCode)',
                            style: const TextStyle(color: _ink600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink900),
                      onPressed: () => setState(() => _isBreakdownModalOpen = false),
                    ),
                  ],
                ),
                const Divider(height: 20, color: _stroke),
                _buildBreakdownRow(
                  title: 'Total Physical Inventory in Store',
                  quantity: '$_totalStock $_unit',
                  color: _ink900,
                  icon: Icons.inventory_2_rounded,
                  description: 'All units received via verified GRN and placed on shelves.',
                ),
                const SizedBox(height: 10),
                _buildBreakdownRow(
                  title: 'Currently Issued to Shopfloor',
                  quantity: '$_issuedStock $_unit',
                  color: const Color(0xFF7B1FA2),
                  icon: Icons.outbox_rounded,
                  description: 'Active in production equipment: Line 1 (10 PCS), Packaging (5 PCS).',
                ),
                const SizedBox(height: 10),
                _buildBreakdownRow(
                  title: 'Net Available for Requisitions',
                  quantity: '$_effectiveAvailable $_unit',
                  color: const Color(0xFF2E7D32),
                  icon: Icons.check_circle_outline,
                  description: 'Unreserved stock ready for dispatch to maintenance & plant teams.',
                ),
                if (_inCartQuantity > 0) ...[
                  const SizedBox(height: 10),
                  _buildBreakdownRow(
                    title: 'Active Holds in User Carts',
                    quantity: '$_inCartQuantity $_unit',
                    color: const Color(0xFF1565C0),
                    icon: Icons.shopping_cart_outlined,
                    description: 'Reserved in current session shopping cart.',
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => setState(() => _isBreakdownModalOpen = false),
                  child: const Text('Close Breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String title,
    required String quantity,
    required Color color,
    required IconData icon,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      quantity,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: _ink600, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     MODAL 2: Location Map Finder Modal
     ========================================================================= */

  Widget _buildLocationFinderModal() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF059669), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Visual Bin Locator (Warehouse Map)',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink900),
                      onPressed: () => setState(() => _isLocationModalOpen = false),
                    ),
                  ],
                ),
                const Divider(height: 20, color: _stroke),

                // Location Coordinates Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place_rounded, color: Color(0xFF334155), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Zone: $_room',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Specific Bin: $_rack • Shelf: $_shelf',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CONFIRMED',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Visual Rack Graphic
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _stroke),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Aisle 2 - Mechanical Drive Storage',
                        style: TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(child: _buildRackColumn(title: 'R-07', isTarget: false)),
                          const SizedBox(width: 6),
                          Expanded(child: _buildRackColumn(title: 'R-08 (Target)', isTarget: true)),
                          const SizedBox(width: 6),
                          Expanded(child: _buildRackColumn(title: 'R-09', isTarget: false)),
                        ],
                      ),
                    ],
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
                  onPressed: () => setState(() => _isLocationModalOpen = false),
                  child: const Text('Dismiss Location View', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRackColumn({required String title, required bool isTarget}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isTarget ? const Color(0xFFFEF3C7) : _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTarget ? _accentAmberBorder : _stroke,
          width: isTarget ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isTarget ? const Color(0xFF92400E) : _ink900,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: isTarget ? _accentAmber : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              isTarget ? 'S-01 [HERE]' : 'S-01',
              style: TextStyle(
                color: isTarget ? Colors.white : _ink700,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: const Text(
              'S-02',
              style: TextStyle(color: _ink600, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     MODAL 3: Thermal QR Sticker Print Preview (STRICTLY NO BARCODES)
     ========================================================================= */

  Widget _buildQrStickerModal() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
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
                            'Thermal QR Sticker Preview',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Standard 50mm x 30mm Shelf & Bin Tag',
                            style: TextStyle(color: _ink600, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink900),
                      onPressed: () => setState(() => _isQrModalOpen = false),
                    ),
                  ],
                ),
                const Divider(height: 20, color: _stroke),

                // Physical Thermal Sticker Representation
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x15000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 2D QR Code Matrix Representation
                            Container(
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black, width: 1.5),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: CustomPaint(
                                painter: _QrCodeMatrixPainter(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _itemCode,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _itemName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: Colors.black,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'LOC: $_rack / $_shelf',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10.5,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'UNIT: $_unit • MIN: $_minStock',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black87,
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
                ),
                const SizedBox(height: 16),

                const Text(
                  'Storekeepers scan this thermal QR sticker with their mobile camera to instantly verify stock, location, and issue items.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _ink600, fontSize: 12),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink900,
                          side: const BorderSide(color: _stroke),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() => _isQrModalOpen = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Simulated printing thermal QR sticker to store label printer.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Sticker'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentAmber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        onPressed: () {
                          setState(() => _isQrModalOpen = false);
                          _handleFinishTour();
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Complete Training', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* =========================================================================
     MODAL 4: Rate History Sheet
     ========================================================================= */

  Widget _buildRateHistoryModal() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
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
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFD97706), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Item Procurement Rate History',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink900),
                      onPressed: () => setState(() => _isRateHistoryModalOpen = false),
                    ),
                  ],
                ),
                const Divider(height: 20, color: _stroke),
                _buildRateEntry(
                  date: '12 Oct 2026',
                  po: 'PO-2026-0891',
                  vendor: 'Continental Belts Ltd.',
                  rate: '₹ 450.00 / PCS',
                  qty: '20 PCS',
                ),
                const SizedBox(height: 8),
                _buildRateEntry(
                  date: '15 Aug 2026',
                  po: 'PO-2026-0742',
                  vendor: 'Apex Transmission Works',
                  rate: '₹ 440.00 / PCS',
                  qty: '25 PCS',
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => setState(() => _isRateHistoryModalOpen = false),
                  child: const Text('Close Rates', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRateEntry({
    required String date,
    required String po,
    required String vendor,
    required String rate,
    required String qty,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendor, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _ink900)),
                Text('$po • $date', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _ink600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rate, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF2E7D32))),
              Text(qty, style: const TextStyle(fontSize: 11, color: _ink600)),
            ],
          ),
        ],
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
          _buildInnerNavItem(icon: Icons.inventory_2_rounded, label: 'Items Catalog', isActive: true),
          const SizedBox(height: 6),
          _buildInnerNavItem(icon: Icons.location_searching_rounded, label: 'Find Item', isActive: false),
          const SizedBox(height: 6),
          _buildInnerNavItem(icon: Icons.warehouse_rounded, label: 'Places / Racks', isActive: false),
        ],
      ),
    );
  }

  Widget _buildInnerNavItem({required IconData icon, required String label, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? _ink900 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? Colors.white : _ink700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _ink900,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
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
          Icon(Icons.inventory_2_rounded, color: _ink900, size: 24),
          Icon(Icons.location_searching_rounded, color: _ink600, size: 22),
          Icon(Icons.warehouse_rounded, color: _ink600, size: 22),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------------------------
   CUSTOM PAINTER: High-Resolution 2D QR Code Matrix (STRICTLY NO BARCODES)
   -------------------------------------------------------------------------- */
class _QrCodeMatrixPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBlack = Paint()..color = Colors.black..style = PaintingStyle.fill;

    // Corner QR Registration Eye 1 (Top-Left)
    _drawQrEye(canvas, const Offset(0, 0), 22, paintBlack);

    // Corner QR Registration Eye 2 (Top-Right)
    _drawQrEye(canvas, Offset(size.width - 22, 0), 22, paintBlack);

    // Corner QR Registration Eye 3 (Bottom-Left)
    _drawQrEye(canvas, Offset(0, size.height - 22), 22, paintBlack);

    // Simulated QR Data Modules Grid (2D Data Matrix)
    const gridSize = 11;
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    // Fixed deterministic matrix pattern for BLT-B64-COG
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
        // Skip corner eyes areas
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
    // Outer black box
    canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, size, size), paint);
    // Inner white gap
    final paintWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(offset.dx + 4, offset.dy + 4, size - 8, size - 8), paintWhite);
    // Center black dot
    canvas.drawRect(Rect.fromLTWH(offset.dx + 7, offset.dy + 7, size - 14, size - 14), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/* --------------------------------------------------------------------------
   ACTION ICON BUTTON COMPONENT: Matching [ItemListCard]
   -------------------------------------------------------------------------- */
class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: _ink900.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color ?? _surfaceAlt.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor ?? _ink900, size: 18),
          ),
        ),
      ),
    );
  }
}
