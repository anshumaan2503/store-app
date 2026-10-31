import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../controllers/store_rack_controller.dart';
import '../../../../domains/models/store_issue_model.dart';

/* ---------------- Palette ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentMint = Color(0xFFB6D3CC);

class ItemIssueVerifyScanPage extends ConsumerStatefulWidget {
  const ItemIssueVerifyScanPage({
    super.key,
    required this.issue,
    required this.line,
  });

  final IssueModel issue;
  final IssueLine line;

  @override
  ConsumerState<ItemIssueVerifyScanPage> createState() =>
      _ItemIssueVerifyScanPageState();
}

class _ItemIssueVerifyScanPageState
    extends ConsumerState<ItemIssueVerifyScanPage> {
  late final MobileScannerController _controller;
  final double scanArea = 280;

  bool _isHandlingCode = false;
  bool _isLoadingRacks = true;
  List<Map<String, dynamic>> _assignedRacks = [];

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
      ],
      torchEnabled: false,
    );
    _loadRacks();
  }

  Future<void> _loadRacks() async {
    try {
      final fetched = await ref
          .read(storeRackControllerProvider)
          .getRacksByItem(widget.line.itemId);
      if (mounted) {
        setState(() {
          _assignedRacks = fetched
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoadingRacks = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRacks = false;
        });
      }
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

  bool _checkMatch(String raw) {
    final lower = raw.trim().toLowerCase();
    final targetItemId = widget.line.itemId.trim().toLowerCase();
    final targetItemName = widget.line.itemName.trim().toLowerCase();

    // 1. Direct Item ID match
    if (targetItemId.isNotEmpty && lower == targetItemId) {
      return true;
    }

    // 2. Item QR format: P0040.<itemId>
    if (lower.startsWith('p0040.')) {
      final scannedId = lower.substring(6).trim();
      if (scannedId == targetItemId ||
          (targetItemName.isNotEmpty && scannedId == targetItemName)) {
        return true;
      }
    }

    // 3. Direct Item Name match (if QR / Barcode encodes item name)
    if (targetItemName.isNotEmpty && lower == targetItemName) {
      return true;
    }

    // 4. Rack / Spot match (if the item is located in specific racks/spots)
    for (final rack in _assignedRacks) {
      final rId = (rack['_id'] ?? rack['id'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final rCode = (rack['code'] ?? '').toString().trim().toLowerCase();
      final rName = (rack['rackName'] ?? '').toString().trim().toLowerCase();

      // Standard Rack QR format: P0041.<rackId>
      if (lower.startsWith('p0041.')) {
        final scannedRack = lower.substring(6).trim();
        if ((rId.isNotEmpty && scannedRack == rId) ||
            (rCode.isNotEmpty && scannedRack == rCode) ||
            (rName.isNotEmpty && scannedRack == rName)) {
          return true;
        }
      }

      // Direct Rack ID / Rack Code match
      if (rId.isNotEmpty && lower == rId) {
        return true;
      }
      if (rCode.isNotEmpty && lower == rCode) {
        return true;
      }
      if (rName.isNotEmpty && lower == rName) {
        return true;
      }
    }

    return false;
  }

  Future<void> _verifyCode(String rawCode) async {
    if (_isHandlingCode) return;
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return;

    _isHandlingCode = true;
    await _controller.pause();

    // If racks are still loading, wait for completion to avoid false negative
    if (_isLoadingRacks) {
      try {
        final fetched = await ref
            .read(storeRackControllerProvider)
            .getRacksByItem(widget.line.itemId);
        _assignedRacks = fetched
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _isLoadingRacks = false;
      } catch (_) {}
    }

    final isMatch = _checkMatch(trimmed);

    if (!mounted) return;

    await _controller.stop();
    if (!mounted) return;
    // Return true on match; return false on wrong QR to trigger "Wrong QR" message & auto-redirect
    Navigator.of(context).pop(isMatch);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandlingCode) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final raw = barcode.rawValue ?? barcode.displayValue;
    if (raw == null || raw.trim().isEmpty) return;

    _verifyCode(raw);
  }

  Future<void> _showManualInputDialog() async {
    final textCtrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: _ink900, size: 20),
            SizedBox(width: 8),
            Text(
              'Enter QR Code Manually',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter item QR (e.g. P0040.${widget.line.itemId}) or location QR:',
              style: const TextStyle(fontSize: 12, color: _ink700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'P0040.${widget.line.itemId}',
                hintStyle: const TextStyle(fontSize: 12, color: _ink600),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: _ink600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(textCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (entered != null && entered.isNotEmpty) {
      await _verifyCode(entered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rackNames = _assignedRacks
        .map((r) => (r['code'] ?? r['rackName'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0.5,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Scan to Verify Item',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink900,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.keyboard_outlined, color: _ink900),
              tooltip: 'Enter Code Manually',
              onPressed: _showManualInputDialog,
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

            return FloatingActionButton.small(
              backgroundColor: _ink900,
              foregroundColor: Colors.white,
              onPressed:
                  isUnavailable ? null : () async => _controller.toggleTorch(),
              child: Icon(icon, size: 20),
            );
          },
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Target Item Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: _surfaceAlt,
                  border: Border(bottom: BorderSide(color: _stroke)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: _ink900,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.line.itemName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _ink900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _accentMint.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Appr: ${widget.line.approvedQty} ${widget.line.unit}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _ink900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoadingRacks
                          ? 'Loading assigned locations...'
                          : (rackNames.isNotEmpty
                              ? 'Assigned Spot: ${rackNames.join(", ")}'
                              : 'No specific spot assigned • Scan Item QR'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _ink700,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Scanner Viewport
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
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
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
        final double size = scanArea.clamp(
          180.0,
          constraints.maxWidth * 0.75,
        );
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
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: top + size + 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point camera at Item QR or Assigned Location QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
