// store_receive_view.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:store_app/src/store/presentation/views/receiving/receiving_item_approval_page.dart';
import 'package:store_app/src/store/presentation/views/receiving/view_receiving_item_page.dart';
import 'package:store_app/src/store/presentation/views/receiving/receiving_store_item_qr_page.dart'; // if you still use it elsewhere, keep imported

import '../../../../auth/controllers/users_controller.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);

class StoreReceiveView extends ConsumerStatefulWidget {
  const StoreReceiveView({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _StoreReceiveViewState();
}

class _StoreReceiveViewState extends ConsumerState<StoreReceiveView>
    with SingleTickerProviderStateMixin {
  int pageIndex = 0;
  TabController? _tabCtrl; // lazy/nullable

  // pages
  // final List<Widget> screens = const [
  //   PlaceStockViewPage(),
  //   ReceivingListPage(),
  //   ReceivingApprovePage(),
  // ];

  // ---------- controller lifecycle ----------
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
    // default to full length (3); build() will immediately fix it if needed
    _ensureTabControllerWith(3);
  }

  @override
  void didUpdateWidget(covariant StoreReceiveView oldWidget) {
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
    final auth = ref.watch(userFindOneDataStreamProvider).value;

    // Safe defaults while data is loading
    final isSuperAdmin = auth?.isSuperAdmin == true;
    final perms = {
      for (final e in (auth?.appWorks ?? const [])) e.toString().trim(),
    };

    final canApprove =
        isSuperAdmin ||
        perms.contains('storeadmin') ||
        perms.contains('approvereceive');

    // Build pages dynamically based on current access
    final pages = <Widget>[
      const PlaceStockViewPage(),
      const ReceivingListPage(),
      if (canApprove) const ReceivingApprovePage(),
    ];

    // Keep selected index valid when pages change
    if (pageIndex >= pages.length) pageIndex = 0;

    // Ensure TabController matches current page count (mobile layout uses it)
    _ensureTabControllerWith(pages.length);

    // (Optional) if you want to show a loader until auth arrives:
    // if (auth == null) {
    //   return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // }

    // if (ref.watch(authModelProvider) == null) {
    //   return const Scaffold(
    //     body: Center(child: Text("Unable to get Admin Data")),
    //   );
    // }

    // _ensureTabController(); // make sure before usage

    // ---------- glassy scaffold over background image ----------
    return Stack(
      fit: StackFit.expand,
      children: const [
        _GlassBackdrop(), // swap in your asset inside this widget if desired
      ],
    ).foreground(
      Scaffold(
        backgroundColor: _surfaceAlt,
        extendBody: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // ---------------- DESKTOP / WIDE ----------------
            if (constraints.maxWidth > 800) {
              return Row(
                children: [
                  SizedBox(
                    width: 108,
                    child: _GlassPanel(
                      borderRadius: 0,
                      padding: 0,
                      opacity: 0.06,
                      child: NavigationRail(
                        backgroundColor: _surface,
                        selectedIndex: pageIndex,
                        indicatorColor: _accentMint,
                        onDestinationSelected:
                            (int index) => setState(() => pageIndex = index),

                        // ✅ Top-left align the rail items
                        groupAlignment: -1.0,
                        leading: const SizedBox(height: 8),

                        labelType: NavigationRailLabelType.all,
                        selectedIconTheme: IconThemeData(
                          size: 26,
                          color: _ink900,
                        ),
                        unselectedIconTheme: const IconThemeData(
                          size: 24,
                          color: _ink700,
                        ),

                        destinations: [
                          const NavigationRailDestination(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            icon: Tooltip(
                              message: 'Places',
                              child: Icon(Icons.warehouse_outlined),
                            ),
                            selectedIcon: Icon(Icons.warehouse),
                            label: Text(
                              'Places',
                              style: TextStyle(color: _ink900),
                            ),
                          ),
                          const NavigationRailDestination(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            icon: Tooltip(
                              message: 'Receiving',
                              child: Icon(Icons.inbox_outlined),
                            ),
                            selectedIcon: Icon(Icons.inbox),
                            label: Text(
                              'Receiving',
                              style: TextStyle(color: _ink900),
                            ),
                          ),
                          if (canApprove)
                            const NavigationRailDestination(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              icon: Tooltip(
                                message: 'Approve',
                                child: Icon(Icons.verified_outlined),
                              ),
                              selectedIcon: Icon(Icons.verified),
                              label: Text(
                                'Approve',
                                style: TextStyle(color: _ink900),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _GlassPanel(
                      borderRadius: 0,
                      intensity: 20,
                      opacity: 1,
                      padding: 0,
                      child: _PageSwitcher(index: pageIndex, screens: pages),
                    ),
                  ),
                ],
              );
            }

            // ---------------- MOBILE / NARROW ----------------
            // Bottom TabBar (glassy, no animation), full-bleed.
            return Column(
              children: [
                // Content card (light)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _stroke),
                      // boxShadow: const [
                      //   BoxShadow(
                      //     color: Color(0x14000000),
                      //     blurRadius: 10,
                      //     offset: Offset(0, 0),
                      //   ),
                      // ],
                    ),
                    child: _PageSwitcher(index: pageIndex, screens: pages),
                  ),
                ),

                // Bottom light TabBar
                SafeArea(
                  top: false,
                  minimum: EdgeInsets.zero,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                    child: SizedBox(
                      height: 56,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashFactory: InkRipple.splashFactory,
                          highlightColor: _accentMint.withValues(alpha: .15),
                          splashColor: _accentMint.withValues(alpha: .20),
                          tabBarTheme: const TabBarThemeData(
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                          ),
                        ),
                        child: TabBar(
                          controller: _tabCtrl!,
                          isScrollable: false,
                          onTap: (i) {
                            if (pageIndex != i) {
                              setState(() => pageIndex = i);
                            }
                          },

                          indicator: ShapeDecoration(
                            color: _accentMint.withValues(alpha: .60),
                            shape: StadiumBorder(
                              side: BorderSide(color: _stroke),
                            ),
                          ),
                          indicatorPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          labelColor: _ink900,
                          unselectedLabelColor: _ink700,
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          tabs: [
                            const _BottomTab(
                              icon: Icons.warehouse_outlined,
                              label: 'Places',
                            ),
                            const _BottomTab(
                              icon: Icons.inbox_outlined,
                              label: 'Receiving',
                            ),
                            if (canApprove)
                              const _BottomTab(
                                icon: Icons.verified_outlined,
                                label: 'Approve',
                              ),
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

/* ---------------- helpers (same style as other pages) ---------------- */

/// A compact bottom tab matching the top bar’s aesthetic (icon + label).
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

/// Full-screen backdrop with background image + gradient overlay.
class _GlassBackdrop extends StatelessWidget {
  const _GlassBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 🌫 Gradient overlay for readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _surface,
                _surface,
                _surface,
                _surface, // bottom fade
              ],
            ),
          ),
        ),

        // 💫 Subtle blue-black tint for consistency
        Container(color: _surfaceAlt),
      ],
    );
  }
}

/// Reusable frosted glass panel (full-bleed by default).
class _GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double padding;
  final double intensity; // blur sigma
  final double opacity; // 0..1 tint
  final EdgeInsets? margin;

  const _GlassPanel({
    required this.child,
    this.borderRadius = 0,
    this.padding = 0,
    this.intensity = 16,
    this.opacity = 0.08,
  }) : margin = null;

  @override
  Widget build(BuildContext context) {
    final glassColor = Theme.of(
      context,
    ).colorScheme.surface.withValues(alpha: opacity);
    return Container(
      margin: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: intensity, sigmaY: intensity),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                width: 1,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                  color: _surface,
                ),
              ],
            ),
            child: Padding(padding: EdgeInsets.all(padding), child: child),
          ),
        ),
      ),
    );
  }
}

/* ---------------- small extension ---------------- */

extension _Foreground on Widget {
  Widget foreground(Widget child) =>
      Stack(fit: StackFit.expand, children: [this, child]);
}
