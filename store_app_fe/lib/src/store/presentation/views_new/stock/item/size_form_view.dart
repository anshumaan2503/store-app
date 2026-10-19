// lib/src/size/views/size_form_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/size_controller.dart';
import '../../../../domains/models/size_model.dart';

class SizeFormView extends ConsumerStatefulWidget {
  final SizeModel? existing;

  const SizeFormView({super.key, this.existing});

  @override
  ConsumerState<SizeFormView> createState() => _SizeFormViewState();
}

class _SizeFormViewState extends ConsumerState<SizeFormView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.existing?.code ?? "");
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? "");
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isLoading = ref.read(sizeControllerProvider);
    if (isLoading) return;

    final controller = ref.read(sizeControllerProvider.notifier);

    if (widget.existing == null) {
      await controller.createSize(size: {
        "code": _codeCtrl.text.trim(),
        "name": _nameCtrl.text.trim(),
      });
    } else {
      await controller.updateSize(size: {
        "id": widget.existing!.id,
        "code": _codeCtrl.text.trim(),
        "name": _nameCtrl.text.trim(),
      });
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(sizeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? "Create Size" : "Edit Size"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: "Size Code",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Size Name",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: Text(widget.existing == null ? "Create" : "Update"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
