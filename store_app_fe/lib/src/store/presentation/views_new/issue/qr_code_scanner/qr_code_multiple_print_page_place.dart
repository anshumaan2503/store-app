// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import '../../../../domains/models/store_place_model.dart';

Future<Uint8List> createListStorePlacePdf(
  List<StorePlace> storePlaceModel,
) async {
  final pdf = Document();
  for (var element in storePlaceModel) {
    print(element);
    String date = DateFormat.yMMMd().format(
      DateTime.parse(element.createdAt.toString()),
    );
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
                      "Store Place",
                      textScaleFactor: 1,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      date,
                      textScaleFactor: 0.5,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(border: Border.all()),
                      child: Text(
                        element.name.toString().toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textScaleFactor: 1,
                        overflow: TextOverflow.span,
                      ),
                    ),
                    Wrap(
                      children: [
                        Text(
                          "Place Code: ${element.type} ,",
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textScaleFactor: 0.7,
                        ),
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
