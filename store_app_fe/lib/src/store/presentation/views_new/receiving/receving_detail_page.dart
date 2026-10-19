import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/widgets/app_bar_page.dart';
import '../../../controllers/store_item_receiving_controller.dart';
import '../../widgets/glass_widget.dart';
import 'receive_to_place_page.dart';
import 'receiving_item_approval_page.dart';

// final receivingDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
//   return ref.read(receivingApiProvider).getById(id);
// });

class ReceivingDetailPage extends ConsumerWidget {
  const ReceivingDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemReceiveOneDataStreamProvider(id));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.description_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Receiving Detail'),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: .10)),
          SafeArea(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              data: (rec) {
                if (rec == null) {
                  return const Center(
                    child: Text(
                      'No item receive found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                final status = (rec['status'] ?? '').toString();
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 26),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Glass(
                            radius: 20,
                            padding: const EdgeInsets.all(16),
                            child: _Header(rec: rec),
                          ),
                          const SizedBox(height: 12),
                          Glass(
                            radius: 20,
                            padding: const EdgeInsets.all(16),
                            child: _Lines(rec: rec),
                          ),
                          const SizedBox(height: 14),
                          if (status == 'DRAFT')
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const ReceivingApprovePage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.verified_rounded),
                              label: const Text('Go to Approvals'),
                            )
                          else if (status == 'APPROVED')
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) =>
                                            ReceiveToPlacePage(receiving: rec),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.download_done_rounded),
                              label: const Text('Receive to Place'),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.rec});
  final Map<String, dynamic> rec;

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return const Color(0xFFF59E0B);
      case 'APPROVED':
        return const Color(0xFF22C55E);
      case 'CLOSED':
        return const Color(0xFF6366F1);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (rec['status'] ?? '').toString();
    final recNo = rec['recNo'] ?? '';
    final source = rec['source'] ?? '';
    final createdAt = rec['createdAt']?.toString() ?? '';
    final remark = rec['remark'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .14),
                border: Border.all(color: Colors.white.withValues(alpha: .22)),
              ),
              child: const Icon(
                Icons.move_to_inbox_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recNo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(source, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text(
                    createdAt,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: .16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _statusColor(status).withValues(alpha: .35),
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (remark.toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Remark: $remark',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ],
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.rec});
  final Map<String, dynamic> rec;

  @override
  Widget build(BuildContext context) {
    final lines = (rec['lines'] as List).cast<Map<String, dynamic>>();
    if (lines.isEmpty) {
      return const Text('No lines', style: TextStyle(color: Colors.white70));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Lines',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final l in lines) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item: ${l['itemId']}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        children: [
                          _kv('Req', l['requestedQty']),
                          _kv('Appr', l['approvedQty']),
                          _kv('Recv', l['receivedQty']),
                          _kv('Unit', l['unit']),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _kv(String k, Object? v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k: ', style: const TextStyle(color: Colors.white70)),
        Text('${v ?? '-'}', style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
