import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/domains/models/auth_model.dart';
import '../../../../auth/domains/providers/uid_provider.dart';
import '../../../../auth/shared/providers/auth_model_provider.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_category_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../controllers/store_room_controller.dart';
import '../../../domains/models/store_items_model.dart';
import '../../../domains/models/store_rack_model.dart';
import '../../../domains/models/store_room_model.dart';

// Original app color tokens
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

bool _canDeleteItems(AuthModel? user) {
  if (user == null) return false;
  return user.isSuperAdmin ||
      user.appWorks.contains("storeadmin") ||
      user.appWorks.contains("storeitemdelete");
}

class ItemEditPage extends ConsumerStatefulWidget {
  const ItemEditPage({super.key, required this.initial});
  final StoreItemsModel initial;

  @override
  ConsumerState<ItemEditPage> createState() => _ItemEditPageState();
}

class _ItemEditPageState extends ConsumerState<ItemEditPage> {
  bool _createRoomAndRack = false;
  StoreRoom? _roomNode;
  StoreRack? _rack;

  final List<StoreItemsModel> _selectedParentItems = [];
  bool _didInitSelectedParentItems = false;
  bool _busy = false;

  late final TextEditingController _minStockCtrl;
  late final TextEditingController _maxCapacityCtrl;

  @override
  void initState() {
    super.initState();
    _minStockCtrl = TextEditingController(
      text:
          widget.initial.minStockQuantity > 0
              ? widget.initial.minStockQuantity.toString()
              : '',
    );
    _maxCapacityCtrl = TextEditingController(
      text:
          widget.initial.maxCapacity > 0
              ? widget.initial.maxCapacity.toString()
              : '',
    );
  }

