import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:store_app/src/components/motion_widgets.dart';
import 'package:store_app/src/store_page/controllers/store_rack_controller.dart';
import '../scan_item_receive_page.dart';
import '../scan_rack_receive_page.dart';
import 'package:store_app/src/store_page/controllers/scanner_settings_controller.dart';
import 'package:store_app/src/store_page/presentation/view/widgets/scanner_mode_selector_bar.dart';

class QRCodeScannerRackPage extends ConsumerStatefulWidget {
  final String? initialItemId;
  final String? initialIndentId;
  final num? initialIndentQty;
  final String? initialIndentNumber;
  final bool isPutaway;
  const QRCodeScannerRackPage({
    super.key,
    this.initialItemId,
    this.initialIndentId,
    this.initialIndentQty,
    this.initialIndentNumber,
    this.isPutaway = false,
  });

  @override
  ConsumerState<QRCodeScannerRackPage> createState() =>
      _QRCodeScannerRackPageState();
}

class _QRCodeScannerRackPageState extends ConsumerState<QRCodeScannerRackPage> {
  late final MobileScannerController _controller;
  final double scanArea = 300;

  bool _isHandlingCode = false;
  bool _isLoadingRacks = false;
  List<Map<String, dynamic>> _assignedRacks = [];

  bool get _isPutawayWorkflow =>
      widget.isPutaway ||
      widget.initialIndentId != null ||
      widget.initialItemId != null;

