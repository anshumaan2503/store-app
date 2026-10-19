// store_admin_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:store_app/src/store/presentation/views/store_item/view_store_item.dart';
import '../../../../auth/shared/providers/auth_model_provider.dart';
import '../dashboard/store_dashboard_page.dart';
import '../store_place/view_store_place.dart';

/* ───────── Light Palette ───────── */

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

const _railWidth = 112.0;

/* ───────── Page ───────── */

class StoreAdminView extends ConsumerStatefulWidget {
  const StoreAdminView({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _StoreAdminViewState();
}

class _StoreAdminViewState extends ConsumerState<StoreAdminView>
    with SingleTickerProviderStateMixin {
  int pageIndex = 0;
  TabController? _tabCtrl;

  // Pages (unchanged)
  final List<Widget> screens = const [
    DashboardScreen(),
    StoreItemsPage(),
    StorePlaceListPage(),
  ];

  void _ensureTabController() {
    if (_tabCtrl == null || _tabCtrl!.length != screens.length) {
      _tabCtrl?.dispose();
      _tabCtrl = TabController(
        length: screens.length,
        vsync: this,
        initialIndex: pageIndex.clamp(0, screens.length - 1),
      );
      _tabCtrl!.addListener(() {
        if (_tabCtrl!.indexIsChanging) return;
        if (mounted && pageIndex != _tabCtrl!.index) {
          setState(() => pageIndex = _tabCtrl!.index);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureTabController();
  }

  @override
  void didUpdateWidget(covariant StoreAdminView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureTabController();
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

    _ensureTabController();

    return Scaffold(
      backgroundColor: _surface,
      // appBar: AppBar(
      //   elevation: 0,
      //   backgroundColor: _surface,
      //   surfaceTintColor: Colors.transparent,
      //   foregroundColor: _ink900,
      //   titleSpacing: 0,
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
      //     onPressed: () => Navigator.maybePop(context),
      //     tooltip: 'Back',
      //   ),
      //   title: Row(
      //     children: [
      //       const SizedBox(width: 4),
      //       const Icon(Icons.dashboard_customize_rounded, color: _ink900),
      //       const SizedBox(width: 10),
      //       const Text(
      //         'Store Admin',
      //         style: TextStyle(
      //           color: _ink900,
      //           fontWeight: FontWeight.w800,
      //           fontSize: 18,
      //         ),
      //       ),
      //       const Spacer(),
      //       Container(
      //         margin: const EdgeInsets.only(right: 8),
      //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      //         decoration: BoxDecoration(
      //           color: _surface,
      //           borderRadius: BorderRadius.circular(999),
      //           border: Border.all(color: _stroke),
      //         ),
      //         child: const Text(
      //           'v1.0',
      //           style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            // ───────── Desktop / Wide ─────────
            if (isWide) {
              return Row(
                children: [
                  // Light rail
                  _LightCard(
                    width: _railWidth,
                    margin: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    padding: EdgeInsets.zero,
                    child: NavigationRail(
                      // NOTE: do not set elevation to 0; leave it null.
                      backgroundColor: Colors.transparent,
                      selectedIndex: pageIndex,
                      groupAlignment: -1.0,
                      labelType: NavigationRailLabelType.all,
                      leading: const SizedBox(height: 6),
                      onDestinationSelected: (i) {
                        setState(() => pageIndex = i);
                        _tabCtrl?.animateTo(i);
                      },
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
                        color: _ink700,
                        fontWeight: FontWeight.w600,
                      ),
                      indicatorColor: _accentMint.withValues(alpha: .5),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text('Dashboard'),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.list_outlined),
                          selectedIcon: Icon(Icons.list),
                          label: Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text('Items'),
                          ),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.storage_outlined),
                          selectedIcon: Icon(Icons.storage),
                          label: Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text('Places'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _LightCard(
                      margin: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                      padding: EdgeInsets.zero,
                      child: _PageSwitcher(index: pageIndex, screens: screens),
                    ),
                  ),
                ],
              );
            }

            // ───────── Mobile / Narrow ─────────
            return Column(
              children: [
                Expanded(
                  child: _LightCard(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    padding: EdgeInsets.zero,
                    child: _PageSwitcher(index: pageIndex, screens: screens),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: _LightCard(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      height: 54,
                      child: TabBar(
                        controller: _tabCtrl!,
                        onTap: (i) {
                          if (pageIndex != i) {
                            setState(() => pageIndex = i);
                          }
                        },
                        indicator: ShapeDecoration(
                          color: _accentMint.withValues(alpha: .65),
                          shape: StadiumBorder(
                            side: BorderSide(color: _stroke),
                          ),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: _ink900,
                        unselectedLabelColor: _ink700,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                        tabs: const [
                          _BottomTab(
                            icon: Icons.dashboard_outlined,
                            label: 'Dashboard',
                          ),
                          _BottomTab(icon: Icons.list_outlined, label: 'Items'),
                          _BottomTab(
                            icon: Icons.storage_outlined,
                            label: 'Places',
                          ),
                        ],
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

/* ───────── Light Card Shell ───────── */

class _LightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? width;
  const _LightCard({
    required this.child,
    this.margin,
    this.padding,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/* ───────── Bottom Tab (mobile) ───────── */

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

/* ───────── Page switcher with keep-alives (unchanged logic) ───────── */

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
