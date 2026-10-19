// dashboard_screen.dart
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/providers/deshboard_provider.dart';

// ====== your data/providers (unchanged) ======
/* ───────────────────────────────────────────────────────────
 * Palette (as requested - UNCHANGED)
 * ─────────────────────────────────────────────────────────── */
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

/* ───────────────────────────────────────────────────────────
 * Typographic helpers (ENHANCED)
 * ─────────────────────────────────────────────────────────── */
TextStyle _title(BuildContext c) => Theme.of(c).textTheme.titleMedium!.copyWith(
  color: _ink900,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.5,
);

TextStyle _subtitle(BuildContext c) => Theme.of(c).textTheme.labelLarge!
    .copyWith(color: _ink700, fontWeight: FontWeight.w600, letterSpacing: 0.3);

TextStyle _muted([double size = 12]) => TextStyle(
  color: _ink600,
  fontSize: size,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.2,
);

TextStyle _value([double size = 26]) => TextStyle(
  color: _ink900,
  fontSize: size,
  fontWeight: FontWeight.w900,
  letterSpacing: -0.5,
);

/* ───────────────────────────────────────────────────────────
 * Enhanced Glass Card with subtle animations
 * ─────────────────────────────────────────────────────────── */
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color borderTint;
  final bool elevated;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 20,
    this.borderTint = _stroke,
    this.elevated = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverEnter() => _controller.forward();
  void _onHoverExit() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: widget.borderTint, width: 1.2),
            boxShadow: [
              if (widget.elevated)
                BoxShadow(
                  color: const Color(0x1A000000),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                )
              else
                BoxShadow(
                  color: const Color(0x0D000000),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
            ],
          ),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Enhanced KPI Tile with premium styling
 * ─────────────────────────────────────────────────────────── */
class GlassKpiTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const GlassKpiTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderTint: color.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted(12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _value(26),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * ─────────────────────────────────────────────────────────── */

class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({
    required this.left,
    required this.right,
  }) : breakpoint = 860;
  final Widget left;
  final Widget right;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        if (c.maxWidth < breakpoint) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Enhanced Dashboard Shell with refined header
 * ─────────────────────────────────────────────────────────── */
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bgTop, _bgBottom],
                  stops: [0.0, 0.7],
                ),
              ),
            ),

            // Content
            SafeArea(
              bottom: false,
              child: NestedScrollView(
                headerSliverBuilder:
                    (_, __) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: GlassCard(
                            elevated: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            borderTint: _accentMint.withValues(alpha: 0.5),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: _accentMint.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: _ink900,
                                      size: 22,
                                    ),
                                    tooltip: 'Back',
                                    onPressed:
                                        () => Navigator.maybePop(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _accentMint.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.dashboard_customize_rounded,
                                    color: _accentMint,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Store Dashboard',
                                        style: _title(
                                          context,
                                        ).copyWith(fontSize: 18),
                                      ),
                                      Text(
                                        'Inventory & Operations',
                                        style: _muted(11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        automaticallyImplyLeading: false,
                        bottom: const PreferredSize(
                          preferredSize: Size.fromHeight(56),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: _GlassTabBar(),
                          ),
                        ),
                      ),
                    ],
                body: const _Tabs(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Enhanced Tab Bar with better styling
 * ─────────────────────────────────────────────────────────── */
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar() : tabWidth = 104;
  final double tabWidth;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          borderTint: _stroke.withValues(alpha: 0.6),
          child: TabBar(
            controller: controller,
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: EdgeInsets.zero,
            indicator: BoxDecoration(
              color: _ink900,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _ink900.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: _surface,
            unselectedLabelColor: _ink600,
            tabs:
                const [
                  _FixedTab(icon: Icons.dashboard_rounded, text: 'Overview'),
                  _FixedTab(icon: Icons.timeline_rounded, text: 'Movements'),
                  _FixedTab(icon: Icons.inventory_2_rounded, text: 'Items'),
                  _FixedTab(icon: Icons.place_rounded, text: 'Places'),
                  _FixedTab(icon: Icons.people_alt_rounded, text: 'Users'),
                ].map((t) => SizedBox(width: tabWidth, child: t)).toList(),
          ),
        ),
      ),
    );
  }
}

