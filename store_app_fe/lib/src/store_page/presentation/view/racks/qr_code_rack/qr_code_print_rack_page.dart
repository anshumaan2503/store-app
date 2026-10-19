import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import 'package:store_app/src/components/motion_widgets.dart';
import '../../../../domains/models/store_rack_model.dart';
import 'qr_code_mutiple_print_rack_page.dart';

class QRCodePrintRackPage extends ConsumerStatefulWidget {
  final List<StoreRack> storeRackList;
  const QRCodePrintRackPage({super.key, required this.storeRackList});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _QRCodePrintRackPageState();
}

class _QRCodePrintRackPageState extends ConsumerState<QRCodePrintRackPage> {
  static const Color _bg = Color(0xFFFAF7F2);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _surfaceAlt = Color(0xFFF2EFE9);
  static const Color _stroke = Color(0xFFE5E0D8);
  static const Color _ink900 = Color(0xFF1E1B18);
  static const Color _ink700 = Color(0xFF57524A);
  static const Color _accentPeach = Color(0xFFF3D7C0);

  @override
  Widget build(BuildContext context) {
    final firstRack =
        widget.storeRackList.isNotEmpty ? widget.storeRackList.first : null;
    final isMultiple = widget.storeRackList.length > 1;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.only(left: 10, top: 10, bottom: 10),
          child: AppBackButton(),
        ),
        title: Column(
          children: [
            Text(
              isMultiple
                  ? "Print ${widget.storeRackList.length} Racks"
                  : "QR Rack Label",
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            if (firstRack != null)
              Text(
                isMultiple ? "Batch Print" : "${firstRack.code} • ${firstRack.roomName}",
                style: const TextStyle(
                  color: _ink700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quick Print',
            icon: const Icon(Icons.print_rounded, color: _ink900),
            onPressed: () async {
              final pdfBytes =
                  await createListRackPdf(widget.storeRackList);
              await Printing.layoutPdf(onLayout: (_) => pdfBytes);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Rack Summary Card using app theme
          if (firstRack != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _stroke),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accentPeach.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stroke),
                    ),
                    child: const Icon(
                      Icons.storage_rounded,
                      color: _ink900,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMultiple
                              ? "${widget.storeRackList.length} Racks Selected"
                              : "Rack ${firstRack.code}",
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMultiple
                              ? "57mm Thermal Roll Format"
                              : "Room: ${firstRack.roomName}${firstRack.remark.isNotEmpty ? ' • ${firstRack.remark}' : ''}",
                          style: const TextStyle(
                            color: _ink700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _stroke),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: _ink900,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "57mm",
                          style: TextStyle(
                            color: _ink900,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Thermal Roll Canvas Container matching app theme
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _stroke),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: PdfPreview(
                dpi: 300.0,
                maxPageWidth: 400.0,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                scrollViewDecoration: const BoxDecoration(color: _surfaceAlt),
                pdfPreviewPageDecoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: _ink900),
                ),
                build: (context) => createListRackPdf(widget.storeRackList),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
