import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:store_app/src/components/motion_widgets.dart';
import '../scan_item_receive_page.dart';
import '../scan_rack_receive_page.dart';

class QRCodeScannerRackPage extends StatefulWidget {
  const QRCodeScannerRackPage({super.key});

  @override
  State<QRCodeScannerRackPage> createState() => _QRCodeScannerRackPageState();
}

class _QRCodeScannerRackPageState extends State<QRCodeScannerRackPage> {
  late final MobileScannerController _controller;
  final double scanArea = 300;

  bool _isHandlingCode = false;

  // ✅ system back blocked by default; allow only when app back is pressed
  bool _allowPopOnce = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [BarcodeFormat.qrCode],
      torchEnabled: false,
    );
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
    // Temporarily allow pop, then pop, then lock again if not popped.
    if (!mounted) return;

    setState(() => _allowPopOnce = true);

    final didPop = await Navigator.of(context).maybePop();

    if (!mounted) return;

    // If it didn't pop (root route), re-lock back.
    if (!didPop) {
      setState(() => _allowPopOnce = false);
    }
    // If it did pop, widget will dispose anyway.
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ✅ System back/gesture will be blocked unless _allowPopOnce=true
      canPop: _allowPopOnce,
      onPopInvoked: (didPop) {
        // If a system-back attempt happens while locked, it won't pop.
        // No action needed.
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,

          // ✅ App back button works
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
              default:
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "QR Code Scanner",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
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
    final ctrl = TextEditingController(text: '69c6287b9827412ba0bc8b6b');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Rack ID (Web / Testing)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                labelText: 'Rack Database ID',
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
      if (result.contains('.')) {
        await _handleScannedValue(result);
      } else {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ScanRackReceivePage(rackId: result),
          ),
        );
      }
    }
  }

  Future<void> _handleScannedValue(String rawValue) async {
    final parts = rawValue.split('.');
    if (parts.length != 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid QR format")));
      return;
    }

    final qrCodeId = parts[0];
    final databaseId = parts[1];

    _isHandlingCode = true;
    await _controller.pause();

    switch (qrCodeId) {
      case "P0040":
        {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => ScanItemReceivePage(itemId: databaseId),
            ),
          );

          if (!mounted) return;

          if (result == true) {
            // Use app navigation (not system)
            Navigator.pop(context, true);
          } else {
            _isHandlingCode = false;
            await _controller.start();
          }
          break;
        }
      case "P0041":
        {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => ScanRackReceivePage(rackId: databaseId),
            ),
          );

          if (!mounted) return;

          if (result == true) {
            // Use app navigation (not system)
            Navigator.pop(context, true);
          } else {
            _isHandlingCode = false;
            await _controller.start();
          }
          break;
        }

      default:
        {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Invalid QR format")));
          _isHandlingCode = false;
          await _controller.start();
        }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandlingCode) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final String? rawValue = barcode.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    _handleScannedValue(rawValue);
  }
}
