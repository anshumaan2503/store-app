// lib/src/store/presentation/views_new/store_dashboard_shell_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/controllers/users_controller.dart';
import '../../../auth/domains/models/auth_model.dart';
import '../../../components/motion_widgets.dart';
import '../../../components/ui_tokens.dart';
import 'issue/issues_list_page.dart';
import 'issue/issues_return_list_page.dart';
import 'items/find_item_page.dart';
import 'items/items_list_page.dart';
import 'notifications/store_notifications_sheet.dart';
import 'help/store_help_sheet.dart';
import 'racks/racks_list_page.dart';
import 'receive/receive_view_page.dart';
import '../../../auth/login_screens/user_management/view_user_page.dart';
import 'guided_tour/guided_tour_overlay.dart';
import '../../controllers/guided_tour_controller.dart';
import '../../controllers/store_items_controller.dart';
import '../../controllers/store_notification_controller.dart';
import '../../controllers/store_cart_controller.dart';
import 'cart/store_cart_page.dart';
import 'cart/store_cart_timer_settings_sheet.dart';
import 'indent/indent_drafts_page.dart';
import '../../controllers/indent_draft_controller.dart';

/* ---------------- Palette (your theme) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);
const _brandPrimary = Color(0xFF2563EB);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

/* ---------------- Navigation Model ---------------- */

enum StoreSection { dashboard, items, findItem, places, admin, receive, issue, returns }

IconData _iconForSection(StoreSection s) {
  switch (s) {
    case StoreSection.dashboard:
      return Icons.grid_view_rounded;
    case StoreSection.items:
      return Icons.list_alt_rounded;
    case StoreSection.findItem:
      return Icons.location_searching_rounded;
    case StoreSection.places:
      return Icons.place_rounded;
    case StoreSection.admin:
      return Icons.admin_panel_settings_rounded;
    case StoreSection.receive:
      return Icons.inbox_rounded;
    case StoreSection.issue:
      return Icons.call_split_rounded;
    case StoreSection.returns:
      return Icons.reset_tv_rounded;
  }
}

String _titleForSection(StoreSection s) {
  switch (s) {
    case StoreSection.dashboard:
      return 'Store Dashboard';
    case StoreSection.items:
      return 'Items';
    case StoreSection.findItem:
      return 'Find Item';
    case StoreSection.places:
      return 'Places';
    case StoreSection.admin:
      return 'Manage Users';
    case StoreSection.receive:
      return 'Receive';
    case StoreSection.issue:
      return 'Issue';
    case StoreSection.returns:
      return 'Return';
  }
}

//* ---------------- Store Permissions Extension ---------------- */

extension AuthModelStorePermissions on AuthModel {
  bool get canReceive =>
      isSuperAdmin ||
      appWorks.contains('storeadmin') ||
      appWorks.any((w) => w.startsWith('storreceive') || w == 'historyReceiveItem');

  bool get canIssue =>
      isSuperAdmin ||
      appWorks.contains('storeadmin') ||
      appWorks.any((w) => w.startsWith('storissue') || w == 'historyissueItem');

  bool get canReturn =>
      isSuperAdmin ||
      appWorks.contains('storeadmin') ||
      appWorks.contains('storissuereturn');

  bool get canPlaces =>
      isSuperAdmin ||
      appWorks.contains('storeadmin') ||
      appWorks.any((w) => w.startsWith('storeplace'));

  bool get canDashboard => true;

  bool get canFindItem =>
      isSuperAdmin ||
      appWorks.contains('storeadmin') ||
      appWorks.contains('storeitemfind');

  bool get canFindItemNav =>
      isSuperAdmin ||
      appWorks.contains('storeadmin') ||
      appWorks.contains('storeitemfind');

  bool get canRaiseIndent =>
      isSuperAdmin ||
      canIssue ||
      canReceive ||
      appWorks.contains('storeadmin') ||
      appWorks.contains('storrefilladd') ||
      appWorks.contains('storeitemview');
}