  ScannerWorkflow get _activeWorkflow =>
      _isPutawayWorkflow ? ScannerWorkflow.putaway : ScannerWorkflow.receive;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [BarcodeFormat.qrCode],
      torchEnabled: false,
    );

    if (widget.initialItemId != null && widget.initialItemId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchAssignedRacks();
      });
    }
  }

  Future<void> _fetchAssignedRacks() async {
    final itemId = widget.initialItemId;
    if (itemId == null || itemId.isEmpty) return;

    if (mounted) setState(() => _isLoadingRacks = true);
    try {
      final racks =
          await ref.read(storeRackControllerProvider).getRacksByItem(itemId);
      if (mounted) {
        setState(() {
          _assignedRacks = racks;
          _isLoadingRacks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRacks = false);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _controller.stop();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _appBack() async {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 10, top: 10, bottom: 10),
            child: AppBackButton(onPressed: _appBack),
          ),
          title: const Text(
            "Store Scanner",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: "Select / Enter Rack ID (Web / Manual)",
              icon: const Icon(Icons.keyboard_outlined),
              onPressed: _manualRackInput,
            ),
          ],
        ),
        floatingActionButton: ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (context, state, _) {
            final torchState = state.torchState;
            final bool isUnavailable = torchState == TorchState.unavailable;

            IconData icon;
            switch (torchState) {
              case TorchState.on:
                icon = Icons.flash_off_outlined;
                break;
              case TorchState.off:
              case TorchState.auto:
              case TorchState.unavailable:
                icon = Icons.flash_on_outlined;
            }

            return FloatingActionButton(
              onPressed:
                  isUnavailable ? null : () async => _controller.toggleTorch(),
              child: Icon(icon),
            );
          },
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Text(
                  _isPutawayWorkflow ? "Put Away Scanner" : "Receive Scanner",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ScannerModeSelectorBar(workflow: _activeWorkflow),

              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      onDetect: _onDetect,
                      errorBuilder: (
                        BuildContext context,
                        MobileScannerException error,
                      ) {
                        return Center(
                          child: Text(
                            'Camera error: ${error.errorCode.name}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      },
                      placeholderBuilder: (BuildContext context) {
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                    _buildScannerOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = scanArea;
        final double left = (constraints.maxWidth - size) / 2;
        final double top = (constraints.maxHeight - size) / 2;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: size,
              height: size,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _manualRackInput() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Rack ID (Web / Manual)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Rack Database ID or Scanned String (e.g. 69c6287b9827412ba0bc8b6b or P0041.<rackId>):',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Rack Database ID or Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Open Rack Putaway'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await _validateAndProceed(result);
    }
  }

  Future<void> _validateAndProceed(String rawInput) async {
    _isHandlingCode = true;
    await _controller.pause();

    String scannedRackTarget = rawInput.trim();

    if (scannedRackTarget.contains('.')) {
      final parts = scannedRackTarget.split('.');
      if (parts.length != 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid QR format")),
        );
        _isHandlingCode = false;
        await _controller.start();
        return;
      }

      final qrCodeId = parts[0];
      final databaseId = parts[1].trim();

      final activeMode =
          ref.read(scannerSettingsProvider).getMode(_activeWorkflow);

      if (qrCodeId == "P0040") {
        if (activeMode == ScannerTargetMode.placeOnly) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Item QR ignored: Scanner set to 'Place only' mode",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF4D4542),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _isHandlingCode = false;
          await _controller.start();
          return;
        }
        if (widget.initialItemId == null) {
          if (!mounted) return;
          await Navigator.pushReplacement<bool, void>(
            context,
            MaterialPageRoute(
              builder: (context) => ScanItemReceivePage(itemId: databaseId),
            ),
          );
          return;
        } else {
          final messenger = ScaffoldMessenger.of(context);
          await _controller.stop();
          if (!mounted) return;
          Navigator.of(context).pop(false);

          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Wrong QR: Please scan a Rack QR code (P0041)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFC62828),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }
      } else if (qrCodeId == "P0041") {
        if (activeMode == ScannerTargetMode.itemOnly) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Place QR ignored: Scanner set to 'Item only' mode",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF4D4542),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _isHandlingCode = false;
          await _controller.start();
          return;
        }

        scannedRackTarget = databaseId;
      } else {
        final messenger = ScaffoldMessenger.of(context);
        await _controller.stop();
        if (!mounted) return;
        Navigator.of(context).pop(false);

        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("Wrong QR: Invalid format", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    final itemId = widget.initialItemId;
    if (itemId != null && itemId.isNotEmpty) {
      // Ensure assigned racks are loaded
      if (_assignedRacks.isEmpty) {
        try {
          _assignedRacks = await ref
              .read(storeRackControllerProvider)
              .getRacksByItem(itemId);
        } catch (_) {}
      }

      // Check if the item already exists / is assigned in any rack
      if (_assignedRacks.isNotEmpty) {
        final matchedRack = _assignedRacks.firstWhere(
          (r) {
            final rId = (r['_id'] ?? r['id'])?.toString().trim() ?? '';
            final rCode =
                (r['code'] ?? '')?.toString().trim().toUpperCase() ?? '';
            final rName =
                (r['rackName'] ?? '')?.toString().trim().toUpperCase() ?? '';
            final target = scannedRackTarget.toUpperCase();
            return rId == scannedRackTarget ||
                rCode == target ||
                rName == target;
          },
          orElse: () => <String, dynamic>{},
        );

        if (matchedRack.isEmpty) {
          // Wrong Rack scanned: automatically close camera and show footer popup
          final assignedCodes = _assignedRacks
              .map((r) =>
                  r['code']?.toString() ?? r['rackName']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .join(', ');

          final messenger = ScaffoldMessenger.of(context);
          await _controller.stop();
          if (!mounted) return;
          Navigator.of(context).pop(false);

          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assignedCodes.isNotEmpty
                          ? 'Wrong QR: Item is assigned in some other rack ($assignedCodes)'
                          : 'Wrong QR',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFC62828),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        } else {
          // Matched! Use the actual matched rack's _id
          scannedRackTarget =
              (matchedRack['_id'] ?? matchedRack['id'])?.toString() ??
                  scannedRackTarget;
        }
      }
    }

    if (!mounted) return;

    await Navigator.pushReplacement<bool, void>(
      context,
      MaterialPageRoute(
        builder: (context) => ScanRackReceivePage(
          rackId: scannedRackTarget,
          initialItemId: widget.initialItemId,
          initialIndentId: widget.initialIndentId,
          initialIndentQty: widget.initialIndentQty,
          initialIndentNumber: widget.initialIndentNumber,
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandlingCode) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final String? rawValue = barcode.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    _validateAndProceed(rawValue);
  }
}
