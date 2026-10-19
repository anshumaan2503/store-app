import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domains/models/auth_model.dart';
import '../../auth/shared/repositories/shared_preference_repository.dart';

/// Direction from which the directional arrow approaches and points toward the target widget.
enum GuidedTourArrowDirection {
  /// Automatically resolves based on target position on the screen.
  auto,

  /// Arrow is positioned above the target, pointing down toward it.
  top,

  /// Arrow is positioned below the target, pointing up toward it.
  bottom,

  /// Arrow is positioned to the left of the target, pointing right toward it.
  left,

  /// Arrow is positioned to the right of the target, pointing left toward it.
  right,
}

/// Represents a single step configuration in a Guided Tour sequence.
class GuidedTourStep {
  /// Unique identifier for this step (e.g. 'issue_request_scan').
  final String id;

  /// Display title shown on the instruction card.
  final String title;

  /// Instructional text explaining the feature to the user.
  final String description;

  /// GlobalKey of the target widget to highlight.
  final GlobalKey targetKey;

  /// Optional callback invoked when the user taps through the spotlight hole on the target.
  final VoidCallback? onTargetTapped;

  /// Optional feature group or section identifier (e.g. 'issue_request', 'inventory', 'places').
  final String? featureId;

  /// Optional Store section that must be active for this step (e.g. 'items', 'places', 'issue').
  final String? targetSection;

  /// Optional condition evaluating whether this step is available for the given user.
  final bool Function(AuthModel user)? isAvailable;

  /// Optional callback invoked when this step becomes the active step.
  final VoidCallback? onStepEntered;

  /// Optional callback invoked when the user leaves this step.
  final VoidCallback? onStepExited;

  /// Optional hint for target widget type (e.g. 'fab', 'app_bar_button', 'card').
  final String? targetType;

  /// Direction from which the directional arrow points toward the target widget.
  final GuidedTourArrowDirection arrowDirection;

  /// Optional positioning hint for directional arrow placement.
  final Alignment? arrowAlignment;

  /// Whether this step is mandatory for first-time app opening (blocks dismissal/skipping).
  final bool isMandatory;

  const GuidedTourStep({
    required this.id,
    required this.title,
    required this.description,
    required this.targetKey,
    this.onTargetTapped,
    this.featureId,
    this.targetSection,
    this.isAvailable,
    this.onStepEntered,
    this.onStepExited,
    this.targetType,
    this.arrowAlignment,
    this.arrowDirection = GuidedTourArrowDirection.auto,
    this.isMandatory = false,
  });

  /// Checks whether the target widget is currently mounted in the element tree.
  bool get isTargetMounted => targetKey.currentContext != null;

  /// Safely checks whether the target widget's RenderBox is attached and has a valid size.
  bool isTargetAvailable() {
    final ctx = targetKey.currentContext;
    if (ctx == null) return false;
    final rb = ctx.findRenderObject();
    if (rb is! RenderBox) return false;
    return rb.attached && rb.hasSize && rb.size.width > 0;
  }
}

/// State tracking active Guided Tour progression and session dismissal.
class GuidedTourState {
  final List<GuidedTourStep> steps;
  final int currentStepIndex;
  final bool isSessionDismissed;

  const GuidedTourState({
    this.steps = const [],
    this.currentStepIndex = 0,
    this.isSessionDismissed = false,
  });

  int get totalSteps => steps.length;
  bool get hasSteps => steps.isNotEmpty;

  GuidedTourStep? get currentStep =>
      (currentStepIndex >= 0 && currentStepIndex < steps.length)
          ? steps[currentStepIndex]
          : null;

  bool get hasNext => currentStepIndex < steps.length - 1;
  bool get hasPrevious => currentStepIndex > 0;
  bool get isFirstStep => currentStepIndex == 0;
  bool get isLastStep =>
      steps.isNotEmpty && currentStepIndex == steps.length - 1;

  GuidedTourState copyWith({
    List<GuidedTourStep>? steps,
    int? currentStepIndex,
    bool? isSessionDismissed,
  }) {
    return GuidedTourState(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isSessionDismissed: isSessionDismissed ?? this.isSessionDismissed,
    );
  }
}

/// Tracks whether the Guided Tour has been dismissed in the current app session.
final guidedTourSessionDismissedProvider = StateProvider<bool>((ref) => false);

/// Backwards-compatible provider for existing call sites (e.g. auth_controller).
final guidedTourStep1SessionDismissedProvider =
    guidedTourSessionDismissedProvider;

/// State provider for the active multi-step Guided Tour sequence.
final guidedTourStateProvider = StateProvider<GuidedTourState>((ref) {
  return const GuidedTourState();
});

/// Controller provider for managing Guided Tour state, navigation, and persistence.
final guidedTourControllerProvider = Provider<GuidedTourController>((ref) {
  return GuidedTourController(ref);
});

class GuidedTourController {
  final Ref _ref;
  GuidedTourController(this._ref);

  static const String _legacyPrefKeyPrefix = 'guided_tour_step1_v2_dont_show_';
  static const String _prefKeyPrefix = 'guided_tour_dont_show_';
  static const String _mandatoryHelpPrefKeyPrefix = 'mandatory_help_completed_';

  /// Canonical target key for Store Help Button in the top header.
  static final GlobalKey storeHelpButtonKey =
      GlobalKey(debugLabel: 'store_help_button');

  /// Standard Store section identifiers for cross-section tour navigation.
  static const String sectionIssue = 'issue';
  static const String sectionItems = 'items';
  static const String sectionPlaces = 'places';
  static const String sectionReceive = 'receive';
  static const String sectionFindItem = 'find_item';

  /// Canonical target key for the Scan for Issue Request FAB.
  static final GlobalKey scanIssueButtonKey =
      GlobalKey(debugLabel: 'scan_issue_button');

