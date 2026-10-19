// lib/src/store/presentation/views/issue/issue_return_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../auth/widgets/app_bar_page.dart'; // GlassAppBar
import '../../../controllers/store_item_issue_controller.dart';
import '../../widgets/glass_widget.dart';

// places
import '../../../controllers/store_place_controller.dart'
    show storePlaceAllDataStreamProvider;

// If you have typed models (optional)
import '../../../domains/models/store_place_model.dart' show StorePlace;

class IssueReturnPage extends ConsumerStatefulWidget {
  const IssueReturnPage({super.key, required this.issueDoc});
  final Map<String, dynamic> issueDoc; // Pass the full CLOSED issue doc

  @override
  ConsumerState<IssueReturnPage> createState() => _IssueReturnPageState();
}

class _ItemLite {
  final String id;
  final String name;
  final int
  returnable; // = issued - returned (or just issued if no returned tracking)
  const _ItemLite({
    required this.id,
    required this.name,
    required this.returnable,
  });
}

class _PlaceLite {
  final String id;
  final String name;
  const _PlaceLite({required this.id, required this.name});
}

class _IssueReturnPageState extends ConsumerState<IssueReturnPage> {
  _ItemLite? _selectedItem;
  _PlaceLite? _selectedPlace;
  final _qtyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  List<_ItemLite> _buildReturnableItems(Map<String, dynamic> doc) {
    print(doc);

    final lines = (doc['lines'] as List?) ?? const [];
    final out = <_ItemLite>[];
    for (final raw in lines) {
      final l = raw as Map<String, dynamic>;
      final iid = (l['itemId'] ?? '').toString();
      final name = (l['itemName'] ?? '').toString();
      final issued =
          (l['issuedQty'] is int)
              ? l['issuedQty'] as int
              : int.tryParse('${l['issuedQty']}') ?? 0;
      final returned =
          (l['returnedQty'] is int)
              ? l['returnedQty'] as int
              : int.tryParse('${l['returnedQty']}') ?? 0;
      final ret = issued - returned;
      if (ret > 0) {
        out.add(
          _ItemLite(id: iid, name: name.isEmpty ? iid : name, returnable: ret),
        );
      }
    }
    return out;
  }

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
    if (n > _selectedItem!.returnable) {
      _toast('Cannot return beyond issued (${_selectedItem!.returnable})');
      return;
    }
    final userId =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

    final body = {
      "userId": userId,
      "itemid": _selectedItem!.id,
      "placeId": _selectedPlace!.id,
      "issueId": widget.issueDoc['_id'],
      "quantity": n,
    };

    setState(() => _busy = true);
    try {
      // ⬇️ call your controller method to return to stock
      final ok = await ref
          .read(itemIssueControllerProvider)
          .returnItemIssue(returnItemIssue: body);
      // final ok = true; // demo
      if (!mounted) return;
      _toast(ok ? 'Returned to stock' : 'Return failed');
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final doc = widget.issueDoc;
    final issNo = (doc['issNo'] ?? '').toString();
    final items = _buildReturnableItems(
      doc,
    ); // only items with something to return

    final placesAsync = ref.watch(storePlaceAllDataStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.undo_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Return To Stock'),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: .10)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
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

                        // 1) Select Item (only those you can return)
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
                                        (x) => x.id == _selectedItem!.id,
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
                                    Text('(Returnable: ${it.returnable})'),
                                  ],
                                ),
                              ),
                          ],
                          onChanged:
                              (v) => setState(() {
                                _selectedItem = v;
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
                            hintStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          iconEnabledColor: Colors.white,
                        ),

                        const SizedBox(height: 14),

                        // 2) Select Place
                        const Text(
                          'Place',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        placesAsync.when(
                          loading:
                              () => const Padding(
                                padding: EdgeInsets.all(8),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                          error:
                              (e, _) => Text(
                                'Error: $e',
                                style: const TextStyle(color: Colors.white),
                              ),
                          data: (places) {
                            final opts =
                                (places as List).map<_PlaceLite>((p) {
                                  if (p is StorePlace) {
                                    return _PlaceLite(
                                      id: p.id.toString(),
                                      name: p.name,
                                    );
                                  }
                                  final m = p as Map<String, dynamic>;
                                  return _PlaceLite(
                                    id: (m['_id'] ?? m['id']).toString(),
                                    name: (m['name'] ?? '').toString(),
                                  );
                                }).toList();

                            return DropdownButtonFormField<_PlaceLite>(
                              initialValue:
                                  (_selectedPlace != null &&
                                          opts.any(
                                            (x) => x.id == _selectedPlace!.id,
                                          ))
                                      ? opts.firstWhere(
                                        (x) => x.id == _selectedPlace!.id,
                                      )
                                      : null,
                              items: [
                                for (final pl in opts)
                                  DropdownMenuItem(
                                    value: pl,
                                    child: Text(
                                      pl.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged:
                                  (v) => setState(() => _selectedPlace = v),
                              dropdownColor: const Color(0xFF1F2544),
                              decoration: InputDecoration(
                                hintText: 'Select place',
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
                            );
                          },
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
                                  : const Icon(Icons.undo_rounded),
                          label: Text(_busy ? 'Returning...' : 'Return'),
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
}
