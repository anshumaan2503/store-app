import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import 'package:store_app/src/components/motion_widgets.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../controllers/store_room_controller.dart';
import '../../../controllers/store_scrap_controller.dart';
import '../../widgets/store_ui_state_widgets.dart';

/* =================== Palette (from your colors) =================== */
// Primary neutrals
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

// Surfaces
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

// Accents
const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

// Page background blend
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

/* =================== Helpers for dynamic model shapes =================== */

String _idOf(dynamic x) {
  if (x == null) return '';
  if (x is Map) return (x['_id'] ?? x['id'] ?? '').toString();
  try {
    final v = (x.id ?? x._id ?? '');
    return v?.toString() ?? '';
  } catch (_) {
    return '';
  }
}

String _nameOf(dynamic x) {
  if (x == null) return '';
  if (x is Map) {
    return (x['name'] ?? x['itemName'] ?? x['title'] ?? x['code'] ?? '')
        .toString();
  }
  try {
    final v = (x.name ?? x.itemName ?? x.title ?? x.code ?? '');
    return v?.toString() ?? '';
  } catch (_) {
    return '';
  }
}

String _roomNameOf(dynamic x) {
  if (x == null) return '';
  if (x is Map) {
    return (x['name'] ?? x['roomName'] ?? x['code'] ?? '').toString();
  }
  try {
    final v = (x.name ?? x.roomName ?? x.code ?? '');
    return v?.toString() ?? '';
  } catch (_) {
    return '';
  }
}

String _rackNameOf(dynamic x) {
  if (x == null) return '';
  if (x is Map) {
    return (x['name'] ?? x['rackName'] ?? x['code'] ?? '').toString();
  }
  try {
    final v = (x.name ?? x.rackName ?? x.code ?? '');
    return v?.toString() ?? '';
  } catch (_) {
    return '';
  }
}

/* =================== Dropdown option model =================== */

class _DDOption {
  const _DDOption({required this.id, required this.label});
  final String id;
  final String label;
}

/* =================== Scrap Create Page =================== */

class ScrapCreatePage extends ConsumerStatefulWidget {
  const ScrapCreatePage({super.key});

  @override
  ConsumerState<ScrapCreatePage> createState() => _ScrapCreatePageState();
}

