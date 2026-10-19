// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import '../../../../domains/models/store_rack_model.dart';

Future<Uint8List> createListRackPdf(List<StoreRack> storeRackModel) async {
  final pdf = Document();
  for (var element in storeRackModel) {
    // print(element);
    // String date = DateFormat.yMMMd().format(
    //   DateTime.parse(element.createdAt.toString()),
    // );
    pdf.addPage(
      Page(
        pageFormat: PdfPageFormat.roll57,
        margin: const EdgeInsets.all(4),
        build: (context) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Column(
                  children: [
                    SizedBox(
                      height: 70,
                      width: 70,
                      child: BarcodeWidget(
                        barcode: Barcode.qrCode(),
                        data: "P0041.${element.id}",
                        drawText: true,
                      ),
                      // ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 1),
              SizedBox(
                width: 75,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Store Rack",
                      textScaleFactor: 1,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Text(
                    //   date,
                    //   textScaleFactor: 0.5,
                    //   style: TextStyle(fontWeight: FontWeight.bold),
                    // ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(border: Border.all()),
                      child: Text(
                        element.code.toString().toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textScaleFactor: 1,
                        overflow: TextOverflow.span,
                      ),
                    ),
                    Wrap(
                      children: [
                        Text(
                          "Room Name: ${element.roomName} ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textScaleFactor: 0.7,
                        ),
                        // Text(
                        //   "Qty: ${element.stockAvailableQuantity}",
                        //   style: TextStyle(fontWeight: FontWeight.bold),
                        //   textScaleFactor: 0.7,
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  return pdf.save();
}
