// lib/src/store/presentation/views/racks/rack_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../controllers/store_room_controller.dart';
import '../../../domains/models/store_rack_model.dart';
import '../../../domains/models/store_room_model.dart';

import '../../widgets/code_gen.dart';
import 'widgets/racks_shared_widgets.dart';
import 'widgets/racks_theme.dart';

class RackFormPage extends ConsumerStatefulWidget {
  const RackFormPage({super.key, this.initial});
  final StoreRack? initial;

  @override
  ConsumerState<RackFormPage> createState() => _RackFormPageState();
}

class _RackFormPageState extends ConsumerState<RackFormPage> {
  final _formKey = GlobalKey<FormState>();

  StoreRoom? _room;
  bool _createRack = false;

  late final TextEditingController _code = TextEditingController(
    text: widget.initial?.code ?? '',
  );
  late final TextEditingController _remark = TextEditingController(
    text: widget.initial?.remark ?? '',
  );

  bool _busy = false;

  RoomQuery get _roomsQuery =>
      const RoomQuery(page: 1, limit: 300, search: '', sort: 'name');

  @override
  void initState() {
    super.initState();

    if (widget.initial == null) {
      _code.text = genCode(prefix: 'RK', name: _code.text);
    } else {
      _createRack = widget.initial!.isScrap;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _openQuickRoomCreate() async {
    final created = await showDialog<StoreRoom>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RoomQuickCreateDialog(isScrap: _createRack),
    );

    if (created == null) return;

    // refresh rooms list (keep as your original invalidate)
    ref.invalidate(storeRoomPagedStreamProvider);

    // auto-select new room
    setState(() => _room = created);
  }

  Future<void> _openTransferItem() async {
    // final ok = await showDialog<bool>(
    //   context: context,
    //   barrierDismissible: false,
    //   builder:
    //       (_) => _TransferItemDialog(
    //         item: widget.initial!.itemId,
    //         rack: widget.initial!,
    //       ),
    // );

    // if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);
  }

  Future<void> _confirmRemoveItem(String rackId, String itemId) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Confirm"),
            content: const Text("Do you want to remove this item?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ok = await ref
                      .read(storeItemsControllerProvider)
                      .transferRack(itemId: itemId, toRackId: rackId);
                  if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);

                  Navigator.pop(ctx, true);
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
    if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);
  }

  Future<void> _confirmRemoveRack(String rackId) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Confirm"),
            content: const Text("Do you want to remove this rack?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ok = await ref
                      .read(storeItemsControllerProvider)
                      .removeRack(toRackId: rackId);
                  if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);

                  Navigator.pop(ctx, true);
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
    if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_room == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select room')));
      return;
    }

    final isEdit = widget.initial != null;
    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ;

    final dto = <String, dynamic>{
      'roomId': _room!.id,
      'roomName': _room!.code, // optional helper for BE
      'code': _code.text.trim(),
      'isScrap': _createRack,
      'remark': _remark.text.trim(),
      'createdBy': createdBy,
      if (isEdit) 'id': widget.initial!.id,
    };

    setState(() => _busy = true);
    try {
      final ok =
          isEdit
              ? await ref
                  .read(storeRackControllerProvider)
                  .updateRack(storeRack: dto)
              : await ref
                  .read(storeRackControllerProvider)
                  .createRack(storeRack: dto);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (isEdit ? 'Updated' : 'Created')
                : (isEdit ? 'Update failed' : 'Create failed'),
          ),
        ),
      );

      if (ok) {
        ref.invalidate(storeRackPagedStreamProvider);
        ref.invalidate(storeRoomPagedStreamProvider);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        return Scaffold(
          backgroundColor: surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: ink900),
            title: Text(
              isEdit ? 'Edit Rack' : 'Create Rack',
              style: const TextStyle(
                color: ink900,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [bgTop, bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Rack Details',
                              style: TextStyle(
                                color: ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // -------------------- EDIT VIEW (read-only + actions) --------------------
                            if (isEdit) ...[
                              Builder(
                                builder: (context) {
                                  final rackAv = ref.watch(
                                    rackDataStockDataStreamProvider(
                                      widget.initial!.id,
                                    ),
                                  );

                                  if (rackAv.value == null) {
                                    return const Center(
                                      child: Text(
                                        "rack Data is not available",
                                        style: TextStyle(
                                          color: ink900,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    );
                                  }

                                  return rackAv.when(
                                    loading:
                                        () => const LinearProgressIndicator(
                                          minHeight: 2,
                                        ),
                                    error:
                                        (e, _) => Text('rack load error: $e'),
                                    data: (rack) {
                                      if (rack == null) {
                                        return const Center(
                                          child: Text(
                                            "rack Data is not available",
                                            style: TextStyle(
                                              color: ink900,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: [
                                          ReadRow(
                                            label: 'Room Name',
                                            value: rack["roomName"],
                                            icon: Icons.text_fields_rounded,
                                          ),
                                          const SizedBox(height: 10),
                                          ReadRow(
                                            label: 'Rack Code',
                                            value: rack["code"],
                                            icon: Icons.text_fields_rounded,
                                          ),
                                          if (rack["isOccupied"]) ...[
                                            const SizedBox(height: 10),
                                            ReadRow(
                                              label: 'Item Name',
                                              value:
                                                  rack["itemName"].toString(),
                                              icon: Icons.text_fields_rounded,
                                            ),
                                            const SizedBox(height: 10),
                                            ReadRow(
                                              label: 'Rack Stock',
                                              value:
                                                  rack["stockAvailableQuantity"]
                                                      .toString(),
                                              icon: Icons.text_fields_rounded,
                                            ),
                                            const SizedBox(height: 10),
                                            (double.parse(
                                                      rack["stockAvailableQuantity"]
                                                          .toString(),
                                                    ) >
                                                    0)
                                                ? (user!.appWorks.contains(
                                                      "storeitemtransfer",
                                                    ))
                                                    ? ElevatedButton(
                                                      onPressed:
                                                          _openTransferItem,
                                                      child: const Text(
                                                        "Transfer Qty",
                                                      ),
                                                    )
                                                    : const SizedBox.shrink()
                                                : ElevatedButton(
                                                  onPressed:
                                                      () => _confirmRemoveItem(
                                                        rack["_id"],
                                                        rack["itemId"],
                                                      ),
                                                  child: const Text(
                                                    "Remove Item",
                                                  ),
                                                ),
                                          ] else ...[
                                            const SizedBox(height: 10),
                                            ElevatedButton(
                                              onPressed:
                                                  () => _confirmRemoveRack(
                                                    rack["_id"],
                                                  ),
                                              child: const Text(
                                                "Remove the Rack",
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ]
                            // -------------------- CREATE/UPDATE FORM VIEW --------------------
                            else ...[
                              Row(
                                children: [
                                  Checkbox(
                                    value: _createRack,
                                    onChanged: (value) {
                                      setState(() {
                                        _createRack = value ?? false;
                                      });
                                    },
                                  ),
                                  const Expanded(
                                    child: Text(
                                      "Create Scrap Storing Rack in this room",
                                      style: TextStyle(
                                        color: ink700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              (_createRack)
                                  ? _RoomDropdownWithCreateScrap(
                                    value: _room,
                                    initial: widget.initial,
                                    onChanged: (v) => setState(() => _room = v),
                                    onCreateTap: _openQuickRoomCreate,
                                    isScrap: _createRack,
                                  )
                                  : _RoomDropdownWithCreate(
                                    value: _room,
                                    initial: widget.initial,
                                    onChanged: (v) => setState(() => _room = v),
                                    onCreateTap: _openQuickRoomCreate,
                                    isScrap: _createRack,
                                  ),

                              const SizedBox(height: 12),

                              AppField(
                                controller: _remark,
                                labelColor: ink900,
                                label: 'Remark',
                                hint: 'Optional note',
                                icon: Icons.notes_rounded,
                                maxLines: 3,
                                validator: (v) => null,
                              ),
                              const SizedBox(height: 18),

                              PrimaryBtn(
                                label:
                                    _busy
                                        ? 'Saving...'
                                        : (isEdit
                                            ? 'Save Changes'
                                            : 'Create Rack'),
                                busy: _busy,
                                onTap: _busy ? null : _save,
                              ),
                            ],
                          ],
                        ),
                      ),
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

/* ---------- Room dropdown with "Room create" on right (GOOD rooms) ---------- */
class _RoomDropdownWithCreate extends ConsumerStatefulWidget {
  const _RoomDropdownWithCreate({
    required this.value,
    required this.onChanged,
    required this.isScrap,
    required this.onCreateTap,
    this.initial,
  });

  final StoreRack? initial;
  final StoreRoom? value;
  final bool isScrap;
  final ValueChanged<StoreRoom?> onChanged;
  final VoidCallback onCreateTap;

  @override
  ConsumerState<_RoomDropdownWithCreate> createState() =>
      __RoomDropdownWithCreateState();
}

class __RoomDropdownWithCreateState
    extends ConsumerState<_RoomDropdownWithCreate> {
  StoreRoom? _room;

  @override
  Widget build(BuildContext context) {
    final roomsAv = ref.watch(findAllRoomDataByGoodStreamProvider);

    return roomsAv.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (paged) {
        final rooms = {for (final r in paged) r.id: r}.values.toList();

        final selectedId =
            widget.value?.id ?? _room?.id ?? (widget.initial?.roomId);

        StoreRoom? byId(String? id) {
          if (id == null) return null;
          for (final r in rooms) {
            if (r.id == id) return r;
          }
          return null;
        }

        final safeValue = byId(selectedId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Room *',
              style: TextStyle(color: ink900, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: surfaceAlt.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: stroke),
              ),
              padding: const EdgeInsets.only(left: 6, right: 6),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.meeting_room_rounded, color: ink600),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StoreRoom>(
                        value: safeValue,
                        isExpanded: true,
                        style: const TextStyle(
                          color: ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        dropdownColor: surface,
                        iconEnabledColor: ink600,
                        hint: const Text(
                          'Select room',
                          style: TextStyle(
                            color: ink600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selectedItemBuilder: (context) {
                          return rooms.map((r) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                r.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ink900,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        items: [
                          for (final r in rooms)
                            DropdownMenuItem<StoreRoom>(
                              value: r,
                              child: Text(
                                r.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ink900,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _room = v);
                          widget.onChanged(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: widget.onCreateTap,
                    child: const Text(
                      'Room create',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/* ---------- Room dropdown with "Room create" on right (SCRAP rooms) ---------- */
class _RoomDropdownWithCreateScrap extends ConsumerStatefulWidget {
  const _RoomDropdownWithCreateScrap({
    required this.value,
    required this.onChanged,
    required this.isScrap,
    required this.onCreateTap,
    this.initial,
  });

  final StoreRack? initial;
  final StoreRoom? value;
  final bool isScrap;
  final ValueChanged<StoreRoom?> onChanged;
  final VoidCallback onCreateTap;

  @override
  ConsumerState<_RoomDropdownWithCreateScrap> createState() =>
      __RoomDropdownWithCreateScrapState();
}

class __RoomDropdownWithCreateScrapState
    extends ConsumerState<_RoomDropdownWithCreateScrap> {
  StoreRoom? _room;

  @override
  Widget build(BuildContext context) {
    final roomsAv = ref.watch(findAllRoomDataByScrapStreamProvider);

    return roomsAv.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (paged) {
        final rooms = {for (final r in paged) r.id: r}.values.toList();

        final selectedId =
            widget.value?.id ?? _room?.id ?? (widget.initial?.roomId);

        StoreRoom? byId(String? id) {
          if (id == null) return null;
          for (final r in rooms) {
            if (r.id == id) return r;
          }
          return null;
        }

        final safeValue = byId(selectedId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Room *',
              style: TextStyle(color: ink900, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: surfaceAlt.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: stroke),
              ),
              padding: const EdgeInsets.only(left: 6, right: 6),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.meeting_room_rounded, color: ink600),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StoreRoom>(
                        value: safeValue,
                        isExpanded: true,
                        style: const TextStyle(
                          color: ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        dropdownColor: surface,
                        iconEnabledColor: ink600,
                        hint: const Text(
                          'Select room',
                          style: TextStyle(
                            color: ink600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selectedItemBuilder: (context) {
                          return rooms.map((r) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                r.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ink900,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        items: [
                          for (final r in rooms)
                            DropdownMenuItem<StoreRoom>(
                              value: r,
                              child: Text(
                                r.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ink900,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _room = v);
                          widget.onChanged(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: widget.onCreateTap,
                    child: const Text(
                      'Room create',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/* ---------- Quick create room dialog (REST create) ---------- */
class _RoomQuickCreateDialog extends ConsumerStatefulWidget {
  const _RoomQuickCreateDialog({required this.isScrap});
  final bool isScrap;

  @override
  ConsumerState<_RoomQuickCreateDialog> createState() =>
      _RoomQuickCreateDialogState();
}

class _RoomQuickCreateDialogState
    extends ConsumerState<_RoomQuickCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _remark = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code.text = genCode(prefix: 'RM', name: '');
    _name.addListener(() {
      final n = _name.text.trim();
      if (n.isEmpty) return;
      _code.text = genCode(prefix: 'RM', name: n);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

    final dto = <String, dynamic>{
      'name': _name.text.trim(),
      'remark': _remark.text.trim(),
      'isScrap': widget.isScrap,
      'createdBy': createdBy,
    };

    setState(() => _busy = true);

    try {
      final created = await ref
          .read(storeRoomControllerProvider)
          .createRoom(storeRoom: dto);

      if (!mounted) return;

      if (created == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Create failed')));
        return;
      }

      Navigator.of(context, rootNavigator: true).pop<StoreRoom>(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed room: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Room'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              AppField(
                controller: _name,
                label: 'Name *',
                labelColor: surfaceAlt,
                hint: 'e.g., Room 1',
                icon: Icons.meeting_room_rounded,
                validator:
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              AppField(
                controller: _remark,
                label: 'Remark',
                labelColor: surfaceAlt,
                hint: 'Optional',
                icon: Icons.notes_rounded,
                maxLines: 2,
                validator: (v) => null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(_busy ? 'Creating...' : 'Create'),
        ),
      ],
    );
  }
}

/* ---------- Transfer Item Dialog ---------- */
class _TransferItemDialog extends ConsumerStatefulWidget {
  const _TransferItemDialog({required this.item, required this.rack});
  final String item;
  final StoreRack rack;

  @override
  ConsumerState<_TransferItemDialog> createState() =>
      _TransferItemDialogState();
}

class _TransferItemDialogState extends ConsumerState<_TransferItemDialog> {
  String _q = '';
  StoreRack? _toRack;
  final _qtyCtrl = TextEditingController();
  bool _busy = false;

  Map<String, dynamic> query = {};

  @override
  void initState() {
    query = {"itemId": widget.item, "rackId": widget.rack.id};
    super.initState();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  int? _parseQty() {
    final s = _qtyCtrl.text.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    final racksAv = ref.watch(
      sameItemRacksWithItemAndRackDataStreamProvider(query),
    );

    final rackstockAv = ref.watch(
      rackDataStockDataStreamProvider(widget.rack.id),
    );

    final itemAv = ref.watch(itemFindOneStreamProvider(widget.item));

    return itemAv.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Item load error: $e')),
      data: (item) {
        final int maxQty = item!.stockAvailableQuantity;

        return rackstockAv.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Rack load error: $e')),
          data: (paged) {
            final filtered = paged;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Transfer Item'),
              content: SizedBox(
                width: 560,
                height: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HintBar(
                      text:
                          'Move quantity from this rack to another rack. Quantity must be ≤ Available.',
                    ),
                    const SizedBox(height: 10),
                    InfoRow(
                      label: 'Item',
                      value: '${item.itemName} (${item.itemCode})',
                    ),
                    InfoRow(label: 'Available', value: '$maxQty'),
                    InfoRow(
                      label: 'Rack',
                      value: '${filtered!["code"]} (${filtered["name"]})',
                    ),
                    InfoRow(
                      label: 'Rack Available',
                      value: '${filtered["stockAvailableQuantity"]}',
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      onChanged: (v) => setState(() => _q = v.trim()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search destination rack...',
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: racksAv.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error:
                            (e, _) =>
                                Center(child: Text('Rack load error: $e')),
                        data: (paged) {
                          final list = paged;
                          final q = _q.trim().toLowerCase();
                          final filteredList =
                              q.isEmpty
                                  ? list
                                  : list.where((r) {
                                    final s = (r.code).toLowerCase();
                                    return s.contains(q);
                                  }).toList();

                          if (filteredList.isEmpty) {
                            return const Center(
                              child: Text('No destination racks found.'),
                            );
                          }

                          return ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder:
                                (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final r = filteredList[i];
                              final sel = _toRack?.id == r.id;
                              return ListTile(
                                onTap: () => setState(() => _toRack = r),
                                leading: Icon(
                                  sel
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: sel ? surface : ink600,
                                ),
                                title: Text(
                                  r.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(r.code),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.swap_horiz_rounded),
                        hintText:
                            'Enter quantity (max ${filtered["stockAvailableQuantity"]})',
                        helperText:
                            'Quantity must be between 1 and ${filtered["stockAvailableQuantity"]}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      _busy
                          ? null
                          : () async {
                            final qty = _parseQty();
                            if (_toRack == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Select destination rack'),
                                ),
                              );
                              return;
                            }

                            final int rackAvail = int.parse(
                              filtered["stockAvailableQuantity"].toString(),
                            );

                            if (qty == null || qty <= 0 || qty > rackAvail) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Enter valid quantity (1..$rackAvail)',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() => _busy = true);
                            try {
                              final ok = await ref
                                  .read(storeItemsControllerProvider)
                                  .transferItem(
                                    itemId: widget.item,
                                    fromRackId: widget.rack.id,
                                    toRackId: _toRack!.id,
                                    qty: qty,
                                  );

                              if (!mounted) return;

                              if (ok) {
                                Navigator.pop(context, true);
                                Navigator.pop(context, true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Transfer failed'),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                  child: Text(_busy ? 'Transferring...' : 'Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
