import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_return_to_same_bag_page.dart';

class SortingQrCodeScanner extends StatefulWidget {
  final String jobId;
  const SortingQrCodeScanner({super.key, required this.jobId});

  @override
  State<SortingQrCodeScanner> createState() => _SortingQrCodeScannerState();
}

class _SortingQrCodeScannerState extends State<SortingQrCodeScanner> {
  late final MobileScannerController _controller;
  final double scanArea = 300;

  bool _isHandlingCode = false;

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
    // Help the camera recover after hot reload.
    // Ignore the returned futures.
    _controller.stop();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          "Store Scanner",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // Flash toggle using the controller state
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
                isUnavailable
                    ? null
                    : () async {
                      await _controller.toggleTorch();
                    },
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
    );
  }

  /// Simple square overlay similar to QrScannerOverlayShape.
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
    // Expected format: "<qrCodeId>.<databaseId>"
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
      // case "P0040":
      //   {
      //     final result = await Navigator.push<bool>(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) => IssueToPlaceByItemPage(itemId: databaseId),
      //       ),
      //     );

      //     if (!mounted) return;

      //     if (result == true) {
      //       Navigator.pop(context, true);
      //     } else {
      //       _isHandlingCode = false;
      //       await _controller.start();
      //     }
      //     break;
      //   }

      // case "P0041":
      //   {
      //   final result = await Navigator.push<bool>(
      //     context,
      //     MaterialPageRoute(
      //       builder:
      //           (context) =>
      //               ReceiveToPlaceByPlaceSelectReceiving(placeId: databaseId),
      //     ),
      //   );

      //   if (!mounted) return;

      //   if (result == true) {
      //     Navigator.pop(context, true);
      //   } else {
      //     _isHandlingCode = false;
      //     await _controller.start();
      //   }
      //   break;
      // }

      case "P0042":
        {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder:
                  (context) => QRReturnToSameBagPage(
                    bagId: databaseId,
                    jobId: widget.jobId,
                  ),
            ),
          );

          if (!mounted) return;

          if (result == true) {
            Navigator.pop(context, true);
          } else {
            _isHandlingCode = false;
            await _controller.start();
          }
          break;
        }

      // case "P0043":
      //   {
      // final result = await Navigator.push<bool>(
      //   context,
      //   MaterialPageRoute(
      //     builder:
      //         (context) =>
      //             ReceiveToPlaceByPlaceSelectReceiving(placeId: databaseId),
      //   ),
      // );

      // if (!mounted) return;

      // if (result == true) {
      //   Navigator.pop(context, true);
      // } else {
      //   _isHandlingCode = false;
      //   await _controller.start();
      // }
      //   break;
      // }

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
