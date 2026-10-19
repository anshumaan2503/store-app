// lib/src/size/views/size_form_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/size_controller.dart';
import '../../../../domains/models/size_model.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isLoading = ref.read(sizeControllerProvider);
    if (isLoading) return;

    final controller = ref.read(sizeControllerProvider.notifier);

    if (widget.existing == null) {
      await controller.createSize(
        size: {"code": _codeCtrl.text.trim(), "name": _nameCtrl.text.trim()},
      );
    } else {
      await controller.updateSize(
        size: {
          "id": widget.existing!.id,
          "code": _codeCtrl.text.trim(),
          "name": _nameCtrl.text.trim(),
        },
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(sizeControllerProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: Text(
          widget.existing == null ? "Create Size" : "Edit Size",
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
                          widget.existing == null
                              ? "Size Details"
                              : "Update Size Details",
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _codeCtrl,
                          decoration: _decor(
                            label: "Size Code *",
                            icon: Icons.confirmation_number_rounded,
                            hint: "e.g., SZ-10",
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? "Required"
                                      : null,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _decor(
                            label: "Size Name *",
                            icon: Icons.straighten_rounded,
                            hint: "e.g., 10mm",
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? "Required"
                                      : null,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 18),
                        _PrimaryBtn(
                          label:
                              isLoading
                                  ? (widget.existing == null
                                      ? "Creating..."
                                      : "Updating...")
                                  : (widget.existing == null
                                      ? "Create"
                                      : "Update"),
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
