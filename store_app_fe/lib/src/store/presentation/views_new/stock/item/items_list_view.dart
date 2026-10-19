// lib/views/items/items_list_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/item_controller.dart';
import '../../../../domains/models/item_model.dart';
// ^ ensure this file defines itemControllerProvider & itemAllDataStreamProvider
import '../../issue/qr_code_scanner/qr_code_scanner.dart';
import 'item_form_view.dart';
import 'items_qr_code/item_qr_code_print_page.dart';

class ItemsListView extends ConsumerWidget {
  const ItemsListView({super.key});

  Future<void> _openForm(BuildContext context, {ItemModel? item}) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ItemFormView(existingItem: item)));
    // No manual reload: WebSocket (itemAllDataStreamProvider) will push fresh data
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ItemModel item) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Are you sure you want to delete ${item.code}?'),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final itemNotifier = ref.read(itemControllerProvider);
                  if (item.id != null) {
                    await itemNotifier.deleteItem(id: item.id!);
                    // Backend should broadcast updated items via WebSocket
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WebSocket-driven items list
    final asyncItems = ref.watch(itemAllDataStreamProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrCodeScanner()),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: asyncItems.when(
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                // re-subscribe / re-emit WebSocket request
                ref.invalidate(itemAllDataStreamProvider);
              },
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No items found. Pull to refresh.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(itemAllDataStreamProvider);
            },
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(
                    '${item.code} – ${item.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Size: ${item.size ?? '-'}   Grade: ${item.grade ?? '-'}\n'
                    'Opening Stock: ${item.openingStock}   Unit: ${item.unit ?? '-'}',
                  ),
                  isThreeLine: true,
                  onTap: () => _openForm(context, item: item),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code),
                        tooltip: 'QR Code',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ItemQRCodePrintPage(
                                    itemModelList: [item],
                                  ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, ref, item),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
