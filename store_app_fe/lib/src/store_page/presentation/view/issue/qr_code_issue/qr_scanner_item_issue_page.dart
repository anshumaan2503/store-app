import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../issue_scan_by_rack_page.dart';
import '../issue_scan_page.dart';
import '../issue_scan_return_page.dart';

class QRCodeScannerIssuePage extends StatefulWidget {
  final bool isReturn;
  const QRCodeScannerIssuePage({super.key, this.isReturn = false});

  @override
  State<QRCodeScannerIssuePage> createState() => _QRCodeScannerIssuePageState();
}

class _QRCodeScannerIssuePageState extends State<QRCodeScannerIssuePage> {
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
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            "Scan for Issue Request",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
                  "Scan QR for Issue Request",
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
              builder: (context) => widget.isReturn
                  ? IssueByItemReturnActionsPage(itemId: databaseId)
                  : IssueByItemActionsPage(itemId: databaseId),
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
              builder: (context) => IssueByRackActionsPage(rackId: databaseId),
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
