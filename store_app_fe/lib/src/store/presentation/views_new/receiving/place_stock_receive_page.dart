import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';

import '../../../controllers/store_item_controller.dart';
import '../../../controllers/store_item_receiving_controller.dart';
import '../../../controllers/store_place_controller.dart'
    hide itemReceiveControllerProvider;

// PlaceItemQty + PlaceItemsQuery
import '../../../domains/models/store_item_model.dart'; // StoreItem

import 'receiving_store_item_qr_page.dart';

/* ---------------- Palette (same as your theme example) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

/* ---------------- Qty Popup (themed) ---------------- */

Future<num?> showQtyPopup(BuildContext context, {required String title}) async {
  final ctrl = TextEditingController();
  String? err;

  return showDialog<num>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: _surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _stroke),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "Qty",
                    hintText: "Enter quantity",
                    hintStyle: const TextStyle(color: _ink600),
                    filled: true,
                    fillColor: _surfaceAlt.withValues(alpha: 0.5),
                    errorText: err,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _stroke),
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
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Enter a positive number.",
                    style: TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: _ink700,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text("Cancel"),
              ),
              _PrimaryBtn(
                icon: Icons.check_rounded,
                label: "Submit",
                compact: true,
                onTap: () {
                  final qty = num.tryParse(ctrl.text.trim());
                  if (qty == null || qty <= 0) {
                    setState(() => err = "Invalid qty");
                    return;
                  }
                  Navigator.pop(ctx, qty);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

/* ---------------- Store Item Picker Dialog (themed) ---------------- */

class _StoreItemPickerDialog extends ConsumerStatefulWidget {
  const _StoreItemPickerDialog({required this.excludeItemIds});
  final Set<String> excludeItemIds;

  @override
  ConsumerState<_StoreItemPickerDialog> createState() =>
      _StoreItemPickerDialogState();
}

class _StoreItemPickerDialogState
    extends ConsumerState<_StoreItemPickerDialog> {
  String search = "";

  @override
  Widget build(BuildContext context) {
    final itemsAv = ref.watch(storeItemAllDataStreamProvider);

    return AlertDialog(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _stroke),
      ),
      title: const Text(
        "Select Item",
        style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: "Search item",
                hintStyle: const TextStyle(color: _ink600),
                prefixIcon: const Icon(Icons.search, color: _ink600),
                filled: true,
                fillColor: _surfaceAlt.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _stroke),
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
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
              ),
              onChanged: (v) => setState(() => search = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: itemsAv.when(
                data: (items) {
                  final q = search.trim().toLowerCase();

                  final rows =
                      items
                          .where((x) => !widget.excludeItemIds.contains(x.id))
                          .where(
                            (x) =>
                                q.isEmpty || x.name.toLowerCase().contains(q),
                          )
                          .toList();

                  if (rows.isEmpty) {
                    return const Center(
                      child: Text(
                        "No items found",
                        style: TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder:
                        (_, __) => const Divider(height: 1, color: _stroke),
                    itemBuilder: (context, i) {
                      final it = rows[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        title: Text(
                          it.name,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          it.unit.isNotEmpty ? it.unit : "",
                          style: const TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: _ink600,
                        ),
                        onTap: () => Navigator.pop(context, it),
                      );
                    },
                  );
                },
                loading:
                    () => const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                error:
                    (e, _) => Center(
                      child: Text(
                        "Error: $e",
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: _ink700,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          child: const Text("Close"),
        ),
      ],
    );
  }
}

/* ---------------- UI Page (themed) ---------------- */

class PlaceStockReceivePage extends ConsumerStatefulWidget {
  const PlaceStockReceivePage({super.key, required this.placeId});
  final String placeId;

  @override
  ConsumerState<PlaceStockReceivePage> createState() =>
      _PlaceStockReceivePageState();
}

class _PlaceStockReceivePageState extends ConsumerState<PlaceStockReceivePage> {
  late PlaceItemsQuery _query;

  @override
  void initState() {
    super.initState();
    _query = PlaceItemsQuery(
      placeId: widget.placeId,
      search: '',
      page: 1,
      limit: 12,
    );
  }

  void _refreshAll() {
    ref.invalidate(storePlaceOneDataStreamProvider(widget.placeId));
    ref.invalidate(placeItemsPagedStreamProvider(_query));
  }

  @override
  Widget build(BuildContext context) {
    final placeAv = ref.watch(storePlaceOneDataStreamProvider(widget.placeId));
    final itemsAv = ref.watch(placeItemsPagedStreamProvider(_query));

    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inventory_2_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              "Receive Stock",
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh, color: _ink900),
            tooltip: "Refresh",
          ),
          IconButton(
            onPressed: () {
              // Optional QR page
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (_) => ReceivingStoreItemQrPage(placeId: widget.placeId),
              //   ),
              // );
            },
            icon: const Icon(Icons.qr_code_scanner, color: _ink900),
            tooltip: "Receive via QR (optional)",
          ),
        ],
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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                wide
                    ? Row(
                      children: [
                        SizedBox(
                          width: 460,
                          child: _ExistingItemsPanel(
                            placeAv: placeAv,
                            itemsAv: itemsAv,
                            onRefresh: _refreshAll,
                            onReceiveTap:
                                (p) => _onReceiveTap(context, placeAv, p),
                            onAddNewItemTap:
                                () =>
                                    _onAddNewItemTap(context, placeAv, itemsAv),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RightInfoPanel(
                            placeAv: placeAv,
                            itemsAv: itemsAv,
                          ),
                        ),
                      ],
                    )
                    : ListView(
                      children: [
                        _ExistingItemsPanel(
                          placeAv: placeAv,
                          itemsAv: itemsAv,
                          onRefresh: _refreshAll,
                          onReceiveTap:
                              (p) => _onReceiveTap(context, placeAv, p),
                          onAddNewItemTap:
                              () => _onAddNewItemTap(context, placeAv, itemsAv),
                        ),
                        const SizedBox(height: 12),
                        _RightInfoPanel(placeAv: placeAv, itemsAv: itemsAv),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  /* -------- Tap existing place item -> qty popup -> controller POST -------- */

  Future<void> _onReceiveTap(
    BuildContext context,
    AsyncValue<dynamic> placeAv,
    PlaceItemQty p,
  ) async {
    final qty = await showQtyPopup(context, title: "Receive • ${p.itemName}");
    if (qty == null) return;

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
    if (createdBy.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found. Please login again.")),
      );
      return;
    }

    final placeName = placeAv.valueOrNull?.name?.toString();

    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
        );
      }

      final body = {
        "placeId": widget.placeId,
        "itemId": p.itemId,
        "qty": qty,
        "createdBy": createdBy,
        "placeName": placeName,
        "itemName": p.itemName,
      };

      final ok = await ref
          .read(itemReceiveControllerProvider)
          .postReceiveStock(postReceiveStock: body);

      if (context.mounted) Navigator.pop(context); // close loader

      if (ok) Navigator.pop(context, true);
      _refreshAll();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Added $qty to ${p.itemName}")));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  /* -------- Add new item -> picker -> qty popup -> controller POST -------- */

  Future<void> _onAddNewItemTap(
    BuildContext context,
    AsyncValue<dynamic> placeAv,
    AsyncValue<List<PlaceItemQty>> itemsAv,
  ) async {
    final existingIds =
        (itemsAv.valueOrNull ?? const <PlaceItemQty>[])
            .map((e) => e.itemId)
            .toSet();

    final picked = await showDialog<StoreItem>(
      context: context,
      builder: (_) => _StoreItemPickerDialog(excludeItemIds: existingIds),
    );

    if (picked == null) return;

    final qty = await showQtyPopup(context, title: "Receive • ${picked.name}");
    if (qty == null) return;

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
    if (createdBy.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found. Please login again.")),
      );
      return;
    }

    final placeName = placeAv.valueOrNull?.name?.toString();

    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
        );
      }

      final body = {
        "placeId": widget.placeId,
        "itemId": picked.id,
        "qty": qty,
        "createdBy": createdBy,
        "placeName": placeName,
        "itemName": picked.name,
      };

      await ref
          .read(itemReceiveControllerProvider)
          .postReceiveStock(postReceiveStock: body);

      if (context.mounted) Navigator.pop(context); // close loader

      _refreshAll();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Added $qty of ${picked.name}")));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}

/* ------------ Left Panel: Place Items (themed) ------------ */

class _ExistingItemsPanel extends StatelessWidget {
  const _ExistingItemsPanel({
    required this.placeAv,
    required this.itemsAv,
    required this.onRefresh,
    required this.onReceiveTap,
    required this.onAddNewItemTap,
  });

  final AsyncValue<dynamic> placeAv; // StorePlace?
  final AsyncValue<List<PlaceItemQty>> itemsAv;
  final VoidCallback onRefresh;
  final Future<void> Function(PlaceItemQty) onReceiveTap;
  final Future<void> Function() onAddNewItemTap;

  @override
  Widget build(BuildContext context) {
    final isLoading = placeAv.isLoading || itemsAv.isLoading;

    return _Card(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Items in this Place",
            style: TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),

          // Place header
          placeAv.when(
            data: (p) {
              if (p == null) return const SizedBox.shrink();
              final name = (p.name ?? "").toString();
              final code = (p.code ?? "").toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  code.isNotEmpty ? "$name • $code" : name,
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          Row(
            children: [
              Expanded(
                child: _PrimaryBtn(
                  icon: Icons.add_rounded,
                  label: "Add New Item",
                  onTap: isLoading ? null : () => onAddNewItemTap(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: _ink900),
                tooltip: "Refresh",
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 10),

          itemsAv.when(
            data: (rows) {
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    "No items are currently stored in this place.",
                    style: TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 540,
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder:
                      (_, __) => const Divider(height: 1, color: _stroke),
                  itemBuilder: (context, i) {
                    final p = rows[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      title: Text(
                        p.itemName,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        "Total: ${p.available}",
                        style: const TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline,
                        color: _ink600,
                      ),
                      onTap: isLoading ? null : () => onReceiveTap(p),
                    );
                  },
                ),
              );
            },
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            error:
                (e, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Error: $e",
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/* ------------ Right Panel: Info (themed) ------------ */

class _RightInfoPanel extends StatelessWidget {
  const _RightInfoPanel({required this.placeAv, required this.itemsAv});

  final AsyncValue<dynamic> placeAv; // StorePlace?
  final AsyncValue<List<PlaceItemQty>> itemsAv;

  @override
  Widget build(BuildContext context) {
    final count = itemsAv.valueOrNull?.length ?? 0;

    return _Card(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Receive Stock",
            style: TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),

          placeAv.when(
            data: (p) {
              if (p == null) {
                return const Text(
                  "Place not loaded yet.",
                  style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv("Place", "${p.name ?? "—"}"),
                  _kv("Code", "${p.code ?? "—"}"),
                  _kv("Type", "${p.type ?? "—"}"),
                ],
              );
            },
            loading:
                () => const Text(
                  "Loading place...",
                  style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
                ),
            error:
                (e, _) => Text(
                  "Place error: $e",
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          ),

          const SizedBox(height: 12),
          _kv("Items in place", "$count"),
          const SizedBox(height: 12),

          const Text(
            "How it works:\n"
            "• Tap existing item → Qty popup → submit\n"
            "• Add New Item → select item → Qty popup → submit\n",
            style: TextStyle(
              color: _ink700,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              "$k:",
              style: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              v,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Shared themed atoms ---------------- */

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  }) : busy = false;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: _ink900,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 11 : 14,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _surface,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: _surface),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: _surface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
