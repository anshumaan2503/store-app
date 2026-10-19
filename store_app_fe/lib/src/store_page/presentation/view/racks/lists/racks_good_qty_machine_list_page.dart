// lib/src/store/presentation/views/racks/lists/racks_good_qty_list_page.dart
import 'package:flutter/material.dart';
import 'racks_qty_machine_list_base.dart';

class RacksGoodQtyMachineListPage extends StatelessWidget {
  const RacksGoodQtyMachineListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RacksQtyMachineListPage(isScrap: false);
  }
}