  @override
  void dispose() {
    _minStockCtrl.dispose();
    _maxCapacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (_createRoomAndRack && _rack == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select Rack Name')));
      return;
    }

    String createdBy = await ref
        .read(spRepositoryProvider)
        .getStringValue("uid");
    if (createdBy.trim().isEmpty) {
      createdBy = ref.read(uidProvider);
    }
    if (createdBy.trim().isEmpty) {
      createdBy = ref.read(authModelProvider)?.uid ?? '';
    }

    final selectedItemIds =
        _selectedParentItems
            .map((e) => e.categoryId)
            .where((cid) => cid != null && cid.isNotEmpty)
            .toSet()
            .toList();

    final dto = <String, dynamic>{
      "categoryId": widget.initial.categoryId,
      if (selectedItemIds.isNotEmpty) "categoryIds": selectedItemIds,
      "rackId": _createRoomAndRack ? (_rack?.id ?? '') : '',
      "maxCapacity":
          (_maxCapacityCtrl.text.trim().isEmpty)
              ? 0
              : int.tryParse(_maxCapacityCtrl.text.trim()) ?? 0,
      "maxQuantity":
          (_maxCapacityCtrl.text.trim().isEmpty)
              ? 0
              : int.tryParse(_maxCapacityCtrl.text.trim()) ?? 0,
      "minStockQuantity":
          (_minStockCtrl.text.trim().isEmpty)
              ? 0
              : int.tryParse(_minStockCtrl.text.trim()) ?? 0,
      "createdBy": createdBy,
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(storeItemsControllerProvider)
          .updateItems(dto: dto, id: widget.initial.id);

      if (!mounted) return;

      if (ok) {
        ref.invalidate(itemPagedStreamProvider);
        ref.invalidate(storeNotOccupiecRackPagedStreamProvider);
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _stroke),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFC62828),
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Delete Item?',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to delete "${widget.initial.itemName}" (${widget.initial.itemCode})?'
              '${widget.initial.totalStockQuantity > 0 ? "\n\nWarning: This item currently has ${widget.initial.totalStockQuantity} in stock. Deleting it will remove the item and clear all rack stock records." : ""}'
              '\n\nThis action cannot be undone.',
              style: const TextStyle(color: _ink700, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: _ink700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
    );

    if (yes != true) return;

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(storeItemsControllerProvider)
          .deleteItems(widget.initial.id);

      if (!mounted) return;

      if (ok) {
        ref.invalidate(itemPagedStreamProvider);
        ref.invalidate(itemScrapPagedStreamProvider);
        ref.invalidate(storeNotOccupiecRackPagedStreamProvider);
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _autoPickFirstRackIfMachine({
    required bool isMachine,
    required StoreRoom? room,
  }) async {
    if (!isMachine) return;

    if (room == null) {
      if (mounted) setState(() => _rack = null);
      return;
    }

    try {
      final racks = await ref
          .read(storeRackControllerProvider)
          .getRacksByRoom(room.id, widget.initial.id);

      if (!mounted) return;

      setState(() {
        _rack = racks.isNotEmpty ? racks.first : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _rack = null);
    }
  }

  Future<void> _openMultiSelectDialog({
    required List<StoreItemsModel> options,
  }) async {
    final selected = await showDialog<List<StoreItemsModel>>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _MultiSelectDialog<StoreItemsModel>(
            title: 'Select Items Subcategory Remove',
            items: options,
            initiallySelected: List<StoreItemsModel>.from(_selectedParentItems),
            labelOf: (x) => x.itemName,
            subtitleOf: (x) => x.itemCode,
          ),
    );

    if (selected == null) return;
    setState(() {
      _selectedParentItems
        ..clear()
        ..addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemNamesAv = ref.watch(itemFindOneStreamProvider(widget.initial.id));
    final catsAv = ref.watch(
      storeCategoryOneStreamProvider(widget.initial.categoryId ?? ''),
    );
    final user = ref.watch(userFindOneDataStreamProvider).value ??
        ref.watch(authModelProvider);
    final canDelete = _canDeleteItems(user);

    final items = itemNamesAv.value ?? widget.initial;
    final category = catsAv.value;
    final isMachine = category?.isMachine ?? false;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Edit Item',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (canDelete)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFC62828),
                ),
                tooltip: 'Delete Item',
                onPressed: _busy ? null : _confirmDelete,
              ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 760,
                ),
                child: _Card(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    18,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      if (itemNamesAv.isLoading) ...[
                        const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Item Details',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _ReadRow(
                        label: 'Item Code',
                                        value: items.itemCode,
                                        icon: Icons.text_fields_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      _ReadRow(
                                        label: 'Item Name',
                                        value: items.itemName,
                                        icon: Icons.text_fields_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      _ReadRow(
                                        label: 'Category',
                                        value: items.categoryLabel,
                                        icon: Icons.category_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      _ReadRow(
                                        label: 'Unit',
                                        value: items.unit,
                                        icon: Icons.straighten_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      _ReadRow(
                                        label: 'Description',
                                        value: items.description,
                                        icon: Icons.notes_rounded,
                                      ),
                                      const SizedBox(height: 14),

                                        // Subcategory Multi-select
                                        Builder(
                                          builder: (context) {
                                            final av = ref.watch(
                                              parentcategoryItemAllDataStreamProvider(
                                                items.id,
                                              ),
                                            );

                                            return av.when(
                                              loading:
                                                  () =>
                                                      const LinearProgressIndicator(
                                                        minHeight: 2,
                                                      ),
                                              error:
                                                  (e, _) => Text(
                                                    'Item load error: $e',
                                                  ),
                                              data: (options) {
                                                if (!_didInitSelectedParentItems) {
                                                  _didInitSelectedParentItems =
                                                      true;
                                                  final initCatId =
                                                      widget.initial.categoryId
                                                          ?.toString();
                                                  if (initCatId != null &&
                                                      initCatId.isNotEmpty) {
                                                    final hit =
                                                        options.where((x) {
                                                          final cid =
                                                              (x.categoryId ?? '')
                                                                  .toString();
                                                          final iid =
                                                              x.id.toString();
                                                          return cid ==
                                                                  initCatId ||
                                                              iid == initCatId;
                                                        }).toList();

                                                    if (hit.isNotEmpty) {
                                                      _selectedParentItems
                                                        ..clear()
                                                        ..add(hit.first);
                                                    }
                                                  }
                                                }

                                                return _MultiSelectField<
                                                  StoreItemsModel
                                                >(
                                                  label:
                                                      'Item Subcategory Remove',
                                                  hint: 'Select items',
                                                  icon: Icons.category_rounded,
                                                  selected: _selectedParentItems,
                                                  textOf: (x) => x.itemName,
                                                  onTap:
                                                      () =>
                                                          _openMultiSelectDialog(
                                                            options: options,
                                                          ),
                                                );
                                              },
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 16),

                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Maximum Quantity (Max Capacity)',
                                              style: TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _maxCapacityCtrl,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Optional (e.g. 100) - limits manual indent creation',
                                                hintStyle: const TextStyle(
                                                  color: _ink600,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.storage_rounded,
                                                  color: _ink600,
                                                ),
                                                filled: true,
                                                fillColor: _surfaceAlt
                                                    .withValues(alpha: 0.55),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: const BorderSide(
                                                    color: _stroke,
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: const BorderSide(
                                                    color: _stroke,
                                                  ),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: const BorderSide(
                                                    color: _ink900,
                                                    width: 1.3,
                                                  ),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Minimum Stock Alert (Refill Threshold)',
                                              style: TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _minStockCtrl,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Optional (e.g. 3) - triggers auto refill',
                                                hintStyle: const TextStyle(
                                                  color: _ink600,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons
                                                      .notifications_active_outlined,
                                                  color: _ink600,
                                                ),
                                                filled: true,
                                                fillColor: _surfaceAlt
                                                    .withValues(alpha: 0.55),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: const BorderSide(
                                                    color: _stroke,
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: const BorderSide(
                                                    color: _stroke,
                                                  ),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: const BorderSide(
                                                    color: _ink900,
                                                    width: 1.3,
                                                  ),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _createRoomAndRack,
                                              onChanged: (value) {
                                                setState(() {
                                                  _createRoomAndRack =
                                                      value ?? false;
                                                  if (!_createRoomAndRack) {
                                                    _roomNode = null;
                                                    _rack = null;
                                                  }
                                                });
                                              },
                                            ),
                                            const Text(
                                              "Add Rack",
                                              style: TextStyle(
                                                color: _ink700,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),

                                        if (_createRoomAndRack) ...[
                                          const SizedBox(height: 12),
                                          Builder(
                                            builder: (context) {
                                              final roomAv =
                                                  (!isMachine)
                                                      ? (items.isScrap)
                                                          ? ref.watch(
                                                            findAllRoomDataByScrapStreamProvider,
                                                          )
                                                          : ref.watch(
                                                            findAllRoomDataByGoodStreamProvider,
                                                          )
                                                      : (items.isScrap)
                                                      ? ref.watch(
                                                        findAllMachineRoomDataByScrapStreamProvider,
                                                      )
                                                      : ref.watch(
                                                        findAllMachineRoomDataByGoodStreamProvider,
                                                      );

                                              return Column(
                                                children: [
                                                  roomAv.when(
                                                    loading:
                                                        () =>
                                                            const LinearProgressIndicator(
                                                              minHeight: 2,
                                                            ),
                                                    error:
                                                        (e, _) => Text(
                                                          'Room load error: $e',
                                                        ),
                                                    data: (paged) {
                                                      final list = paged;
                                                      return _DropdownField<
                                                        StoreRoom
                                                      >(
                                                        label: 'Room *',
                                                        hint: 'Select room',
                                                        icon:
                                                            Icons
                                                                .view_module_rounded,
                                                        value: _roomNode,
                                                        items: list,
                                                        textOf: (x) => x.code,
                                                        onChanged: (v) async {
                                                          setState(() {
                                                            _roomNode = v;
                                                            _rack = null;
                                                          });
                                                          await _autoPickFirstRackIfMachine(
                                                            isMachine:
                                                                isMachine,
                                                            room: v,
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),

                                                  if (!isMachine &&
                                                      _roomNode != null) ...[
                                                    const SizedBox(height: 12),
                                                    Builder(
                                                      builder: (context) {
                                                        final rackAv = ref.watch(
                                                          rackDataByRoomDataStreamProvider(
                                                            RackByRoomArgs(
                                                              roomId:
                                                                  _roomNode!.id,
                                                              itemId:
                                                                  widget
                                                                      .initial
                                                                      .id,
                                                            ),
                                                          ),
                                                        );

                                                        return rackAv.when(
                                                          loading:
                                                              () =>
                                                                  const LinearProgressIndicator(
                                                                    minHeight: 2,
                                                                  ),
                                                          error:
                                                              (e, _) => Text(
                                                                'Rack load error: $e',
                                                              ),
                                                          data: (racks) {
                                                            return _DropdownField<
                                                              StoreRack
                                                            >(
                                                              label: 'Rack *',
                                                              hint:
                                                                  'Select rack',
                                                              icon:
                                                                  Icons
                                                                      .category_rounded,
                                                              value: _rack,
                                                              items: racks,
                                                              textOf:
                                                                  (x) => x.code,
                                                              onChanged:
                                                                  (v) => setState(
                                                                    () =>
                                                                        _rack = v,
                                                                  ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              );
                                            },
                                          ),
                                        ],

                                        const SizedBox(height: 20),

                                        Row(
                                          children: [
                                            Expanded(
                                              child: _SecondaryBtn(
                                                icon: Icons.close_rounded,
                                                label: 'Cancel',
                                                onTap:
                                                    () =>
                                                        Navigator.pop(context),
                                              ),
                                            ),
                                            if (canDelete) ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _DangerBtn(
                                                  icon:
                                                      Icons
                                                          .delete_outline_rounded,
                                                  label: 'Delete',
                                                  busy: _busy,
                                                  onTap:
                                                      _busy
                                                          ? null
                                                          : _confirmDelete,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: canDelete ? 1 : 2,
                                              child: _PrimaryBtn(
                                                label:
                                                    _busy
                                                        ? 'Saving...'
                                                        : 'Update',
                                                busy: _busy,
                                                onTap: _busy ? null : _save,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ),
                            ),
                          ),
                        ),
                      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  const _ReadRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ink600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
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
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(
              color: _ink600,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          selectedItemBuilder: (context) {
            return [
              if (allowNull)
                Text(
                  nullLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              for (final it in items)
                Text(
                  textOf(it),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
            ];
          },
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
                child: Text(
                  textOf(it),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _ink600,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: 0.55),
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

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.onTap,
    required this.busy,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ink900,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _surface,
                    ),
                  )
                else
                  const Icon(Icons.save_rounded, size: 16, color: _surface),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: _surface,
                    fontWeight: FontWeight.w900,
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

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _stroke),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: _ink900),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: _ink900,
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

class _DangerBtn extends StatelessWidget {
  const _DangerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFEBEE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFFCDD2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFC62828),
                    ),
                  )
                else
                  Icon(icon, size: 16, color: const Color(0xFFC62828)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFC62828),
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

class _MultiSelectField<T> extends StatelessWidget {
  const _MultiSelectField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.textOf,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final List<T> selected;
  final String Function(T) textOf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasSel = selected.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: _ink600),
              filled: true,
              fillColor: _surfaceAlt.withValues(alpha: 0.55),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _stroke),
              ),
              suffixIcon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: _ink600,
              ),
            ),
            child:
                hasSel
                    ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in selected)
                          Chip(
                            label: Text(
                              textOf(s),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            backgroundColor: _surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: _stroke),
                            ),
                          ),
                      ],
                    )
                    : Text(
                      hint,
                      style: const TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        ),
      ],
    );
  }
}

class _MultiSelectDialog<T> extends StatefulWidget {
  const _MultiSelectDialog({
    required this.title,
    required this.items,
    required this.initiallySelected,
    required this.labelOf,
    this.subtitleOf,
  });

  final String title;
  final List<T> items;
  final List<T> initiallySelected;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;

  @override
  State<_MultiSelectDialog<T>> createState() => _MultiSelectDialogState<T>();
}

class _MultiSelectDialogState<T> extends State<_MultiSelectDialog<T>> {
  final Set<int> _selectedIdx = {};
  String _q = '';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.items.length; i++) {
      if (widget.initiallySelected.contains(widget.items[i])) {
        _selectedIdx.add(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _q.trim().toLowerCase();
    final indexed = <MapEntry<int, T>>[];
    for (int i = 0; i < widget.items.length; i++) {
      final it = widget.items[i];
      final l = widget.labelOf(it).toLowerCase();
      final s = (widget.subtitleOf?.call(it) ?? '').toLowerCase();
      if (query.isEmpty || l.contains(query) || s.contains(query)) {
        indexed.add(MapEntry(i, it));
      }
    }

    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _stroke),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: _ink600),
                hintText: 'Search...',
                hintStyle: const TextStyle(color: _ink600),
                filled: true,
                fillColor: _surfaceAlt.withValues(alpha: 0.55),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _stroke),
                ),
              ),
              style: const TextStyle(color: _ink900),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: indexed.length,
                itemBuilder: (_, i) {
                  final realIdx = indexed[i].key;
                  final it = indexed[i].value;
                  final isChecked = _selectedIdx.contains(realIdx);

                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedIdx.add(realIdx);
                        } else {
                          _selectedIdx.remove(realIdx);
                        }
                      });
                    },
                    title: Text(
                      widget.labelOf(it),
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle:
                        widget.subtitleOf == null
                            ? null
                            : Text(widget.subtitleOf!(it)),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel', style: TextStyle(color: _ink700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ink900,
            foregroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final out = _selectedIdx.map((i) => widget.items[i]).toList();
            Navigator.pop(context, out);
          },
          child: Text('Apply (${_selectedIdx.length})'),
        ),
      ],
    );
  }
}