/* ---------------- Page ---------------- */

class StoreDashboardShellPage extends ConsumerStatefulWidget {
  const StoreDashboardShellPage({super.key, this.showBack = true});
  final bool showBack;

  @override
  ConsumerState<StoreDashboardShellPage> createState() =>
      _StoreDashboardShellPageState();
}

class _StoreDashboardShellPageState
    extends ConsumerState<StoreDashboardShellPage>
    with TickerProviderStateMixin {
  StoreSection _section = StoreSection.items;
  bool _initialSectionSet = false;
  late final TabController _dashTabs = TabController(length: 5, vsync: this);

  OverlayEntry? _guidedTourEntry;
  String? _lastCheckedMandatoryUid;
  bool _mandatoryHelpChecked = false;

  void _checkMandatoryHelpTour(AuthModel user) {
    if (_lastCheckedMandatoryUid == user.uid && _mandatoryHelpChecked) return;
    _lastCheckedMandatoryUid = user.uid;
    _mandatoryHelpChecked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = ref.read(guidedTourControllerProvider);
      final hasCompleted = await controller.hasCompletedMandatoryHelp(user.uid);
      if (!hasCompleted && mounted) {
        final step = controller.createMandatoryHelpStep(
          user: user,
          onHelpTapped: () async {
            final dontShowAgain = controller.isMandatoryHelpDontShowAgain;
            await controller.markMandatoryHelpCompleted(
              user.uid,
              dontShowAgain: dontShowAgain,
            );
            if (mounted) {
              showStoreHelpSheet(context, onStartTour: _startGuidedTour);
            }
          },
        );
        _startGuidedTour([step]);
      }
    });
  }

  void _removeGuidedTourOverlay() {
    if (_guidedTourEntry != null) {
      _guidedTourEntry?.remove();
      _guidedTourEntry = null;
    }
  }

  void _dismissGuidedTour({required bool dontShowAgain, String? uid}) {
    _removeGuidedTourOverlay();
    if (uid != null && mounted) {
      ref
          .read(guidedTourControllerProvider)
          .dismissTour(uid: uid, dontShowAgain: dontShowAgain);
    }
  }

  void _startGuidedTour(List<GuidedTourStep> steps) {
    if (steps.isEmpty) return;
    _removeGuidedTourOverlay();

    final user = ref.read(userFindOneDataStreamProvider).value;
    final controller = ref.read(guidedTourControllerProvider);

    // If the first step targets a different section, navigate there first
    final firstStep = steps.first;
    if (firstStep.targetSection != null) {
      _handleTourSectionNavigation(firstStep.targetSection!);
    }

    controller.startTour(steps: steps, user: user);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlay = Overlay.maybeOf(context);
      if (overlay == null) return;

      _removeGuidedTourOverlay();

      _guidedTourEntry = OverlayEntry(
        builder: (context) => GuidedTourOverlay(
          onDismiss: ({required bool dontShowAgain}) {
            _dismissGuidedTour(dontShowAgain: false, uid: user?.uid);
          },
          onDontShowAgainChanged: (dontShow) {
            if (user != null) {
              ref
                  .read(guidedTourControllerProvider)
                  .dismissTour(uid: user.uid, dontShowAgain: dontShow);
            }
          },
        ),
      );

      overlay.insert(_guidedTourEntry!);
    });
  }

  @override
  void initState() {
    super.initState();
    final cachedUser = ref.read(userFindOneDataStreamProvider).value;
    if (cachedUser != null &&
        cachedUser.canIssue &&
        !cachedUser.canReceive &&
        !cachedUser.isSuperAdmin) {
      _section = StoreSection.issue;
      _initialSectionSet = true;
    }
    ref.read(guidedTourControllerProvider).setSectionNavigator((sectionName) {
      _handleTourSectionNavigation(sectionName);
    });
    GuidedTourController.openIndentDraftsHandler = () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const IndentDraftsPage(),
          ),
        );
      }
    };
    GuidedTourController.openStoreCartHandler = () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StoreCartPage(),
          ),
        );
      }
    };
  }

  @override
  void dispose() {
    _removeGuidedTourOverlay();
    ref.read(guidedTourControllerProvider).setSectionNavigator(null);
    GuidedTourController.openIndentDraftsHandler = null;
    GuidedTourController.openStoreCartHandler = null;
    _dashTabs.dispose();
    super.dispose();
  }

  void _handleTourSectionNavigation(String sectionName) {
    StoreSection? target;
    switch (sectionName.toLowerCase()) {
      case 'items':
        target = StoreSection.items;
        break;
      case 'places':
        target = StoreSection.places;
        break;
      case 'issue':
        target = StoreSection.issue;
        break;
      case 'finditem':
      case 'find_item':
        target = StoreSection.findItem;
        break;
      case 'dashboard':
        target = StoreSection.dashboard;
        break;
      case 'receive':
        target = StoreSection.receive;
        break;
      case 'returns':
      case 'return':
        target = StoreSection.returns;
        break;
    }
    if (target != null && target != _section) {
      setState(() {
        _section = target!;
      });
    }
  }

  bool get _isMain3 =>
      _section == StoreSection.dashboard ||
      _section == StoreSection.items ||
      _section == StoreSection.findItem ||
      _section == StoreSection.places;

  @override
  Widget build(BuildContext context) {
    // Real-time notification sync: when item inventory updates, refresh notifications
    ref.listen(itemAllPagedStreamProvider, (_, __) {
      ref.read(storeNotificationControllerProvider.notifier).refresh();
    });

    // Coordinate Store section with Guided Tour active step if cross-section navigation is required
    ref.listen<GuidedTourState>(guidedTourStateProvider, (previous, next) {
      final step = next.currentStep;
      if (step?.targetSection != null) {
        _handleTourSectionNavigation(step!.targetSection!);
      }
    });

    // Clean up active overlay if the tour was dismissed anywhere in the app
    ref.listen<bool>(guidedTourSessionDismissedProvider, (previous, dismissed) {
      if (dismissed && _guidedTourEntry != null) {
        _removeGuidedTourOverlay();
      }
    });

    final w = MediaQuery.of(context).size.width;
    final pagedUser = ref.watch(userFindOneDataStreamProvider);
    // Wide enough to show screenshot-style dual sidebars
    final bool showSidebar = (kIsWeb && w >= 980) || w >= 1100;

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            backgroundColor: _surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final u = user;
        if (!_initialSectionSet) {
          _initialSectionSet = true;
          if (u.canIssue && !u.canReceive && !u.isSuperAdmin) {
            _section = StoreSection.issue;
          }
        }
        if (_section == StoreSection.findItem && !u.canFindItemNav) {
          _section = (u.canIssue && !u.canReceive && !u.isSuperAdmin)
              ? StoreSection.issue
              : StoreSection.items;
        }
        _checkMandatoryHelpTour(u);
        return Scaffold(
          backgroundColor: _surface,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgTop, _bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child:
                    showSidebar
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _UnifiedStoreSidebar(
                              selected: _section,
                              user: u,
                              onSelect: (s) {
                                if (s == StoreSection.findItem && !u.canFindItemNav) return;
                                if (s == StoreSection.places && !u.canPlaces) return;
                                setState(() => _section = s);
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildContent(
                                context,
                                u,
                                showSidebar: true,
                              ),
                            ),
                          ],
                        )
                        : _buildContent(context, u, showSidebar: false),
              ),
            ),
          ),

          // Mobile: bottom nav only for Dashboard/Items/Places (like your structure)
          bottomNavigationBar:
              showSidebar
                  ? null
                  : _BottomNav(
                    section: _section,
                    user: u,
                    onChange: (s) {
                      if (s == StoreSection.findItem && !u.canFindItemNav) return;
                      setState(() => _section = s);
                    },
                  ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    AuthModel user, {
    required bool showSidebar,
  }) {
    final title = _titleForSection(_section);
    final leadingIcon = _iconForSection(_section);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(
          showBack: widget.showBack,
          title: title,
          subtitle: 'Inventory & Operations',
          leadingIcon: leadingIcon,
          onBack: () {
            if (_section != StoreSection.items && _section != StoreSection.dashboard) {
              setState(() => _section = StoreSection.items);
            } else {
              Navigator.maybePop(context);
            }
          },
          onStartTour: _startGuidedTour,
          // 3-dots menu to access Receive, Issue, Return on mobile/tablet or top header
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.canRaiseIndent) ...[
                Consumer(
                  builder: (context, ref, _) {
                    final draftState = ref.watch(indentDraftControllerProvider);
                    return Badge.count(
                      count: draftState.lineCount,
                      isLabelVisible: draftState.lineCount > 0,
                      backgroundColor: _ink900,
                      textColor: _surface,
                      child: Tooltip(
                        message: 'Indent Cart (${draftState.lineCount})',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const IndentDraftsPage(),
                              ),
                            );
                          },
                          child: Container(
                            key: GuidedTourController.indentCartButtonKey,
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _stroke),
                            ),
                            child: const Icon(
                              Icons.post_add_rounded,
                              color: _ink900,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (user.canIssue) ...[
                Consumer(
                  builder: (context, ref, _) {
                    final cart = ref.watch(storeCartProvider);
                    return Badge.count(
                      count: cart.lineCount,
                      isLabelVisible: cart.lineCount > 0,
                      backgroundColor: _ink900,
                      textColor: _surface,
                      child: Tooltip(
                        message: 'Requisition Cart (${cart.lineCount})',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StoreCartPage(),
                              ),
                            );
                          },
                          child: Container(
                            key: GuidedTourController.requisitionCartHeaderKey,
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _stroke),
                            ),
                            child: const Icon(
                              Icons.shopping_cart_outlined,
                              color: _ink900,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (user.isSuperAdmin)
                Builder(
                  builder: (context) {
                    final w = MediaQuery.of(context).size.width;
                    if (w < 430) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Settings',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => showCartTimerSettingsSheet(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _stroke),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: _brandPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    );
                  },
                ),
              if (!showSidebar &&
                  (user.canReceive ||
                      user.canIssue ||
                      user.canReturn ||
                      user.isSuperAdmin))
                PopupMenuButton<StoreSection>(
                  tooltip: 'More Sections',
                  onSelected: (s) => setState(() => _section = s),
                  itemBuilder: (_) {
                    final items = <PopupMenuEntry<StoreSection>>[];

                    if (user.canReceive) {
                      items.add(
                        const PopupMenuItem<StoreSection>(
                          value: StoreSection.receive,
                          child: Row(
                            children: [
                              Icon(Icons.inbox_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Receive'),
                            ],
                          ),
                        ),
                      );
                    }

                    if (user.canIssue) {
                      items.add(
                        const PopupMenuItem<StoreSection>(
                          value: StoreSection.issue,
                          child: Row(
                            children: [
                              Icon(Icons.call_split_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Issue'),
                            ],
                          ),
                        ),
                      );
                    }
                    if (user.canReturn) {
                      items.add(
                        const PopupMenuItem<StoreSection>(
                          value: StoreSection.returns,
                          child: Row(
                            children: [
                              Icon(Icons.reset_tv_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Return'),
                            ],
                          ),
                        ),
                      );
                    }
                    if (user.isSuperAdmin) {
                      items.add(
                        const PopupMenuItem<StoreSection>(
                          value: StoreSection.admin,
                          child: Row(
                            children: [
                              Icon(Icons.manage_accounts_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Manage Users'),
                            ],
                          ),
                        ),
                      );
                    }
                    return items;
                  },

                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stroke),
                    ),
                    child: const Icon(Icons.more_vert, color: _ink900),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: AnimatedSwitcher(
            duration: AppAnimationTokens.transition,
            switchInCurve: AppAnimationTokens.entrance,
            switchOutCurve: AppAnimationTokens.exit,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.015, 0.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildSectionView(user),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionView(AuthModel user) {
    switch (_section) {
      case StoreSection.dashboard:
        return Column(
          key: const ValueKey(StoreSection.dashboard),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _PillTabs(controller: _dashTabs),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TabBarView(
                controller: _dashTabs,
                physics: const BouncingScrollPhysics(),
                children: const [
                  _OverviewTab(),
                  _MovementsTab(),
                  _ItemsTabInsideDashboard(),
                  _PlacesTabInsideDashboard(),
                  _UsersTab(),
                ],
              ),
            ),
          ],
        );
      case StoreSection.items:
        return KeyedSubtree(
          key: const ValueKey(StoreSection.items),
          child: ItemsListPage(
            goodItemsTabKey: GuidedTourController.goodItemsTabKey,
            scrapItemsTabKey: GuidedTourController.scrapItemsTabKey,
          ),
        );
      case StoreSection.findItem:
        if (!user.canFindItemNav) {
          return const KeyedSubtree(
            key: ValueKey(StoreSection.items),
            child: ItemsListPage(),
          );
        }
        return const KeyedSubtree(
          key: ValueKey(StoreSection.findItem),
          child: FindItemPage(),
        );
      case StoreSection.places:
        if (!user.canPlaces) {
          return const KeyedSubtree(
            key: ValueKey(StoreSection.items),
            child: ItemsListPage(),
          );
        }
        return KeyedSubtree(
          key: const ValueKey(StoreSection.places),
          child: RacksListPage(
            goodItemRacksTabKey: GuidedTourController.goodItemRacksTabKey,
            scrapItemRacksTabKey: GuidedTourController.scrapItemRacksTabKey,
            goodMachineRoomsTabKey:
                GuidedTourController.goodMachineRoomsTabKey,
            scrapMachineRoomsTabKey:
                GuidedTourController.scrapMachineRoomsTabKey,
          ),
        );
      case StoreSection.admin:
        return const KeyedSubtree(
          key: ValueKey(StoreSection.admin),
          child: UsersListPage(),
        );
      case StoreSection.receive:
        return const KeyedSubtree(
          key: ValueKey(StoreSection.receive),
          child: ReceivePagedListPage(),
        );
      case StoreSection.returns:
        return const KeyedSubtree(
          key: ValueKey(StoreSection.returns),
          child: IssuesReturnListPage(),
        );
      case StoreSection.issue:
        return KeyedSubtree(
          key: const ValueKey(StoreSection.issue),
          child: IssuesListPage(
            scanIssueButtonKey: GuidedTourController.scanIssueButtonKey,
          ),
        );
    }
  }
}

/* ---------------- Unified Modern Store Sidebar (Desktop / Web) ---------------- */

class _UnifiedStoreSidebar extends StatelessWidget {
  const _UnifiedStoreSidebar({
    required this.selected,
    required this.user,
    required this.onSelect,
  });

  final StoreSection selected;
  final AuthModel user;
  final ValueChanged<StoreSection> onSelect;

  bool _isSelected(StoreSection s) => selected == s;

  @override
  Widget build(BuildContext context) {
    final initials = user.name.trim().isNotEmpty
        ? user.name.trim().substring(0, 1).toUpperCase()
        : 'U';
    final roleText = user.isSuperAdmin
        ? 'Super Admin'
        : user.canReceive && user.canIssue
            ? 'Store Manager'
            : user.canIssue
                ? 'Issue Incharge'
                : 'Store Staff';

    return Container(
      width: 215,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Branding Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke.withValues(alpha: .7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _ink900,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: _accentMint,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Store Inventory',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Active Hub',
                            style: TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Scrollable Navigation Item List (Prevents overflow on smaller laptop screens)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _NavCategoryLabel(label: 'MAIN'),
                  const SizedBox(height: 3),
                  _SidebarItem(
                    activeIcon: Icons.grid_view_rounded,
                    inactiveIcon: Icons.grid_view_outlined,
                    label: 'Dashboard',
                    selected: _isSelected(StoreSection.dashboard),
                    onTap: () => onSelect(StoreSection.dashboard),
                  ),
                  _SidebarItem(
                    activeIcon: Icons.list_alt_rounded,
                    inactiveIcon: Icons.list_alt_outlined,
                    label: 'Items',
                    selected: _isSelected(StoreSection.items),
                    onTap: () => onSelect(StoreSection.items),
                  ),
                  if (user.canFindItemNav)
                    _SidebarItem(
                      key: GuidedTourController.findItemKey,
                      activeIcon: Icons.location_searching_rounded,
                      inactiveIcon: Icons.search_rounded,
                      label: 'Find Item',
                      selected: _isSelected(StoreSection.findItem),
                      onTap: () => onSelect(StoreSection.findItem),
                    ),
                  if (user.canPlaces)
                    _SidebarItem(
                      key: GuidedTourController.placesKey,
                      activeIcon: Icons.place_rounded,
                      inactiveIcon: Icons.place_outlined,
                      label: 'Places',
                      selected: _isSelected(StoreSection.places),
                      onTap: () => onSelect(StoreSection.places),
                    ),

                  if (user.canReceive || user.canIssue || user.canReturn) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: _stroke.withValues(alpha: .5),
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    ),
                    const _NavCategoryLabel(label: 'OPERATIONS'),
                    const SizedBox(height: 3),
                    if (user.canReceive)
                      _SidebarItem(
                        activeIcon: Icons.inbox_rounded,
                        inactiveIcon: Icons.move_to_inbox_outlined,
                        label: 'Receive',
                        selected: _isSelected(StoreSection.receive),
                        onTap: () => onSelect(StoreSection.receive),
                      ),
                    if (user.canIssue)
                      _SidebarItem(
                        key: GuidedTourController.issueNavButtonKey,
                        activeIcon: Icons.call_split_rounded,
                        inactiveIcon: Icons.call_split_outlined,
                        label: 'Issue',
                        selected: _isSelected(StoreSection.issue),
                        onTap: () => onSelect(StoreSection.issue),
                      ),
                    if (user.canReturn)
                      _SidebarItem(
                        activeIcon: Icons.reset_tv_rounded,
                        inactiveIcon: Icons.restart_alt_rounded,
                        label: 'Return',
                        selected: _isSelected(StoreSection.returns),
                        onTap: () => onSelect(StoreSection.returns),
                      ),
                  ],

                  if (user.isSuperAdmin) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: _stroke.withValues(alpha: .5),
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    ),
                    const _NavCategoryLabel(label: 'ADMINISTRATION'),
                    const SizedBox(height: 3),
                    _SidebarItem(
                      activeIcon: Icons.manage_accounts_rounded,
                      inactiveIcon: Icons.manage_accounts_outlined,
                      label: 'Manage Users',
                      selected: _isSelected(StoreSection.admin),
                      onTap: () => onSelect(StoreSection.admin),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // User Profile Quick Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: .25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke.withValues(alpha: .5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: _ink900,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: _accentMint,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name.isNotEmpty ? user.name : 'Store User',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        roleText,
                        style: const TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w500,
                          fontSize: 9.5,
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
        ],
      ),
    );
  }
}

class _NavCategoryLabel extends StatelessWidget {
  const _NavCategoryLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: _ink600,
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _ink900 : Colors.transparent;
    final fg = selected ? _surface : _ink700;
    final iconColor = selected ? _accentMint : _ink900;
    final icon = selected ? activeIcon : inactiveIcon;

    return Container(
      margin: const EdgeInsets.only(bottom: 2.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          hoverColor: _accentMint.withValues(alpha: .2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12.5,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: _accentMint,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- Mobile Bottom Nav ---------------- */

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.section,
    required this.onChange,
    this.user,
  });

  final StoreSection section;
  final ValueChanged<StoreSection> onChange;
  final AuthModel? user;

  bool get _showFindItem => user?.canFindItemNav ?? false;
  bool get _showPlaces => user?.canPlaces ?? false;

  List<StoreSection> get _destinations {
    final list = <StoreSection>[StoreSection.dashboard, StoreSection.items];
    if (_showFindItem) list.add(StoreSection.findItem);
    if (_showPlaces) list.add(StoreSection.places);
    return list;
  }

  int _indexOf(StoreSection s) {
    final list = _destinations;
    final idx = list.indexOf(s);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _accentMint.withValues(alpha: .55),
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            color: sel ? _ink900 : _ink700,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(color: sel ? _ink900 : _ink700, size: 24);
        }),
      ),
      child: NavigationBar(
        selectedIndex: _indexOf(section),
        onDestinationSelected: (i) {
          final list = _destinations;
          if (i >= 0 && i < list.length) {
            onChange(list[i]);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'Items',
          ),
          if (_showFindItem)
            NavigationDestination(
              key: GuidedTourController.findItemKey,
              icon: const Icon(Icons.location_searching_rounded),
              selectedIcon: const Icon(Icons.location_searching_rounded),
              label: 'Find Item',
            ),
          if (_showPlaces)
            NavigationDestination(
              key: GuidedTourController.placesKey,
              icon: const Icon(Icons.place_outlined),
              selectedIcon: const Icon(Icons.place_rounded),
              label: 'Places',
            ),
        ],
      ),
    );
  }
}


