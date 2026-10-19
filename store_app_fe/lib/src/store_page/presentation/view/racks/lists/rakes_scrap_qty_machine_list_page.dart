// lib/src/store/presentation/views/racks/lists/racks_scrap_qty_list_page.dart
import 'package:flutter/material.dart';
import 'racks_qty_machine_list_base.dart';

class RacksScrapQtyMachineListPage extends StatelessWidget {
  const RacksScrapQtyMachineListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RacksQtyMachineListPage(isScrap: true);
  }
}
