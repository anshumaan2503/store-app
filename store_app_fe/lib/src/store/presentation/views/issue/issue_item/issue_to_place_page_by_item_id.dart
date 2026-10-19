// lib/features/store/pages/issue_to_place_by_item_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:store_app/src/store/presentation/views/issue/issue_item/issue_lite.dart';

import '../../../../../auth/widgets/app_bar_page.dart';
import '../../../../controllers/store_item_issue_controller.dart';
import '../../../../controllers/store_place_controller.dart';
import '../../../widgets/glass_widget.dart';

class IssueToPlaceByItemPage extends ConsumerStatefulWidget {
  const IssueToPlaceByItemPage({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<IssueToPlaceByItemPage> createState() =>
      _IssueToPlaceByItemPageState();
}

class _PlaceLite {
  final String id;
  final String name;
  final int availableHere; // total - IssuedQuantity - completedQuantity
  const _PlaceLite({
    required this.id,
    required this.name,
    required this.availableHere,
  });
}

class _IssueToPlaceByItemPageState
    extends ConsumerState<IssueToPlaceByItemPage> {
  IssueLite? _selectedIssue;
  _PlaceLite? _selectedPlace;
  final _qtyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    final it = widget.itemId;
    final iss = _selectedIssue;
    final pl = _selectedPlace;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    if (iss == null) return _toast('Select issue');
    if (pl == null) return _toast('Select place');
    if (qty <= 0) return _toast('Quantity must be > 0');
    if (qty > iss.remaining) {
      return _toast('Cannot exceed issue remaining (${iss.remaining})');
    }
    if (qty > pl.availableHere) {
      return _toast('Place has only ${pl.availableHere} available');
    }

    final payload = {
      'itemid': it,
      'placeId': pl.id,
      'issueId': iss.id,
      'quantity': qty,
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(itemIssueControllerProvider)
          .itemIssueToPlace(itemIssueToPlace: payload);
      if (!mounted) return;
      _toast(ok ? 'Issued to place' : 'Issue failed');
      if (ok) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(
      itemIssuesByItemStreamProvider(widget.itemId),
    );
    final spiqAsync = ref.watch(storePlaceQuantityAllDataStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.call_split_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Issue Item To Place'),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: .10)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Glass(
                    radius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Select Issue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Issues dropdown
                        issuesAsync.when(
                          loading:
                              () => const LinearProgressIndicator(minHeight: 2),
                          error:
                              (e, _) => Text(
                                'Error: $e',
                                style: const TextStyle(color: Colors.white),
                              ),
                          data: (list) {
                            final items = list; // List<IssueLite>
                            final safeValue =
                                (_selectedIssue != null &&
                                        items.any(
                                          (x) => x.id == _selectedIssue!.id,
                                        ))
                                    ? items.firstWhere(
                                      (x) => x.id == _selectedIssue!.id,
                                    )
                                    : null;

                            return DropdownButtonFormField<IssueLite>(
                              initialValue: safeValue,
                              items: [
                                for (final it in items)
                                  DropdownMenuItem(
                                    value: it,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          it.issNo,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('(Remain: ${it.remaining})'),
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _selectedIssue = v;
                                  _selectedPlace = null;
                                  _qtyCtrl.clear();
                                });
                              },
                              dropdownColor: const Color(0xFF1F2544),
                              decoration: InputDecoration(
                                hintText: 'Select an approved issue',
                                prefixIcon: const Icon(
                                  Icons.upload_rounded,
                                  color: Colors.white,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: .10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              iconEnabledColor: Colors.white,
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Select Place',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Places dropdown filtered by itemId with availability from SPIQ
                        spiqAsync.when(
                          loading:
                              () => const LinearProgressIndicator(minHeight: 2),
                          error:
                              (e, _) => Text(
                                'Error: $e',
                                style: const TextStyle(color: Colors.white),
                              ),
                          data: (raw) {
                            final itemId = widget.itemId;
                            final spiq = (raw as List).cast<dynamic>();

                            final placeOpts = <_PlaceLite>[];
                            for (final d in spiq) {
                              final m = d as Map<String, dynamic>;
                              final mid = (m['itemId'] ?? '').toString();
                              if (mid != itemId) continue;

                              final placeId = (m['placeId'] ?? '').toString();
                              if (placeId.isEmpty) continue;
                              final placeName =
                                  (m['placeName'] ?? '').toString();

                              final total = _toInt(m['totalQuantity']);
                              final issued = _toInt(m['IssuedQuantity']);
                              final completed = _toInt(m['completedQuantity']);
                              final availableHere = total - issued - completed;
                              if (availableHere <= 0) continue;

                              placeOpts.add(
                                _PlaceLite(
                                  id: placeId,
                                  name: placeName.isEmpty ? placeId : placeName,
                                  availableHere: availableHere,
                                ),
                              );
                            }

                            final safeValue =
                                (_selectedPlace != null &&
                                        placeOpts.any(
                                          (p) => p.id == _selectedPlace!.id,
                                        ))
                                    ? placeOpts.firstWhere(
                                      (p) => p.id == _selectedPlace!.id,
                                    )
                                    : null;

                            return DropdownButtonFormField<_PlaceLite>(
                              initialValue: safeValue,
                              items: [
                                for (final p in placeOpts)
                                  DropdownMenuItem(
                                    value: p,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(Avail here: ${p.availableHere})',
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _selectedPlace = v;
                                  _qtyCtrl.clear();
                                });
                              },
                              dropdownColor: const Color(0xFF1F2544),
                              decoration: InputDecoration(
                                hintText:
                                    (_selectedIssue == null)
                                        ? 'Select issue first'
                                        : 'Select place',
                                prefixIcon: const Icon(
                                  Icons.place_rounded,
                                  color: Colors.white,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: .10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              iconEnabledColor: Colors.white,
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'Quantity',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.numbers_rounded,
                              color: Colors.white,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: .10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),

                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon:
                              _busy
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.remove_done_rounded),
                          label: Text(_busy ? 'Issuing...' : 'Issue'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }
}