/* ---------------- Header Card ---------------- */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.showBack,
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.onBack,
    this.trailing,
    this.onStartTour,
  });

  final bool showBack;
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final VoidCallback onBack;
  final Widget? trailing;
  final ValueChanged<List<GuidedTourStep>>? onStartTour;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // On narrow screens or when back button is shown, omit the redundant leading icon to conserve space
    final hideLeadingIcon = (showBack && screenWidth < 460) || screenWidth < 415;
    final actionGap = screenWidth < 400 ? 5.0 : 8.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
      child: Row(
        children: [
          if (showBack)
            AppBackButton(
              onPressed: onBack,
            ),
          if (showBack && !hideLeadingIcon) const SizedBox(width: 10),
          if (!hideLeadingIcon) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _stroke,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke),
              ),
              child: Icon(leadingIcon, color: _ink900),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StoreNotificationBellButton(),
                  SizedBox(width: actionGap),
                  StoreHelpButton(onStartTour: onStartTour),
                  if (trailing != null) ...[
                    SizedBox(width: actionGap),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Pill Tabs (Dashboard) ---------------- */

class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: _ink900,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: _surface,
        unselectedLabelColor: _ink600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        tabs: const [
          Tab(
            child: _TabLabel(icon: Icons.grid_view_rounded, text: 'Overview'),
          ),
          Tab(
            child: _TabLabel(icon: Icons.show_chart_rounded, text: 'Movements'),
          ),
          Tab(child: _TabLabel(icon: Icons.inventory_2_rounded, text: 'Items')),
          Tab(child: _TabLabel(icon: Icons.place_rounded, text: 'Places')),
          Tab(child: _TabLabel(icon: Icons.people_alt_rounded, text: 'Users')),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(text)],
      ),
    );
  }
}

