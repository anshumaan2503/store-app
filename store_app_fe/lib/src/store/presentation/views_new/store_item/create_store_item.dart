// lib/src/store/presentation/views/store_item/create_store_item.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/constants.dart';
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
 * Bag radio enum
 * ─────────────────────────────────────────────────────────── */
enum _BagChoice { yes, no }

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

  // ✅ Bag state
  late bool _isBag = widget.initial?.isBag ?? false;
  late final TextEditingController _maxQty = TextEditingController(
    text: (widget.initial?.maxQuantity ?? 0).toString(),
  );

  bool _submitting = false;

  // Image picker state
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  /// ✅ IMPORTANT (Web-safe): keep bytes for preview + upload
  Uint8List? _pickedBytes;

  String? _uploadedUrl;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _category.dispose();
    _unit.dispose();
    _imageUrlCtrl.dispose();
    _maxQty.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) {
      final bytes = await x.readAsBytes(); // ✅ works on Web + Mobile
      setState(() {
        _pickedImage = x;
        _pickedBytes = bytes;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x != null) {
      final bytes = await x.readAsBytes(); // ✅ works on Web + Mobile
      setState(() {
        _pickedImage = x;
        _pickedBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue('uid') ?? '';

    final int maxQtyParsed = int.tryParse(_maxQty.text.trim()) ?? 0;
    if (_isBag && maxQtyParsed <= 0) {
      _snack('Max quantity must be greater than 0 for bag items');
      return;
    }

    final bool isCreate = widget.initial == null;

    // ✅ prefer uploaded url if available
    final String finalImageUrl =
        (_uploadedUrl?.trim().isNotEmpty == true)
            ? _uploadedUrl!.trim()
            : _imageUrlCtrl.text.trim();

    final Map<String, dynamic> dto = {
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'category': _category.text.trim(),
      'unit': _unit.text.trim(),
      'imageUrl': finalImageUrl,

      // ✅ NEW keys
      'isBag': _isBag,
      'maxQuantity': _isBag ? maxQtyParsed : 0,
    };

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
        // ✅ Web-safe bytes (no File())
        final bytes = _pickedBytes ?? await _pickedImage!.readAsBytes();

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

            // ✅ keep controller synced so update/save uses this
            _imageUrlCtrl.text = imageUrl;

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
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
                          pickedBytes: _pickedBytes,
                          pickedImage: _pickedImage,
                          uploadedUrl: _uploadedUrl,
                          existingUrl: widget.initial?.imageUrl,
                          typedUrl: _imageUrlCtrl.text.trim(),
                          onPickGallery: _pickFromGallery,
                          onPickCamera: _pickFromCamera,
                          onClear: () {
                            setState(() {
                              _pickedImage = null;
                              _pickedBytes = null;
                            });
                          },
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

                        LayoutBuilder(
                          builder: (context, c) {
                            final isNarrow = c.maxWidth < 520;

                            final categoryField = _Field(
                              controller: _category,
                              label: 'Category',
                              hint: 'e.g., grain',
                              icon: Icons.category_rounded,
                              validator: (_) => null,
                            );

                            final unitField = _Field(
                              controller: _unit,
                              label: 'Unit',
                              hint: 'kg / pcs / box',
                              icon: Icons.straighten_rounded,
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Unit required'
                                          : null,
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  categoryField,
                                  const SizedBox(height: 14),
                                  unitField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: categoryField),
                                const SizedBox(width: 12),
                                Expanded(child: unitField),
                              ],
                            );
                          },
                        ),

                        // ✅ Bag radio
                        const SizedBox(height: 16),
                        _BagSelector(
                          value: _isBag ? _BagChoice.yes : _BagChoice.no,
                          onChanged: (v) {
                            setState(() {
                              _isBag = (v == _BagChoice.yes);
                              if (!_isBag) _maxQty.text = "0";
                              if (_isBag && _maxQty.text.trim().isEmpty) {
                                _maxQty.text = "1";
                              }
                            });
                          },
                        ),

                        // ✅ Max quantity (only if bag)
                        if (_isBag) ...[
                          const SizedBox(height: 14),
                          _Field(
                            controller: _maxQty,
                            label: 'Max Quantity (Bag)',
                            hint: 'e.g., 50',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (!_isBag) return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Max quantity required';
                              }
                              final n = int.tryParse(v.trim());
                              if (n == null || n <= 0) {
                                return 'Enter a valid max quantity';
                              }
                              return null;
                            },
                          ),
                        ],

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
 * Bag Selector
 * ─────────────────────────────────────────────────────────── */
class _BagSelector extends StatelessWidget {
  const _BagSelector({required this.value, required this.onChanged});

  final _BagChoice value;
  final ValueChanged<_BagChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Is Bag Item?",
            style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RadioCard(
                  label: "Yes (Bag)",
                  value: _BagChoice.yes,
                  groupValue: value,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RadioCard(
                  label: "No",
                  value: _BagChoice.no,
                  groupValue: value,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadioCard extends StatelessWidget {
  const _RadioCard({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final _BagChoice value;
  final _BagChoice groupValue;
  final ValueChanged<_BagChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return Material(
      color: selected ? _surfaceAlt : _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _ink900 : _stroke),
          ),
          child: Row(
            children: [
              Radio<_BagChoice>(
                value: value,
                groupValue: groupValue,
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
                activeColor: _ink900,
              ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Fields
 * ─────────────────────────────────────────────────────────── */
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final int maxLines;
  final TextInputType? keyboardType;

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
          keyboardType: keyboardType,
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
 * Image picker row (Web-safe)
 * ─────────────────────────────────────────────────────────── */
class _ImagePickRow extends StatelessWidget {
  const _ImagePickRow({
    required this.pickedBytes,
    required this.pickedImage,
    required this.uploadedUrl,
    required this.existingUrl,
    required this.typedUrl,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
  });

  final Uint8List? pickedBytes;
  final XFile? pickedImage;
  final String? uploadedUrl;
  final String? existingUrl;
  final String typedUrl;

  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget preview;

    final String urlToShow =
        (uploadedUrl?.trim().isNotEmpty == true)
            ? uploadedUrl!.trim()
            : (typedUrl.isNotEmpty ? typedUrl : ((existingUrl ?? '').trim()));

    if (pickedBytes != null) {
      // ✅ Web-safe preview
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          pickedBytes!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    } else if (urlToShow.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          urlToShow,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke),
              ),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, _, __) {
            return Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke),
              ),
              child: const Icon(
                Icons.broken_image_outlined,
                color: _ink600,
                size: 28,
              ),
            );
          },
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
              if (pickedBytes != null || pickedImage != null)
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