class _ScrapCreatePageState extends ConsumerState<ScrapCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();

  // ✅ NEW: Remark controller
  final _remarkCtrl = TextEditingController();

  bool _submitting = false;

  // ✅ store selected ids (stable for DropdownButtonFormField)
  String? _itemId;
  String? _roomId;
  String? _rackId;

  // Your snippet variables
  final int _limit = 20;
  final String _q = '';

  ItemPagedQuery get _itemsQuery =>
      ItemPagedQuery(page: 1, limit: _limit, search: _q, sort: '-createdAt');

  RoomQuery get _roomsQuery =>
      const RoomQuery(page: 1, limit: 300, search: '', sort: 'name');

  RackQuery get _racksQuery => RackQuery(
    page: 1,
    limit: _limit,
    search: _q,
    sort: 'createdAt',
    roomId: _roomId, // ✅ racks depend on selected roomId
  );

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _remarkCtrl.dispose(); // ✅ dispose remark controller
    super.dispose();
  }

  Future<void> _submitScrap() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if ((_itemId ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an item')));
      return;
    }
    if ((_roomId ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a room')));
      return;
    }
    if ((_rackId ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a rack')));
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid qty')));
      return;
    }

    // ✅ NEW: remark (optional)
    final remark = _remarkCtrl.text.trim();

    setState(() => _submitting = true);

    try {
      final itemId = _itemId!;
      final roomId = _roomId!;
      final rackId = _rackId!;

      await ref
          .read(storeScrapControllerProvider)
          .scrapItem(
            itemId: itemId,
            roomId: roomId,
            rackId: rackId,
            qty: qty,
            // ✅ NEW: pass remark
            remark: remark,
            createdBy:
                await ref.read(spRepositoryProvider).getStringValue("uid") ??
                "",
          );

      if (!mounted) return;
      showStoreSnackBar(context, 'Scrap recorded successfully');
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      showStoreSnackBar(context, 'Add scrap failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;

    final itemsAv = ref.watch(itemScrapPagedStreamProvider(_itemsQuery));
    final roomsAv = ref.watch(storeSrcapRoomPagedStreamProvider(_roomsQuery));
    final racksAv =
        (_roomId == null || _roomId!.isEmpty)
            ? const AsyncValue.data(null)
            : ref.watch(storeScrapRackPagedStreamProvider(_racksQuery));

    return Scaffold(
      backgroundColor: _bgBottom,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: const Padding(
          padding: EdgeInsets.only(left: 10, top: 10, bottom: 10),
          child: AppBackButton(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.delete_sweep_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Add Scrap',
              style: TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW > 720 ? 720 : maxW),
                child: _Card(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionTitle('Selection', Icons.tune_rounded),
                        const SizedBox(height: 12),

                        // ===================== ITEM DROPDOWN =====================
                        itemsAv.when(
                          loading:
                              () => const _DropDownField(
                                label: 'Item',
                                hintText: 'Loading items...',
                                icon: Icons.inventory_2_outlined,
                                options: [],
                                value: null,
                                enabled: false,
                                loading: true,
                              ),
                          error:
                              (e, _) => _DropDownField(
                                label: 'Item',
                                hintText: 'Failed to load items',
                                icon: Icons.inventory_2_outlined,
                                options: const [],
                                value: null,
                                enabled: false,
                                loading: false,
                                footerError: 'Item load error: $e',
                              ),
                          data: (paged) {
                            final list = paged.rows;
                            final options =
                                list.map<_DDOption>((it) {
                                  final id = _idOf(it);
                                  final label =
                                      (it.itemName as String?)
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? it.itemName
                                          : _nameOf(it);
                                  return _DDOption(id: id, label: label);
                                }).toList();

                            return _DropDownField(
                              label: 'Item',
                              hintText: 'Select item',
                              icon: Icons.inventory_2_outlined,
                              options: options,
                              value: _itemId,
                              enabled: true,
                              loading: false,
                              onChanged: (v) => setState(() => _itemId = v),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // ===================== ROOM DROPDOWN =====================
                        roomsAv.when(
                          loading:
                              () => const _DropDownField(
                                label: 'Room',
                                hintText: 'Loading rooms...',
                                icon: Icons.meeting_room_outlined,
                                options: [],
                                value: null,
                                enabled: false,
                                loading: true,
                              ),
                          error:
                              (e, _) => _DropDownField(
                                label: 'Room',
                                hintText: 'Failed to load rooms',
                                icon: Icons.meeting_room_outlined,
                                options: const [],
                                value: null,
                                enabled: false,
                                loading: false,
                                footerError: 'Room load error: $e',
                              ),
                          data: (paged) {
                            final list = paged.rows;
                            final options =
                                list.map<_DDOption>((r) {
                                  final id = _idOf(r);
                                  final label = r.code;
                                  return _DDOption(id: id, label: label);
                                }).toList();

                            return _DropDownField(
                              label: 'Room',
                              hintText: 'Select room',
                              icon: Icons.meeting_room_outlined,
                              options: options,
                              value: _roomId,
                              enabled: true,
                              loading: false,
                              onChanged: (v) {
                                setState(() {
                                  _roomId = v;
                                  _rackId = null;
                                });
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // ===================== RACK DROPDOWN =====================
                        (_roomId == null || _roomId!.isEmpty)
                            ? const _DropDownField(
                              label: 'Rack',
                              hintText: 'Select room first',
                              icon: Icons.view_in_ar_outlined,
                              options: [],
                              value: null,
                              enabled: false,
                              loading: false,
                            )
                            : racksAv.when(
                              loading:
                                  () => const _DropDownField(
                                    label: 'Rack',
                                    hintText: 'Loading racks...',
                                    icon: Icons.view_in_ar_outlined,
                                    options: [],
                                    value: null,
                                    enabled: false,
                                    loading: true,
                                  ),
                              error:
                                  (e, _) => _DropDownField(
                                    label: 'Rack',
                                    hintText: 'Failed to load racks',
                                    icon: Icons.view_in_ar_outlined,
                                    options: const [],
                                    value: null,
                                    enabled: false,
                                    loading: false,
                                    footerError: 'Rack load error: $e',
                                  ),
                              data: (paged) {
                                final list = paged!.rows;
                                final options =
                                    list.map<_DDOption>((rk) {
                                      final id = _idOf(rk);
                                      final label = rk.code;
                                      return _DDOption(id: id, label: label);
                                    }).toList();

                                return _DropDownField(
                                  label: 'Rack',
                                  hintText: 'Select rack',
                                  icon: Icons.view_in_ar_outlined,
                                  options: options,
                                  value: _rackId,
                                  enabled: true,
                                  loading: false,
                                  onChanged: (v) => setState(() => _rackId = v),
                                );
                              },
                            ),

                        const SizedBox(height: 14),

                        const _SectionTitle(
                          'Qty',
                          Icons.confirmation_number_outlined,
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Qty is required';
                            final n = int.tryParse(t);
                            if (n == null || n <= 0) return 'Qty must be > 0';
                            return null;
                          },
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            constraints: const BoxConstraints(minHeight: 44),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            prefixIcon: const Icon(
                              Icons.numbers_rounded,
                              color: _ink600,
                              size: 20,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            filled: true,
                            fillColor: _surface,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _stroke),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _ink900,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ✅ NEW: REMARK FIELD
                        const _SectionTitle('Remark', Icons.notes_rounded),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _remarkCtrl,
                          keyboardType: TextInputType.multiline,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 200,
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.length > 200) return 'Remark is too long';
                            return null; // optional
                          },
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Icon(
                                Icons.notes_rounded,
                                color: _ink600,
                                size: 20,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            hintText: 'Optional: add a remark...',
                            hintStyle: const TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w600,
                            ),
                            filled: true,
                            fillColor: _surface,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _stroke),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _ink900,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        FilledButton.icon(
                          onPressed: _submitting ? null : _submitScrap,
                          icon:
                              _submitting
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.add_rounded),
                          label: Text(_submitting ? 'Adding...' : 'Add Scrap'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink900,
                            foregroundColor: _surface,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
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

/* =================== Dropdown Field (NO CUT selected value) =================== */

class _DropDownField extends StatelessWidget {
  const _DropDownField({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.options,
    required this.value,
    required this.enabled,
    required this.loading,
    this.onChanged,
    this.footerError,
  });

  final String label;
  final String hintText;
  final IconData icon;

  final List<_DDOption> options;

  final String? value;
  final bool enabled;
  final bool loading;
  final ValueChanged<String?>? onChanged;
  final String? footerError;

  @override
  Widget build(BuildContext context) {
    final canUse = enabled && !loading;

    final items =
        options.map<DropdownMenuItem<String>>((o) {
          final isSel = (value != null && value!.isNotEmpty && value == o.id);
          return DropdownMenuItem<String>(
            value: o.id,
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color:
                    isSel ? _accentMint.withValues(alpha: .35) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                o.label.isNotEmpty ? o.label : o.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink900,
                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: (value != null && value!.isNotEmpty) ? value : null,
          items: items,
          onChanged: canUse ? onChanged : null,
          isExpanded: true,
          dropdownColor: _surfaceAlt,
          itemHeight: 52,
          selectedItemBuilder: (ctx) {
            return options.map((o) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  o.label.isNotEmpty ? o.label : o.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList();
          },
          decoration: InputDecoration(
            isDense: true,
            constraints: const BoxConstraints(minHeight: 44),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            prefixIcon: Icon(icon, color: _ink600, size: 20),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon:
                loading
                    ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : null,
            filled: true,
            fillColor: canUse ? _surface : _surface.withValues(alpha: .85),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _ink900, width: 1.2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _stroke.withValues(alpha: .7)),
            ),
          ),
          hint: Text(
            hintText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink600, fontWeight: FontWeight.w600),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 22,
            color: canUse ? _ink600 : _ink600.withValues(alpha: .4),
          ),
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        if (footerError != null) ...[
          const SizedBox(height: 6),
          Text(
            footerError!,
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/* =================== UI Bits =================== */

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  }) : radius = 16;

  final Widget child;
  final EdgeInsets padding;
  final double radius;

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
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon);

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _ink600),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [_accentPeach, _accentMint],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