/* ---------------- Dashboard Tabs ---------------- */

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Key Metrics',
            subtitle: 'Real-time inventory overview',
          ),
          const SizedBox(height: 10),

          // Metrics row like screenshot
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final int cols = w >= 980 ? 7 : (w >= 720 ? 4 : 2);

              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _MetricCard(
                    title: 'Items',
                    value: 'Coming Soon',
                    icon: Icons.inventory_2_rounded,
                    tint: _accentMint,
                  ),
                  _MetricCard(
                    title: 'Places',
                    value: 'Coming Soon',
                    icon: Icons.place_rounded,
                    tint: _accentPeach,
                  ),
                  _MetricCard(
                    title: 'Open RCV',
                    value: 'Coming Soon',
                    icon: Icons.inbox_rounded,
                    tint: _accentMint,
                  ),
                  _MetricCard(
                    title: 'Open ISS',
                    value: 'Coming Soon',
                    icon: Icons.call_split_rounded,
                    tint: _accentPeach,
                  ),
                  _MetricCard(
                    title: 'SOH',
                    value: 'Coming Soon',
                    icon: Icons.storage_rounded,
                    tint: _accentMint,
                  ),
                  _MetricCard(
                    title: 'Today RCV',
                    value: 'Coming Soon',
                    icon: Icons.today_rounded,
                    tint: _accentPeach,
                  ),
                  _MetricCard(
                    title: 'Today ISS',
                    value: 'Coming Soon',
                    icon: Icons.event_available_rounded,
                    tint: _accentPeach,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),
          const _SectionTitle(
            title: 'Performance',
            subtitle: 'Throughput analysis',
          ),
          const SizedBox(height: 10),

          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 760;
              if (!wide) {
                return const Column(
                  children: [
                    _PerfCard(
                      title: 'Receiving',
                      value: 'Coming Soon',
                      icon: Icons.inbox_rounded,
                      tint: _accentMint,
                    ),
                    SizedBox(height: 12),
                    _PerfCard(
                      title: 'Issue',
                      value: 'Coming Soon',
                      icon: Icons.call_split_rounded,
                      tint: _accentPeach,
                    ),
                  ],
                );
              }
              return const Row(
                children: [
                  Expanded(
                    child: _PerfCard(
                      title: 'Receiving',
                      value: 'Coming Soon',
                      icon: Icons.inbox_rounded,
                      tint: _accentMint,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _PerfCard(
                      title: 'Issue',
                      value: 'Coming Soon',
                      icon: Icons.call_split_rounded,
                      tint: _accentPeach,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MovementsTab extends StatelessWidget {
  const _MovementsTab();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Movements (Coming Soon)',
        style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ItemsTabInsideDashboard extends StatelessWidget {
  const _ItemsTabInsideDashboard();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Dashboard > Items tab (Coming Soon)',
        style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PlacesTabInsideDashboard extends StatelessWidget {
  const _PlacesTabInsideDashboard();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Dashboard > Places tab (Coming Soon)',
        style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_rounded, size: 54, color: _ink600),
          const SizedBox(height: 12),
          const Text(
            'User Management',
            style: TextStyle(
              color: _ink900,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'View, search, edit, and manage all registered system users.',
            style: TextStyle(color: _ink600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsersListPage()),
                  );
                },
                icon: const Icon(Icons.group_outlined, size: 18),
                label: const Text(
                  'Manage Users',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B67E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------- Stubs for Admin / Receive / Issue ---------------- */

class _AdminPageStub extends StatelessWidget {
  const _AdminPageStub();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Admin page (Coming Soon)',
        style: TextStyle(color: _ink700, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ReceivePageStub extends StatelessWidget {
  const _ReceivePageStub();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Receive page (Coming Soon)',
        style: TextStyle(color: _ink700, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _IssuePageStub extends StatelessWidget {
  const _IssuePageStub();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Issue page (Coming Soon)',
        style: TextStyle(color: _ink700, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/* ---------------- UI Components ---------------- */

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: _ink600,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: Icon(icon, color: _ink900),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: _ink600,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfCard extends StatelessWidget {
  const _PerfCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: Icon(icon, color: _ink900),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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
