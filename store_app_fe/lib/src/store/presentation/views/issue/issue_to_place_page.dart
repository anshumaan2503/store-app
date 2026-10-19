import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/widgets/app_bar_page.dart'; // GlassAppBar
import '../../../controllers/store_place_controller.dart';
import '../../widgets/glass_widget.dart';

// Your controllers/providers (adjust imports to your project)
import '../../../controllers/store_item_issue_controller.dart'
    show itemIssueControllerProvider, itemIssueOneDataStreamProvider;

/// Page to issue a single line: pick Item (from Issue’s remaining),
/// then pick Place (from per-place quantity provider for that item),
/// then enter Qty and submit one-shot.
class IssueToPlacePage extends ConsumerStatefulWidget {
  const IssueToPlacePage({super.key, required this.issueId});
  final String issueId;

  @override
  ConsumerState<IssueToPlacePage> createState() => _IssueToPlacePageState();
}

class _ItemLite {
  final String id;
  final String name;
  final int remaining; // approved - issued
  const _ItemLite({
    required this.id,
    required this.name,
    required this.remaining,
  });
}

class _PlaceLite {
  final String id;
  final String name;
  final int availableHere; // parsed from SPIQ (total - issued - completed)
  const _PlaceLite({
    required this.id,
    required this.name,
    required this.availableHere,
  });
}

class _IssueToPlacePageState extends ConsumerState<IssueToPlacePage> {
  _ItemLite? _selectedItem;
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
    if (_selectedItem == null) {
      _toast('Select item');
      return;
    }
    if (_selectedPlace == null) {
      _toast('Select place');
      return;
    }
    final n = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (n <= 0) {
      _toast('Quantity must be > 0');
      return;
    }
    if (n > _selectedItem!.remaining) {
      _toast('Cannot issue beyond remaining (${_selectedItem!.remaining})');
      return;
    }
    if (n > _selectedPlace!.availableHere) {
      _toast('Place has only ${_selectedPlace!.availableHere} available');
      return;
    }

