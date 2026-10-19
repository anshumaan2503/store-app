// lib/views/items/item_form_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../store_page/controllers/store_unit_name_controller.dart';
import '../../../../../store_page/domains/models/store_unit_name_model.dart';
import '../../../../controllers/grade_controller.dart';
import '../../../../controllers/item_controller.dart';
import '../../../../controllers/size_controller.dart';
import '../../../../domains/models/grade_model.dart';
import '../../../../domains/models/item_model.dart';
import '../../../../domains/models/size_model.dart';

import 'grade_form_view.dart';
import 'size_form_view.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class ItemFormView extends ConsumerStatefulWidget {
  final ItemModel? existingItem;

  const ItemFormView({super.key, this.existingItem});

  @override
  ConsumerState<ItemFormView> createState() => _ItemFormViewState();
}

class _ItemFormViewState extends ConsumerState<ItemFormView> {
  final _formKey = GlobalKey<FormState>();

  // late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _openingStockCtrl;
  // late TextEditingController _unitCtrl;

  StoreUnitName? _unitName;
  bool isLoading = false;
  String? _selectedSizeId;
  String? _selectedGradeId;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    // _codeCtrl = TextEditingController(text: item?.code ?? '');
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _openingStockCtrl = TextEditingController(
      text: (item?.openingStock ?? 0).toString(),
    );
    // _unitCtrl = TextEditingController(text: item?.unit ?? '');