class _FixedTab extends StatelessWidget {
  const _FixedTab({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return const TabBarView(
      physics: BouncingScrollPhysics(),
      children: [
        _OverviewTab(),
        _MovementsTab(),
        _ItemsTab(),
        _PlacesTab(),
        _UsersTab(),
      ],
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Chart helpers (light theme - ENHANCED)
 * ─────────────────────────────────────────────────────────── */
FlGridData _grid() => FlGridData(
  show: true,
  getDrawingHorizontalLine:
      (v) => FlLine(color: _stroke.withValues(alpha: 0.5), strokeWidth: 1),
  getDrawingVerticalLine:
      (v) => FlLine(color: _stroke.withValues(alpha: 0.3), strokeWidth: 0.8),
);

AxisTitles _leftTitles() => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 42,
    getTitlesWidget: (v, _) => Text('${v.toInt()}', style: _muted(10)),
  ),
);

SideTitles _bottomTitles(List<String> labels) => SideTitles(
  showTitles: true,
  getTitlesWidget: (value, meta) {
    final i = value.toInt();
    if (i >= 0 && i < labels.length) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        angle: 45 * math.pi / 180,
        space: 6,
        child: Text(
          labels[i],
          style: _muted(9),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return const SizedBox.shrink();
  },
);

/* ───────────────────────────────────────────────────────────
 * Tab 1: Overview (Enhanced Layout)
 * ─────────────────────────────────────────────────────────── */
class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();
  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final kpis = ref.watch(kpiProvider);
    final recTp = ref.watch(throughputReceivingProvider);
    final issTp = ref.watch(throughputIssueProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Metrics',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('Real-time inventory overview', style: _muted(12)),
                const SizedBox(height: 12),
                kpis.when(
                  data: (d) {
                    return LayoutBuilder(
                      builder: (_, c) {
                        final spacing = 10.0;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            GlassKpiTile(
                              icon: Icons.inventory_2_rounded,
                              title: 'Items',
                              value: '${d.totalItems}',
                              color: _accentMint,
                            ),
                            GlassKpiTile(
                              icon: Icons.place_rounded,
                              title: 'Places',
                              value: '${d.totalPlaces}',
                              color: _accentPeach,
                            ),
                            GlassKpiTile(
                              icon: Icons.move_to_inbox_rounded,
                              title: 'Open RCV',
                              value: '${d.openReceivings}',
                              color: _ink600,
                            ),
                            GlassKpiTile(
                              icon: Icons.outbox_rounded,
                              title: 'Open ISS',
                              value: '${d.openIssues}',
                              color: _ink700,
                            ),
                            GlassKpiTile(
                              icon: Icons.storage_rounded,
                              title: 'SOH',
                              value: '${d.stockOnHand}',
                              color: _accentMint,
                            ),
                            GlassKpiTile(
                              icon: Icons.today_rounded,
                              title: 'Today RCV',
                              value: '${d.todayReceived}',
                              color: _accentPeach,
                            ),
                            GlassKpiTile(
                              icon: Icons.today_outlined,
                              title: 'Today ISS',
                              value: '${d.todayIssued}',
                              color: _ink600,
                            ),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const _SkeletonLoader(),
                  error: (e, _) => _ErrorWidget(message: 'KPIs error: $e'),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('Throughput analysis', style: _muted(12)),
                const SizedBox(height: 12),
                _ResponsiveRow(
                  left: GlassCard(
                    elevated: true,
                    child: recTp.when(
                      data:
                          (v) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _accentMint.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.move_to_inbox_rounded,
                                      color: _accentMint,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Receiving', style: _muted(11)),
                                        Text(
                                          '${v.toStringAsFixed(1)}h avg',
                                          style: _value(20),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      loading: () => const _SkeletonLoader(),
                      error:
                          (e, _) =>
                              _ErrorWidget(message: 'Receiving error: $e'),
                    ),
                  ),
                  right: GlassCard(
                    elevated: true,
                    child: issTp.when(
                      data:
                          (v) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _accentPeach.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.outbox_rounded,
                                      color: _accentPeach,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Issue', style: _muted(11)),
                                        Text(
                                          '${v.toStringAsFixed(1)}h avg',
                                          style: _value(20),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      loading: () => const _SkeletonLoader(),
                      error: (e, _) => _ErrorWidget(message: 'Issue error: $e'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * ─────────────────────────────────────────────────────────── */

class _MovementsTab extends ConsumerStatefulWidget {
  const _MovementsTab();
  @override
  ConsumerState<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends ConsumerState<_MovementsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final trend = ref.watch(trendProvider);
    final movements = ref.watch(itemMovementsProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trend Analysis',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('7-day movement breakdown', style: _muted(12)),
                const SizedBox(height: 12),
                GlassCard(
                  elevated: true,
                  child: trend.when(
                    data:
                        (rows) => SizedBox(
                          height: 260,
                          child: _GroupedBarTrend(data: rows),
                        ),
                    loading: () => const _SkeletonLoader(),
                    error: (e, _) => _ErrorWidget(message: 'Trend error: $e'),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Timeline',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('Recent item movements', style: _muted(12)),
                const SizedBox(height: 12),
                GlassCard(
                  child: movements.when(
                    data: (rows) => _MovementTimeline(rows: rows),
                    loading: () => const _SkeletonLoader(),
                    error:
                        (e, _) => _ErrorWidget(message: 'Timeline error: $e'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemsTab extends ConsumerStatefulWidget {
  const _ItemsTab();
  @override
  ConsumerState<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends ConsumerState<_ItemsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = ref.watch(itemsMinProvider);
    final topIssued = ref.watch(topIssuedProvider);
    final topReceived = ref.watch(topReceivedProvider);
    final locs = ref.watch(itemLocationsProvider);
    final selId = ref.watch(selectedItemIdProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Items',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('Performance metrics', style: _muted(12)),
                const SizedBox(height: 12),
                _ResponsiveRow(
                  left: GlassCard(
                    elevated: true,
                    child: topIssued.when(
                      data:
                          (rows) => _TopItemsBar(
                            title: 'Top Issued',
                            rows: rows,
                            color: _accentPeach,
                          ),
                      loading: () => const _SkeletonLoader(),
                      error:
                          (e, _) =>
                              _ErrorWidget(message: 'Top issued error: $e'),
                    ),
                  ),
                  right: GlassCard(
                    elevated: true,
                    child: topReceived.when(
                      data:
                          (rows) => _TopItemsBar(
                            title: 'Top Received',
                            rows: rows,
                            color: _accentMint,
                          ),
                      loading: () => const _SkeletonLoader(),
                      error:
                          (e, _) =>
                              _ErrorWidget(message: 'Top received error: $e'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item Details',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      items.when(
                        data: (list) {
                          final currSel = selId;
                          if ((currSel == null || currSel.isEmpty) &&
                              list.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref.read(selectedItemIdProvider.notifier).state =
                                  list.first.id;
                            });
                          }
                          if (list.isEmpty) {
                            return _ErrorWidget(message: 'No items found');
                          }
                          return Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                'Select Item:',
                                style: _title(context).copyWith(fontSize: 14),
                              ),
                              DropdownButton<String>(
                                dropdownColor: _surface,
                                value: currSel ?? list.first.id,
                                items:
                                    list
                                        .map(
                                          (it) => DropdownMenuItem(
                                            value: it.id,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 240,
                                              ),
                                              child: Text(
                                                '${it.name} (${it.unit})',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: _ink900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (v) =>
                                        ref
                                            .read(
                                              selectedItemIdProvider.notifier,
                                            )
                                            .state = v,
                              ),
                            ],
                          );
                        },
                        loading: () => const _SkeletonLoader(),
                        error:
                            (e, _) => _ErrorWidget(message: 'Items error: $e'),
                      ),
                      const SizedBox(height: 16),
                      locs.when(
                        data: (rows) => _ItemLocationsList(rows: rows),
                        loading: () => const _SkeletonLoader(),
                        error:
                            (e, _) =>
                                _ErrorWidget(message: 'Locations error: $e'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacesTab extends ConsumerStatefulWidget {
  const _PlacesTab();
  @override
  ConsumerState<_PlacesTab> createState() => _PlacesTabState();
}

class _PlacesTabState extends ConsumerState<_PlacesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final util = ref.watch(placeUtilProvider);
    final heat = ref.watch(heatmapProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Utilization',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('Place availability metrics', style: _muted(12)),
                const SizedBox(height: 12),
                GlassCard(
                  elevated: true,
                  child: util.when(
                    data:
                        (rows) => SizedBox(
                          height: 280,
                          child: _PlaceUtilScrollable(
                            rows: rows.take(12).toList(),
                          ),
                        ),
                    loading: () => const _SkeletonLoader(),
                    error:
                        (e, _) => _ErrorWidget(message: 'Place util error: $e'),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usage Heat',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('Place activity distribution', style: _muted(12)),
                const SizedBox(height: 12),
                GlassCard(
                  child: heat.when(
                    data: (rows) => _PlaceHeatList(rows: rows, embedded: true),
                    loading: () => const _SkeletonLoader(),
                    error: (e, _) => _ErrorWidget(message: 'Heatmap error: $e'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceUtilScrollable extends StatelessWidget {
  final List<PlaceUtilRow> rows;
  const _PlaceUtilScrollable({required this.rows});

  @override
  Widget build(BuildContext context) {
    const double barWidth = 16;
    const double groupsSpace = 18;
    const double horizontalPadding = 48;

    return LayoutBuilder(
      builder: (_, c) {
        final barsCount = rows.length;
        final estWidth =
            barsCount * barWidth +
            (barsCount - 1) * groupsSpace +
            horizontalPadding;
        final neededWidth = estWidth.clamp(c.maxWidth, double.infinity);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: neededWidth.isFinite ? neededWidth : c.maxWidth,
            child: _PlaceUtilBar(rows: rows),
          ),
        );
      },
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ua = ref.watch(userActivityProvider);
    final low = ref.watch(lowStockProvider);
    final dead = ref.watch(deadStockProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Activity',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('Operations overview', style: _muted(12)),
                const SizedBox(height: 12),
                GlassCard(
                  elevated: true,
                  child: ua.when(
                    data:
                        (rows) => SizedBox(
                          height: 260,
                          child: _UserActivityBar(rows: rows),
                        ),
                    loading: () => const _SkeletonLoader(),
                    error:
                        (e, _) =>
                            _ErrorWidget(message: 'User activity error: $e'),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Alerts',
                  style: _title(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text('Low stock and inactive items', style: _muted(12)),
                const SizedBox(height: 12),
                _ResponsiveRow(
                  left: GlassCard(
                    elevated: true,
                    child: low.when(
                      data:
                          (rows) => _SimpleList(
                            title: 'Low Stock',
                            rows: rows,
                            color: _accentPeach,
                            subtitle: '<10 units',
                          ),
                      loading: () => const _SkeletonLoader(),
                      error:
                          (e, _) =>
                              _ErrorWidget(message: 'Low stock error: $e'),
                    ),
                  ),
                  right: GlassCard(
                    elevated: true,
                    child: dead.when(
                      data:
                          (rows) => _SimpleList(
                            title: 'Dead Stock',
                            rows: rows,
                            color: _ink700,
                            subtitle: '60+ days inactive',
                          ),
                      loading: () => const _SkeletonLoader(),
                      error:
                          (e, _) =>
                              _ErrorWidget(message: 'Dead stock error: $e'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Helper widgets and utilities
 * ─────────────────────────────────────────────────────────── */

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_ink600),
          ),
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  const _ErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentPeach.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: _ink700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: _muted(12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Charts & Lists (palette-applied)
 * ─────────────────────────────────────────────────────────── */
class _GroupedBarTrend extends StatelessWidget {
  final List<TrendPoint> data;
  const _GroupedBarTrend({required this.data});

  @override
  Widget build(BuildContext context) {
    final labels = data.map((e) => e.day).toList();
    final groups = <BarChartGroupData>[
      for (int i = 0; i < data.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 10,
          barRods: [
            BarChartRodData(
              toY: data[i].receive.toDouble(),
              width: 12,
              color: _accentMint,
              borderRadius: BorderRadius.circular(6),
            ),
            BarChartRodData(
              toY: data[i].issue.toDouble(),
              width: 12,
              color: _accentPeach,
              borderRadius: BorderRadius.circular(6),
            ),
            BarChartRodData(
              toY: data[i].scrap.toDouble(),
              width: 12,
              color: _ink600.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('7-Day Trend', style: _title(context).copyWith(fontSize: 14)),
        const SizedBox(height: 10),
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: groups,
              groupsSpace: 16,
              barTouchData: BarTouchData(enabled: true),
              gridData: _grid(),
              titlesData: FlTitlesData(
                leftTitles: _leftTitles(),
                bottomTitles: AxisTitles(sideTitles: _bottomTitles(labels)),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserActivityBar extends StatelessWidget {
  final List<UserActivityRow> rows;
  const _UserActivityBar({required this.rows});

  @override
  Widget build(BuildContext context) {
    final bars = <BarChartGroupData>[
      for (int i = 0; i < rows.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rows[i].ops.toDouble(),
              width: 16,
              gradient: const LinearGradient(
                colors: [_ink700, _ink600],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operations by User',
          style: _title(context).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: bars,
              gridData: _grid(),
              titlesData: FlTitlesData(
                leftTitles: _leftTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: _bottomTitles(rows.map((e) => e.name).toList()),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final u = rows[groupIndex];
                    return BarTooltipItem(
                      '${u.name}\n',
                      const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text: 'Ops: ${u.ops}\n',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: 'RCV: ${u.receiveQty}  ISS: ${u.issueQty}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    );
                  },
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  tooltipRoundedRadius: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceHeatList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final bool embedded;
  const _PlaceHeatList({required this.rows, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Place Usage Distribution',
          style: _title(context).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          itemCount: rows.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, i) {
            final r = rows[i];
            final pct = ((r['usagePct'] ?? 0.0) as num).toDouble().clamp(
              0.0,
              1.0,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r['name']} (${r['code']})',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 160,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _stroke),
                      color: _surfaceAlt,
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: pct,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [_accentMint, _accentPeach],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MovementTimeline extends StatelessWidget {
  final List<ItemMovement> rows;
  const _MovementTimeline({required this.rows});

  @override
  Widget build(BuildContext context) {
    final h = rows.isEmpty ? 120.0 : 400.0;
    return SizedBox(
      height: h,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder:
            (_, __) => const Divider(height: 8, color: Color(0x11000000)),
        itemBuilder: (ctx, i) {
          final m = rows[i];
          final color = m.type == 'RECEIVE' ? _accentMint : _accentPeach;
          final time =
              '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
          final date =
              '${m.createdAt.year}-${m.createdAt.month.toString().padLeft(2, '0')}-${m.createdAt.day.toString().padLeft(2, '0')}';
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                m.type == 'RECEIVE'
                    ? Icons.move_to_inbox_rounded
                    : Icons.outbox_rounded,
                color: color,
                size: 18,
              ),
            ),
            title: Text(
              m.itemName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              '$date $time • Qty: ${m.qty} • ${m.placeName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _ink600),
            ),
          );
        },
      ),
    );
  }
}

class _PlaceUtilBar extends StatelessWidget {
  final List<PlaceUtilRow> rows;
  const _PlaceUtilBar({required this.rows});

  @override
  Widget build(BuildContext context) {
    final labels = rows.map((e) => e.name).toList();
    final bars = <BarChartGroupData>[
      for (int i = 0; i < rows.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rows[i].available.toDouble(),
              width: 16,
              color: i.isEven ? _accentMint : _accentPeach,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Quantities',
          style: _title(context).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              gridData: _grid(),
              alignment: BarChartAlignment.spaceBetween,
              titlesData: FlTitlesData(
                leftTitles: _leftTitles(),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(sideTitles: _bottomTitles(labels)),
              ),
              barGroups: bars,
              groupsSpace: 18,
              barTouchData: BarTouchData(enabled: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _SimpleList extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> rows;
  final Color color;

  const _SimpleList({
    required this.title,
    required this.rows,
    required this.color,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    final height = rows.isEmpty ? 120.0 : 260.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _title(context).copyWith(fontSize: 14)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: _muted(11)),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: height,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder:
                (_, __) => const Divider(height: 8, color: Color(0x11000000)),
            itemBuilder: (ctx, i) {
              final r = rows[i];
              final name = (r['name'] ?? r['itemName'] ?? '—').toString();
              final cat = (r['category'] ?? r['placeName'] ?? '').toString();
              final available =
                  r['available'] ?? r['availableQty'] ?? r['qty'] ?? '';
              final unit = r['unit'] ?? '';
              return Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _ink900,
                            fontSize: 13,
                          ),
                        ),
                        if (cat.isNotEmpty)
                          Text(
                            cat,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _ink600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$available${unit.toString().isNotEmpty ? ' $unit' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _ink900,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopItemsBar extends StatelessWidget {
  final String title;
  final List<TopItemRow> rows;
  final Color color;

  const _TopItemsBar({
    required this.title,
    required this.rows,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final labels = rows.map((e) => e.name).toList();
    final groups = <BarChartGroupData>[
      for (int i = 0; i < rows.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rows[i].qty.toDouble(),
              width: 16,
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _title(context).copyWith(fontSize: 14)),
        const SizedBox(height: 10),
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              gridData: _grid(),
              titlesData: FlTitlesData(
                leftTitles: _leftTitles(),
                bottomTitles: AxisTitles(sideTitles: _bottomTitles(labels)),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              barGroups: groups,
              groupsSpace: 18,
              barTouchData: BarTouchData(enabled: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemLocationsList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _ItemLocationsList({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('No locations for this item yet.', style: _muted(12)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Storage Locations',
          style: _title(context).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 10),
        ...rows.map((r) {
          final place = (r['placeName'] ?? '').toString();
          final code = (r['code'] ?? '').toString();
          final total = (r['totalQuantity'] ?? 0).toString();
          final issued =
              (r['issuedQuantity'] ?? r['issuedQty'] ?? 0).toString();
          final avail = (r['available'] ?? r['availableQty'] ?? 0).toString();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _surfaceAlt.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          code,
                          style: const TextStyle(
                            color: _ink600,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('T: $total', style: _muted(10)),
                      Text('I: $issued', style: _muted(10)),
                      Text('A: $avail', style: _muted(10)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
