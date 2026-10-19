import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../domains/models/store_place_model.dart';
import 'qr_code_multiple_print_page_place.dart';

class QRCodePrintPlacePage extends ConsumerStatefulWidget {
  final List<StorePlace> storePlaceList;
  const QRCodePrintPlacePage({super.key, required this.storePlaceList});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _QRCodePrintPlacePageState();
}

class _QRCodePrintPlacePageState extends ConsumerState<QRCodePrintPlacePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // automaticallyImplyLeading: false, // Removes back arrow
        centerTitle: true, // Centers the title
        title: const Text(
          "Store Place",
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
          build: (context) => createListStorePlacePdf(widget.storePlaceList),
        ),
      ),
    );
  }
}
