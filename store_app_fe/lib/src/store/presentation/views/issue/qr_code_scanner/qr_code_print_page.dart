import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:store_app/src/store/presentation/views/issue/qr_code_scanner/qr_code_multiple_print_page.dart';

import '../../../../domains/models/store_item_model.dart';

class QRCodePrintPage extends ConsumerStatefulWidget {
  final List<StoreItem> storeItemList;
  const QRCodePrintPage({super.key, required this.storeItemList});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _QRCodePrintPageState();
}

class _QRCodePrintPageState extends ConsumerState<QRCodePrintPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // automaticallyImplyLeading: false, // Removes back arrow
        centerTitle: true, // Centers the title
        title: const Text(
          "Store Items",
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
          build: (context) => createListStoreItemPdf(widget.storeItemList),
        ),
      ),
    );
  }
}
