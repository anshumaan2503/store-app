import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../controllers/store_room_controller.dart';
import '../../../domains/models/store_room_model.dart';

import '../../widgets/code_gen.dart';
import 'widgets/racks_shared_widgets.dart';
import 'widgets/racks_theme.dart';
// import 'rack_form_page.dart';

enum RackTypeOption {
  goodsRack,
  scrapRack,
}

extension RackTypeOptionDetails on RackTypeOption {
  String get title {
    switch (this) {
      case RackTypeOption.goodsRack:
        return 'Goods Rack';
      case RackTypeOption.scrapRack:
        return 'Scrap Rack';
    }
  }

  String get description {
    switch (this) {
      case RackTypeOption.goodsRack:
        return 'For normal goods storage';
      case RackTypeOption.scrapRack:
        return 'For scrap material storage';
    }
  }

  IconData get icon {
    switch (this) {
      case RackTypeOption.goodsRack:
        return Icons.shelves;
      case RackTypeOption.scrapRack:
        return Icons.recycling_rounded;
    }
  }

  bool get isScrap {
    switch (this) {
      case RackTypeOption.goodsRack:
        return false;
      case RackTypeOption.scrapRack:
        return true;
    }
  }
}

class AddRackPage extends ConsumerStatefulWidget {
  const AddRackPage({super.key});

  @override
  ConsumerState<AddRackPage> createState() => _AddRackPageState();
}

class _AddRackPageState extends ConsumerState<AddRackPage> {
  final _formKey = GlobalKey<FormState>();

