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

/// Interactive Training Sandbox for Feature F1:
/// Creating & Editing Store Items (Master Catalog Setup).
///
/// Replicates the authentic layout of [ItemsListPage] with dual navigation sidebars,
/// search/filters, the full-fidelity item registration form (+ Add Item),
/// and the item specification edit workflow without touching production database collections.
class ItemCreationSimulatorScreen extends ConsumerStatefulWidget {
  const ItemCreationSimulatorScreen({super.key});

  @override
  ConsumerState<ItemCreationSimulatorScreen> createState() =>
      _ItemCreationSimulatorScreenState();
}

class _ItemCreationSimulatorScreenState
    extends ConsumerState<ItemCreationSimulatorScreen>
    with SingleTickerProviderStateMixin {
  // Guided Walkthrough Steps:
  // 1 = Tap "+ Add Item" Button
  // 2 = Define Part Name, SKU & Unit
  // 3 = Assign Category & Storage Shelf
  // 4 = Attach Reference Photo & Save
  // 5 = Tap "Edit" on newly created catalog card
  int _currentStep = 1;
  static const int _totalSteps = 5;

  // Active top tab in Catalog:
  // 0 = Good Items, 1 = Scrap Items
  int _selectedCatalogTab = 0;

  // In-memory demo state
  bool _isCreateModalOpen = false;
  bool _isEditModalOpen = false;
  bool _hasSavedItem = false;
  bool _hasPhotoAttached = false;
  bool _isSubmitting = false;

  // Form controllers
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _skuCtrl = TextEditingController();
  final TextEditingController _unitCtrl = TextEditingController(text: 'PCS');
  final TextEditingController _minStockCtrl = TextEditingController(text: '10');

  String _selectedCategory = '';
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
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _unitCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  void _resetScenario() {
    setState(() {
      _currentStep = 1;
      _selectedCatalogTab = 0;
      _isCreateModalOpen = false;
      _isEditModalOpen = false;
      _hasSavedItem = false;
      _hasPhotoAttached = false;
      _isSubmitting = false;
      _selectedCategory = '';
      _selectedRack = '';
      _searchCtrl.clear();
      _nameCtrl.clear();
      _skuCtrl.clear();
      _unitCtrl.text = 'PCS';
      _minStockCtrl.text = '10';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sandbox reset to initial state.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  void _handleOpenCreateModal() {
    setState(() {
      _isCreateModalOpen = true;
      if (_currentStep == 1) {
        _currentStep = 2;
      }
    });
  }

  void _handleCloseCreateModal() {
    setState(() {
      _isCreateModalOpen = false;
      if (_currentStep >= 2 && !_hasSavedItem) {
        _currentStep = 1;
      }
    });
  }

  void _handleAutofillItemDetails() {
    setState(() {
      _nameCtrl.text = 'V-BELT B-64 (Heavy Duty Cogged)';
      _skuCtrl.text = 'BLT-B64-COG';
      _unitCtrl.text = 'PCS';
      if (_currentStep == 2) {
        _currentStep = 3;
      }
    });
  }

  void _handleAssignCategoryAndRack(String category, String rack) {
    setState(() {
      _selectedCategory = category;
      _selectedRack = rack;
      if (_currentStep == 3) {
        _currentStep = 4;
      }
    });
  }

  void _handleTogglePhoto() {
    setState(() {
      _hasPhotoAttached = true;
    });
  }

  Future<void> _handleSaveCatalogItem() async {
    setState(() {
      _isSubmitting = true;
    });

    // Simulate 600ms catalog database registration
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _hasSavedItem = true;
      _isCreateModalOpen = false;
      if (_currentStep == 4) {
        _currentStep = 5;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Master item V-BELT B-64 saved to catalog!'),
        backgroundColor: Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 2000),
      ),
    );
  }

  void _handleOpenEditModal() {
    setState(() {
      _isEditModalOpen = true;
    });
  }

  void _handleCloseEditModal() {
    setState(() {
      _isEditModalOpen = false;
    });
  }

  void _handleSaveEditedSpecifications() {
    setState(() {
      _isEditModalOpen = false;
    });

    showSimulatorCompletionDialog(
      context: context,
      tourTitle: 'F1: Creating & Editing Store Items',
      description:
          'You successfully registered new catalog material V-BELT B-64 (BLT-B64-COG), assigned category Belts & Transmission and Rack R-08, attached a photo, and learned how to edit item specifications without altering live master data.',
      onReplay: _resetScenario,
      onGoToLive: () {
        Navigator.pop(context); // Close simulator
        // Safely route to live Items section
        ref.read(guidedTourControllerProvider).requestSection('items');
      },
    );
  }

  String _getStepLabel() {
    switch (_currentStep) {
      case 1:
        return 'Tap "+ Add Item" button';
      case 2:
        return 'Define part name, SKU & unit';
      case 3:
        return 'Assign category & default shelf';
      case 4:
        return 'Attach reference photo & save';
      case 5:
        return 'Modify specifications via "Edit"';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreWalkthroughSimulatorShell(
      title: 'Item Registration & Catalog Setup',
      currentStepLabel: _getStepLabel(),
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onExit: () => Navigator.pop(context),
      onReset: _resetScenario,
      child: Stack(
        children: [
          _buildRealStoreShellLayout(context),
          if (_isCreateModalOpen) _buildItemCreationModalView(),
          if (_isEditModalOpen) _buildItemEditModalView(),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW A: Full Real Store App Layout (Matching ItemsListPage)
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
                // Step 1 Coachmark (if on Step 1)
                if (_currentStep == 1) ...[
                  _buildCoachmarkCard(
                    stepNumber: 1,
                    title: 'Step 1: Initiate Catalog Item Registration',
                    message:
                        'Tap the highlighted "+ Add Item" button below to register a new material, consumable, or spare part into the central store catalog without modifying live inventory.',
                  ),
                  const SizedBox(height: 10),
                ],

                // Step 5 Coachmark (if on Step 5)
                if (_currentStep == 5) ...[
                  _buildCoachmarkCard(
                    stepNumber: 5,
                    title: 'Step 5: Modify Existing Specifications',
                    message:
                        'Need to change a shelf location, update photo, or adjust minimum reorder levels? Tap the highlighted "Edit" button on the card below.',
                  ),
                  const SizedBox(height: 10),
                ],

                // 3. Tab Bar (Good Items vs Scrap Items)
                _buildGoodScrapTabBar(),
                const SizedBox(height: 10),

                // 4. Search, Download & + Add Item Action Row
                _buildSearchAndActionRow(),
                const SizedBox(height: 12),

                // 5. Newly Created Item Card (Active on Step 5)
                if (_hasSavedItem) ...[
                  _buildNewlyCreatedItemCard(_currentStep == 5),
                  const SizedBox(height: 10),
                ],

                // 6. Existing Catalog Card (Tapered Roller Bearing 32208)
                _buildExistingCatalogCard(),
                const SizedBox(height: 14),

                // 7. Operational Guidelines Card
                _buildOperationalGuidelineCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /* ---------------- Real Header Card (matching Items View) ---------------- */

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
              Icons.inventory_2_rounded,
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
                  'Items',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Master Material Catalog & Stock Inventory',
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

  /* ---------------- Tab Bar: Good Items vs Scrap Items ---------------- */

  Widget _buildGoodScrapTabBar() {
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
              onTap: () => setState(() => _selectedCatalogTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedCatalogTab == 0 ? _surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedCatalogTab == 0
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
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: _selectedCatalogTab == 0 ? _ink900 : _ink600,
                    ),
                    const SizedBox(width: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _hasSavedItem ? 'Good Items (2)' : 'Good Items (1)',
                        style: TextStyle(
                          color: _selectedCatalogTab == 0 ? _ink900 : _ink600,
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
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedCatalogTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedCatalogTab == 1 ? _surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_sweep_outlined,
                      size: 16,
                      color: _selectedCatalogTab == 1 ? _ink900 : _ink600,
                    ),
                    const SizedBox(width: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Scrap Items (0)',
                        style: TextStyle(
                          color: _selectedCatalogTab == 1 ? _ink900 : _ink600,
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
        ],
      ),
    );
  }

  /* ---------------- Search & + Add Item Action Row ---------------- */

  Widget _buildSearchAndActionRow() {
    final isStep1 = _currentStep == 1;

    return Card(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _stroke),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          if (isMobile) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Search by item name, SKU...',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(color: _ink900, fontSize: 13.5),
                        ),
                      ),
                      IconButton(
                        tooltip: "Refresh Catalog",
                        onPressed: () {},
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        color: _ink900,
                      ),
                      IconButton(
                        tooltip: "Export Excel",
                        onPressed: () {},
                        icon: const Icon(Icons.download_rounded, size: 20),
                        color: _ink900,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildAddItemButton(isStep1),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search by item name, SKU, or category...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(color: _ink900, fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: "Refresh Catalog",
                  onPressed: () {},
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: _ink900,
                ),
                IconButton(
                  tooltip: "Export Excel",
                  onPressed: () {},
                  icon: const Icon(Icons.download_rounded, size: 20),
                  color: _ink900,
                ),
                const SizedBox(width: 8),

                // Step 1 Spotlight: + Add Item Button
                _buildAddItemButton(isStep1),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddItemButton(bool isStep1) {
    final btn = FilledButton.icon(
      key: GuidedTourController.addItemButtonKey,
      onPressed: _handleOpenCreateModal,
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
        '+ Add Item',
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

  /* ---------------- Catalog Cards ---------------- */

  Widget _buildNewlyCreatedItemCard(bool isStep5) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStep5 ? _accentAmberBorder : const Color(0xFFA5D6A7),
          width: isStep5 ? 2.0 : 1.5,
        ),
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
              // Photo Thumbnail Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Icon(
                  Icons.settings_input_composite_rounded,
                  color: Color(0xFF92400E),
                  size: 26,
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
                            'V-BELT B-64 (Heavy Duty Cogged)',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Step 5 Spotlight: Edit Action Button
                        _buildEditActionButton(isStep5),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildPillBadge('BLT-B64-COG'),
                        _buildPillBadge('Belts & Transmission', icon: Icons.category_outlined),
                        _buildPillBadge('Rack R-08 (Shelf S-01)', icon: Icons.shelves),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: const Text(
                            'NEWLY REGISTERED',
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

          // Real-time Stock Metrics Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: _buildStockMetricItem('Total Stock', '0 PCS', _ink900)),
                Expanded(child: _buildStockMetricItem('Available', '0 PCS', const Color(0xFF1B5E20))),
                Expanded(child: _buildStockMetricItem('Issued', '0 PCS', const Color(0xFF6B7280))),
                Expanded(child: _buildStockMetricItem('Min Alert', '${_minStockCtrl.text} PCS', const Color(0xFFE65100))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditActionButton(bool isStep5) {
    final btn = OutlinedButton.icon(
      key: GuidedTourController.firstItemEditButtonKey,
      onPressed: _handleOpenEditModal,
      style: OutlinedButton.styleFrom(
        backgroundColor: isStep5 ? _accentAmber : _surface,
        foregroundColor: isStep5 ? Colors.white : _ink900,
        side: BorderSide(
          color: isStep5 ? _accentAmberBorder : _stroke,
          width: isStep5 ? 2.0 : 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: Icon(
        Icons.edit_outlined,
        size: 14,
        color: isStep5 ? Colors.white : _ink900,
      ),
      label: Text(
        'Edit',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: isStep5 ? Colors.white : _ink900,
        ),
      ),
    );

    if (isStep5) {
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

  Widget _buildExistingCatalogCard() {
    return Card(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accentMint.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: _ink900,
                    size: 24,
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
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildPillBadge('BRG-32208-TRB'),
                          _buildPillBadge('Bearings & Transmission', icon: Icons.category_outlined),
                          _buildPillBadge('Rack R-12', icon: Icons.shelves),
                          _buildPillBadge('Main Store Room', icon: Icons.room_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildStockMetricItem('Total Stock', '35 PCS', _ink900)),
                  Expanded(child: _buildStockMetricItem('Available', '35 PCS', const Color(0xFF1B5E20))),
                  Expanded(child: _buildStockMetricItem('Issued', '0 PCS', const Color(0xFF6B7280))),
                  Expanded(child: _buildStockMetricItem('Min Alert', '5 PCS', const Color(0xFFE65100))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockMetricItem(String label, String value, Color col) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: _ink600,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: col,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ],
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
                'Master Catalog Rules',
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
            '• Maintain unique SKU codes across all equipment parts to avoid requisition clashes.\n'
            '• Attach standard reference photos to assist field technicians in visual part verification.\n'
            '• Pre-assigning storage rack coordinates streamlines inward Goods Received Notes (GRN).',
            style: TextStyle(color: _ink700, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW B: Item Creation Sheet / Modal Form (Steps 1.2, 1.3, 1.4)
     ========================================================================= */

  Widget _buildItemCreationModalView() {
    final isStep2 = _currentStep == 2;
    final isStep3 = _currentStep == 3;
    final isStep4 = _currentStep == 4;

    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _stroke),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x28000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Modal Header
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
                          Icons.add_box_rounded,
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
                              'Register New Material Item',
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Master catalog record definition & shelf tagging',
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
                        onPressed: _handleCloseCreateModal,
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                        tooltip: 'Close Registration',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Step 2 Coachmark
                  if (isStep2) ...[
                    _buildCoachmarkCard(
                      stepNumber: 2,
                      title: 'Step 2: Define Part Name, SKU & Unit',
                      message:
                          'Enter the standard part name, internal SKU code, and measurement unit. Tap the highlighted "⚡ Autofill Sample Item" button to load test data.',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Step 3 Coachmark
                  if (isStep3) ...[
                    _buildCoachmarkCard(
                      stepNumber: 3,
                      title: 'Step 3: Assign Category & Storage Shelf',
                      message:
                          'Choose the operational category and default shelf rack where this item will reside. Tap the highlighted "Belts & Transmission" option below.',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Step 4 Coachmark
                  if (isStep4) ...[
                    _buildCoachmarkCard(
                      stepNumber: 4,
                      title: 'Step 4: Attach Reference Photo & Save',
                      message:
                          'Attach a part reference photo for shopfloor visual verification, then tap the highlighted "Save to Catalog" button.',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Form Section 1: Item Identity & SKU
                  _buildItemIdentitySection(isStep2),
                  const SizedBox(height: 12),

                  // Form Section 2: Category & Default Shelf Location
                  _buildCategoryAndRackSection(isStep3),
                  const SizedBox(height: 12),

                  // Form Section 3: Photo & Visual Recognition
                  _buildPhotoAttachmentSection(isStep4),
                  const SizedBox(height: 16),

                  // Modal Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleCloseCreateModal,
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
                        child: _buildSaveCatalogItemButton(isStep4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemIdentitySection(bool isStep2) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStep2 ? _accentAmberBorder : _stroke,
          width: isStep2 ? 1.8 : 1.0,
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
                  Icon(Icons.badge_outlined, size: 17, color: _ink900),
                  SizedBox(width: 8),
                  Text(
                    'Part Identity & Unit',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              _buildAutofillItemButton(isStep2),
            ],
          ),
          const SizedBox(height: 12),

          // Part Title Input
          _buildTextInput(
            label: 'Part Title / Item Name *',
            hint: 'e.g. V-BELT B-64 (Heavy Duty Cogged)',
            controller: _nameCtrl,
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 10),

          // SKU & Unit Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextInput(
                  label: 'Internal SKU / Code *',
                  hint: 'e.g. BLT-B64-COG',
                  controller: _skuCtrl,
                  icon: Icons.qr_code_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextInput(
                  label: 'Unit *',
                  hint: 'PCS',
                  controller: _unitCtrl,
                  icon: Icons.straighten_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutofillItemButton(bool isStep2) {
    final btn = FilledButton.icon(
      onPressed: _handleAutofillItemDetails,
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
        '⚡ Autofill: V-BELT B-64',
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

  Widget _buildCategoryAndRackSection(bool isStep3) {
    final isSelected = _selectedCategory.isNotEmpty || _selectedRack.isNotEmpty;

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
              Icon(Icons.category_outlined, size: 17, color: _ink900),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Category & Default Storage Shelf *',
                  maxLines: 1,
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
          const SizedBox(height: 8),
          const Text(
            'Select parent operational category and warehouse rack for inventory tracking.',
            style: TextStyle(color: _ink600, fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Category Options
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildCategoryOptionChip(
                category: 'Belts & Transmission',
                rack: 'Rack R-08 (Shelf S-01)',
                isHighlighted: isStep3,
                isSelected: isSelected,
                onTap: () => _handleAssignCategoryAndRack(
                  'Belts & Transmission',
                  'Rack R-08 (Shelf S-01)',
                ),
              ),
              _buildCategoryOptionChip(
                category: 'Bearings & Bushings',
                rack: 'Rack R-12 (Shelf S-03)',
                isHighlighted: false,
                isSelected: false,
                onTap: () => _handleAssignCategoryAndRack(
                  'Bearings & Bushings',
                  'Rack R-12 (Shelf S-03)',
                ),
              ),
              _buildCategoryOptionChip(
                category: 'Filtration Units',
                rack: 'Rack R-04 (Shelf S-02)',
                isHighlighted: false,
                isSelected: false,
                onTap: () => _handleAssignCategoryAndRack(
                  'Filtration Units',
                  'Rack R-04 (Shelf S-02)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryOptionChip({
    required String category,
    required String rack,
    required bool isHighlighted,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final chip = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? _accentAmber
              : (isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFFAFAFA)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlighted
                ? _accentAmberBorder
                : (isSelected ? const Color(0xFF2E7D32) : _stroke),
            width: isHighlighted || isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.folder_outlined,
              size: 15,
              color: isHighlighted
                  ? Colors.white
                  : (isSelected ? const Color(0xFF2E7D32) : _ink700),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    color: isHighlighted
                        ? Colors.white
                        : (isSelected ? const Color(0xFF1B5E20) : _ink900),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Default: $rack',
                  style: TextStyle(
                    color: isHighlighted
                        ? Colors.white.withValues(alpha: 0.85)
                        : _ink600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isHighlighted) {
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
          child: chip,
        ),
      );
    }
    return chip;
  }

  Widget _buildPhotoAttachmentSection(bool isStep4) {
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: Color(0xFF92400E),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Reference Photo Attached: v_belt_b64.jpg',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Visual reference stored for shopfloor recognition',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink600,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _handleTogglePhoto,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: _stroke),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(
              _hasPhotoAttached ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
              size: 14,
              color: _hasPhotoAttached ? const Color(0xFF059669) : _ink700,
            ),
            label: Text(
              _hasPhotoAttached ? 'Attached' : 'Add Photo',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveCatalogItemButton(bool isStep4) {
    final btn = FilledButton.icon(
      onPressed: _isSubmitting ? null : _handleSaveCatalogItem,
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
          : const Icon(Icons.save_rounded, size: 18),
      label: Text(
        _isSubmitting ? 'Registering Material...' : 'Save to Catalog',
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

  Widget _buildTextInput({
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

  /* =========================================================================
     VIEW C: Item Edit Modal Form (Step 1.5)
     ========================================================================= */

  Widget _buildItemEditModalView() {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
                          Icons.edit_note_rounded,
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
                              'Edit Item Specifications',
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Update location, alert levels or descriptions',
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
                        onPressed: _handleCloseEditModal,
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildTextInput(
                    label: 'Part Title',
                    hint: 'V-BELT B-64 (Heavy Duty Cogged)',
                    controller: _nameCtrl,
                    icon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 10),
                  _buildTextInput(
                    label: 'Min Reorder Threshold (Stock Alert)',
                    hint: '10',
                    controller: _minStockCtrl,
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 16),

                  FilledButton.icon(
                    onPressed: _handleSaveEditedSpecifications,
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
                      'Save Updated Specifications',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