  /// Canonical target key for Find Item nav icon.
  static final GlobalKey findItemKey = GlobalKey(debugLabel: 'find_item_nav');

  /// Canonical target key for Places nav icon.
  static final GlobalKey placesKey = GlobalKey(debugLabel: 'places_nav');

  /// Canonical target key for Good Items tab.
  static final GlobalKey goodItemsTabKey =
      GlobalKey(debugLabel: 'good_items_tab');

  /// Canonical target key for Scrap Items tab.
  static final GlobalKey scrapItemsTabKey =
      GlobalKey(debugLabel: 'scrap_items_tab');

  /// Canonical target key for Good Item Racks tab.
  static final GlobalKey goodItemRacksTabKey =
      GlobalKey(debugLabel: 'good_item_racks_tab');

  /// Canonical target key for Scrap Item Racks tab.
  static final GlobalKey scrapItemRacksTabKey =
      GlobalKey(debugLabel: 'scrap_item_racks_tab');

  /// Canonical target key for Good Machine Rooms tab.
  static final GlobalKey goodMachineRoomsTabKey =
      GlobalKey(debugLabel: 'good_machine_rooms_tab');

  /// Canonical target key for Scrap Machine Rooms tab.
  static final GlobalKey scrapMachineRoomsTabKey =
      GlobalKey(debugLabel: 'scrap_machine_rooms_tab');

  /// Canonical target key for the "+ Add Item" header action button (F1).
  static final GlobalKey addItemButtonKey =
      GlobalKey(debugLabel: 'add_item_button');

  /// Canonical target key for the Items search & filter bar (F1).
  static final GlobalKey itemSearchBarKey =
      GlobalKey(debugLabel: 'item_search_bar');

  /// Canonical target key for the first Item Card in the list (F1).
  static final GlobalKey firstItemCardKey =
      GlobalKey(debugLabel: 'first_item_card');

  /// Canonical target key for the first Item's Stock Metrics (F1).
  static final GlobalKey firstItemStockMetricsKey =
      GlobalKey(debugLabel: 'first_item_stock_metrics');

  /// Canonical target key for the first Item's Edit action button (F1).
  static final GlobalKey firstItemEditButtonKey =
      GlobalKey(debugLabel: 'first_item_edit_button');

  /// Canonical target key for the first Item's Code & Specifications tags (F2).
  static final GlobalKey firstItemDetailsKey =
      GlobalKey(debugLabel: 'first_item_details');

  /// Canonical target key for the first Item's Action buttons cluster (F2).
  static final GlobalKey firstItemActionsKey =
      GlobalKey(debugLabel: 'first_item_actions');

  /// Canonical target key for the Places zone selector tabs (F3).
  static final GlobalKey placesZoneTabsKey =
      GlobalKey(debugLabel: 'places_zone_tabs');

  /// Canonical target key for the first Rack Card (F3).
  static final GlobalKey firstRackCardKey =
      GlobalKey(debugLabel: 'first_rack_card');

  /// Canonical target key for the first Rack Card's Print QR button (F3).
  static final GlobalKey firstRackPrintQrKey =
      GlobalKey(debugLabel: 'first_rack_print_qr');

  /// Canonical target key for Receive Stock / Inward action button (F4).
  static final GlobalKey receiveStockActionKey =
      GlobalKey(debugLabel: 'receive_stock_action');

  /// Canonical target key for first Inward Receipt Record card (F4).
  static final GlobalKey firstReceiveRecordKey =
      GlobalKey(debugLabel: 'first_receive_record');

  /// Canonical target key for first Inward Receipt Rack Location tag (F4).
  static final GlobalKey firstReceiveRackLocationKey =
      GlobalKey(debugLabel: 'first_receive_rack_location');

  /// Canonical target key for first Inward Receipt Print QR sticker button (F4).
  static final GlobalKey firstReceivePrintQrKey =
      GlobalKey(debugLabel: 'first_receive_print_qr');

  /// Canonical target key for Find Item search bar (F5).
  static final GlobalKey findItemSearchBarKey =
      GlobalKey(debugLabel: 'find_item_search_bar');

  /// Canonical target key for first Item card in Find Item list (F5).
  static final GlobalKey firstFindItemCardKey =
      GlobalKey(debugLabel: 'first_find_item_card');

  /// Canonical target key for first Shelf Location Coordinates badge (F5).
  static final GlobalKey firstFindItemLocationKey =
      GlobalKey(debugLabel: 'first_find_item_location');

  /// Canonical target key for first Real-Time Available Stock Pill (F5).
  static final GlobalKey firstFindItemStockPillKey =
      GlobalKey(debugLabel: 'first_find_item_stock_pill');

  /// Canonical target key for Issue Quantity and Destination Machine reason (F6).
  static final GlobalKey issueQuantityStepperKey =
      GlobalKey(debugLabel: 'issue_quantity_stepper');

  /// Canonical target key for Add to Cart button on the first item in Items list.
  static final GlobalKey firstItemAddToCartKey =
      GlobalKey(debugLabel: 'first_item_add_to_cart');

  /// Canonical target key for Header Requisition Cart button.
  static final GlobalKey requisitionCartHeaderKey =
      GlobalKey(debugLabel: 'requisition_cart_header');

  /// Canonical target key for Header Indent Cart button (F6).
  static final GlobalKey indentCartButtonKey =
      GlobalKey(debugLabel: 'indent_cart_button');

  /// Canonical target key for Submit Indent Request button (F6).
  static final GlobalKey indentCartSubmitKey =
      GlobalKey(debugLabel: 'indent_cart_submit');

  /// Canonical target key for Submit Request button inside Requisition Cart (StoreCartPage).
  static final GlobalKey requisitionCartSubmitKey =
      GlobalKey(debugLabel: 'requisition_cart_submit');

