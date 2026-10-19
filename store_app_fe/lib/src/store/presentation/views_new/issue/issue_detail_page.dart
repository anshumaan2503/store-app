// lib/src/store/presentation/views/issue/issue_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/store_item_issue_controller.dart';

class IssueDetailPage extends ConsumerWidget {
  const IssueDetailPage({super.key, required this.id});
  final String id;

  // ───────────────── Palette ─────────────────
  static const _ink900 = Color(0xFF282321);
  static const _ink700 = Color(0xFF4D4542);
  static const _ink600 = Color(0xFF867471);
  static const _surface = Color(0xFFFFFFFF);
  static const _stroke = Color(0xFFDFE1D6);
  static const _accentMint = Color(0xFFB6D3CC);
  static const _accentPeach = Color(0xFFF3D7C0);
  static const _bgTop = Color(0xFFFFFFF8);
  static const _bgBottom = Color(0xFFFFF4E2);

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
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIssue = ref.watch(itemIssueOneDataStreamProvider(id));

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.outbox_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Issue Detail',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: asyncIssue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (e, _) => Center(
                  child: _Card(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: _ink700),
                    ),
                  ),
                ),
            data: (doc) {
              if (doc == null) {
                return const Center(
                  child: _Card(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No item issue found',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              final issNo = (doc['issNo'] ?? '').toString();
              final status = (doc['status'] ?? '').toString();
              final reason = (doc['reason'] ?? '').toString();
              final created = doc['createdAt']?.toString() ?? '';
              final lines = (doc['lines'] as List?) ?? const [];

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _Card(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  issNo.isEmpty ? '(No #)' : issNo,
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _accentPeach,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: _stroke),
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
                          const SizedBox(height: 8),
                          Text(
                            reason,
                            style: const TextStyle(
                              color: _ink700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Created: $created',
                            style: const TextStyle(
                              color: _ink600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Lines',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _IssueLinesTable(lines: lines),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IssueLinesTable extends StatelessWidget {
  const _IssueLinesTable({required this.lines});
  final List lines;

  static const _ink900 = IssueDetailPage._ink900;
  static const _ink700 = IssueDetailPage._ink700;
  static const _surface = IssueDetailPage._surface;
  static const _stroke = IssueDetailPage._stroke;
  static const _accentMint = IssueDetailPage._accentMint;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return _Card(
        padding: const EdgeInsets.all(12),
        child: const Center(
          child: Text('No lines', style: TextStyle(color: _ink700)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _stroke)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Text(
                      'Item',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Req Qty',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Approved',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Issued',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final raw in lines) _LineRow(raw: raw as Map<String, dynamic>),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.raw});
  final Map<String, dynamic> raw;

  static const _ink900 = IssueDetailPage._ink900;
  static const _ink700 = IssueDetailPage._ink700;
  static const _stroke = IssueDetailPage._stroke;
  static const _accentMint = IssueDetailPage._accentMint;

  @override
  Widget build(BuildContext context) {
    final itemName = (raw['itemName'] ?? '').toString();
    final itemId = (raw['itemId'] ?? '').toString();
    final req = raw['requestedQty'] ?? 0;
    final appr = raw['approvedQty'] ?? 0;
    final iss = raw['issuedQty'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _stroke)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              itemName.isNotEmpty ? itemName : itemId,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(flex: 2, child: _Badge(text: '$req')),
          Expanded(flex: 2, child: _Badge(text: '$appr')),
          Expanded(flex: 2, child: _Badge(text: '$iss')),
        ],
      ),
    );
  }
}

/* ───────────── Reusable light components ───────────── */

class _Card extends StatelessWidget {
  const _Card({this.child, this.padding}) : height = null;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double? height;

  static const _surface = IssueDetailPage._surface;
  static const _stroke = IssueDetailPage._stroke;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  static const _ink900 = IssueDetailPage._ink900;
  static const _surface = IssueDetailPage._surface;
  static const _stroke = IssueDetailPage._stroke;
  static const _accentMint = IssueDetailPage._accentMint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _accentMint, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          text,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