    _selectedSizeId = item?.sizeId;
    _selectedGradeId = item?.gradeId;
  }

  @override
  void dispose() {
    // _codeCtrl.dispose();
    _nameCtrl.dispose();
    _openingStockCtrl.dispose();
    // _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateSize() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SizeFormView()));
    ref.invalidate(sizeAllDataStreamProvider);
  }

  Future<void> _openCreateGrade() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GradeFormView()));
    ref.invalidate(gradeAllDataStreamProvider);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  UnitNamePagedQuery get _unitNameQuery =>
      const UnitNamePagedQuery(page: 1, limit: 400, search: '', sort: 'name');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final sizesAsync = ref.read(sizeAllDataStreamProvider);
    final gradesAsync = ref.read(gradeAllDataStreamProvider);

    final sizes = sizesAsync.maybeWhen(
      data: (value) => value,
      orElse: () => <SizeModel>[],
    );
    final grades = gradesAsync.maybeWhen(
      data: (value) => value,
      orElse: () => <GradeModel>[],
    );

    SizeModel? selectedSize;
    GradeModel? selectedGrade;

    if (_selectedSizeId != null) {
      selectedSize = sizes.firstWhere(
        (s) => s.id == _selectedSizeId,
        orElse: () => SizeModel(id: _selectedSizeId, code: '', name: ''),
      );
    }
    if (_unitName == null) {
      _showError("Please Select Item Unit");
    }

    if (_selectedGradeId != null) {
      selectedGrade = grades.firstWhere(
        (g) => g.id == _selectedGradeId,
        orElse: () => GradeModel(id: _selectedGradeId, code: '', name: ''),
      );
    }

    final payload = <String, dynamic>{
      // 'code': _codeCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'sizeId': selectedSize?.id,
      'size': selectedSize?.name,
      'gradeId': selectedGrade?.id,
      'grade': selectedGrade?.name,
      'openingStock': int.tryParse(_openingStockCtrl.text) ?? 0,
      'unit': _unitName?.id,
      'unitName': _unitName?.name,
    };
    setState(() => isLoading = true);
    final existing = widget.existingItem;
    if (existing != null && existing.id != null) payload['id'] = existing.id;

    final itemNotifier = ref.read(itemControllerProvider);

    if (existing == null) {
      await itemNotifier.createItem(item: payload);
    } else {
      await itemNotifier.updateItem(item: payload);
    }

    if (!mounted) return;

    Navigator.of(context).pop();

    setState(() => isLoading = true);
  }

  InputDecoration _decor({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _ink700, fontWeight: FontWeight.w800),
      hintStyle: const TextStyle(color: _ink600, fontWeight: FontWeight.w700),
      prefixIcon: Icon(icon, color: _ink600),
      filled: true,
      fillColor: _surfaceAlt.withValues(alpha: .55),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;
    final unitNamesAv = ref.watch(unitNamePagedStreamProvider(_unitNameQuery));
    // If you expose loading from ItemNotifier, replace with ref.watch(...)

    final sizesAsync = ref.watch(sizeAllDataStreamProvider);
    final gradesAsync = ref.watch(gradeAllDataStreamProvider);

    final sizes = sizesAsync.maybeWhen(
      data: (value) => value,
      orElse: () => <SizeModel>[],
    );
    final grades = gradesAsync.maybeWhen(
      data: (value) => value,
      orElse: () => <GradeModel>[],
    );

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: Text(
          isEdit ? 'Edit Item' : 'Create Item',
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
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
                constraints: const BoxConstraints(maxWidth: 760),
                child: _Card(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isEdit ? 'Update Item Details' : 'Item Details',
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // TextFormField(
                        //   controller: _codeCtrl,
                        //   decoration: _decor(
                        //     label: 'Item Code *',
                        //     icon: Icons.confirmation_number_rounded,
                        //     hint: 'e.g., ITM-001',
                        //   ),
                        //   validator:
                        //       (v) =>
                        //           (v == null || v.trim().isEmpty)
                        //               ? 'Item code is required'
                        //               : null,
                        //   style: const TextStyle(
                        //     color: _ink900,
                        //     fontWeight: FontWeight.w800,
                        //   ),
                        // ),
                        // const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _decor(
                            label: 'Item Name *',
                            icon: Icons.inventory_2_rounded,
                            hint: 'e.g., 10mm Rod',
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Item name is required'
                                      : null,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // SIZE row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedSizeId,
                                items:
                                    sizes
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(
                                              '${s.code} - ${s.name}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (value) =>
                                        setState(() => _selectedSizeId = value),
                                dropdownColor: _surface,
                                decoration: _decor(
                                  label: 'Size',
                                  icon: Icons.straighten_rounded,
                                ),
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _MiniActionBtn(
                              icon: Icons.add_rounded,
                              tooltip: 'Add Size',
                              onTap: _openCreateSize,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // GRADE row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedGradeId,
                                items:
                                    grades
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g.id,
                                            child: Text(
                                              '${g.code} - ${g.name}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (value) => setState(
                                      () => _selectedGradeId = value,
                                    ),
                                dropdownColor: _surface,
                                decoration: _decor(
                                  label: 'Grade',
                                  icon: Icons.layers_rounded,
                                ),
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _MiniActionBtn(
                              icon: Icons.add_rounded,
                              tooltip: 'Add Grade',
                              onTap: _openCreateGrade,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row(
                        //   children: [
                        //     Expanded(
                        //       child: TextFormField(
                        //         controller: _openingStockCtrl,
                        //         keyboardType: TextInputType.number,
                        //         readOnly: true,
                        //         decoration: _decor(
                        //           label: 'Opening Stock',
                        //           icon: Icons.inventory_rounded,
                        //         ),
                        //         style: const TextStyle(
                        //           color: _ink900,
                        //           fontWeight: FontWeight.w800,
                        //         ),
                        //       ),
                        //     ),
                        //     const SizedBox(width: 12),

                        // Expanded(
                        //   child: TextFormField(
                        //     controller: _unitCtrl,
                        //     decoration: _decor(
                        //       label: 'Unit (e.g. KG, NO)',
                        //       icon: Icons.scale_rounded,
                        //     ),
                        //     style: const TextStyle(
                        //       color: _ink900,
                        //       fontWeight: FontWeight.w800,
                        //     ),
                        //   ),
                        // ),
                        unitNamesAv.when(
                          loading:
                              () => const LinearProgressIndicator(minHeight: 2),
                          error: (e, _) => Text('UnitName load error: $e'),
                          data: (paged) {
                            final list = paged.rows;
                            final safe =
                                (_unitName != null &&
                                        list.any((x) => x.id == _unitName!.id))
                                    ? list.firstWhere(
                                      (x) => x.id == _unitName!.id,
                                    )
                                    : null;

                            return _DropdownField<StoreUnitName>(
                              label: 'Unit Name',
                              hint: 'Select unit name',
                              icon: Icons.text_fields_rounded,
                              value: safe,
                              idOf: (x) => x.id,
                              items: list,
                              textOf: (x) => '${x.name}  (${x.code})',
                              onChanged: (v) => setState(() => _unitName = v),
                            );
                          },
                        ),
                        // ],
                        // ),
                        const SizedBox(height: 18),

                        _PrimaryBtn(
                          label:
                              isLoading
                                  ? (isEdit ? 'Updating...' : 'Creating...')
                                  : (isEdit ? 'Update' : 'Create'),
                          busy: isLoading,
                          onTap: isLoading ? null : _submit,
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

/* ---------------- Shared UI ---------------- */

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

class _MiniActionBtn extends StatelessWidget {
  const _MiniActionBtn({
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: Icon(icon, color: _ink900),
          ),
        ),
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                const Icon(Icons.save_rounded, size: 18, color: _surface),
              const SizedBox(width: 8),
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
    required this.idOf,
    required this.onChanged,
    this.allowNull = false,
  });

  final String label;
  final String hint;
  final IconData icon;

  final T? value;
  final List<T> items;

  final String Function(T) textOf;
  final String Function(T) idOf;
  final ValueChanged<T?> onChanged;

  final bool allowNull;

  T? _findById(List<T> list, String id) {
    for (final it in list) {
      if (idOf(it) == id) return it;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // De-duplicate items by id
    final map = <String, T>{};
    for (final it in items) {
      map[idOf(it)] = it;
    }
    final uniqueItems = map.values.toList();

    // Safe selected id
    final selectedId =
        value == null
            ? null
            : (_findById(uniqueItems, idOf(value as T)) == null
                ? null
                : idOf(value as T));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   label,
        //   style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        // ),
        // const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: selectedId,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(color: _ink600, fontWeight: FontWeight.w700),
          ),
          items: [
            if (allowNull)
              DropdownMenuItem<String?>(
                value: null,
                child: Text(hint, overflow: TextOverflow.ellipsis),
              ),
            for (final it in uniqueItems)
              DropdownMenuItem<String?>(
                value: idOf(it),
                child: Text(textOf(it), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            if (id == null) return onChanged(null);
            final obj = _findById(uniqueItems, id);
            onChanged(obj);
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: .55),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
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