  /// Static callback invoked to open Indent Drafts view during tour navigation.
  static VoidCallback? openIndentDraftsHandler;

  /// Static callback invoked to open Requisition Cart (StoreCartPage) during tour navigation.
  static VoidCallback? openStoreCartHandler;

  /// Canonical target key for the Issue navigation button in the left sidebar / shell.
  static final GlobalKey issueNavButtonKey =
      GlobalKey(debugLabel: 'issue_nav_button');

  /// Canonical target key for Approve button on the first pending requisition card.
  static final GlobalKey firstIssueApproveButtonKey =
      GlobalKey(debugLabel: 'first_issue_approve_button');

  /// Canonical target key for READY FOR ISSUE status badge on requisition card.
  static final GlobalKey readyForIssueBadgeKey =
      GlobalKey(debugLabel: 'ready_for_issue_badge');

  /// Canonical target key for Issue (Pick Up) button on requisition card.
  static final GlobalKey firstIssueDispatchButtonKey =
      GlobalKey(debugLabel: 'first_issue_dispatch_button');

  /// Canonical target key for Pending Approvals tab / filter chip (F7).
  static final GlobalKey pendingApprovalsTabKey =
      GlobalKey(debugLabel: 'pending_approvals_tab');

  /// Canonical target key for Requisition Card line items and inspection (F7).
  static final GlobalKey requisitionLineItemsKey =
      GlobalKey(debugLabel: 'requisition_line_items');

  /// Canonical target key for Quantity Adjustment Stepper / approved qty (F7).
  static final GlobalKey approvalQuantityStepperKey =
      GlobalKey(debugLabel: 'approval_quantity_stepper');

  /// Canonical target key for Approve and Reject decision action buttons (F7).
  static final GlobalKey approvalDecisionButtonsKey =
      GlobalKey(debugLabel: 'approval_decision_buttons');

  /// Canonical target key for Approved Requests tab / dispatch filter (F8).
  static final GlobalKey approvedRequestsTabKey =
      GlobalKey(debugLabel: 'approved_requests_tab');

  /// Canonical target key for Shelf & Rack Coordinates locator (F8).
  static final GlobalKey issueShelfCoordinatesKey =
      GlobalKey(debugLabel: 'issue_shelf_coordinates');

  /// Canonical target key for QR / Barcode Scanner Action button (F8).
  static final GlobalKey issueScanVerifyKey =
      GlobalKey(debugLabel: 'issue_scan_verify');

  /// Canonical target key for Confirm Issue / Dispatch button (F8).
  static final GlobalKey issueConfirmDispatchKey =
      GlobalKey(debugLabel: 'issue_confirm_dispatch');

  /// Canonical step ID for the Scan for Issue Request FAB.
  static const String issueRequestScanStepId = 'issue_request_scan';

  /// Standard step ID for Find Item step.
  static const String findItemStepId = 'find_item';

  /// Standard step ID for Places step.
  static const String placesStepId = 'places';

  /// Standard step ID for Good Items step.
  static const String goodItemsStepId = 'good_items';

  /// Standard step ID for Scrap Items step.
  static const String scrapItemsStepId = 'scrap_items';

  /// Standard step ID for Good Item Racks step.
  static const String goodItemRacksStepId = 'good_item_racks';

  /// Standard step ID for Scrap Item Racks step.
  static const String scrapItemRacksStepId = 'scrap_item_racks';

  /// Standard step ID for Good Machine Rooms step.
  static const String goodMachineRoomsStepId = 'good_machine_rooms';

  /// Standard step ID for Scrap Machine Rooms step.
  static const String scrapMachineRoomsStepId = 'scrap_machine_rooms';

  /// Callback registered by the active Store shell to perform section switching.
  void Function(String section)? _sectionNavHandler;

  /// Registers or unregisters the Store shell section navigation callback.
  void setSectionNavigator(void Function(String section)? handler) {
    _sectionNavHandler = handler;
  }

  /// Requests the Store shell to navigate to a specific section by name.
  bool requestSection(String section) {
    if (_sectionNavHandler != null) {
      _sectionNavHandler!(section);
      return true;
    }
    return false;
  }

  /// Verifies whether the authenticated user has access to the Scan for Issue Request FAB in the UI.
  static bool hasScanIssueFabAccess(AuthModel user) {
    return user.isSuperAdmin ||
        user.appWorks.isEmpty ||
        user.appWorks.contains('storissueedit') ||
        user.appWorks.any((w) => w.startsWith('storissue'));
  }

  /// Verifies whether the authenticated user can see the Find Item navigation entry.
  static bool canAccessFindItemNav(AuthModel user) {
    return user.isSuperAdmin || user.appWorks.contains('storeitemfind');
  }

  /// Verifies whether the authenticated user can access the Store Items section.
  static bool canAccessItems(AuthModel user) {
    return true;
  }

  /// Verifies whether the authenticated user can access the Store Places section.
  static bool canAccessPlaces(AuthModel user) {
    return true;
  }

