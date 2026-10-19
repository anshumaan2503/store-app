// lib/views/items/items_list_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/item_controller.dart';
import '../../../../domains/models/item_model.dart';
import '../../issue/qr_code_scanner/qr_code_scanner.dart';
import 'item_form_view.dart';
import 'items_qr_code/item_qr_code_print_page.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class ItemsListView extends ConsumerWidget {
  const ItemsListView({super.key});

  Future<void> _openForm(BuildContext context, {ItemModel? item}) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ItemFormView(existingItem: item)));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ItemModel item) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: _surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _stroke),
            ),
            title: const Text(
              'Delete Item',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
            ),
            content: Text(
              'Are you sure you want to delete ${item.code}?',
              style: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: _ink700,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final itemNotifier = ref.read(itemControllerProvider);
                  if (item.id != null) {
                    await itemNotifier.deleteItem(id: item.id!);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _ink900,
                  foregroundColor: _surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(itemAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Items',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: _ink900),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrCodeScanner()),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _ink900,
        foregroundColor: _surface,
        elevation: 2,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: asyncItems.when(
          data: (items) {
            if (items.isEmpty) {
              return RefreshIndicator(
                color: _ink900,
                onRefresh:
                    () async => ref.invalidate(itemAllDataStreamProvider),
                child: ListView(
                  padding: const EdgeInsets.only(top: 120),
                  children: const [
                    Center(
                      child: Text(
                        'No items found. Pull to refresh.',
                        style: TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: _ink900,
              onRefresh: () async => ref.invalidate(itemAllDataStreamProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];

                  return _ItemCard(
                    item: item,
                    onTap: () => _openForm(context, item: item),
                    onQr: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ItemQRCodePrintPage(itemModelList: [item]),
                        ),
                      );
                    },
                    onDelete: () => _confirmDelete(context, ref, item),
                  );
                },
              ),
            );
          },
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: _ink900),
              ),
          error:
              (err, st) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

/* ---------------- UI Parts ---------------- */

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onTap,
    required this.onQr,
    required this.onDelete,
  });

  final ItemModel item;
  final VoidCallback onTap;
  final VoidCallback onQr;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = '${item.code} – ${item.name}';

    final subtitle =
        'Size: ${item.size ?? '-'}   Grade: ${item.grade ?? '-'}\n'
        'Opening Stock: ${item.openingStock}   Unit: ${item.unitName ?? '-'}';

    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _stroke),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BadgeIcon(icon: Icons.category_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _IconChipButton(
                    icon: Icons.qr_code_rounded,
                    tooltip: 'QR Code',
                    onTap: onQr,
                  ),
                  const SizedBox(height: 8),
                  _IconChipButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Icon(icon, color: _ink900, size: 22),
    );
  }
}

class _IconChipButton extends StatelessWidget {
  const _IconChipButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _surfaceAlt.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: Icon(icon, color: _ink900, size: 20),
          ),
        ),
      ),
    );
  }
}
