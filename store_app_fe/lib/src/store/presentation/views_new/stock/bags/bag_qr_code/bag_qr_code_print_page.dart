import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../../domains/models/bag_model.dart';
import 'bag_qr_code_multiple_print_page.dart';

class BagQRCodePrintPage extends ConsumerStatefulWidget {
  final List<BagModel> bagModelList;
  const BagQRCodePrintPage({super.key, required this.bagModelList});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _BagQRCodePrintPageState();
}

class _BagQRCodePrintPageState extends ConsumerState<BagQRCodePrintPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // automaticallyImplyLeading: false, // Removes back arrow
        centerTitle: true, // Centers the title
        title: const Text(
          "Bag Item",
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
          build: (context) => createListBagModelPdf(widget.bagModelList),
        ),
      ),
    );
  }
}
