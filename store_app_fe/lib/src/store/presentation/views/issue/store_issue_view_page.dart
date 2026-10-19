// store_issue_view.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:store_app/src/store/presentation/views/issue/issue_item_approval_page.dart';
import 'package:store_app/src/store/presentation/views/issue/issue_store_closed_list.dart';
import 'package:store_app/src/store/presentation/views/issue/issued_store_item_qr_page.dart';
import 'package:store_app/src/store/presentation/views/issue/view_store_issue.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/shared/providers/auth_model_provider.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _stroke = Color(0xFFDFE1D6);
const _surface = Color(0xFFFFFFFF);
const _mint = Color(0xFFB6D3CC);
const _peach = Color(0xFFF3D7C0);
const _bgTop = Color(0xFFFFFFFA);
const _bgBottom = Color(0xFFFFF3E3);
const _railGradTop = Color(0xFFEDECF8);
const _railGradBottom = Color(0xFFF7E8E0);

class StoreIssueView extends ConsumerStatefulWidget {
  const StoreIssueView({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _StoreIssueViewState();
}

class _StoreIssueViewState extends ConsumerState<StoreIssueView>
    with SingleTickerProviderStateMixin {
  int pageIndex = 0;
  TabController? _tabCtrl;

  // ─────────────────── Light palette ───────────────────

  void _ensureTabControllerWith(int len) {
    if (_tabCtrl == null || _tabCtrl!.length != len) {
      _tabCtrl?.dispose();
      _tabCtrl = TabController(
        length: len,
        vsync: this,
        initialIndex: pageIndex.clamp(0, len - 1),
      );
      _tabCtrl!.addListener(() {
        if (!mounted || _tabCtrl!.indexIsChanging) return;
        if (pageIndex != _tabCtrl!.index) {
          setState(() => pageIndex = _tabCtrl!.index);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureTabControllerWith(4);
  }

  @override
  void didUpdateWidget(covariant StoreIssueView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureTabControllerWith(_tabCtrl?.length ?? 3);
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authModelProvider) == null) {
      return const Scaffold(
        body: Center(child: Text("Unable to get Admin Data")),
      );
    }

    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };
    final canAdmin = isSuperAdmin || perms.contains('storeadmin');
    final canApprove = canAdmin || perms.contains('storissueapprove');
    final canReturn = canAdmin || perms.contains('storissuereturn');

    final pages = <Widget>[
      const IssuedStoreItemQrPage(),
      const IssueListPage(),
      if (canApprove) const IssueApprovalPage(),
      if (canReturn) const IssueClosedListPage(),
    ];

    final tabMeta = <({IconData icon, IconData selected, String label})>[
      (
        icon: Icons.qr_code_scanner_outlined,
        selected: Icons.qr_code_scanner,
        label: 'Scan',
      ),
      (icon: Icons.list_outlined, selected: Icons.list, label: 'Issues'),
      if (canApprove)
        (
          icon: Icons.verified_outlined,
          selected: Icons.verified,
          label: 'Approve',
        ),
      if (canReturn)
        (
          icon: Icons.done_all_outlined,
          selected: Icons.done_all,
          label: 'Closed',
        ),
    ];

    if (pageIndex >= pages.length) pageIndex = 0;
    _ensureTabControllerWith(pages.length);

    return Stack(
      fit: StackFit.expand,
      children: const [_LightBackdrop()],
    ).foreground(
      Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // ───────── DESKTOP / WIDE ─────────
            if (constraints.maxWidth > 800) {
              return Row(
                children: [
                  // Light rail
                  Container(
                    width: 116,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_surface, _surface],
                      ),
                      border: const Border(
                        right: BorderSide(color: _stroke, width: 1),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: NavigationRail(
                        backgroundColor: Colors.transparent,
                        selectedIndex: pageIndex,
                        groupAlignment: -1.0,
                        leading: const SizedBox(height: 8),
                        labelType: NavigationRailLabelType.all,

                        // Light indicator “pill”
                        indicatorColor: _mint.withValues(alpha: 0.55),
                        indicatorShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _stroke, width: 1),
                        ),

                        // Icon + label colors
                        selectedIconTheme: const IconThemeData(
                          size: 26,
                          color: _ink900,
                        ),
                        unselectedIconTheme: const IconThemeData(
                          size: 24,
                          color: _ink600,
                        ),
                        selectedLabelTextStyle: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                        ),
                        unselectedLabelTextStyle: const TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w600,
                        ),

                        onDestinationSelected:
                            (int index) => setState(() => pageIndex = index),
                        destinations: [
                          for (final m in tabMeta)
                            NavigationRailDestination(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              icon: Tooltip(
                                message: m.label,
                                child: Icon(m.icon),
                              ),
                              selectedIcon: Icon(m.selected),
                              label: Text(m.label),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Content surface with subtle card feel
                  Expanded(
                    child: _LightPanel(
                      borderRadius: 0,
                      padding: 0,
                      child: _PageSwitcher(index: pageIndex, screens: pages),
                    ),
                  ),
                ],
              );
            }

            // ───────── MOBILE / NARROW ─────────
            return Column(
              children: [
                Expanded(
                  child: _LightPanel(
                    borderRadius: 0,
                    padding: 0,
                    child: _PageSwitcher(index: pageIndex, screens: pages),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: EdgeInsets.zero,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _surface,
                      border: Border(top: BorderSide(color: _stroke, width: 1)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 58,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashFactory: InkRipple.splashFactory,
                          highlightColor: _mint.withValues(alpha: .14),
                          splashColor: _mint.withValues(alpha: .18),
                          tabBarTheme: const TabBarThemeData(
                            dividerColor: Colors.transparent,
                          ),
                        ),
                        child: TabBar(
                          controller: _tabCtrl!,
                          isScrollable: false,
                          onTap: (i) {
                            if (pageIndex != i) setState(() => pageIndex = i);
                          },
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelPadding: EdgeInsets.zero,
                          indicatorPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),

                          // Light colors
                          labelColor: _ink900,
                          unselectedLabelColor: _ink600,
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),

                          // Mint “pill” with soft border
                          indicator: BoxDecoration(
                            color: _mint.withValues(alpha: .45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _stroke, width: 1),
                          ),

                          tabs: [
                            for (final m in tabMeta)
                              _BottomTab(icon: m.icon, label: m.label),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ───────────────── helpers ───────────────── */

class _BottomTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _BottomTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      iconMargin: const EdgeInsets.only(bottom: 2),
      icon: Icon(icon, size: 18),
      text: label,
    );
  }
}

/// Keeps page state alive while switching.
class _PageSwitcher extends StatefulWidget {
  final int index;
  final List<Widget> screens;
  const _PageSwitcher({required this.index, required this.screens});

  @override
  State<_PageSwitcher> createState() => _PageSwitcherState();
}

class _PageSwitcherState extends State<_PageSwitcher>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return IndexedStack(
      index: widget.index,
      children: widget.screens
          .map((w) => _KeepAlive(child: w))
          .toList(growable: false),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Light background gradient over your image.
class _LightBackdrop extends StatelessWidget {
  const _LightBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
        // Warm light veil to keep pages legible
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
        ),
        // ultra subtle white blur glow
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(),
        ),
      ],
    );
  }
}

/// Light “panel” (replaces frosted glass look with a soft card surface)
class _LightPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double padding;
  final EdgeInsets? margin;

  const _LightPanel({
    required this.child,
    this.borderRadius = 0,
    this.padding = 0,
  }) : margin = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _stroke, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

/* ───────── extension ───────── */
extension _Foreground on Widget {
  Widget foreground(Widget child) =>
      Stack(fit: StackFit.expand, children: [this, child]);
}
