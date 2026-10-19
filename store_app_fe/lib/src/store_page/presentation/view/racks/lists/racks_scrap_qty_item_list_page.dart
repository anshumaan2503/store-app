// lib/src/store/presentation/views/racks/lists/racks_scrap_qty_list_page.dart
import 'package:flutter/material.dart';
import 'racks_qty_item_list_base.dart';

class RacksScrapQtyItemListPage extends StatelessWidget {
  const RacksScrapQtyItemListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RacksQtyItemListPage(isScrap: true);
  }
}
