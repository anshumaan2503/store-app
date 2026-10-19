// lib/src/store/presentation/views/racks/lists/racks_good_qty_list_page.dart
import 'package:flutter/material.dart';
import 'racks_qty_item_list_base.dart';

class RacksGoodQtyItemListPage extends StatelessWidget {
  const RacksGoodQtyItemListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RacksQtyItemListPage(isScrap: false);
  }
}
