// lib/views/items/item_form_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/grade_controller.dart';
import '../../../../controllers/item_controller.dart';
import '../../../../controllers/size_controller.dart';
import '../../../../domains/models/grade_model.dart';
import '../../../../domains/models/item_model.dart';
import '../../../../domains/models/size_model.dart';

// Import your Size & Grade form pages
import 'grade_form_view.dart';
import 'size_form_view.dart';

class ItemFormView extends ConsumerStatefulWidget {
  final ItemModel? existingItem;

  const ItemFormView({super.key, this.existingItem});

  @override
  ConsumerState<ItemFormView> createState() => _ItemFormViewState();
}

class _ItemFormViewState extends ConsumerState<ItemFormView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _openingStockCtrl;
  late TextEditingController _unitCtrl;

  String? _selectedSizeId;
  String? _selectedGradeId;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _codeCtrl = TextEditingController(text: item?.code ?? '');
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _openingStockCtrl = TextEditingController(
      text: (item?.openingStock ?? 0).toString(),
    );
    _unitCtrl = TextEditingController(text: item?.unit ?? '');

    _selectedSizeId = item?.sizeId;
    _selectedGradeId = item?.gradeId;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _openingStockCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateSize() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SizeFormView()));
    // refresh size list after returning
    ref.invalidate(sizeAllDataStreamProvider);
  }

  Future<void> _openCreateGrade() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GradeFormView()));
    // refresh grade list after returning
    ref.invalidate(gradeAllDataStreamProvider);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Latest sizes/grades from WS providers
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

    if (_selectedGradeId != null) {
      selectedGrade = grades.firstWhere(
        (g) => g.id == _selectedGradeId,
        orElse: () => GradeModel(id: _selectedGradeId, code: '', name: ''),
      );
    }

    final Map<String, dynamic> payload = {
      'code': _codeCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'sizeId': selectedSize?.id,
      'size': selectedSize?.name,
      'gradeId': selectedGrade?.id,
      'grade': selectedGrade?.name,
      'openingStock': int.tryParse(_openingStockCtrl.text) ?? 0,
      'unit': _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
    };

    final existing = widget.existingItem;
    if (existing != null && existing.id != null) {
      payload['id'] = existing.id;
    }

    final itemNotifier = ref.read(itemControllerProvider);

    if (existing == null) {
      await itemNotifier.createItem(item: payload);
    } else {
      await itemNotifier.updateItem(item: payload);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;

    // If you expose loading from ItemNotifier, swap this with ref.watch(...)
    const bool isLoading = false;

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
      appBar: AppBar(title: Text(isEdit ? 'Edit Item' : 'Create Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Code',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Item code is required'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Item name is required'
                            : null,
              ),
              const SizedBox(height: 12),

              // SIZE row: dropdown + plus button
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
                                  child: Text('${s.code} - ${s.name}'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() => _selectedSizeId = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Size',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Size',
                    onPressed: _openCreateSize,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // GRADE row: dropdown + plus button
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
                                  child: Text('${g.code} - ${g.name}'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() => _selectedGradeId = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Grade',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Grade',
                    onPressed: _openCreateGrade,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _openingStockCtrl,
                      keyboardType: TextInputType.number,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Opening Stock',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit (e.g. KG, NO)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: Text(isEdit ? 'Update' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
