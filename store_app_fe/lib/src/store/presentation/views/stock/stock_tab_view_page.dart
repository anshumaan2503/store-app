// lib/views/home/home_tab_view_page.dart
import 'package:flutter/material.dart';

import 'bags/bags_list_view.dart';
import 'item/items_list_view.dart';
import 'sorting/machine_add_sotring_job.dart';
import 'sorting/sorting_jobs_list_view.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class StockTabViewPage extends StatelessWidget {
  const StockTabViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // ✅ must match TabBar tabs count & TabBarView children
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: _ink900),
          title: const Text(
            'Inventory & Sorting',
            style: TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(72),
            child: _ThemedTabBar(),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const TabBarView(
            physics: BouncingScrollPhysics(),
            children: [
              MachineAddSotringJob(),
              BagsListView(),
              ItemsListView(),
              SortingJobsListView(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemedTabBar extends StatelessWidget {
  const _ThemedTabBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        decoration: BoxDecoration(
          color: _surfaceAlt, // track
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke),
        ),
        child: TabBar(
          // ✅ evenly spaced across width
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.tab,

          // ✅ beautiful pill indicator
          indicator: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke),
            boxShadow: [
              BoxShadow(
                color: _ink600.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          indicatorPadding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 2,
          ),

          // ✅ typography
          labelColor: _ink900,
          unselectedLabelColor: _ink600,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.15,
          ),

          // ✅ remove extra line under TabBar
          dividerColor: Colors.transparent,

          // ✅ better tap feedback (optional)
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return _ink700.withValues(alpha: 0.08);
            }
            return Colors.transparent;
          }),

          tabs: const [
            Tab(
              icon: Icon(Icons.precision_manufacturing_outlined, size: 18),
              text: 'Machine',
            ),
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Bags'),
            Tab(icon: Icon(Icons.category_outlined, size: 18), text: 'Items'),
            Tab(
              icon: Icon(Icons.qr_code_2_outlined, size: 18),
              text: 'Sorting',
            ),
          ],
        ),
      ),
    );
  }
}
