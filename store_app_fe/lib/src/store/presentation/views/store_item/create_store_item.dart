// lib/src/store/presentation/views/store_item/create_store_item.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/constants.dart';
import 'package:store_app/src/components/motion_widgets.dart';
import '../../../controllers/store_item_controller.dart';
import '../../../domains/models/store_item_model.dart';

/* ───────────────────────────────────────────────────────────
 * Palette (same as dashboard)
 * ─────────────────────────────────────────────────────────── */
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

/* ───────────────────────────────────────────────────────────
 * Page
 * ─────────────────────────────────────────────────────────── */
class StoreItemFormPage extends ConsumerStatefulWidget {
  const StoreItemFormPage({super.key, this.initial});
  final StoreItem? initial;

  @override
  ConsumerState<StoreItemFormPage> createState() => _StoreItemFormPageState();
}

class _StoreItemFormPageState extends ConsumerState<StoreItemFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final TextEditingController _category = TextEditingController(
    text: widget.initial?.category ?? '',
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.initial?.unit ?? '',
  );
  late final TextEditingController _imageUrlCtrl = TextEditingController(
    text: widget.initial?.imageUrl ?? '',
  );

  bool _submitting = false;

  // Image picker state
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  String? _uploadedUrl;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _category.dispose();
    _unit.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _pickedImage = x);
  }

  Future<void> _pickFromCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x != null) setState(() => _pickedImage = x);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue('uid') ?? '';

    final Map<String, dynamic> dto = {
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'category': _category.text.trim(),
      'unit': _unit.text.trim(),
      'imageUrl': _imageUrlCtrl.text.trim(), // still allow manual url
    };

    final bool isCreate = widget.initial == null;
    if (isCreate) {
      dto['createdBy'] = createdBy;
    } else {
      dto['id'] = widget.initial!.id;
    }

    setState(() => _submitting = true);

    bool ok = false;
    String? itemId;

    try {
      // 1) Save basic fields
      if (isCreate) {
        itemId = await ref
            .read(storeItemControllerProvider)
            .createStoreItem(storeItemModel: dto);
        if (itemId == null || itemId.isEmpty) {
          _snack('Create failed');
          return;
        }
        ok = true;
      } else {
        ok = await ref
            .read(storeItemControllerProvider)
            .updateStoreItem(storeItemModel: dto);
        if (!ok) {
          _snack('Update failed');
          return;
        }
        itemId = widget.initial!.id;
      }

      // 2) Upload selected image (if any)
      if (_pickedImage != null && (itemId.isNotEmpty)) {
        final bytes = await File(_pickedImage!.path).readAsBytes();

        String mime = 'image/png';
        final lower = _pickedImage!.name.toLowerCase();
        if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
          mime = 'image/jpeg';
        } else if (lower.endsWith('.webp')) {
          mime = 'image/webp';
        }
        final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

        final uri = Uri.parse(
          '${Constants.socketUrl}/api/store/$itemId/image/base64',
        );
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'base64': dataUrl}),
        );

        final Map<String, dynamic> body = jsonDecode(
          utf8.decode(res.bodyBytes),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final imageUrl =
              (body['imageUrl'] ?? body['entity']?['imageUrl'])?.toString();
          if (imageUrl != null && imageUrl.isNotEmpty) {
            setState(() => _uploadedUrl = imageUrl);
            _snack('Image uploaded');
          } else {
            _snack('Uploaded but no URL returned');
          }
        } else {
          _snack(
            'Image upload failed: ${(body['msg'] ?? body['error'] ?? '').toString()}',
          );
        }
      }

      // 3) Done
      _snack(isCreate ? 'Item created' : 'Item updated');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.only(left: 10, top: 10, bottom: 10),
          child: AppBackButton(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_rounded, color: _ink900),
            const SizedBox(width: 8),
            Text(
              isEdit ? 'Edit Store Item' : 'Create Store Item',
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _Card(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Header(),
                        const SizedBox(height: 18),

                        _ImagePickRow(
                          pickedImage: _pickedImage,
                          uploadedUrl: _uploadedUrl,
                          existingUrl: widget.initial?.imageUrl,
                          onPickGallery: _pickFromGallery,
                          onPickCamera: _pickFromCamera,
                          onClear: () => setState(() => _pickedImage = null),
                        ),
                        const SizedBox(height: 16),

                        _Field(
                          controller: _name,
                          label: 'Item Name',
                          hint: 'e.g., Rice',
                          icon: Icons.badge_rounded,
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Name required'
                                      : null,
                        ),
                        const SizedBox(height: 14),

                        _Field(
                          controller: _desc,
                          label: 'Description',
                          hint: 'Short description',
                          icon: Icons.notes_rounded,
                          validator: (_) => null,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 14),

                        // Responsive 2-up row that wraps on small widths
                        LayoutBuilder(
                          builder: (context, c) {
                            final isNarrow = c.maxWidth < 520;
                            final fields = [
                              Expanded(
                                child: _Field(
                                  controller: _category,
                                  label: 'Category',
                                  hint: 'e.g., grain',
                                  icon: Icons.category_rounded,
                                  validator: (_) => null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _Field(
                                  controller: _unit,
                                  label: 'Unit',
                                  hint: 'kg / pcs / box',
                                  icon: Icons.straighten_rounded,
                                  validator:
                                      (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Unit required'
                                              : null,
                                ),
                              ),
                            ];
                            if (isNarrow) {
                              // Stack vertically with spacing—no overflow
                              return Column(
                                children: [
                                  fields[0],
                                  const SizedBox(height: 14),
                                  fields[2],
                                ],
                              );
                            }
                            return Row(children: fields);
                          },
                        ),

                        // Optional manual URL (commented—enable if you want it in UI)
                        // const SizedBox(height: 14),
                        // _Field(
                        //   controller: _imageUrlCtrl,
                        //   label: 'Image URL (optional)',
                        //   hint: 'https://... (or use picker above)',
                        //   icon: Icons.image_outlined,
                        //   validator: (_) => null,
                        // ),
                        const SizedBox(height: 22),
                        _PrimaryBtn(
                          icon:
                              _submitting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.save_rounded,
                          label:
                              _submitting
                                  ? 'Saving...'
                                  : (isEdit ? 'Save Changes' : 'Create Item'),
                          onTap: _submitting ? null : _submit,
                          busy: _submitting,
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

/* ───────────────────────────────────────────────────────────
 * Header
 * ─────────────────────────────────────────────────────────── */
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _AvatarIcon(),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'Store Item',
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

class _AvatarIcon extends StatelessWidget {
  const _AvatarIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_accentMint, _accentPeach]),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.inventory_2_rounded, color: _ink900),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Fields & Inputs
 * ─────────────────────────────────────────────────────────── */
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
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ink600),
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 12,
            ),
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
        ),
      ],
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Image picker row
 * ─────────────────────────────────────────────────────────── */
class _ImagePickRow extends StatelessWidget {
  const _ImagePickRow({
    required this.pickedImage,
    required this.uploadedUrl,
    required this.existingUrl,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
  });

  final XFile? pickedImage;
  final String? uploadedUrl;
  final String? existingUrl;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget preview;

    if (pickedImage != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(pickedImage!.path),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    } else if ((uploadedUrl ?? '').isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          uploadedUrl!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    } else if ((existingUrl ?? '').isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          existingUrl!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    } else {
      preview = Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _stroke),
        ),
        child: const Icon(Icons.image_outlined, color: _ink600, size: 28),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        preview,
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SecondaryBtn(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: onPickGallery,
              ),
              if (!kIsWeb)
                _SecondaryBtn(
                  icon: Icons.photo_camera_outlined,
                  label: 'Camera',
                  onTap: onPickCamera,
                ),
              if (pickedImage != null)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded, color: _ink700),
                  label: const Text(
                    'Clear',
                    style: TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Buttons & Card
 * ─────────────────────────────────────────────────────────── */
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
            blurRadius: 16,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _ink900),
              const SizedBox(width: 8),
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
    );
  }
}
