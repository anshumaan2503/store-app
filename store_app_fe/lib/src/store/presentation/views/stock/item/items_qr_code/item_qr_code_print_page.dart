import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../../domains/models/item_model.dart';
import 'itwm_qr_code_print_view_page.dart';

class ItemQRCodePrintPage extends ConsumerStatefulWidget {
  final List<ItemModel> itemModelList;
  const ItemQRCodePrintPage({super.key, required this.itemModelList});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ItemQRCodePrintPageState();
}

class _ItemQRCodePrintPageState extends ConsumerState<ItemQRCodePrintPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // automaticallyImplyLeading: false, // Removes back arrow
        centerTitle: true, // Centers the title
        title: const Text(
          "Item Item",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: PdfPreview(
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          build: (context) => createListItemModelPdf(widget.itemModelList),
        ),
      ),
    );
  }
}