  StoreRoom? _room;
  RackTypeOption _selectedRackType = RackTypeOption.goodsRack;
  bool _giveCustomName = false;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _remark = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _remark.dispose();
    super.dispose();
  }

  void _onRackTypeChanged(RackTypeOption type) {
    if (_selectedRackType == type) return;
    setState(() {
      _selectedRackType = type;
      _room = null; // reset room when type changes
    });
  }

  Future<void> _openQuickRoomCreate() async {
    final created = await showDialog<StoreRoom>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RoomQuickCreateDialog(isScrap: _selectedRackType.isScrap),
    );

    if (created == null) return;

    // refresh rooms list
    ref.invalidate(storeRoomPagedStreamProvider);

    // auto-select new room
    setState(() => _room = created);
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

    final trimmedCustomName = _name.text.trim();
    if (_giveCustomName && trimmedCustomName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid rack name')),
      );
      return;
    }

    final createdBy = await ref
        .read(spRepositoryProvider)
        .getStringValue("uid");

    final dto = <String, dynamic>{
      'roomId': _room!.id,
      'isScrap': _selectedRackType.isScrap,
      'remark': _remark.text.trim(),
      'createdBy': createdBy,
    };
    if (_giveCustomName && trimmedCustomName.isNotEmpty) {
      dto['rackName'] = trimmedCustomName;
    }

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(storeRackControllerProvider)
          .createRack(storeRack: dto);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ok ? 'Created' : 'Create failed')));

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
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: ink900),
        title: const Text(
          'Create Rack',
          style: TextStyle(color: ink900, fontWeight: FontWeight.w900),
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

                        // Section: Rack Type
                        const Text(
                          'Rack Type',
                          style: TextStyle(
                            color: ink900,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select the type of rack to create. Available rooms will update automatically.',
                          style: TextStyle(
                            color: ink600,
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 460;
                            final goodsCard = _RackTypeCard(
                              type: RackTypeOption.goodsRack,
                              isSelected:
                                  _selectedRackType == RackTypeOption.goodsRack,
                              enabled: !_busy,
                              onTap: () =>
                                  _onRackTypeChanged(RackTypeOption.goodsRack),
                            );
                            final scrapCard = _RackTypeCard(
                              type: RackTypeOption.scrapRack,
                              isSelected:
                                  _selectedRackType == RackTypeOption.scrapRack,
                              enabled: !_busy,
                              onTap: () =>
                                  _onRackTypeChanged(RackTypeOption.scrapRack),
                            );

                            if (isWide) {
                              return Row(
                                children: [
                                  Expanded(child: goodsCard),
                                  const SizedBox(width: 12),
                                  Expanded(child: scrapCard),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  goodsCard,
                                  const SizedBox(height: 10),
                                  scrapCard,
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 18),

                        // Room Selection
                        (_selectedRackType == RackTypeOption.scrapRack)
                            ? _RoomDropdownWithCreateScrap(
                              value: _room,
                              onChanged: (v) => setState(() => _room = v),
                              onCreateTap: _openQuickRoomCreate,
                            )
                            : _RoomDropdownWithCreate(
                              value: _room,
                              onChanged: (v) => setState(() => _room = v),
                              onCreateTap: _openQuickRoomCreate,
                            ),

                        const SizedBox(height: 16),

                        // Custom Rack Name Checkbox Toggle
                        InkWell(
                          onTap: _busy
                              ? null
                              : () {
                                  setState(() {
                                    _giveCustomName = !_giveCustomName;
                                    if (!_giveCustomName) {
                                      _name.clear();
                                    }
                                  });
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _giveCustomName,
                                    activeColor: ink900,
                                    checkColor: surface,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    onChanged: _busy
                                        ? null
                                        : (val) {
                                            setState(() {
                                              _giveCustomName = val ?? false;
                                              if (!_giveCustomName) {
                                                _name.clear();
                                              }
                                            });
                                          },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "Give this rack a custom name",
                                  style: TextStyle(
                                    color: ink900,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Custom Rack Name Input Field
                        if (_giveCustomName) ...[
                          const SizedBox(height: 14),
                          AppField(
                            controller: _name,
                            labelColor: ink900,
                            label: 'Rack Name *',
                            hint: 'Enter rack name (e.g. Electrical Spare Rack)',
                            icon: Icons.label_outline_rounded,
                            enabled: !_busy,
                            validator: (v) {
                              if (_giveCustomName &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'Rack Name is required when custom name is enabled';
                              }
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 16),

                        AppField(
                          controller: _remark,
                          labelColor: ink900,
                          label: 'Remark',
                          hint: 'Optional note',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                          validator: (v) => null,
                        ),
                        const SizedBox(height: 22),

                        PrimaryBtn(
                          label: _busy ? 'Saving...' : 'Create Rack',
                          busy: _busy,
                          onTap: _busy ? null : _save,
                        ),
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
  }
}

class _RackTypeCard extends StatelessWidget {
  final RackTypeOption type;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _RackTypeCard({
    required this.type,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? accentPeach.withValues(alpha: 0.35)
                : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? ink900 : stroke,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ink900.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? ink900 : surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? ink900 : stroke,
                  ),
                ),
                child: Icon(
                  type.icon,
                  size: 22,
                  color: isSelected ? Colors.white : ink900,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: TextStyle(
                        color: ink900,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.description,
                      style: const TextStyle(
                        color: ink600,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? ink900 : stroke,
                    width: isSelected ? 6 : 2,
                  ),
                  color: isSelected ? Colors.white : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------- Room dropdown with "Room create" on right (GOOD rooms) ---------- */
class _RoomDropdownWithCreate extends ConsumerStatefulWidget {
  const _RoomDropdownWithCreate({
    required this.value,
    required this.onChanged,
    required this.onCreateTap,
  });

  final StoreRoom? value;
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
        final selectedId = widget.value?.id ?? _room?.id;

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
    required this.onCreateTap,
  });

  final StoreRoom? value;
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
        final selectedId = widget.value?.id ?? _room?.id;

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

    final createdBy = await ref
        .read(spRepositoryProvider)
        .getStringValue("uid");

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
                labelColor: ink900,
                hint: 'e.g., Room 1',
                icon: Icons.meeting_room_rounded,
                validator:
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              AppField(
                controller: _remark,
                label: 'Remark',
                labelColor: ink900,
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
