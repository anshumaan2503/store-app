// lib/src/store/presentation/views/racks/widgets/rack_card.dart
import 'package:flutter/material.dart';
import '../../../../domains/models/store_rack_model.dart';
import 'racks_theme.dart';
import 'racks_shared_widgets.dart';

class RackCard extends StatelessWidget {
  const RackCard({
    super.key,
    required this.rack,
    required this.canEdit,
    required this.onEdit,
    required this.onQr,
    this.qrButtonKey,
  });

  final StoreRack rack;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onQr;
  final Key? qrButtonKey;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentPeach.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: stroke),
          ),
          child: const Icon(Icons.view_module_rounded, color: ink900),
        ),
        title: Text(
          rack.rackName.trim().isNotEmpty ? rack.rackName.trim() : rack.code,
          style: const TextStyle(color: ink900, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          rack.rackName.trim().isNotEmpty
              ? '${rack.code}${rack.remark.isNotEmpty ? " • ${rack.remark}" : ""}'
              : (rack.remark.isNotEmpty ? " • ${rack.remark}" : ""),
          style: const TextStyle(color: ink700, fontWeight: FontWeight.w600),
        ),
        trailing: Wrap(
          spacing: 6,
          children: [
            // IconButton(
            //   tooltip: 'QR Rack Receive',
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (_) => ScanRackReceivePage(rackId: rack.id),
            //       ),
            //     );
            //   },
            //   icon: const Icon(Icons.takeout_dining, color: ink700),
            // ),
            // IconButton(
            //   tooltip: 'QR Rack Issue',
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (_) => IssueByRackActionsPage(rackId: rack.id),
            //       ),
            //     );
            //   },
            //   icon: const Icon(Icons.record_voice_over, color: ink700),
            // ),
            if (canEdit)
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, color: ink700),
              ),
            IconButton(
              key: qrButtonKey,
              tooltip: 'QR Code',
              onPressed: onQr,
              icon: const Icon(Icons.qr_code, color: ink700),
            ),
          ],
        ),
      ),
    );
  }
}