  /// Factory helper creating the canonical GuidedTourStep for the Scan for Issue Request FAB.
  static GuidedTourStep createIssueRequestScanStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: issueRequestScanStepId,
      title: 'Create an Issue Request',
      description:
          "Tap Scan for Issue Request to scan an item's QR code and quickly start your request.",
      targetKey: targetKey ?? scanIssueButtonKey,
      targetSection: sectionIssue,
      onTargetTapped: onTargetTapped,
      featureId: 'issue_request',
      arrowDirection: GuidedTourArrowDirection.top,
      isAvailable: isAvailable ?? hasScanIssueFabAccess,
    );
  }

  /// Factory helper creating the GuidedTourStep for Find Item feature discovery.
  static GuidedTourStep createFindItemStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: findItemStepId,
      title: 'Find Item',
      description:
          'Find Item helps you locate an item and see where it is stored.',
      targetKey: targetKey ?? findItemKey,
      onTargetTapped: onTargetTapped,
      featureId: 'find_item',
      arrowDirection: GuidedTourArrowDirection.auto,
      isAvailable: isAvailable ?? canAccessFindItemNav,
    );
  }

  /// Factory helper creating the GuidedTourStep for Places feature discovery.
  static GuidedTourStep createPlacesStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: placesStepId,
      title: 'Places',
      description:
          "Places lets you access the Store's racks and rooms.",
      targetKey: targetKey ?? placesKey,
      onTargetTapped: onTargetTapped,
      featureId: 'places',
      arrowDirection: GuidedTourArrowDirection.auto,
      isAvailable: isAvailable ?? canAccessPlaces,
    );
  }

  /// Factory helper creating the GuidedTourStep for Good Items feature discovery.
  static GuidedTourStep createGoodItemsStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    VoidCallback? onStepEntered,
    VoidCallback? onStepExited,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: goodItemsStepId,
      title: 'Good Items',
      description:
          'These are store items currently in good, usable condition.',
      targetKey: targetKey ?? goodItemsTabKey,
      targetSection: sectionItems,
      onTargetTapped: onTargetTapped,
      onStepEntered: onStepEntered,
      onStepExited: onStepExited,
      featureId: 'items',
      arrowDirection: GuidedTourArrowDirection.bottom,
      isAvailable: isAvailable ?? canAccessItems,
    );
  }

  /// Factory helper creating the GuidedTourStep for Scrap Items feature discovery.
  static GuidedTourStep createScrapItemsStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    VoidCallback? onStepEntered,
    VoidCallback? onStepExited,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: scrapItemsStepId,
      title: 'Scrap Items',
      description:
          'These are store items classified as scrap.',
      targetKey: targetKey ?? scrapItemsTabKey,
      targetSection: sectionItems,
      onTargetTapped: onTargetTapped,
      onStepEntered: onStepEntered,
      onStepExited: onStepExited,
      featureId: 'items',
      arrowDirection: GuidedTourArrowDirection.bottom,
      isAvailable: isAvailable ?? canAccessItems,
    );
  }

  /// Factory helper creating the GuidedTourStep for Good Item Racks feature discovery.
  static GuidedTourStep createGoodItemRacksStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    VoidCallback? onStepEntered,
    VoidCallback? onStepExited,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: goodItemRacksStepId,
      title: 'Good Item Racks',
      description:
          'These racks are used to store items currently in good, usable condition.',
      targetKey: targetKey ?? goodItemRacksTabKey,
      targetSection: sectionPlaces,
      onTargetTapped: onTargetTapped,
      onStepEntered: onStepEntered,
      onStepExited: onStepExited,
      featureId: 'places',
      arrowDirection: GuidedTourArrowDirection.bottom,
      isAvailable: isAvailable ?? canAccessPlaces,
    );
  }

  /// Factory helper creating the GuidedTourStep for Scrap Item Racks feature discovery.
  static GuidedTourStep createScrapItemRacksStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    VoidCallback? onStepEntered,
    VoidCallback? onStepExited,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: scrapItemRacksStepId,
      title: 'Scrap Item Racks',
      description:
          'These racks are used to store items classified as scrap.',
      targetKey: targetKey ?? scrapItemRacksTabKey,
      targetSection: sectionPlaces,
      onTargetTapped: onTargetTapped,
      onStepEntered: onStepEntered,
      onStepExited: onStepExited,
      featureId: 'places',
      arrowDirection: GuidedTourArrowDirection.bottom,
      isAvailable: isAvailable ?? canAccessPlaces,
    );
  }

  /// Factory helper creating the GuidedTourStep for Good Machine Rooms feature discovery.
  static GuidedTourStep createGoodMachineRoomsStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    VoidCallback? onStepEntered,
    VoidCallback? onStepExited,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: goodMachineRoomsStepId,
      title: 'Good Machine Rooms',
      description:
          'These machine rooms are locations used for good or usable items.',
      targetKey: targetKey ?? goodMachineRoomsTabKey,
      targetSection: sectionPlaces,
      onTargetTapped: onTargetTapped,
      onStepEntered: onStepEntered,
      onStepExited: onStepExited,
      featureId: 'places',
      arrowDirection: GuidedTourArrowDirection.bottom,
      isAvailable: isAvailable ?? canAccessPlaces,
    );
  }

  /// Factory helper creating the GuidedTourStep for Scrap Machine Rooms feature discovery.
  static GuidedTourStep createScrapMachineRoomsStep({
    GlobalKey? targetKey,
    VoidCallback? onTargetTapped,
    VoidCallback? onStepEntered,
    VoidCallback? onStepExited,
    bool Function(AuthModel user)? isAvailable,
  }) {
    return GuidedTourStep(
      id: scrapMachineRoomsStepId,
      title: 'Scrap Machine Rooms',
      description:
          'These machine rooms are locations used for scrap items.',
      targetKey: targetKey ?? scrapMachineRoomsTabKey,
      targetSection: sectionPlaces,
      onTargetTapped: onTargetTapped,
      onStepEntered: onStepEntered,
      onStepExited: onStepExited,
      featureId: 'places',
      arrowDirection: GuidedTourArrowDirection.bottom,
      isAvailable: isAvailable ?? canAccessPlaces,
    );
  }

  /// Assembles and filters the canonical sequence of Store Guided Tour candidate steps.
  static List<GuidedTourStep> buildStoreTourSteps({
    GlobalKey? scanIssueButtonKey,
    AuthModel? user,
    VoidCallback? onScanTargetTapped,
  }) {
    final candidateSteps = [
      createIssueRequestScanStep(
        targetKey: scanIssueButtonKey ?? GuidedTourController.scanIssueButtonKey,
        onTargetTapped: onScanTargetTapped,
      ),
      createFindItemStep(),
      createPlacesStep(),
      createGoodItemsStep(),
      createScrapItemsStep(),
      createGoodItemRacksStep(),
      createScrapItemRacksStep(),
      createGoodMachineRoomsStep(),
      createScrapMachineRoomsStep(),
    ];

    if (user != null) {
      return candidateSteps.where((step) {
        if (step.isAvailable != null && !step.isAvailable!(user)) {
          return false;
        }
        return true;
      }).toList();
    }

    return candidateSteps;
  }

  /// Factory method to build the steps for F1: Creating & Editing Store Items.
  static List<GuidedTourStep> buildF1CreateAndEditItemSteps({
    VoidCallback? onAddItemTapped,
  }) {
    return [
      GuidedTourStep(
        id: 'f1_step1_add_item',
        title: 'Create New Master Item',
        description:
            "Tap '+ Add Item' to register a new material, consumable, or spare part into the central store catalog.",
        targetKey: addItemButtonKey,
        targetSection: sectionItems,
        onTargetTapped: onAddItemTapped,
        featureId: 'f1_create_edit_item',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'f1_step2_search_bar',
        title: 'Catalog Search & Filtering',
        description:
            'Quick-filter items by name, SKU/part code, or category to check existing entries before creating new ones.',
        targetKey: itemSearchBarKey,
        targetSection: sectionItems,
        featureId: 'f1_create_edit_item',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'f1_step3_item_card',
        title: 'Master Item Record & Details',
        description:
            'Each card represents a registered SKU. You can inspect live available quantity, in-cart reservations, and reorder levels.',
        targetKey: firstItemCardKey,
        targetSection: sectionItems,
        featureId: 'f1_create_edit_item',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f1_step4_stock_metrics',
        title: 'Real-Time Stock Availability',
        description:
            'Live stock pills display exactly how many units are unreserved on the shelf, in active carts, and ready at the store counter.',
        targetKey: firstItemStockMetricsKey,
        targetSection: sectionItems,
        featureId: 'f1_create_edit_item',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f1_step5_edit_button',
        title: 'Modify Existing Specifications',
        description:
            "Need to change a shelf location, update specifications, or adjust reorder thresholds? Tap 'Edit' on any item card anytime.",
        targetKey: firstItemEditButtonKey,
        targetSection: sectionItems,
        featureId: 'f1_create_edit_item',
        arrowDirection: GuidedTourArrowDirection.left,
      ),
    ];
  }

  /// Factory method to build the steps for F2: Understanding Item Cards & Inventory Stock.
  static List<GuidedTourStep> buildF2ItemCardSteps() {
    return [
      GuidedTourStep(
        id: 'f2_step1_search_filter',
        title: 'Quick Search & Filtering',
        description:
            'Instantly locate items by Item Name, SKU/part code, or apply category filters to narrow down the master catalog.',
        targetKey: itemSearchBarKey,
        targetSection: sectionItems,
        featureId: 'f2_item_cards_stock',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'f2_step2_stock_counts',
        title: 'Real-Time Stock Counts',
        description:
            'Live stock pills show available unreserved stock, quantities held in user carts, pending requisitions, and counter-ready units.',
        targetKey: firstItemStockMetricsKey,
        targetSection: sectionItems,
        featureId: 'f2_item_cards_stock',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f2_step3_item_details',
        title: 'Item Identification & Tags',
        description:
            'Review master SKU code, category classification, units of measure, and tap Details for a full department activity breakdown.',
        targetKey: firstItemDetailsKey,
        targetSection: sectionItems,
        featureId: 'f2_item_cards_stock',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f2_step4_actions_menu',
        title: 'Item Action Controls',
        description:
            'Use action buttons to add items directly to your requisition cart, generate QR stickers, inspect location, or review pricing.',
        targetKey: firstItemActionsKey,
        targetSection: sectionItems,
        featureId: 'f2_item_cards_stock',
        arrowDirection: GuidedTourArrowDirection.left,
      ),
    ];
  }

  /// Factory method to build the steps for F3: Managing Racks & Places (Facility Architecture).
  static List<GuidedTourStep> buildF3RacksAndPlacesSteps() {
    return [
      GuidedTourStep(
        id: 'f3_step1_places_nav',
        title: 'Warehouse Layout Structure',
        description:
            'Access the structural layout of your store: consumable racks, machine rooms, and storage bins.',
        targetKey: placesKey,
        targetSection: sectionPlaces,
        featureId: 'f3_racks_places',
        arrowDirection: GuidedTourArrowDirection.auto,
      ),
      GuidedTourStep(
        id: 'f3_step2_zone_selectors',
        title: 'Storage Categories',
        description:
            'Browse warehouse rooms, machine spares locations, and organized rack clusters across Good and Scrap inventory.',
        targetKey: placesZoneTabsKey,
        targetSection: sectionPlaces,
        featureId: 'f3_racks_places',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'f3_step3_rack_card',
        title: 'Inspect Shelf Capacity & Items',
        description:
            'Tap any rack card to view all SKUs currently stored on that shelf, total item count, and available capacity.',
        targetKey: firstRackCardKey,
        targetSection: sectionPlaces,
        featureId: 'f3_racks_places',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f3_step4_print_qr',
        title: 'Print Shelf Signboards',
        description:
            'Print large-format QR placards to attach to physical rack pillars for quick operator scanning.',
        targetKey: firstRackPrintQrKey,
        targetSection: sectionPlaces,
        featureId: 'f3_racks_places',
        arrowDirection: GuidedTourArrowDirection.left,
      ),
    ];
  }

  /// Factory method to build the steps for F4: Receiving Items & Inwarding (GRN / Supplier Delivery).
  static List<GuidedTourStep> buildF4ReceivingAndInwardSteps() {
    return [
      GuidedTourStep(
        id: 'f4_step1_inward_action',
        title: 'Inward Incoming Goods',
        description:
            "Tap 'Receive Stock' to start a new Goods Received Note (GRN) when shipments arrive from suppliers or internal plants.",
        targetKey: receiveStockActionKey,
        targetSection: sectionReceive,
        featureId: 'f4_receive_inward',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'f4_step2_delivery_details',
        title: 'Log Delivery Details',
        description:
            'Review inward consignments: received quantity (+QTY), item codes, delivery timestamps, receiving operator, and delivery challan notes.',
        targetKey: firstReceiveRecordKey,
        targetSection: sectionReceive,
        featureId: 'f4_receive_inward',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f4_step3_destination_rack',
        title: 'Assign Shelf Location',
        description:
            'Every received consignment is mapped directly to its assigned warehouse room and shelf rack location for rapid placement.',
        targetKey: firstReceiveRackLocationKey,
        targetSection: sectionReceive,
        featureId: 'f4_receive_inward',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f4_step4_print_qr',
        title: 'Print Barcode Labels',
        description:
            'Generate and print QR code stickers to label incoming boxes or parts before placing them on warehouse shelves.',
        targetKey: firstReceivePrintQrKey,
        targetSection: sectionReceive,
        featureId: 'f4_receive_inward',
        arrowDirection: GuidedTourArrowDirection.left,
      ),
    ];
  }

  /// Factory method to build the steps for F5: Finding Items & Shelf Locators (Inventory Navigation).
  static List<GuidedTourStep> buildF5FindItemsSteps() {
    return [
      GuidedTourStep(
        id: 'f5_step1_find_item_nav',
        title: 'Store Locator Tool',
        description:
            "Tap 'Find Item' to quickly search any tool, spare, or consumable across all store rooms.",
        targetKey: findItemKey,
        targetSection: sectionFindItem,
        featureId: 'f5_find_items',
        arrowDirection: GuidedTourArrowDirection.auto,
      ),
      GuidedTourStep(
        id: 'f5_step2_search_bar',
        title: 'Search by Name or SKU',
        description:
            'Type any part name, code, or keyword to see instant live matches with real-time stock balances.',
        targetKey: findItemSearchBarKey,
        targetSection: sectionFindItem,
        featureId: 'f5_find_items',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'f5_step3_shelf_coordinates',
        title: 'Precise Location Coordinates',
        description:
            'Displays the exact Building, Room, and Rack code so you can walk directly to the shelf.',
        targetKey: firstFindItemLocationKey,
        targetSection: sectionFindItem,
        featureId: 'f5_find_items',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f5_step4_available_stock',
        title: 'Check Stock Before Walking',
        description:
            'Verifies that the item has available unreserved stock before you travel to the warehouse.',
        targetKey: firstFindItemStockPillKey,
        targetSection: sectionFindItem,
        featureId: 'f5_find_items',
        arrowDirection: GuidedTourArrowDirection.left,
      ),
    ];
  }

  /// Factory method to build the steps for F6: Item Issuing Request (Add to Cart & Submit).
  static List<GuidedTourStep> buildF6IndentRequestSteps() {
    return [
      GuidedTourStep(
        id: 'issue_req_step1_add_to_cart',
        title: '1. Add Item to Cart',
        description:
            "Browse catalog materials and tap the 'Add to Cart' button on an item card to add required units.",
        targetKey: firstItemAddToCartKey,
        targetSection: sectionItems,
        featureId: 'f6_issue_request',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'issue_req_step2_open_cart',
        title: '2. Open Requisition Cart',
        description:
            'Your items collect in the Requisition Cart at the top header. The badge shows your total line count. Tap to review.',
        targetKey: requisitionCartHeaderKey,
        targetSection: sectionItems,
        featureId: 'f6_issue_request',
        arrowDirection: GuidedTourArrowDirection.bottom,
        onTargetTapped: () => openStoreCartHandler?.call(),
      ),
      GuidedTourStep(
        id: 'issue_req_step3_submit_request',
        title: '3. Submit Issue Request',
        description:
            'In the cart, specify your destination machine and reason, check quantities, and tap Submit Request to send for approval.',
        targetKey: requisitionCartSubmitKey,
        targetSection: sectionItems,
        featureId: 'f6_issue_request',
        arrowDirection: GuidedTourArrowDirection.top,
        onStepEntered: () => openStoreCartHandler?.call(),
      ),
    ];
  }

  /// Factory method to build the steps for F7: Accept & Issue Requests (Go to Issue, Approve, Ready for Issue, Submit).
  static List<GuidedTourStep> buildF7ApprovalGovernanceSteps() {
    return [
      GuidedTourStep(
        id: 'accept_req_step1_go_to_issue',
        title: '1. Go to Issue Section',
        description:
            'Tap Issue on the navigation menu to view all incoming material requisitions and shopfloor requests.',
        targetKey: issueNavButtonKey,
        targetSection: sectionIssue,
        featureId: 'f7_accept_issue',
        arrowDirection: GuidedTourArrowDirection.right,
      ),
      GuidedTourStep(
        id: 'accept_req_step2_pending_queue',
        title: '2. Review Active Requisitions',
        description:
            "Under 'Ready for Issue & Active', locate requests marked 'PENDING APPROVAL' submitted by shopfloor personnel.",
        targetKey: pendingApprovalsTabKey,
        targetSection: sectionIssue,
        featureId: 'f7_accept_issue',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'accept_req_step3_click_approve',
        title: '3. Approve Requisition',
        description:
            "Tap 'Approve' to inspect line quantities, verify warehouse balance, adjust approved counts if needed, and confirm sign-off.",
        targetKey: firstIssueApproveButtonKey,
        targetSection: sectionIssue,
        featureId: 'f7_accept_issue',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'accept_req_step4_ready_for_issue',
        title: '4. Ready for Issue Status',
        description:
            "Once approved, the status updates to 'READY FOR ISSUE', confirming that physical material handover can proceed.",
        targetKey: readyForIssueBadgeKey,
        targetSection: sectionIssue,
        featureId: 'f7_accept_issue',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'accept_req_step5_submit_dispatch',
        title: '5. Issue & Submit Handover',
        description:
            "Tap 'Issue (Pick Up)' to select the source shelf/rack, verify items, and tap 'Submit' to deduct stock and complete the request.",
        targetKey: firstIssueDispatchButtonKey,
        targetSection: sectionIssue,
        featureId: 'f7_accept_issue',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
    ];
  }

  /// Factory method to build the steps for F8: Physical Item Issuance from Racks (Outward Dispatch).
  static List<GuidedTourStep> buildF8PhysicalIssuanceSteps() {
    return [
      GuidedTourStep(
        id: 'f8_step1_ready_dispatch',
        title: 'Ready for Dispatch Queue',
        description:
            'Shows all requisitions that have received managerial approval and are ready for physical issuance.',
        targetKey: approvedRequestsTabKey,
        targetSection: sectionIssue,
        featureId: 'f8_physical_issuance',
        arrowDirection: GuidedTourArrowDirection.bottom,
      ),
      GuidedTourStep(
        id: 'f8_step2_locate_rack',
        title: 'Locate Storage Rack',
        description:
            'Identifies the exact room and rack code where the storekeeper must pick the physical parts.',
        targetKey: issueShelfCoordinatesKey,
        targetSection: sectionIssue,
        featureId: 'f8_physical_issuance',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f8_step3_scan_verify',
        title: 'Scan QR to Verify Pick',
        description:
            "Scan the item's barcode or shelf QR to ensure 100% pick accuracy before handing goods to the requester.",
        targetKey: issueScanVerifyKey,
        targetSection: sectionIssue,
        featureId: 'f8_physical_issuance',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
      GuidedTourStep(
        id: 'f8_step4_record_dispatch',
        title: 'Record Dispatch & Deduct Stock',
        description:
            'Deducts stock from the warehouse ledger in real time and notifies the requester that their material is ready.',
        targetKey: issueConfirmDispatchKey,
        targetSection: sectionIssue,
        featureId: 'f8_physical_issuance',
        arrowDirection: GuidedTourArrowDirection.top,
      ),
    ];
  }

  bool _mandatoryHelpDontShowAgain = false;
  bool get isMandatoryHelpDontShowAgain => _mandatoryHelpDontShowAgain;

  /// Sets whether the user has toggled 'Don't show again' on the mandatory Help & Support spotlight card.
  void setMandatoryHelpDontShowAgain(bool value) {
    _mandatoryHelpDontShowAgain = value;
  }

  /// Resets the current session dismissal state and tour step index (e.g. upon user login).
  void resetSession() {
    _ref.read(guidedTourSessionDismissedProvider.notifier).state = false;
    final currentState = _ref.read(guidedTourStateProvider);
    _ref.read(guidedTourStateProvider.notifier).state = currentState.copyWith(
      currentStepIndex: 0,
      isSessionDismissed: false,
    );
    _mandatoryHelpDontShowAgain = false;
  }

  /// Clears tour dismissal preferences and resets the session so the tour can be replayed.
  Future<void> resetTour({required String uid}) async {
    try {
      final sp = _ref.read(spRepositoryProvider);
      await sp.remove('$_prefKeyPrefix$uid');
      await sp.remove('$_legacyPrefKeyPrefix$uid');
      await sp.remove('$_mandatoryHelpPrefKeyPrefix$uid');
    } catch (_) {}
    resetSession();
  }

  /// Checks whether this user has permanently dismissed the mandatory Help & Support tour via 'Don't show again'.
  Future<bool> hasCompletedMandatoryHelp(String uid) async {
    try {
      final sp = _ref.read(spRepositoryProvider);
      final val = await sp.getStringValue('$_mandatoryHelpPrefKeyPrefix$uid');
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Marks the mandatory Help & Support tap as completed for this user.
  /// If [dontShowAgain] is true, permanently suppresses the popup on future logins.
  /// If [dontShowAgain] is false, only dismisses it for the current login session.
  Future<void> markMandatoryHelpCompleted(
    String uid, {
    bool? dontShowAgain,
  }) async {
    final bool shouldPersist = dontShowAgain ?? _mandatoryHelpDontShowAgain;
    if (shouldPersist) {
      try {
        final sp = _ref.read(spRepositoryProvider);
        await sp.setStringValue('$_mandatoryHelpPrefKeyPrefix$uid', 'true');
      } catch (_) {}
    }
    dismissTour(uid: uid, dontShowAgain: shouldPersist);
  }

  /// Factory helper creating the mandatory first-time Help & Support step (like games).
  GuidedTourStep createMandatoryHelpStep({
    required AuthModel user,
    VoidCallback? onHelpTapped,
  }) {
    return GuidedTourStep(
      id: 'mandatory_help_intro',
      title: 'Welcome to Store App',
      description:
          'Tap the Help & Support icon to review interactive walkthroughs, operational lifecycle guides, and workflow tutorials.',
      targetKey: storeHelpButtonKey,
      onTargetTapped: onHelpTapped,
      featureId: 'mandatory_help',
      arrowDirection: GuidedTourArrowDirection.bottom,
      isMandatory: true,
    );
  }

  /// Backwards-compatible alias for resetTour.
  Future<void> enableTourAgain({required String uid}) => resetTour(uid: uid);

  /// Verifies whether the authenticated user has access to Issue Request flow.
  bool isIssueRequester(AuthModel user) {
    return hasScanIssueFabAccess(user);
  }

  /// Checks whether the Guided Tour should be automatically displayed for this user.
  Future<bool> shouldShowTour({required AuthModel user}) async {
    // 1. Must not already have been dismissed in the current session
    final sessionDismissed = _ref.read(guidedTourSessionDismissedProvider);
    if (sessionDismissed) return false;

    // 3. Must not have "Don't show this again" persisted for this specific user
    try {
      final sp = _ref.read(spRepositoryProvider);
      // Check current generic preference first
      final val = await sp.getStringValue('$_prefKeyPrefix${user.uid}');
      if (val == 'true') return false;

      // Check legacy Step 1 preference for backward compatibility
      final legacyVal = await sp.getStringValue(
        '$_legacyPrefKeyPrefix${user.uid}',
      );
      if (legacyVal == 'true') return false;
    } catch (_) {
      // In case of any local storage read error, default to allowing tour
    }

    return true;
  }

  /// Backwards-compatible alias for shouldShowTour.
  Future<bool> shouldShowStep1({required AuthModel user}) =>
      shouldShowTour(user: user);

  /// Filters a list of candidate steps according to user capabilities/conditions.
  List<GuidedTourStep> filterAvailableSteps({
    required List<GuidedTourStep> steps,
    required AuthModel user,
  }) {
    return steps.where((step) {
      if (step.isAvailable != null && !step.isAvailable!(user)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Starts a Guided Tour with candidate steps, optionally filtered by user capabilities.
  void startTour({required List<GuidedTourStep> steps, AuthModel? user}) {
    _ref.read(guidedTourSessionDismissedProvider.notifier).state = false;
    final activeSteps =
        user != null ? filterAvailableSteps(steps: steps, user: user) : steps;
    initTour(activeSteps);
  }

  /// Initializes the sequence of active steps for the Guided Tour.
  void initTour(List<GuidedTourStep> steps) {
    _ref.read(guidedTourSessionDismissedProvider.notifier).state = false;
    _ref.read(guidedTourStateProvider.notifier).state = GuidedTourState(
      steps: steps,
      currentStepIndex: 0,
      isSessionDismissed: false,
    );
    if (steps.isNotEmpty) {
      final first = steps.first;
      if (first.targetSection != null) {
        requestSection(first.targetSection!);
      }
      first.onStepEntered?.call();
    }
  }

  /// Advances to the next step in the sequence if available.
  void nextStep() {
    final current = _ref.read(guidedTourStateProvider);
    if (current.hasNext) {
      current.currentStep?.onStepExited?.call();
      final nextIndex = current.currentStepIndex + 1;
      _ref.read(guidedTourStateProvider.notifier).state = current.copyWith(
        currentStepIndex: nextIndex,
      );
      if (nextIndex < current.steps.length) {
        final nextStep = current.steps[nextIndex];
        if (nextStep.targetSection != null) {
          requestSection(nextStep.targetSection!);
        }
        nextStep.onStepEntered?.call();
      }
    }
  }

  /// Returns to the previous step in the sequence if available.
  void previousStep() {
    final current = _ref.read(guidedTourStateProvider);
    if (current.hasPrevious) {
      current.currentStep?.onStepExited?.call();
      final prevIndex = current.currentStepIndex - 1;
      _ref.read(guidedTourStateProvider.notifier).state = current.copyWith(
        currentStepIndex: prevIndex,
      );
      if (prevIndex >= 0 && prevIndex < current.steps.length) {
        final prevStep = current.steps[prevIndex];
        if (prevStep.targetSection != null) {
          requestSection(prevStep.targetSection!);
        }
        prevStep.onStepEntered?.call();
      }
    }
  }

  /// Jumps to an explicit step index in the sequence.
  void goToStep(int index) {
    final current = _ref.read(guidedTourStateProvider);
    if (index >= 0 &&
        index < current.totalSteps &&
        index != current.currentStepIndex) {
      current.currentStep?.onStepExited?.call();
      _ref.read(guidedTourStateProvider.notifier).state = current.copyWith(
        currentStepIndex: index,
      );
      final destStep = current.steps[index];
      if (destStep.targetSection != null) {
        requestSection(destStep.targetSection!);
      }
      destStep.onStepEntered?.call();
    }
  }

  /// Marks the Guided Tour as dismissed for the session and optionally persists preference per user.
  Future<void> dismissTour({
    required String uid,
    required bool dontShowAgain,
  }) async {
    // Mark dismissed in current session
    _ref.read(guidedTourSessionDismissedProvider.notifier).state = true;
    final currentState = _ref.read(guidedTourStateProvider);
    _ref.read(guidedTourStateProvider.notifier).state = currentState.copyWith(
      isSessionDismissed: true,
    );

    // Persist preference per user if requested
    if (dontShowAgain && uid.isNotEmpty) {
      try {
        final sp = _ref.read(spRepositoryProvider);
        await sp.setStringValue('$_prefKeyPrefix$uid', 'true');
        // Also persist legacy key so older checks remain consistent
        await sp.setStringValue('$_legacyPrefKeyPrefix$uid', 'true');
      } catch (_) {}
    }
  }

  /// Skips the entire Guided Tour.
  Future<void> skipTour({
    required String uid,
    required bool dontShowAgain,
  }) async {
    await dismissTour(uid: uid, dontShowAgain: dontShowAgain);
  }

  /// Completes the Guided Tour.
  Future<void> completeTour({
    required String uid,
    required bool dontShowAgain,
  }) async {
    await dismissTour(uid: uid, dontShowAgain: dontShowAgain);
  }

  /// Backwards-compatible alias for dismissTour.
  Future<void> dismissStep1({
    required String uid,
    required bool dontShowAgain,
  }) => dismissTour(uid: uid, dontShowAgain: dontShowAgain);
}
