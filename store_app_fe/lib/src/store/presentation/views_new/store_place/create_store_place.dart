// lib/src/store/presentation/views/store_place/create_store_place.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_place_controller.dart';
import '../../../domains/models/store_place_model.dart';

/* ---------------- Palette (same as dashboard) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

/* ---------------- Main Page ---------------- */

class StorePlaceFormPage extends ConsumerStatefulWidget {
  const StorePlaceFormPage({super.key, this.initial});
  final StorePlace? initial;

  @override
  ConsumerState<StorePlaceFormPage> createState() => _StorePlaceFormPageState();
}

class _StorePlaceFormPageState extends ConsumerState<StorePlaceFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.initial?.code ?? '',
  );
  late final TextEditingController _type = TextEditingController(
    text: widget.initial?.type ?? '',
  );
  late final TextEditingController _remark = TextEditingController(
    text: widget.initial?.remark ?? '',
  );

  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _type.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
    final isCreate = widget.initial == null;

    final dto = {
      'name': _name.text.trim(),
      'code': _code.text.trim(),
      'type': _type.text.trim(),
      'remark': _remark.text.trim(),
      if (isCreate) 'createdBy': createdBy else 'id': widget.initial!.id,
    };

    setState(() => _submitting = true);
    bool ok = false;

    try {
      ok =
          isCreate
              ? await ref
                  .read(storePlaceControllerProvider)
                  .createStorePlace(storePlaceModel: dto)
              : await ref
                  .read(storePlaceControllerProvider)
                  .updateStorePlace(storePlaceModel: dto);
    } catch (_) {
      ok = false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? (isCreate ? 'Created' : 'Updated') : 'Save failed'),
      ),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

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
          children: [
            const Icon(Icons.maps_home_work_rounded, color: _ink900),
            const SizedBox(width: 8),
            Text(
              isEdit ? 'Edit Store Place' : 'Create Store Place',
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        centerTitle: true,
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
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _Card(
                  radius: 20,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Header(),
                        const SizedBox(height: 20),

                        _Field(
                          controller: _name,
                          label: 'Place Name *',
                          hint: 'e.g., Main Warehouse',
                          icon: Icons.badge_rounded,
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                        ),
                        const SizedBox(height: 16),

                        _TwoUp(
                          left: _Field(
                            controller: _code,
                            label: 'Code',
                            hint: 'e.g., WH-01',
                            icon: Icons.qr_code_2_rounded,
                            validator: (_) => null,
                          ),
                          right: _Field(
                            controller: _type,
                            label: 'Type',
                            hint: 'Warehouse / Shelf / Store',
                            icon: Icons.category_rounded,
                            validator: (_) => null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _Field(
                          controller: _remark,
                          label: 'Remark',
                          hint: 'Optional note or comment',
                          icon: Icons.notes_rounded,
                          validator: (_) => null,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 26),

                        _PrimaryBtn(
                          icon:
                              _submitting
                                  ? Icons.hourglass_empty_rounded
                                  : Icons.save_rounded,
                          label:
                              _submitting
                                  ? 'Saving...'
                                  : (isEdit ? 'Save Changes' : 'Create Place'),
                          busy: _submitting,
                          onTap: _submitting ? null : _submit,
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

/* ---------------- Supporting Widgets ---------------- */

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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _accentMint),
          child: const Icon(Icons.maps_home_work_rounded, color: _ink900),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Store Place',
            style: TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final int maxLines;

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
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ink600),
            prefixIcon: Icon(icon, color: _ink600),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TwoUp extends StatelessWidget {
  const _TwoUp({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 560;
        if (isNarrow) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
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
    );
  }
}
