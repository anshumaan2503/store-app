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

const _accentPeach = Color(0xFFF3D7C0);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

const _accentAmber = Color(0xFFF59E0B);
const _accentAmberBorder = Color(0xFFD97706);

/// Interactive Training Sandbox for Feature F3:
/// Managing Racks & Places (Facility Architecture & Visual Warehouse Layout).
///
/// Replicates the authentic layout of [RacksListPage] and [RackCard] with dual navigation sidebars,
/// storage zone tabs (Good Items Racks, Scrap Racks, Machine Rooms), room filter dropdown,
/// rack occupancy & capacity meters (24/30 Bins - 80%), stored SKU inspector,
/// and large-format QR rack placard printing (strictly 2D QR codes, NO LINEAR BARCODES)
/// without altering live database records.
class RackManagementSimulatorScreen extends ConsumerStatefulWidget {
  const RackManagementSimulatorScreen({super.key});

  @override
  ConsumerState<RackManagementSimulatorScreen> createState() =>
      _RackManagementSimulatorScreenState();
}

class _RackManagementSimulatorScreenState
    extends ConsumerState<RackManagementSimulatorScreen>
    with SingleTickerProviderStateMixin {
  // Guided Walkthrough Steps:
  // 1 = Warehouse Layout Structure (Places Navigation Tab)
  // 2 = Storage Categories & Rooms (placesZoneTabsKey / Room Dropdown)
  // 3 = Inspect Shelf Capacity & Items (firstRackCardKey)
  // 4 = Print Shelf Signboards (firstRackPrintQrKey)
  int _currentStep = 1;
  static const int _totalSteps = 4;

  // Active top tab in Places:
  // 0 = Good Items Racks, 1 = Scrap Items Racks, 2 = Good Machine Rooms, 3 = Scrap Machine Rooms
  int _selectedZoneTabIndex = 0;

  // Search & Filter state
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedRoom = 'Central Machine Spares Room';

  // In-memory demo simulation state
  bool _isContentsModalOpen = false;
  bool _isQrPlacardModalOpen = false;
  bool _isAddRackModalOpen = false;

  // Target Rack Mock Data
  final String _targetRackCode = 'R-12';
  final String _targetRackName = 'Heavy Mechanical Spares Rack';
  final String _targetRoom = 'Central Machine Spares Room';
  final int _occupiedBins = 24;
  final int _totalBins = 30;
  final List<String> _storedSkus = [
    'BALL BEARING 6204-2RS',
    'BRONZE BUSHING 35MM',
    'FLANGE ADAPTER 4-BOLT',
    'FLEXIBLE COUPLING 20MM',
  ];

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
      _selectedZoneTabIndex = 0;
      _selectedRoom = 'Central Machine Spares Room';
      _searchCtrl.clear();
      _isContentsModalOpen = false;
      _isQrPlacardModalOpen = false;
      _isAddRackModalOpen = false;
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

  void _handleOpenContentsModal() {
    setState(() {
      _isContentsModalOpen = true;
      if (_currentStep == 3) {
        // user actively inspected rack in step 3
      }
    });
  }

  void _handleOpenQrPlacardModal() {
    setState(() {
      _isQrPlacardModalOpen = true;
      if (_currentStep == 4) {
        // step 4 completed
      }
    });
  }

  void _handleFinishTour() {
    showSimulatorCompletionDialog(
      context: context,
      tourTitle: 'F3: Managing Racks & Places (Facility Architecture)',
      description:
          'You mastered the warehouse storage architecture: browsing room zones, auditing shelf occupancy (24/30 bins - 80% on Rack R-12), inspecting stored mechanical SKUs, and printing large-format QR rack placards without altering live warehouse locations!',
      onReplay: _resetScenario,
      onGoToLive: () {
        Navigator.pop(context); // Close simulator
        ref.read(guidedTourControllerProvider).requestSection('places');
      },
    );
  }

  String _getStepLabel() {
    switch (_currentStep) {
      case 1:
        return 'Warehouse Layout Structure';
      case 2:
        return 'Storage Categories & Rooms';
      case 3:
        return 'Inspect Shelf Capacity & Items';
      case 4:
        return 'Print Shelf Signboards';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreWalkthroughSimulatorShell(
      title: 'Warehouse Layout, Racks & Places',
      currentStepLabel: _getStepLabel(),
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onExit: () => Navigator.pop(context),
      onReset: _resetScenario,
      child: Stack(
        children: [
          _buildRealStoreShellLayout(context),
          if (_isContentsModalOpen) _buildRackContentsModal(),
          if (_isQrPlacardModalOpen) _buildQrPlacardModal(),
          if (_isAddRackModalOpen) _buildAddRackModal(),
        ],
      ),
    );
  }

  /* =========================================================================
     VIEW: Full Authentic Store App Layout (Matching RacksListPage)
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

                  // Inner Navigation Sidebar (Dashboard, Items, Find Item, Places [Spotlight Step 1])
                  _buildInnerStoreNav(),
                  const SizedBox(width: 12),

                  // Main Places / Racks Content Area
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
        // 1. Places Header Card (Add Rack, Add Room, Refresh, Export)
        _buildPlacesHeaderCard(),
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

                // Zone Tabs Bar (Spotlight for Step 2)
                _buildZoneTabsCard(),
                const SizedBox(height: 12),

                // Filter Card (Room Dropdown + Rack Search)
                _buildRoomAndSearchFilterCard(),
                const SizedBox(height: 14),

                // Rack Cards List (Spotlight for Step 3 & 4 on Target Rack R-12)
                _buildTargetRackCard(),
                const SizedBox(height: 12),

                // Contextual Secondary Rack Cards (to give full authentic warehouse view)
                _buildSecondaryRackCard(
                  code: 'R-11',
                  name: 'Fasteners & Gaskets Rack',
                  room: 'Central Machine Spares Room',
                  occupied: 12,
                  total: 20,
                  storedPreview: 'Hex Bolts M12, Flange Gaskets, Washers',
                ),
                const SizedBox(height: 10),
                _buildSecondaryRackCard(
                  code: 'R-13',
                  name: 'Pneumatic Valves & Cylinders',
                  room: 'Central Machine Spares Room',
                  occupied: 18,
                  total: 25,
                  storedPreview: 'Solenoid Valves, Air Filters, Fittings',
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
        title = 'Step 1 of 4: Warehouse Layout Structure';
        message =
            'Access the structural layout of your store facility: consumable racks, machine spares rooms, and designated storage bins. Notice "Places / Racks" is highlighted in the navigation bar.';
        icon = Icons.warehouse_rounded;
        break;
      case 2:
        title = 'Step 2 of 4: Storage Categories & Rooms';
        message =
            'Browse inventory categories using the highlighted zone tabs ("Good Items Racks", "Scrap Racks", "Machine Rooms") and filter specific rooms like "Central Machine Spares Room" below.';
        icon = Icons.meeting_room_rounded;
        break;
      case 3:
        title = 'Step 3 of 4: Inspect Shelf Capacity & Items';
        message =
            'Inspect the highlighted Rack R-12 card below: it is currently at 80% capacity (24 / 30 bins occupied). Tap the card or "Inspect Bins" to see the full list of stored mechanical SKUs.';
        icon = Icons.storage_rounded;
        break;
      case 4:
        title = 'Step 4 of 4: Print Shelf Signboards (QR Placards)';
        message =
            'Print large-format 2D QR placards to mount onto physical warehouse pillars for quick mobile barcode/QR scanning. Tap the highlighted QR Code button on Rack R-12 to complete the tour.';
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
     TOP TOOLBAR: Add Rack, Add Room, Refresh, Export (Matching RacksListPage)
     ========================================================================= */

  Widget _buildPlacesHeaderCard() {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _stroke),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.apartment_rounded, size: 16, color: _ink900),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Store Physical Racks',
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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildToolbarButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh Racks',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Racks list refreshed (Sandbox)'),
                            duration: Duration(milliseconds: 900),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildToolbarButton(
                      icon: Icons.file_download_rounded,
                      tooltip: 'Export Rack Audit Excel',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rack audit Excel download simulated in training sandbox.'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ink900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                      ),
                      onPressed: () {
                        setState(() => _isAddRackModalOpen = true);
                      },
                      icon: const Icon(Icons.storage_rounded, size: 15),
                      label: const Text(
                        'Add Rack',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
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
                        Icon(Icons.apartment_rounded, size: 16, color: _ink900),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Store Architecture & Physical Racks',
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

              // Refresh Button
              _buildToolbarButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh Racks',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Racks list refreshed (Sandbox)'),
                      duration: Duration(milliseconds: 900),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),

              // Export Excel
              _buildToolbarButton(
                icon: Icons.file_download_rounded,
                tooltip: 'Export Rack Audit Excel',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rack audit Excel download simulated in training sandbox.'),
                      duration: Duration(milliseconds: 1200),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),

              // Add Rack Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ink900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
                onPressed: () {
                  setState(() => _isAddRackModalOpen = true);
                },
                icon: const Icon(Icons.storage_rounded, size: 15),
                label: const Text(
                  'Add Rack',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          );
        },
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
     ZONE TABS CARD: Good Racks, Scrap Racks, Machine Rooms (Spotlight Step 2)
     ========================================================================= */

  Widget _buildZoneTabsCard() {
    final bool isHighlighted = _currentStep == 2;

    Widget content = Container(
      padding: const EdgeInsets.all(4),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          if (isNarrow) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildZoneTabItem(index: 0, label: 'Good Items (12)', isNarrow: true),
                  const SizedBox(width: 6),
                  _buildZoneTabItem(index: 1, label: 'Scrap Items (2)', isNarrow: true),
                  const SizedBox(width: 6),
                  _buildZoneTabItem(index: 2, label: 'Good Rooms (4)', isNarrow: true),
                  const SizedBox(width: 6),
                  _buildZoneTabItem(index: 3, label: 'Scrap Rooms (1)', isNarrow: true),
                ],
              ),
            );
          }
          return Row(
            children: [
              _buildZoneTabItem(index: 0, label: 'Good Items Racks (12)'),
              const SizedBox(width: 4),
              _buildZoneTabItem(index: 1, label: 'Scrap Items Racks (2)'),
              const SizedBox(width: 4),
              _buildZoneTabItem(index: 2, label: 'Good Machine Rooms (4)'),
              const SizedBox(width: 4),
              _buildZoneTabItem(index: 3, label: 'Scrap Machine Rooms (1)'),
            ],
          );
        },
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

  Widget _buildZoneTabItem({required int index, required String label, bool isNarrow = false}) {
    final bool isSelected = _selectedZoneTabIndex == index;
    final item = InkWell(
      onTap: () {
        setState(() => _selectedZoneTabIndex = index);
        if (index != 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label tab preview in sandbox.'),
              duration: const Duration(milliseconds: 900),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 9, horizontal: isNarrow ? 14 : 4),
        decoration: BoxDecoration(
          color: isSelected ? _ink900 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : _ink700,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );

    if (isNarrow) {
      return item;
    }
    return Expanded(child: item);
  }

  /* =========================================================================
     FILTER ROW: Room Dropdown Selector & Rack Search Field
     ========================================================================= */

  Widget _buildRoomAndSearchFilterCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final roomDropdown = Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRoom,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: _ink700),
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'All Rooms',
                    child: Text('All Warehouse Rooms'),
                  ),
                  DropdownMenuItem(
                    value: 'Central Machine Spares Room',
                    child: Text('Central Machine Spares Room (Bldg A)'),
                  ),
                  DropdownMenuItem(
                    value: 'Consumables & Lubricants Store',
                    child: Text('Consumables & Lubricants Store (Bldg B)'),
                  ),
                  DropdownMenuItem(
                    value: 'Electrical Spares Bay',
                    child: Text('Electrical Spares Bay (Bldg C)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedRoom = v);
                  }
                },
              ),
            ),
          );

          final searchField = Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18, color: _ink600),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search rack by code (e.g. R-12, R-11)...',
                      hintStyle: TextStyle(color: _ink500, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                roomDropdown,
                const SizedBox(height: 8),
                searchField,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: roomDropdown,
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: searchField,
              ),
            ],
          );
        },
      ),
    );
  }

  /* =========================================================================
     TARGET RACK CARD: Rack R-12 (Spotlight for Steps 3 & 4)
     ========================================================================= */

  Widget _buildTargetRackCard() {
    final bool highlightCard = _currentStep == 3;
    final bool highlightQr = _currentStep == 4;
    final double occupancyRatio = _occupiedBins / _totalBins; // 0.8 (80%)

    Widget cardBody = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (highlightCard || highlightQr) ? _accentAmberBorder : _stroke,
          width: (highlightCard || highlightQr) ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (highlightCard || highlightQr)
            const BoxShadow(
              color: Color(0x55F59E0B),
              blurRadius: 14,
              spreadRadius: 2,
            )
          else
            const BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spotlight Banner
          if (highlightCard || highlightQr) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  Expanded(
                    child: Text(
                      highlightCard
                          ? 'SPOTLIGHT: Inspect shelf capacity (80%) and stored mechanical SKUs below.'
                          : 'SPOTLIGHT: Tap the highlighted QR Code button to print the shelf signboard.',
                      style: const TextStyle(
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

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;

              final detailsColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _targetRackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _stroke),
                        ),
                        child: Text(
                          _targetRackCode,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_targetRoom • Zone Aisle 02',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _ink600, fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  // Capacity Progress Bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: occupancyRatio,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$_occupiedBins / $_totalBins Bins (${(occupancyRatio * 100).toInt()}%)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Stored SKUs Badges Row
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (final sku in _storedSkus)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            sku,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );

              final actionInspectButton = InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _handleOpenContentsModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 14, color: _ink900),
                      SizedBox(width: 4),
                      Text(
                        'Inspect Bins',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final actionEditButton = _buildRackActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit Rack',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rack configuration is covered in Admin Settings.'),
                      duration: Duration(milliseconds: 1200),
                    ),
                  );
                },
              );

              final actionQrButton = _buildRackActionButton(
                icon: Icons.qr_code_2_rounded,
                tooltip: 'Print Rack QR Placard',
                isHighlighted: highlightQr,
                onTap: _handleOpenQrPlacardModal,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _accentPeach.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _stroke),
                          ),
                          child: const Icon(
                            Icons.view_module_rounded,
                            color: _ink900,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: detailsColumn),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: _stroke),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        actionInspectButton,
                        const Spacer(),
                        actionEditButton,
                        const SizedBox(width: 6),
                        actionQrButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _accentPeach.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _stroke),
                    ),
                    child: const Icon(
                      Icons.view_module_rounded,
                      color: _ink900,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: detailsColumn),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      actionInspectButton,
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          actionEditButton,
                          const SizedBox(width: 6),
                          actionQrButton,
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (highlightCard) {
      return ScaleTransition(
        scale: _pulseScale,
        child: cardBody,
      );
    }
    return cardBody;
  }

  Widget _buildSecondaryRackCard({
    required String code,
    required String name,
    required String room,
    required int occupied,
    required int total,
    required String storedPreview,
  }) {
    final double ratio = occupied / total;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: const Icon(Icons.storage_rounded, color: _ink700, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _stroke),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$room • Stored: $storedPreview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _ink600, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$occupied / $total Bins (${(ratio * 100).toInt()}%)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, size: 20, color: _ink700),
            tooltip: 'Print QR Placard',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Placard printing simulated for $code.'),
                  duration: const Duration(milliseconds: 900),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRackActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isHighlighted = false,
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
              color: isHighlighted ? const Color(0xFFFEF3C7) : _surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHighlighted ? _accentAmberBorder : _stroke,
                width: isHighlighted ? 1.8 : 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isHighlighted ? _accentAmberBorder : _ink900,
            ),
          ),
        ),
      ),
    );
  }

  /* =========================================================================
     MODAL 1: Rack Contents & Capacity Inspector Modal
     ========================================================================= */

  Widget _buildRackContentsModal() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
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
                        child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFB45309), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rack Inventory: $_targetRackCode',
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '$_targetRackName • $_targetRoom',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _ink600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                        onPressed: () => setState(() => _isContentsModalOpen = false),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: _stroke),

                  // Occupancy Stats Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildMetricColumn('Total Bins', '30 Bins', _ink900),
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildMetricColumn('Occupied', '24 Bins (80%)', const Color(0xFFB45309)),
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildMetricColumn('Free Capacity', '6 Bins (20%)', const Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Stored Materials on Shelf Bins:',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // List of stored items
                  _buildStoredItemRow(
                    shelf: 'Shelf S-01 (Top Bin)',
                    sku: 'BALL BEARING 6204-2RS',
                    code: 'BRG-6204-2RS',
                    qty: '28 PCS Available',
                  ),
                  const SizedBox(height: 6),
                  _buildStoredItemRow(
                    shelf: 'Shelf S-02 (Middle Bin)',
                    sku: 'BRONZE BUSHING 35MM',
                    code: 'BSH-35-BRZ',
                    qty: '14 PCS Available',
                  ),
                  const SizedBox(height: 6),
                  _buildStoredItemRow(
                    shelf: 'Shelf S-03 (Lower Bin)',
                    sku: 'FLANGE ADAPTER 4-BOLT',
                    code: 'FLG-4B-ADP',
                    qty: '8 PCS Available',
                  ),
                  const SizedBox(height: 6),
                  _buildStoredItemRow(
                    shelf: 'Shelf S-04 (Bottom Bin)',
                    sku: 'FLEXIBLE COUPLING 20MM',
                    code: 'CPL-20-FLX',
                    qty: '6 PCS Available',
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ink900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => _isContentsModalOpen = false),
                    child: const Text('Close Rack Inspector', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _ink600, fontSize: 11)),
      ],
    );
  }

  Widget _buildStoredItemRow({
    required String shelf,
    required String sku,
    required String code,
    required String qty,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _ink900),
                ),
                Text(
                  '$shelf • Code: $code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _ink600, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            qty,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF059669)),
          ),
        ],
      ),
    );
  }

  /* =========================================================================
     MODAL 2: Large-Format QR Rack Placard Modal (STRICTLY NO BARCODES)
     ========================================================================= */

  Widget _buildQrPlacardModal() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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
                            'Large-Format QR Rack Placard',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Physical Shelf Pillar Signboard (A4 / A5 Layout)',
                            style: TextStyle(color: _ink600, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink900),
                      onPressed: () => setState(() => _isQrPlacardModalOpen = false),
                    ),
                  ],
                ),
                const Divider(height: 20, color: _stroke),

                // Physical Pillar Placard Representation
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Placard Header Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'CENTRAL MACHINE SPARES STORE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Large Rack Identifier
                        Text(
                          'RACK $_targetRackCode',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            letterSpacing: 1.5,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _targetRackName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Large 2D QR Code Matrix
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: CustomPaint(
                            painter: _RackQrPlacardPainter(),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Subtitle Coordinates
                        const Text(
                          'AISLE 02 • MECHANICAL SPARES ZONE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SCAN WITH STORE QR SCANNER TO AUDIT BINS OR DISPATCH ITEMS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Physical placards are laminated and mounted on rack pillars so operators can verify room/shelf locations instantly with their mobile camera.',
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
                          setState(() => _isQrPlacardModalOpen = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Simulated sending large-format QR placard to store printer.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Placard'),
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
                          setState(() => _isQrPlacardModalOpen = false);
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
     MODAL 3: Add Rack Form Preview
     ========================================================================= */

  Widget _buildAddRackModal() {
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storage_rounded, color: Color(0xFF1D4ED8), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Create New Warehouse Rack',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink900),
                      onPressed: () => setState(() => _isAddRackModalOpen = false),
                    ),
                  ],
                ),
                const Divider(height: 20, color: _stroke),
                const Text(
                  'Assign rack code, friendly name, target room, and shelf capacity.',
                  style: TextStyle(color: _ink600, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sample Code: R-14', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      Text('Assigned Room: Central Machine Spares Room', style: TextStyle(fontSize: 11, color: _ink700)),
                      Text('Default Capacity: 25 Bins', style: TextStyle(fontSize: 11, color: _ink700)),
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
                  onPressed: () {
                    setState(() => _isAddRackModalOpen = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rack creation completed in simulation.'),
                        duration: Duration(milliseconds: 1200),
                      ),
                    );
                  },
                  child: const Text('Save Rack (Demo)', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final bool highlightPlaces = _currentStep == 1;

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
          _buildInnerNavItem(icon: Icons.location_searching_rounded, label: 'Find Item', isActive: false),
          const SizedBox(height: 6),
          _buildInnerNavItem(
            icon: Icons.warehouse_rounded,
            label: 'Places / Racks',
            isActive: true,
            isHighlighted: highlightPlaces,
          ),
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
          Icon(Icons.location_searching_rounded, color: _ink600, size: 22),
          Icon(Icons.warehouse_rounded, color: _ink900, size: 24),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------------------------
   CUSTOM PAINTER: High-Resolution 2D QR Code Matrix for Rack Placard
   (STRICTLY 2D QR CODE, NO LINEAR BARCODES)
   -------------------------------------------------------------------------- */
class _RackQrPlacardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBlack = Paint()..color = Colors.black..style = PaintingStyle.fill;

    // Corner QR Registration Eye 1 (Top-Left)
    _drawQrEye(canvas, const Offset(0, 0), 26, paintBlack);

    // Corner QR Registration Eye 2 (Top-Right)
    _drawQrEye(canvas, Offset(size.width - 26, 0), 26, paintBlack);

    // Corner QR Registration Eye 3 (Bottom-Left)
    _drawQrEye(canvas, Offset(0, size.height - 26), 26, paintBlack);

    // Simulated 2D QR Matrix Data Modules for Rack R-12
    const gridSize = 12;
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    final matrix = [
      [0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1],
      [0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0],
      [1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1],
      [0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0],
      [1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1],
      [0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1],
      [1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0],
      [0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1],
      [0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0],
      [1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1],
      [0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0],
      [1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1],
    ];

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Skip corner eyes areas
        if ((r < 4 && c < 4) || (r < 4 && c > 7) || (r > 7 && c < 4)) {
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
    canvas.drawRect(Rect.fromLTWH(offset.dx + 4.5, offset.dy + 4.5, size - 9, size - 9), paintWhite);
    // Center black dot
    canvas.drawRect(Rect.fromLTWH(offset.dx + 8, offset.dy + 8, size - 16, size - 16), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
