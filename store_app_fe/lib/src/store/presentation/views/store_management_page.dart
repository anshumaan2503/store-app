// store_home.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// PAGES
import 'package:store_app/src/store/presentation/views/issue/store_issue_view_page.dart';
import 'package:store_app/src/store/presentation/views/receiving/store_receive_view_page.dart';
import 'package:store_app/src/store/presentation/views/store_item/store_admin_view.dart';

// DATA
import '../../../auth/controllers/users_controller.dart';
// App header you already have
import '../widgets/all_app_bar.dart';

/* ──────────────────────────── Light Palette ──────────────────────────── */
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

const _shadow = Color(0x14000000);

/* ──────────────────────────── StoreHome ──────────────────────────── */

class StoreHome extends ConsumerStatefulWidget {
  const StoreHome({super.key});
  @override
  ConsumerState<StoreHome> createState() => _StoreHomeState();
}

class _StoreHomeState extends ConsumerState<StoreHome> {
  bool _showLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // fallback so first load isn't "stuck"
    Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _showLoading = false);
    });
  }

  _TabsBundle _buildTabsFor({
    required bool isSuperAdmin,
    required List<String> appWorks,
  }) {
    final tabs = <_TabDef>[];
    final perms =
        appWorks.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

    if (perms.contains('storeadmin')) {
      tabs.add(
        _TabDef(
          label: 'Admin',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          page: const StoreAdminView(),
        ),
      );
    }

    if (perms.contains('storreceiveview')) {
      tabs.add(
        _TabDef(
          label: 'Receive',
          icon: Icons.inbox_outlined,
          selectedIcon: Icons.inbox_rounded,
          page: const StoreReceiveView(),
        ),
      );
    }

    if (perms.contains('storissueview')) {
      tabs.add(
        _TabDef(
          label: 'Issue',
          icon: Icons.outbox_outlined,
          selectedIcon: Icons.outbox_rounded,
          page: const StoreIssueView(),
        ),
      );
    }

    return _TabsBundle(tabs: tabs);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userFindOneDataStreamProvider);

    return userAsync.when(
      loading: () => _loadingScaffold(),
      error: (e, _) => _errorScaffold('Error: $e'),
      data: (user) {
        if (user == null) {
          return _showLoading
              ? _loadingScaffold()
              : _errorScaffold('Unable to find Store User');
        }

        final isSuperAdmin = user.isSuperAdmin == true;
        final appWorks =
            (user.appWorks as List?)?.map((e) => e.toString()).toList() ?? [];
        final tabsBundle = _buildTabsFor(
          isSuperAdmin: isSuperAdmin,
          appWorks: appWorks,
        );

        if (tabsBundle.tabs.isEmpty) {
          return _errorScaffold('No access granted for this account');
        }
        if (_selectedIndex >= tabsBundle.tabs.length) _selectedIndex = 0;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: DefaultTabController(
            length: tabsBundle.tabs.length,
            initialIndex: _selectedIndex,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabController = DefaultTabController.of(context);

                // ───────────────── Desktop / Wide ─────────────────
                if (constraints.maxWidth >= 960) {
                  return Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: PreferredSize(
                      preferredSize: Size.fromHeight(_appBarH(context)),
                      child: _TopBarCard(child: const MyAppbar()),
                    ),
                    body: Row(
                      children: [
                        // Left Rail
                        SizedBox(
                          width: 260,
                          child: _NavRailCard(
                            header: const _BrandHeader(),
                            child: NavigationRail(
                              backgroundColor: Colors.transparent,
                              selectedIndex: _selectedIndex,
                              groupAlignment: -1,
                              useIndicator: true,
                              indicatorShape: const StadiumBorder(),
                              indicatorColor: _accentMint.withValues(alpha: .55),
                              selectedIconTheme: const IconThemeData(
                                color: _ink900,
                                size: 24,
                              ),
                              unselectedIconTheme: const IconThemeData(
                                color: _ink700,
                                size: 24,
                              ),
                              selectedLabelTextStyle: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w800,
                              ),
                              unselectedLabelTextStyle: const TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w600,
                              ),
                              onDestinationSelected: (i) {
                                setState(() => _selectedIndex = i);
                                tabController.animateTo(i);
                              },
                              labelType: NavigationRailLabelType.all,
                              destinations: [
                                for (final t in tabsBundle.tabs)
                                  NavigationRailDestination(
                                    icon: Icon(t.icon),
                                    selectedIcon: Icon(t.selectedIcon),
                                    label: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(t.label),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Content
                        Expanded(
                          child: _SurfaceBodyCard(
                            child: TabBarView(
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                for (final t in tabsBundle.tabs) t.page,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ───────────────── Mobile / Tablet ─────────────────
                return Scaffold(
                  backgroundColor: Colors.transparent,

                  body: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: _SurfaceBodyCard(
                      child: TabBarView(
                        children: [for (final t in tabsBundle.tabs) t.page],
                      ),
                    ),
                  ),
                  bottomNavigationBar: _BottomNavBar(
                    currentIndex: _selectedIndex,
                    onChanged: (i) {
                      setState(() => _selectedIndex = i);
                      tabController.animateTo(i);
                    },
                    items: [
                      for (final t in tabsBundle.tabs)
                        _BottomItem(
                          label: t.label,
                          icon: t.icon,
                          selectedIcon: t.selectedIcon,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /* ─────────── Loading / Error ─────────── */

  Widget _loadingScaffold() => Scaffold(
    backgroundColor: _bgTop,
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(_appBarH(context)),
      child: _TopBarCard(child: const MyAppbar()),
    ),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _errorScaffold(String msg) => Scaffold(
    backgroundColor: _bgTop,
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(_appBarH(context)),
      child: _TopBarCard(child: const MyAppbar()),
    ),
    body: Center(
      child: _SurfaceBodyCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              msg,
              style: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/* ──────────────────────────── Atoms & Layout ──────────────────────────── */

class _TabsBundle {
  final List<_TabDef> tabs;
  _TabsBundle({required this.tabs});
}

class _TabDef {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  _TabDef({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}

class _TopBarCard extends StatelessWidget {
  const _TopBarCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      // decoration: BoxDecoration(
      //   color: _surface,
      //   borderRadius: BorderRadius.circular(14),
      //   border: Border.all(color: _stroke, width: 1),
      //   boxShadow: const [
      //     BoxShadow(color: _shadow, offset: Offset(0, 6), blurRadius: 12),
      //   ],
      // ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
    );
  }
}

class _NavRailCard extends StatelessWidget {
  const _NavRailCard({required this.child, required this.header});
  final Widget child;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke, width: 1),
        boxShadow: const [
          BoxShadow(color: _shadow, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          header,
          const SizedBox(height: 8),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SurfaceBodyCard extends StatelessWidget {
  const _SurfaceBodyCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(color: _shadow, blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LogoDot(),
        SizedBox(width: 10),
        Text(
          'Store',
          style: TextStyle(
            color: _ink900,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }
}

class _LogoDot extends StatelessWidget {
  const _LogoDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _accentMint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: const Icon(Icons.store_rounded, color: _ink900, size: 20),
    );
  }
}

/* ──────────────────────────── Bottom Navigation (M3) ──────────────────────────── */

class _BottomItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  _BottomItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.items,
    required this.onChanged,
  });

  final int currentIndex;
  final List<_BottomItem> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _ink900,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            color: sel ? _ink900 : _ink700,
            fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(color: sel ? Colors.white : _ink700, size: 22);
        }),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onChanged,
        destinations: [
          for (final it in items)
            NavigationDestination(
              icon: Icon(it.icon),
              selectedIcon: Icon(it.selectedIcon),
              label: it.label,
            ),
        ],
      ),
    );
  }
}

/* ──────────────────────────── Sizing ──────────────────────────── */

double _appBarH(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  final h = MediaQuery.of(context).size.height;
  if (w < 500 || h < 700) return 48;
  if (w < 1100) return 60;
  return 68;
}