    final payload = {
      "itemid": _selectedItem!.id,
      "placeId": _selectedPlace!.id,
      "issueId": widget.issueId,
      "quantity": n,
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(itemIssueControllerProvider)
          .itemIssueToPlace(itemIssueToPlace: payload);
      if (!mounted) return;
      _toast(ok ? 'Issued to place' : 'Issue failed');
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueAsync = ref.watch(
      itemIssueOneDataStreamProvider(widget.issueId),
    );
    final spiqAsync = ref.watch(storePlaceQuantityAllDataStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.call_split_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Issue To Place'),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: .10)),
          SafeArea(
            child: issueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              data: (doc) {
                if (doc == null) {
                  return const Center(
                    child: Text(
                      'Issue not found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final issNo = (doc['issNo'] ?? '').toString();
                final lines = (doc['lines'] as List?) ?? const [];

                // Build selectable items: only those with remaining > 0
                final items = <_ItemLite>[];
                for (final r in lines) {
                  final l = r as Map<String, dynamic>;
                  final iid = (l['itemId'] ?? '').toString();
                  final name = (l['itemName'] ?? '').toString();

                  final req =
                      (l['requestedQty'] is int)
                          ? l['requestedQty'] as int
                          : int.tryParse('${l['requestedQty']}') ?? 0;
                  final appr =
                      (l['approvedQty'] is int)
                          ? l['approvedQty'] as int
                          : int.tryParse('${l['approvedQty']}') ?? 0;
                  final issued =
                      (l['issuedQty'] is int)
                          ? l['issuedQty'] as int
                          : int.tryParse('${l['issuedQty']}') ?? 0;
                  final rem = req - issued;
                  if (rem > 0) {
                    items.add(
                      _ItemLite(
                        id: iid,
                        name: name.isEmpty ? iid : name,
                        remaining: rem,
                      ),
                    );
                  }
                }

                // Build place options from StorePlaceItemQuantity stream,
                // filtered by the selected item
                return spiqAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, _) => Center(
                        child: Text(
                          'Error: $e',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                  data: (raw) {
                    final selectedItemId = _selectedItem?.id;

                    // Parse SPIQ docs
                    // shape example:
                    // {
                    //   id: "...",
                    //   itemId: "68dd...",
                    //   itemName: "rice",
                    //   placeId: "68df...",
                    //   placeName: "house 2",
                    //   totalQuantity: "1232",
                    //   IssuedQuantity: "0",
                    //   completedQuantity: "0",
                    //   ...
                    // }
                    final allSpiq = (raw as List).cast<dynamic>();

                    // Per-place availability for ONLY the selected item
                    final placeOpts = <_PlaceLite>[];
                    if (selectedItemId != null && selectedItemId.isNotEmpty) {
                      for (final d in allSpiq) {
                        final m = d as Map<String, dynamic>;
                        final itemId = (m['itemId'] ?? '').toString();
                        if (itemId != selectedItemId) continue;

                        final placeId = (m['placeId'] ?? '').toString();
                        if (placeId.isEmpty) continue;

                        final placeName = (m['placeName'] ?? '').toString();
                        final total =
                            int.tryParse('${m['totalQuantity'] ?? 0}') ?? 0;
                        final issued =
                            int.tryParse('${m['IssuedQuantity'] ?? 0}') ?? 0;
                        final completed =
                            int.tryParse('${m['completedQuantity'] ?? 0}') ?? 0;
                        final availHere = total - issued - completed;
                        if (availHere <= 0) {
                          continue; // hide zero-availability places
                        }

                        placeOpts.add(
                          _PlaceLite(
                            id: placeId,
                            name: placeName.isEmpty ? placeId : placeName,
                            availableHere: availHere,
                          ),
                        );
                      }

                      // If the currently selected place is no longer valid for this item, clear it.
                      if (_selectedPlace != null &&
                          !placeOpts.any((p) => p.id == _selectedPlace!.id)) {
                        // also clear qty so user re-enters according to the new place
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _selectedPlace = null;
                            _qtyCtrl.clear();
                          });
                        });
                      }
                    } else {
                      // No item selected yet → no places
                      if (_selectedPlace != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _selectedPlace = null;
                            _qtyCtrl.clear();
                          });
                        });
                      }
                    }

                    return SingleChildScrollView(
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
                                Text(
                                  'Issue #$issNo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 1) Select Item (remaining > 0)
                                const Text(
                                  'Item',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<_ItemLite>(
                                  initialValue:
                                      (_selectedItem != null &&
                                              items.any(
                                                (x) =>
                                                    x.id == _selectedItem!.id,
                                              ))
                                          ? items.firstWhere(
                                            (x) => x.id == _selectedItem!.id,
                                          )
                                          : null,
                                  items: [
                                    for (final it in items)
                                      DropdownMenuItem(
                                        value: it,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              it.name,
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
                                  onChanged:
                                      (v) => setState(() {
                                        _selectedItem = v;
                                        _selectedPlace =
                                            null; // reset place after item change
                                        _qtyCtrl.clear();
                                      }),
                                  dropdownColor: const Color(0xFF1F2544),
                                  decoration: InputDecoration(
                                    hintText: 'Select item',
                                    prefixIcon: const Icon(
                                      Icons.inventory_2_rounded,
                                      color: Colors.white,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: .10),
                                    hintStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  iconEnabledColor: Colors.white,
                                ),

                                const SizedBox(height: 14),

                                // 2) Select Place (from SPIQ for that item)
                                const Text(
                                  'Place',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<_PlaceLite>(
                                  initialValue:
                                      (_selectedPlace != null &&
                                              placeOpts.any(
                                                (p) =>
                                                    p.id == _selectedPlace!.id,
                                              ))
                                          ? placeOpts.firstWhere(
                                            (p) => p.id == _selectedPlace!.id,
                                          )
                                          : null,
                                  items: [
                                    for (final pl in placeOpts)
                                      DropdownMenuItem(
                                        value: pl,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              pl.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '(Avail here: ${pl.availableHere})',
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  onChanged:
                                      (v) => setState(() {
                                        _selectedPlace = v;
                                        _qtyCtrl.clear();
                                      }),
                                  dropdownColor: const Color(0xFF1F2544),
                                  decoration: InputDecoration(
                                    hintText:
                                        _selectedItem == null
                                            ? 'Select item first'
                                            : 'Select place',
                                    prefixIcon: const Icon(
                                      Icons.place_rounded,
                                      color: Colors.white,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: .10),
                                    hintStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  iconEnabledColor: Colors.white,
                                  disabledHint: const Text('Select item first'),
                                ),

                                const SizedBox(height: 14),

                                // 3) Quantity
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
                                          : const Icon(
                                            Icons.remove_done_rounded,
                                          ),
                                  label: Text(_busy ? 'Issuing...' : 'Issue'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
