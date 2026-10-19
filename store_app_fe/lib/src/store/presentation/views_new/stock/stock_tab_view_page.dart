// lib/views/home/home_tab_view_page.dart
import 'package:flutter/material.dart';

import 'bags/bags_list_view.dart';
import 'item/items_list_view.dart';
import 'sorting/sorting_jobs_list_view.dart';

class StockTabViewPage extends StatelessWidget {
  const StockTabViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // Bags, Items, Sorting, Sizes, Grades
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory & Sorting'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Bags'),
              Tab(icon: Icon(Icons.category_outlined), text: 'Items'),
              Tab(
                icon: Icon(Icons.precision_manufacturing_outlined),
                text: 'Sorting',
              ),
              // Tab(
              //   icon: Icon(Icons.straighten_outlined),
              //   text: 'Sizes',
              // ),
              // Tab(
              //   icon: Icon(Icons.layers_outlined),
              //   text: 'Grades',
              // ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BagsListView(),
            ItemsListView(),
            SortingJobsListView(),
            // SizesListView(),
            // GradesListView(),
          ],
        ),
      ),
    );
  }
}
