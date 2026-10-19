// issues_return_list_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/auth_controller.dart';
import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/domains/models/auth_model.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/utils.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../domains/models/store_issue_model.dart';
import '../../../domains/models/store_rack_model.dart';
import 'qr_code_issue/qr_scanner_item_issue_page.dart';

/* ---------------- Palette (matches your theme) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

const _accentMint = Color(0xFFB6D3CC);

const _shadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
];

/* ---------------- helpers ---------------- */
String _idOf(Map<String, dynamic> m) =>
    (m["_id"] ?? m["id"] ?? "").toString().trim();

int _i(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;

/// Remaining to return (issued - (returned + scrap))
int _remainReturn(IssueLine l) =>
    math.max(0, _i(l.issuedQty) - (_i(l.returnQty) + _i(l.scrapQty)));

class IssuesReturnListPage extends ConsumerStatefulWidget {
  const IssuesReturnListPage({super.key});

  @override
  ConsumerState<IssuesReturnListPage> createState() =>
      _IssuesReturnListPageState();
}

class _IssuesReturnListPageState extends ConsumerState<IssuesReturnListPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _page = 1;
  final int _limit = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final query = IssueQuery(
    //   search: _search,
    //   page: _page,
    //   limit: _limit,
    //   sort: '-createdAt',
    // );

    // final issuesAv = ref.watch(pagedIssuesStreamProvider(query));
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: _surface,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: _surface,
              surfaceTintColor: Colors.transparent,
              iconTheme: const IconThemeData(color: _ink900),
              title: const Text(
                'Issues',
                style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
              ),
            ),
            body: const Center(child: Text('User not found')),
          );
        }
        final canViewAll = user.isSuperAdmin ||
            user.appWorks.isEmpty ||
            user.appWorks.contains("storeadmin") ||
            user.appWorks.contains("storissueview") ||
            user.appWorks.contains("storissueapprove") ||
            user.appWorks.contains("storissuefromstock") ||
            user.appWorks.contains("storissuereturn");

        final query = IssueQuery(
          search: _search,
          page: _page,
          limit: _limit,
          sort: '-createdAt',
          createdBy: canViewAll ? null : user.uid,
        );
        final issuesAv = ref.watch(pagedIssuesStreamProvider(query));

        return Scaffold(
          backgroundColor: _surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: _surface,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: _ink900),
            title: const Text(
              'Issues',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
            ),
          ),
          floatingActionButton: () {
            final hasAccess = user.appWorks.contains("storissueedit") ||
                user.appWorks.contains("storissuereturn");
            final w = MediaQuery.of(context).size.width;
            final isIPadSize = w <= 768;

            if (!hasAccess || !isIPadSize) return null;

            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QRCodeScannerIssuePage(isReturn: true),
                  ),
                );
              },
              elevation: 6,
              backgroundColor: _ink900,
              foregroundColor: _surface,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'QR Return',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _stroke),
              ),
            );
          }(),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgTop, _bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _SearchBarRow(
                          controller: _searchCtrl,
                          onChanged:
                              (v) => setState(() {
                                _search = v.trim();
                                _page = 1;
                              }),
                          onReset: () {
                            _searchCtrl.clear();
                            setState(() {
                              _search = '';
                              _page = 1;
                            });
                          },
                          onFilter: () {},
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: issuesAv.when(
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error: (e, _) => Center(child: Text('Error: $e')),
                            data: (paged) {
                              final rows = paged.rows;
                              if (rows.isEmpty) {
                                return const Center(
                                  child: Text('No issues found'),
                                );
                              }
                              return ListView.separated(
                                itemCount: rows.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final issue = rows[i];
                                  return _IssueCard(
                                    key: ValueKey(issue.id), // ✅ important
                                    issue: issue,
                                    onChanged:
                                        () => ref.invalidate(
                                          pagedIssuesStreamProvider(query),
                                        ),
                                    user: user,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        issuesAv.when(
                          loading: () => const SizedBox(height: 34),
                          error: (_, __) => const SizedBox(height: 34),
                          data:
                              (paged) => _Pager(
                                page: _page,
                                totalPages: (paged.total / paged.limit).ceil(),
                                onPage: (p) => setState(() => _page = p),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ---------------- Search Row ---------------- */

class _SearchBarRow extends StatelessWidget {
  const _SearchBarRow({
    required this.controller,
    required this.onChanged,
    required this.onFilter,
    required this.onReset,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Search by Issue No / Reason / Item name',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: _surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _ink900, width: 1.2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onFilter,
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink900,
              iconColor: _ink900,
              side: const BorderSide(color: _stroke),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18, color: _ink900),
            label: const Text(
              'Filter',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink900,
              iconColor: _ink900,
              side: const BorderSide(color: _stroke),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18, color: _ink900),
            label: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Card ---------------- */

class _IssueCard extends ConsumerStatefulWidget {
  const _IssueCard({
    super.key,
    required this.issue,
    required this.user,
    required this.onChanged,
  });

  final AuthModel user;
  final IssueModel issue;
  final VoidCallback onChanged;

  @override
  ConsumerState<_IssueCard> createState() => __IssueCardState();
}

class __IssueCardState extends ConsumerState<_IssueCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final createdByAv = ref.watch(userByIdProvider(issue.createdBy));
    final canReturnForThisItem = issue.lines.any((l) => _remainReturn(l) > 0);

    final filledStyle = FilledButton.styleFrom(
      backgroundColor: _accentMint.withValues(alpha: .65),
      foregroundColor: _ink900,
      disabledBackgroundColor: _accentMint.withValues(alpha: .18),
      disabledForegroundColor: _ink700.withValues(alpha: .55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    return createdByAv.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        if (user == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final a =
            (widget.user.divisionIds)
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toSet();

        final b =
            (user.divisionIds)
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toSet();

        final hasCommon = widget.user.isSuperAdmin ||
            widget.user.appWorks.contains("storeadmin") ||
            widget.user.appWorks.contains("storissuereturn") ||
            a.isEmpty ||
            b.isEmpty ||
            a.intersection(b).isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _bgTop, width: 1.2),
            boxShadow: _shadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _surfaceAlt.withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _stroke),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: _ink900,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            issue.issNo,
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            issue.reason.isEmpty ? '—' : issue.reason,
                            style: const TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Created By - ${user.name}',
                            style: const TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fmt(issue.createdAt),
                            style: const TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MiniTable(lines: issue.lines),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setState(() => _open = !_open),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Show actions',
                          style: TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _open
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: _ink700,
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState:
                      _open
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        // OutlinedButton.icon(
                        //   onPressed: () {},
                        //   icon: const Icon(Icons.visibility_rounded, size: 18),
                        //   label: const Text('View'),
                        //   style: OutlinedButton.styleFrom(
                        //     foregroundColor: _ink900,
                        //     side: const BorderSide(color: _stroke),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(14),
                        //     ),
                        //     padding: const EdgeInsets.symmetric(
                        //       horizontal: 14,
                        //       vertical: 12,
                        //     ),
                        //   ),
                        // ),
                        (widget.user.appWorks.contains("storissuereturn") &&
                                hasCommon)
                            ? FilledButton.icon(
                              onPressed:
                                  canReturnForThisItem
                                      ? () async {
                                        await showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder:
                                              (_) => _ReturnSheet(
                                                issue: issue,
                                                onChanged: widget.onChanged,
                                              ),
                                        );
                                      }
                                      : null,
                              icon: const Icon(
                                Icons.assignment_return_rounded,
                                size: 18,
                              ),
                              label: const Text('Return'),
                              style: filledStyle,
                            )
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}:${two(d.month)}:${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}

/* ---------------- Mini table ---------------- */

class _MiniTable extends StatelessWidget {
  const _MiniTable({required this.lines});
  final List<IssueLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: .35),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: const Border(bottom: BorderSide(color: _stroke)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: _Hdr('Item')),
                Expanded(flex: 2, child: _Hdr('Req Qty')),
                Expanded(flex: 2, child: _Hdr('Approved')),
                Expanded(flex: 2, child: _Hdr('Issued')),
              ],
            ),
          ),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No lines',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
              ),
            )
          else
            ...lines.map((row) {
              final rejected =
                  _i(row.approvedRejectQty) + _i(row.issuedRejectQty);

              return Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _stroke)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.itemName,
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Returned: ${_i(row.returnQty)}',
                            style: const TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Scrap: ${_i(row.scrapQty)}',
                            style: const TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Rejected: $rejected',
                            style: const TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _QtyPill('${_i(row.requestedQty)}'),
                    ),
                    Expanded(
                      flex: 2,
                      child: _QtyPill('${_i(row.approvedQty)}'),
                    ),
                    Expanded(flex: 2, child: _QtyPill('${_i(row.issuedQty)}')),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  const _Hdr(this.t);
  final String t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        t,
        style: const TextStyle(color: _ink700, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  const _QtyPill(this.t);
  final String t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(minWidth: 70),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _accentMint.withValues(alpha: .9), width: 1.2),
        ),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

/* ---------------- Return Sheet (FULLY UPDATED) ---------------- */

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet({required this.issue, required this.onChanged});

  final IssueModel issue;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  late List<IssueLine> _lines;

  final Map<String, TextEditingController> _goodCtrls = {};
  final Map<String, TextEditingController> _scrapCtrls = {};
  final Set<String> _busy = {};

  final Map<String, Map<String, dynamic>> _goodRackByItem = {};
  final Map<String, StoreRack> _scrapRackByItem = {};

  bool _didChange = false;

  bool get _canReturnNow => _lines.any((l) => _remainReturn(l) > 0);

  @override
  void initState() {
    super.initState();
    _lines = List<IssueLine>.from(widget.issue.lines);

    for (final l in _lines) {
      final rr = _remainReturn(l);
      _goodCtrls[l.itemId] = TextEditingController(text: rr > 0 ? '$rr' : '0');
      _scrapCtrls[l.itemId] = TextEditingController(text: '0');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_canReturnNow) {
        widget.onChanged();
        Navigator.pop(context, true);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _goodCtrls.values) {
      c.dispose();
    }
    for (final c in _scrapCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _asInt(String s) => int.tryParse(s.trim()) ?? 0;

  Future<String> _getUid() async {
    final uid =
        (await ref.read(spRepositoryProvider).getStringValue('uid')) ?? '';
    return uid.trim();
  }

  Future<bool> _ensureGoodRackSelected(IssueLine line) async {
    try {
      final raw = await ref
          .read(storeRackControllerProvider)
          .getRacksByItem(line.itemId);

      final list =
          raw
              .whereType<Map<String, dynamic>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

      if (list.isEmpty) {
        if (!mounted) return false;
        final retry = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('No Racks Available'),
                content: Text(
                  'No active inventory rack found for ${line.itemName}. Would you like to retry?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
        );
        if (retry == true) {
          return _ensureGoodRackSelected(line);
        }
        return false;
      }

      if (list.length == 1) {
        setState(() => _goodRackByItem[line.itemId] = list.first);
        return true;
      }

      final existing = _goodRackByItem[line.itemId];
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder:
            (_) => RackByItemSelectionDialog(
              itemId: line.itemId,
              racks: list,
              initialRackId: existing == null ? null : _idOf(existing),
            ),
      );

      if (selected == null) return false;
      setState(() => _goodRackByItem[line.itemId] = selected);
      return true;
    } catch (e) {
      if (!mounted) return false;
      final retry = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Rack Load Error'),
              content: Text('Failed to load rack data: $e. Would you like to retry?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Retry'),
                ),
              ],
            ),
      );
      if (retry == true) {
        return _ensureGoodRackSelected(line);
      }
      return false;
    }
  }

  Future<bool> _ensureScrapRackSelected(IssueLine line) async {
    try {
      final list = await ref
          .read(storeRackControllerProvider)
          .getScrapRacksByItem(line.itemId);

      if (list.isEmpty) {
        if (!mounted) return false;
        final retry = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('No Scrap Racks Available'),
                content: Text(
                  'No scrap rack found for ${line.itemName}. Would you like to retry?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
        );
        if (retry == true) {
          return _ensureScrapRackSelected(line);
        }
        return false;
      }

      if (list.length == 1) {
        setState(() => _scrapRackByItem[line.itemId] = list.first);
        return true;
      }

      final selected = await showDialog<StoreRack>(
        context: context,
        builder:
            (_) => ScrapRackSelectionDialog(
              racks: list,
              initialRackId: _scrapRackByItem[line.itemId]?.id,
            ),
      );

      if (selected == null) return false;
      setState(() => _scrapRackByItem[line.itemId] = selected);
      return true;
    } catch (e) {
      if (!mounted) return false;
      final retry = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Scrap Rack Load Error'),
              content: Text('Failed to load scrap rack data: $e. Would you like to retry?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Retry'),
                ),
              ],
            ),
      );
      if (retry == true) {
        return _ensureScrapRackSelected(line);
      }
      return false;
    }
  }

  int _toInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  Future<void> _returnOne(IssueLine line) async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final remaining = _remainReturn(line);
    if (remaining <= 0) {
      showSnackBar('Nothing remaining to return');
      return;
    }

    final good = _asInt(_goodCtrls[line.itemId]?.text ?? '0');
    final scrap = _asInt(_scrapCtrls[line.itemId]?.text ?? '0');
    final total = good + scrap;

    if (good < 0 || scrap < 0) {
      showSnackBar('Qty cannot be negative');
      return;
    }
    if (total <= 0) {
      showSnackBar('Enter good or scrap qty');
      return;
    }
    if (total > remaining) {
      showSnackBar('Total exceeds remaining ($remaining)');
      return;
    }

    final goodRack = _goodRackByItem[line.itemId];
    if (goodRack == null) {
      showSnackBar('Select Rack');
      return;
    }

    StoreRack? scrapRack;
    if (scrap > 0) {
      scrapRack = _scrapRackByItem[line.itemId];
      if (scrapRack == null) {
        showSnackBar('Select Scrap Rack');
        return;
      }
    }

    setState(() => _busy.add(line.itemId));

    try {
      final res = await ref
          .read(issueControllerProvider)
          .returnLine(
            issueId: widget.issue.id,
            itemId: line.itemId,
            rackId: _idOf(goodRack),
            scrapRackId: scrapRack?.id ?? "",
            returnedBy: uid,
            goodQty: good,
            scrapQty: scrap,
          );

      if (res == null) {
        widget.onChanged();
        return;
      }

      final data =
          (res['data'] is Map)
              ? Map<String, dynamic>.from(res['data'] as Map)
              : <String, dynamic>{};

      final updatedLine =
          (data['updatedLine'] is Map)
              ? Map<String, dynamic>.from(data['updatedLine'] as Map)
              : <String, dynamic>{};

      // ✅ IMPORTANT: fallback to the line we acted on
      final updatedItemId =
          (updatedLine['itemId'] ?? '').toString().trim().isNotEmpty
              ? (updatedLine['itemId'] ?? '').toString()
              : line.itemId;

      // ✅ IMPORTANT: fallback values if backend doesn't return totals
      final fallbackReturn = _i(line.returnQty) + good;
      final fallbackScrap = _i(line.scrapQty) + scrap;

      final nextReturn = _toInt(updatedLine['returnQty'], fallbackReturn);
      final nextScrap = _toInt(updatedLine['scrapQty'], fallbackScrap);

      setState(() {
        _didChange = true;

        _lines =
            _lines.map((x) {
              if (x.itemId == updatedItemId) {
                final nx = x.copyWith(
                  returnQty: nextReturn,
                  scrapQty: nextScrap,
                );
                final rr = _remainReturn(nx);

                _goodCtrls[x.itemId]?.text = rr > 0 ? '$rr' : '0';
                _scrapCtrls[x.itemId]?.text = '0';
                return nx;
              }
              return x;
            }).toList();
      });

      // ✅ refresh parent list
      widget.onChanged();

      // ✅ auto close if ALL remaining == 0
      final allDoneAfter = _lines.every((l) => _remainReturn(l) <= 0);
      if (allDoneAfter && mounted) {
        Navigator.pop(context, true);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Returned successfully')));
    } catch (e) {
      showSnackBar('Return failed: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(line.itemId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.78;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _didChange);
        return false;
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _stroke),
                boxShadow: _shadow,
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Return Items: ${widget.issue.issNo}',
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, _didChange),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final l = _lines[i];
                        final busy = _busy.contains(l.itemId);
                        final remaining = _remainReturn(l);

                        final disabled = busy || remaining <= 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _surfaceAlt.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _stroke),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l.itemName,
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Issued: ${_i(l.issuedQty)}',
                                    style: const TextStyle(
                                      color: _ink700,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Returned: ${_i(l.returnQty)}',
                                    style: const TextStyle(
                                      color: _ink700,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Scrap: ${_i(l.scrapQty)}',
                                    style: const TextStyle(
                                      color: _ink700,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Remaining: $remaining',
                                    style: const TextStyle(
                                      color: _ink900,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Good Qty',
                                          style: TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _goodCtrls[l.itemId],
                                          enabled: !disabled,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          cursorColor: const Color(0xFF111827),
                                          style: const TextStyle(
                                            color: Color(0xFF111827),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            hintText: '0',
                                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                            ),
                                            disabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Scrap Qty',
                                          style: TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _scrapCtrls[l.itemId],
                                          enabled: !disabled,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          cursorColor: const Color(0xFF111827),
                                          style: const TextStyle(
                                            color: Color(0xFF111827),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            hintText: '0',
                                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                            ),
                                            disabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: SizedBox(
                                  height: 44,
                                  width: 140,
                                  child: FilledButton(
                                    onPressed:
                                        disabled
                                            ? null
                                            : () async {
                                              final good = _asInt(
                                                _goodCtrls[l.itemId]?.text ??
                                                    '0',
                                              );
                                              final scrap = _asInt(
                                                _scrapCtrls[l.itemId]?.text ??
                                                    '0',
                                              );
                                              final total = good + scrap;

                                              if (total <= 0) {
                                                showSnackBar(
                                                  'Enter good or scrap qty',
                                                );
                                                return;
                                              }

                                              final okGood =
                                                  await _ensureGoodRackSelected(
                                                    l,
                                                  );
                                              if (!okGood) return;

                                              if (scrap > 0) {
                                                final okScrap =
                                                    await _ensureScrapRackSelected(
                                                      l,
                                                    );
                                                if (!okScrap) return;
                                              }

                                              await _returnOne(l);
                                            },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _accentMint.withValues(
                                        alpha: .75,
                                      ),
                                      foregroundColor: _ink900,
                                      disabledBackgroundColor: _accentMint
                                          .withValues(alpha: .18),
                                      disabledForegroundColor: _ink700
                                          .withValues(alpha: .55),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child:
                                        busy
                                            ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : Text(
                                              remaining <= 0
                                                  ? 'Returned'
                                                  : 'Return',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- Pager + Card ---------------- */

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final tp = totalPages < 1 ? 1 : totalPages;

    int start = (page - 2).clamp(1, tp);
    int end = (start + 4).clamp(1, tp);
    start = (end - 4).clamp(1, tp);

    final pages = <int>[];
    for (int p = start; p <= end; p++) {
      pages.add(p);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page <= 1 ? null : () => onPage(page - 1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        ...pages.map((p) {
          final active = p == page;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              onTap: () => onPage(p),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 44,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? _accentMint.withValues(alpha: .75) : _surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _stroke),
                ),
                child: Text(
                  '$p',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }),
        IconButton(
          onPressed: page >= tp ? null : () => onPage(page + 1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/* ---------------- Rack By Item Dialog (UPDATED: NO PROVIDER DEP) ---------------- */

class RackByItemSelectionDialog extends StatefulWidget {
  const RackByItemSelectionDialog({
    super.key,
    required this.itemId,
    required this.racks,
    this.initialRackId,
  });

  final String itemId;
  final String? initialRackId;
  final List<Map<String, dynamic>> racks;

  @override
  State<RackByItemSelectionDialog> createState() =>
      _RackByItemSelectionDialogState();
}

class _RackByItemSelectionDialogState extends State<RackByItemSelectionDialog> {
  Map<String, dynamic>? _rack;
  bool _didInit = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.racks;

    if (!_didInit) {
      _didInit = true;

      if (widget.initialRackId != null) {
        final hit =
            list.where((x) => _idOf(x) == widget.initialRackId).toList();
        if (hit.isNotEmpty) _rack = hit.first;
      }

      if (list.length == 1) {
        _rack ??= list.first;
      }
    }

    final mustSelect = list.length > 1;
    final canSubmit = !mustSelect || _rack != null;

    Map<String, dynamic>? safeValue;
    if (_rack != null) {
      final id = _idOf(_rack!);
      final hit = list.where((x) => _idOf(x) == id).toList();
      safeValue = hit.isNotEmpty ? hit.first : null;
    }

    return AlertDialog(
      title: const Text('Select Rack'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DropdownField<Map<String, dynamic>>(
              label: 'Rack *',
              hint: 'Select rack',
              icon: Icons.category_rounded,
              value: safeValue,
              items: list,
              textOf: (x) => '${x["code"]} • ${x["roomName"]}',
              onChanged: (rack) => setState(() => _rack = rack),
            ),
            const SizedBox(height: 10),
            if (mustSelect && _rack == null)
              const Text(
                'Please select a rack to continue.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 12),
            if (_rack != null)
              _RackDetailsCard(rack: _rack, itemId: widget.itemId),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canSubmit ? () => Navigator.pop(context, _rack) : null,
          child: const Text('Select'),
        ),
      ],
    );
  }
}

/* ---------------- Scrap Rack Dialog ---------------- */

class ScrapRackSelectionDialog extends StatefulWidget {
  const ScrapRackSelectionDialog({
    super.key,
    required this.racks,
    this.initialRackId,
  });

  final List<StoreRack> racks;
  final String? initialRackId;

  @override
  State<ScrapRackSelectionDialog> createState() =>
      _ScrapRackSelectionDialogState();
}

class _ScrapRackSelectionDialogState extends State<ScrapRackSelectionDialog> {
  StoreRack? _rack;

  @override
  Widget build(BuildContext context) {
    final list = widget.racks;

    if (_rack == null && widget.initialRackId != null) {
      final hit = list.where((x) => x.id == widget.initialRackId).toList();
      if (hit.isNotEmpty) _rack = hit.first;
    }
    _rack ??= list.first;

    final mustSelect = list.length > 1;
    final canSubmit = !mustSelect || _rack != null;

    return AlertDialog(
      title: const Text('Select Scrap Rack'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DropdownField<StoreRack>(
              label: 'Scrap Rack *',
              hint: 'Select rack',
              icon: Icons.category_rounded,
              value: _rack,
              items: list,
              textOf: (x) => '${x.code} • ${x.roomName}',
              onChanged: (v) => setState(() => _rack = v),
            ),
            const SizedBox(height: 12),
            if (_rack != null)
              _SimpleRackDetailsCard(
                code: _rack!.code,
                roomName: _rack!.roomName,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canSubmit ? () => Navigator.pop(context, _rack) : null,
          child: const Text('Select'),
        ),
      ],
    );
  }
}

class _SimpleRackDetailsCard extends StatelessWidget {
  const _SimpleRackDetailsCard({required this.code, required this.roomName});
  final String code;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _RackDetailRow(label: 'Code', value: code),
          _RackDetailRow(label: 'Room', value: roomName),
        ],
      ),
    );
  }
}

/* ---------------- Shared UI ---------------- */

class _RackDetailRow extends StatelessWidget {
  const _RackDetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.textOf,
    required this.onChanged,
    this.allowNull = false,
    this.nullLabel = 'None',
  });

  final String label;
  final String hint;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) textOf;
  final ValueChanged<T?> onChanged;

  final bool allowNull;
  final String nullLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          items: [
            if (allowNull)
              DropdownMenuItem<T?>(
                value: null,
                child: Text(
                  nullLabel,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            for (final it in items)
              DropdownMenuItem<T?>(
                value: it,
                child: Text(textOf(it), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: .55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
            ),
          ),
          style: const TextStyle(
            color: _ink900,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          dropdownColor: _surface,
          iconEnabledColor: _ink600,
        ),
      ],
    );
  }
}

/* ---------------- Rack Details Card (UPDATED FOR itemlist) ---------------- */

class _RackDetailsCard extends StatelessWidget {
  const _RackDetailsCard({required this.rack, required this.itemId});
  final Map<String, dynamic>? rack;
  final String itemId;

  @override
  Widget build(BuildContext context) {
    if (rack == null) return const Text('No rack selected');

    Map<String, dynamic>? itemRow;

    final itemList = rack!["itemlist"] ?? rack!["itemList"] ?? rack!["items"];
    if (itemList is List) {
      for (final it in itemList) {
        if (it is Map) {
          final m = Map<String, dynamic>.from(it);
          if ((m["itemId"] ?? "").toString() == itemId) {
            itemRow = m;
            break;
          }
        }
      }
    }

    final totalStock =
        (itemRow?["totalStockQuantity"] ?? rack!["totalStockQuantity"] ?? 0)
            .toString();

    final availStock =
        (itemRow?["stockAvailableQuantity"] ??
                rack!["stockAvailableQuantity"] ??
                0)
            .toString();

    final itemName = (itemRow?["itemName"] ?? "").toString();
    final itemCode = (itemRow?["itemCode"] ?? "").toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (rack!["code"] ?? "").toString(),
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _RackDetailRow(
            label: 'Code',
            value: (rack!["code"] ?? '').toString(),
          ),
          _RackDetailRow(
            label: 'Room',
            value: (rack!["roomName"] ?? '').toString(),
          ),
          if (itemName.isNotEmpty)
            _RackDetailRow(label: 'Item', value: '$itemName ($itemCode)'),
          _RackDetailRow(label: 'Total Stock', value: totalStock),
          _RackDetailRow(label: 'Aval. Stock', value: availStock),
        ],
      ),
    );
  }
}
