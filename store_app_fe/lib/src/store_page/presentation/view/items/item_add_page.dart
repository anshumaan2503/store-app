// item_create_page.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../auth/domains/providers/uid_provider.dart';
import '../../../../auth/shared/providers/auth_model_provider.dart';
import '../../../../auth/shared/providers/token_provider.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/constants.dart';
import '../../../controllers/store_category_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../controllers/store_room_controller.dart';
import '../../../controllers/store_unit_name_controller.dart';
import '../../../domains/models/store_category_model.dart';
import '../../../domains/models/store_rack_model.dart';
import '../../../domains/models/store_room_model.dart';
import '../../../domains/models/store_unit_name_model.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

bool _isTopLevel(StoreCategory c) => (c.parentId?.isEmpty ?? true);

/// Your rule: only allow item subcategories with isNormalItem == true
List<StoreCategory> _onlyNormalItems(List<StoreCategory> list) =>
    list.where((c) => c.isNormalItem).toList();

class ItemCreatePage extends ConsumerStatefulWidget {
  const ItemCreatePage({super.key});

  @override
  ConsumerState<ItemCreatePage> createState() => _ItemCreatePageState();
}

class _ItemCreatePageState extends ConsumerState<ItemCreatePage> {
  final _formKey = GlobalKey<FormState>();

  StoreUnitName? _unitName;
  StoreRoom? _roomNode;
  StoreRack? _rack;
  StoreRoom? _scrapRoomNode;
  bool _storageLocationExpanded = false;

  final bool _createRoomAndRack = true;

  final _desc = TextEditingController();
  final _maxCapacity = TextEditingController();
  final _minStock = TextEditingController();
  String? _uploadedUrl;
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  bool _busy = false;

  StoreRack? _scrapRack;
  late final TextEditingController _imageUrlCtrl = TextEditingController();

  StoreCategory? _parent;
  StoreCategory? _sublevel1CategoryNode;
  StoreCategory? _sublevel2CategoryNode;
  StoreCategory? _sublevel3CategoryNode;

  final _namelevel1 = TextEditingController();
  final _namelevel2 = TextEditingController();
  final _namelevel3 = TextEditingController();

  List<StoreCategory> _itemSubcategories = [];

  // Optional name logic retained (you can remove if not needed)
  StoreCategory? _itemNameFromSubcategory;
  final TextEditingController _customItemNameCtrl = TextEditingController();

  void _clearAllNameFields() {
    _namelevel1.clear();
    _namelevel2.clear();
    _namelevel3.clear();
  }

  bool _level1SubCategory = false;
  bool _level2SubCategory = false;
  bool _level3SubCategory = false;

  void _resetItemSubcategoryAndItemName() {
    _itemSubcategories = [];
    _itemNameFromSubcategory = null;
    _customItemNameCtrl.clear();
  }

  void _resetAllSubLevels() {
    _level1SubCategory = false;
    _level2SubCategory = false;
    _level3SubCategory = false;

    _sublevel1CategoryNode = null;
    _sublevel2CategoryNode = null;
    _sublevel3CategoryNode = null;

    _clearAllNameFields();
    _resetItemSubcategoryAndItemName();

    // also clear dependent selections (prevents old state leaking)
    _roomNode = null;
    _rack = null;
    _scrapRoomNode = null;
    _scrapRack = null;
    _unitName = null;
    _desc.clear();
    _maxCapacity.clear();
    _minStock.clear();
  }

  void _resetLevel2AndBelow() {
    _level2SubCategory = false;
    _level3SubCategory = false;

    _sublevel2CategoryNode = null;
    _sublevel3CategoryNode = null;

    _namelevel2.clear();
    _namelevel3.clear();

    _resetItemSubcategoryAndItemName();

    _roomNode = null;
    _rack = null;
    _scrapRoomNode = null;
    _scrapRack = null;
    _unitName = null;
    _desc.clear();
    _maxCapacity.clear();
    _minStock.clear();
  }

  void _resetLevel3() {
    _level3SubCategory = false;
    _sublevel3CategoryNode = null;
    _namelevel3.clear();

    _resetItemSubcategoryAndItemName();

    _roomNode = null;
    _rack = null;
    _scrapRoomNode = null;
    _scrapRack = null;
    _unitName = null;
    _desc.clear();
  }

  String? _computeItemNameOrNull() {
    if (_parent == null) return null;
    if (!_level1SubCategory) return null;

    if (_sublevel1CategoryNode == null) {
      final t = _namelevel1.text.trim();
      return t.isEmpty ? null : t;
    }

    if (!_level2SubCategory) {
      final t = _sublevel1CategoryNode!.name.trim();
      return t.isEmpty ? null : t;
    }

    if (_sublevel2CategoryNode == null) {
      final t = _namelevel2.text.trim();
      return t.isEmpty ? null : t;
    }

    if (!_level3SubCategory) {
      final t = _sublevel2CategoryNode!.name.trim();
      return t.isEmpty ? null : t;
    }

    if (_sublevel3CategoryNode == null) {
      final t = _namelevel3.text.trim();
      return t.isEmpty ? null : t;
    }

    final t = _sublevel3CategoryNode!.name.trim();
    return t.isEmpty ? null : t;
  }

  /// Final name can be null.
  /// - If item subcategories selected: name is optional (custom overrides)
  /// - Else: fallback to old compute logic
  String? _computeFinalItemNameOrNull() {
    final itemSubcategoryIds = _itemSubcategories.map((e) => e.id).toList();
    if (itemSubcategoryIds.isNotEmpty) {
      final t = _customItemNameCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    return _computeItemNameOrNull();
  }

  StoreCategory? _computeCategoryIdOrNull() {
    if (_parent == null) return null;

    if (!_level1SubCategory) return _parent;
    if (_sublevel1CategoryNode == null) return _parent;

    if (!_level2SubCategory) return _sublevel1CategoryNode;
    if (_sublevel2CategoryNode == null) return _sublevel1CategoryNode;

    if (!_level3SubCategory) return _sublevel2CategoryNode;
    if (_sublevel3CategoryNode == null) return _sublevel2CategoryNode;

    return _sublevel3CategoryNode;
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
      // NOTE: Ideally pick from "good racks" (same as dropdown).
      // If you have a controller method for good racks, use that here.
      final racks = await ref
          .read(storeRackControllerProvider)
          .getRacksByRoom(room.id, "");
      if (!mounted) return;

      setState(() {
        _rack = racks.isNotEmpty ? racks.first : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _rack = null);
    }
  }

  Future<void> _autoPickFirstScrapRackIfMachine({
    required bool isMachine,
    required StoreRoom? room,
  }) async {
    if (!isMachine) return;

    if (room == null) {
      if (mounted) setState(() => _scrapRack = null);
      return;
    }

    try {
      final racks = await ref
          .read(storeRackControllerProvider)
          .getRacksByRoom(room.id, "");
      if (!mounted) return;

      final filteredRacks =
          racks.where((r) => r.id != _rack?.id).toList();

      setState(() {
        _scrapRack = filteredRacks.isNotEmpty
            ? filteredRacks.first
            : (racks.isNotEmpty ? racks.first : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _scrapRack = null);
    }
  }

  UnitNamePagedQuery get _unitNameQuery =>
      const UnitNamePagedQuery(page: 1, limit: 400, search: '', sort: 'name');

  @override
  void dispose() {
    _desc.dispose();
    _imageUrlCtrl.dispose();
    _maxCapacity.dispose();
    _minStock.dispose();
    _namelevel1.dispose();
    _namelevel2.dispose();
    _namelevel3.dispose();

    _customItemNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickItemSubcategories(List<StoreCategory> options) async {
    final selected = await showDialog<List<StoreCategory>>(
      context: context,
      builder:
          (_) => _CategoryMultiSelectDialog(
            title: "Select Item subcategory",
            items: options,
            initiallySelected: _itemSubcategories,
          ),
    );

    if (selected != null) {
      setState(() {
        _itemSubcategories = selected;

        // keep dropdown in sync if you later enable it
        if (_itemSubcategories.isEmpty) {
          _itemNameFromSubcategory = null;
          _customItemNameCtrl.clear();
        } else {
          final stillValid =
              _itemNameFromSubcategory != null &&
              _itemSubcategories.any(
                (x) => x.id == _itemNameFromSubcategory!.id,
              );
          if (!stillValid) {
            _itemNameFromSubcategory = _itemSubcategories.first;
          }
        }

        // IMPORTANT: when subcats selected, clear rack/unit/desc so stale values never get sent
        if (_itemSubcategories.isNotEmpty) {
          _roomNode = null;
          _rack = null;
          _scrapRack = null;
          _unitName = null;
          _desc.clear();
        }
      });
    }
  }

  Future<void> _openQuickUnitNameCreate() async {
    final created = await showDialog<StoreUnitName>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UnitNameQuickCreateDialog(),
    );
    if (created == null) return;
    ref.invalidate(unitNamePagedStreamProvider);
    setState(() => _unitName = created);
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) {
      final bytes = await x.readAsBytes();
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
      final bytes = await x.readAsBytes();
      setState(() {
        _pickedImage = x;
        _pickedBytes = bytes;
      });
    }
  }


  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final itemName = _computeFinalItemNameOrNull();
    final categoryNode = _computeCategoryIdOrNull();
    if (categoryNode == null) {
      _showError("Please select a category.");
      return;
    }

    final itemSubcategoryIds = _itemSubcategories.map((e) => e.id).toList();
    final hasSubcats = itemSubcategoryIds.isNotEmpty;

    // When NO subcats: need racks and unit if createRoomAndRack
    if (_createRoomAndRack && !hasSubcats) {
      if (_rack == null) {
        setState(() => _storageLocationExpanded = true);
        _showError('Select Rack');
        return;
      }
      if (_scrapRack == null) {
        setState(() => _storageLocationExpanded = true);
        _showError('Select Scrap Rack');
        return;
      }
    }

    if (!hasSubcats && _unitName == null) {
      _showError('Select Unit');
      return;
    }

    final String finalImageUrl =
        (_uploadedUrl?.trim().isNotEmpty == true)
            ? _uploadedUrl!.trim()
            : _imageUrlCtrl.text.trim();

    String createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid");
    if (createdBy.trim().isEmpty) {
      createdBy = ref.read(uidProvider);
    }
    if (createdBy.trim().isEmpty) {
      createdBy = ref.read(authModelProvider)?.uid ?? '';
    }

    // RULE:
    // - If no item subcategories => itemName must exist (else nothing to identify)
    // - If subcategories => itemName is optional
    if (!hasSubcats && (itemName == null || itemName.trim().isEmpty)) {
      _showError("Please enter Item Name or select Item subcategory.");
      return;
    }
    if (categoryNode.isbag && _maxCapacity.text.trim().isEmpty) {
      _showError("Please enter Bag Capacity");
      return;
    }

    // IMPORTANT: prevent stale rack/unit/desc leaking when subcategories exist
    final dto = <String, dynamic>{
      "rackId": (!_createRoomAndRack || hasSubcats) ? null : _rack?.id,
      "scrapRackId":
          (!_createRoomAndRack || hasSubcats) ? null : _scrapRack?.id,
      "categoryId": categoryNode.id,
      "subCategoryIds": hasSubcats ? itemSubcategoryIds : null,
      "itemName":
          (itemName == null || itemName.trim().isEmpty) ? null : itemName,
      "unit": hasSubcats ? null : _unitName?.id,
      "maxCapacity":
          (_maxCapacity.text.trim().isEmpty)
              ? 0
              : int.tryParse(_maxCapacity.text.trim()) ?? 0,
      "maxQuantity":
          (_maxCapacity.text.trim().isEmpty)
              ? 0
              : int.tryParse(_maxCapacity.text.trim()) ?? 0,
      "minStockQuantity":
          (_minStock.text.trim().isEmpty)
              ? 0
              : int.tryParse(_minStock.text.trim()) ?? 0,
      "description":
          hasSubcats
              ? null
              : (_desc.text.trim().isEmpty ? null : _desc.text.trim()),
      "imageUrl": finalImageUrl.isEmpty ? null : finalImageUrl,
      "createdBy": createdBy.trim().isEmpty ? null : createdBy.trim(),
    };

    setState(() => _busy = true);
    try {
      final itemId = await ref
          .read(storeItemsControllerProvider)
          .createItems(dto: dto);

      if (!mounted) return;

      if (itemId == null || itemId.isEmpty) {
        // createItems already showed the failure message from backend
        return;
      }

      // Upload selected image (if any)
      if (_pickedImage != null) {
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
          '${Constants.socketUrl}/api/store/storeitems/$itemId/image/base64',
        );

        String token = ref.read(authTokenProvider);
        if (token.isEmpty) {
          token =
              await ref.read(spRepositoryProvider).getStringValue('authToken');
        }

        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
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

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Created')));

      ref.invalidate(itemPagedStreamProvider);
      ref.invalidate(storeNotOccupiecRackPagedStreamProvider);
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitNamesAv = ref.watch(unitNamePagedStreamProvider(_unitNameQuery));
    final catsAv = ref.watch(parentcategoryAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Create Item',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
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
                        const Text(
                          'Item Details',
                          style: TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _ImagePickRow(
                          pickedBytes: _pickedBytes,
                          pickedImage: _pickedImage,
                          uploadedUrl: _uploadedUrl,
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

                        const SizedBox(height: 12),

                        // Category Dropdown
                        catsAv.when(
                          loading:
                              () => const LinearProgressIndicator(minHeight: 2),
                          error: (e, _) => Text('Category load error: $e'),
                          data: (paged) {
                            final map = <String, StoreCategory>{};
                            for (final c in paged) {
                              map[c.id] = c;
                            }
                            final list = map.values.toList();

                            final StoreCategory? safeValue =
                                (_parent != null &&
                                        list.any((x) => x.id == _parent!.id))
                                    ? list.firstWhere(
                                      (x) => x.id == _parent!.id,
                                    )
                                    : null;

                            return _DropdownField<StoreCategory>(
                              label: 'Category *',
                              hint: 'Select category',
                              icon: Icons.category_rounded,
                              value: safeValue,
                              items: list,
                              textOf: (x) => x.name,
                              onChanged: (v) {
                                setState(() {
                                  _parent = v;
                                  _resetAllSubLevels();
                                });
                              },
                              idOf: (x) => x.id,
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // Checkbox for Subcategory
                        if (_parent != null) ...[
                          const SizedBox(height: 8),
                          Material(
                            color: _level1SubCategory
                                ? _surfaceAlt.withValues(alpha: 0.5)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _level1SubCategory
                                    ? _ink900.withValues(alpha: 0.25)
                                    : _stroke,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _level1SubCategory = !_level1SubCategory;
                                  if (!_level1SubCategory) {
                                    _resetAllSubLevels();
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: Checkbox(
                                        value: _level1SubCategory,
                                        activeColor: _ink900,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            _level1SubCategory = value ?? false;
                                            if (!_level1SubCategory) {
                                              _resetAllSubLevels();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Select Subcategory For (${_parent!.name})",
                                        style: TextStyle(
                                          color: _ink900,
                                          fontWeight: _level1SubCategory
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (_level1SubCategory) ...[
                            if (_parent!.isMachine) ...[
                              Builder(
                                builder: (context) {
                                  final subcatslevel1Av = ref.watch(
                                    levelOnecategoryByIdperentDataStreamProvider(
                                      _parent!.id,
                                    ),
                                  );

                                  return subcatslevel1Av.when(
                                    loading:
                                        () => const LinearProgressIndicator(
                                          minHeight: 2,
                                        ),
                                    error:
                                        (e, _) =>
                                            Text('Subcategory load error: $e'),
                                    data: (subcategorieslevel1) {
                                      return _DropdownField<StoreCategory>(
                                        label:
                                            'Subcategory Of (${_parent!.name}) *',
                                        hint: 'Select subcategory',
                                        icon: Icons.category_rounded,
                                        value: _sublevel1CategoryNode,
                                        items: subcategorieslevel1,
                                        idOf: (x) => x.id,
                                        textOf: (x) => x.name,
                                        onChanged: (v) {
                                          setState(() {
                                            _sublevel1CategoryNode = v;
                                            _resetLevel2AndBelow();
                                          });
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ],

                            if (_sublevel1CategoryNode != null &&
                                _parent!.isMachine) ...[
                              const SizedBox(height: 8),

                              // if (_sublevel1CategoryNode!.isMachine) ...[
                              //   Row(
                              //     children: [
                              //       Checkbox(
                              //         value: _level2SubCategory,
                              //         onChanged: (value) {
                              //           setState(() {
                              //             _level2SubCategory = value ?? false;
                              //             if (!_level2SubCategory) {
                              //               _resetLevel2AndBelow();
                              //             }
                              //           });
                              //         },
                              //       ),
                              //       Text(
                              //         "Select Subcategory For (${_sublevel1CategoryNode!.name})",
                              //         style: TextStyle(
                              //           color: _ink700,
                              //           fontWeight: FontWeight.w600,
                              //         ),
                              //       ),
                              //     ],
                              //   ),
                              // ],
                              if (_level2SubCategory) ...[
                                Builder(
                                  builder: (context) {
                                    final subcatslevel2Av = ref.watch(
                                      levelTwocategoryByIdperentDataStreamProvider(
                                        _sublevel1CategoryNode!.id,
                                      ),
                                    );

                                    return subcatslevel2Av.when(
                                      loading:
                                          () => const LinearProgressIndicator(
                                            minHeight: 2,
                                          ),
                                      error:
                                          (e, _) => Text(
                                            'Subcategory load error: $e',
                                          ),
                                      data: (subcategorieslevel2) {
                                        return _DropdownField<StoreCategory>(
                                          label:
                                              'Subcategory Of (${_sublevel1CategoryNode!.name}) *',
                                          hint: 'Select Subcategory',
                                          icon: Icons.category_rounded,
                                          value: _sublevel2CategoryNode,
                                          items: subcategorieslevel2,
                                          idOf: (x) => x.id,
                                          textOf: (x) => x.name,
                                          onChanged: (v) {
                                            setState(() {
                                              _sublevel2CategoryNode = v;
                                              _resetLevel3();
                                            });
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),

                                if (_sublevel2CategoryNode != null &&
                                    _sublevel1CategoryNode!.isMachine) ...[
                                  const SizedBox(height: 8),

                                  if (_sublevel2CategoryNode!.isMachine) ...[
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _level3SubCategory,
                                          onChanged: (value) {
                                            setState(() {
                                              _level3SubCategory =
                                                  value ?? false;
                                              if (!_level3SubCategory) {
                                                _resetLevel3();
                                              }
                                            });
                                          },
                                        ),
                                        Text(
                                          "Select Subcategory For (${_sublevel2CategoryNode!.name})",
                                          style: TextStyle(
                                            color: _ink700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  if (_level3SubCategory) ...[
                                    if (_sublevel2CategoryNode!.isMachine) ...[
                                      Builder(
                                        builder: (context) {
                                          final subcatslevel3Av = ref.watch(
                                            levelThreecategoryByIdperentDataStreamProvider(
                                              _sublevel2CategoryNode!.id,
                                            ),
                                          );

                                          return subcatslevel3Av.when(
                                            loading:
                                                () =>
                                                    const LinearProgressIndicator(
                                                      minHeight: 2,
                                                    ),
                                            error:
                                                (e, _) => Text(
                                                  'Subcategory load error: $e',
                                                ),
                                            data: (subcategorieslevel3) {
                                              return _DropdownField<
                                                StoreCategory
                                              >(
                                                label:
                                                    'Subcategory Of (${_sublevel2CategoryNode!.name}) *',
                                                hint: 'Select Subcategory',
                                                icon: Icons.category_rounded,
                                                value: _sublevel3CategoryNode,
                                                items: subcategorieslevel3,
                                                idOf: (x) => x.id,
                                                textOf: (x) => x.name,
                                                onChanged: (v) {
                                                  setState(() {
                                                    _sublevel3CategoryNode = v;
                                                  });
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],

                                    // When level-3 not selected: show item-subcategory multi select (NORMAL ITEMS only)
                                    if (_sublevel3CategoryNode == null &&
                                        _sublevel2CategoryNode!.isMachine) ...[
                                      const SizedBox(height: 10),
                                      Builder(
                                        builder: (context) {
                                          final subcatsAvwithGI = ref.watch(
                                            itemCategoryByIdperentDataStreamProvider(
                                              _sublevel2CategoryNode!.id,
                                            ),
                                          );

                                          return subcatsAvwithGI.when(
                                            loading:
                                                () =>
                                                    const LinearProgressIndicator(
                                                      minHeight: 2,
                                                    ),
                                            error:
                                                (e, _) => Text(
                                                  'Subcategory load error: $e',
                                                ),
                                            data: (subcategorieslevel3) {
                                              final options = _onlyNormalItems(
                                                subcategorieslevel3,
                                              );

                                              return FormField<
                                                List<StoreCategory>
                                              >(
                                                initialValue:
                                                    _itemSubcategories,
                                                builder: (state) {
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Item Subcategory For (${_sublevel2CategoryNode!.name})",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: _ink700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      InkWell(
                                                        onTap: () async {
                                                          await _pickItemSubcategories(
                                                            options,
                                                          );
                                                          state.didChange(
                                                            _itemSubcategories,
                                                          );
                                                        },
                                                        child: InputDecorator(
                                                          decoration: InputDecoration(
                                                            prefixIcon: const Icon(
                                                              Icons
                                                                  .category_rounded,
                                                            ),
                                                            border: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            errorText:
                                                                state.errorText,
                                                            hintText:
                                                                "Select Item Subcategory For (${_sublevel2CategoryNode!.name})",
                                                            hintStyle:
                                                                TextStyle(
                                                                  color:
                                                                      _ink700,
                                                                ),
                                                            contentPadding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 12,
                                                                ),
                                                          ),
                                                          child:
                                                              _itemSubcategories
                                                                      .isEmpty
                                                                  ? Text(
                                                                    "Select Item Subcategory For (${_sublevel2CategoryNode!.name})",
                                                                    style: TextStyle(
                                                                      color:
                                                                          _ink700,
                                                                    ),
                                                                  )
                                                                  : Wrap(
                                                                    spacing: 8,
                                                                    runSpacing:
                                                                        8,
                                                                    children:
                                                                        _itemSubcategories.map((
                                                                          c,
                                                                        ) {
                                                                          return Chip(
                                                                            label: Text(
                                                                              c.name,
                                                                            ),
                                                                            onDeleted: () {
                                                                              setState(
                                                                                () {
                                                                                  _itemSubcategories.removeWhere(
                                                                                    (
                                                                                      x,
                                                                                    ) =>
                                                                                        x.id ==
                                                                                        c.id,
                                                                                  );
                                                                                  if (_itemSubcategories.isEmpty) {
                                                                                    _customItemNameCtrl.clear();
                                                                                  }
                                                                                },
                                                                              );
                                                                              state.didChange(
                                                                                _itemSubcategories,
                                                                              );
                                                                            },
                                                                          );
                                                                        }).toList(),
                                                                  ),
                                                        ),
                                                      ),
                                                      if (_itemSubcategories
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        _Field(
                                                          controller:
                                                              _customItemNameCtrl,
                                                          label:
                                                              'Item Name (optional) For (${_sublevel2CategoryNode!.name})',
                                                          hint: 'Optional',
                                                          icon:
                                                              Icons
                                                                  .edit_rounded,
                                                          labelColor: _ink900,
                                                          validator:
                                                              (_) => null,
                                                        ),
                                                      ],
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ],
                              ] else ...[
                                // Level-2 not selected: show item-subcategory multi select (NORMAL ITEMS only)
                                const SizedBox(height: 10),
                                Builder(
                                  builder: (context) {
                                    final subcatsAvwithGI = ref.watch(
                                      itemCategoryByIdperentDataStreamProvider(
                                        _sublevel1CategoryNode!.id,
                                      ),
                                    );

                                    return subcatsAvwithGI.when(
                                      loading:
                                          () => const LinearProgressIndicator(
                                            minHeight: 2,
                                          ),
                                      error:
                                          (e, _) => Text(
                                            'Subcategory load error: $e',
                                          ),
                                      data: (subcategorieslevel3) {
                                        final options = _onlyNormalItems(
                                          subcategorieslevel3,
                                        );

                                        return FormField<List<StoreCategory>>(
                                          initialValue: _itemSubcategories,
                                          builder: (state) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Item Subcategory Add In (${_sublevel1CategoryNode!.name})",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: _ink700,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                InkWell(
                                                  onTap: () async {
                                                    await _pickItemSubcategories(
                                                      options,
                                                    );
                                                    state.didChange(
                                                      _itemSubcategories,
                                                    );
                                                  },
                                                  child: InputDecorator(
                                                    decoration: InputDecoration(
                                                      prefixIcon: const Icon(
                                                        Icons.category_rounded,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      errorText:
                                                          state.errorText,
                                                      hintText:
                                                          "Select Item Subcategory For (${_sublevel1CategoryNode!.name})",
                                                      hintStyle: TextStyle(
                                                        color: _ink700,
                                                      ),
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 12,
                                                          ),
                                                    ),
                                                    child:
                                                        _itemSubcategories
                                                                .isEmpty
                                                            ? Text(
                                                              "Select Item Subcategory For (${_sublevel1CategoryNode!.name})",
                                                              style: TextStyle(
                                                                color: _ink700,
                                                              ),
                                                            )
                                                            : Wrap(
                                                              spacing: 8,
                                                              runSpacing: 8,
                                                              children:
                                                                  _itemSubcategories.map((
                                                                    c,
                                                                  ) {
                                                                    return Chip(
                                                                      label: Text(
                                                                        c.name,
                                                                      ),
                                                                      onDeleted: () {
                                                                        setState(() {
                                                                          _itemSubcategories.removeWhere(
                                                                            (
                                                                              x,
                                                                            ) =>
                                                                                x.id ==
                                                                                c.id,
                                                                          );
                                                                          if (_itemSubcategories
                                                                              .isEmpty) {
                                                                            _customItemNameCtrl.clear();
                                                                          }
                                                                        });
                                                                        state.didChange(
                                                                          _itemSubcategories,
                                                                        );
                                                                      },
                                                                    );
                                                                  }).toList(),
                                                            ),
                                                  ),
                                                ),
                                                if (_itemSubcategories
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 10),
                                                  _Field(
                                                    controller:
                                                        _customItemNameCtrl,
                                                    label:
                                                        'Item Name (optional) For (${_sublevel1CategoryNode!.name})',
                                                    hint: 'Optional',
                                                    icon: Icons.edit_rounded,
                                                    labelColor: _ink900,
                                                    validator: (_) => null,
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ] else ...[
                              const SizedBox(height: 10),
                              _Field(
                                controller: _namelevel1,
                                label:
                                    'Name Subcategory For (${_parent!.name})*',
                                hint: 'e.g., Electrical / Motors',
                                icon: Icons.category_rounded,
                                labelColor: _ink900,
                                validator:
                                    (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                              ),
                            ],
                          ],
                        ],

                        // Room/Rack (only if no item subcategories)
                        if (_createRoomAndRack &&
                            _itemSubcategories.isEmpty) ...[
                          const SizedBox(height: 14),
                          Builder(
                            builder: (context) {
                              final categoryNode = _computeCategoryIdOrNull();
                              if (categoryNode == null) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _surfaceAlt.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _stroke),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: _ink600,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Select Category first to configure storage locations",
                                          style: TextStyle(
                                            color: _ink700,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final isMachineCategory =
                                  categoryNode.isMachine ||
                                  (_parent?.isMachine ?? false);

                              final roomAv = ref.watch(
                                isMachineCategory
                                    ? findAllMachineRoomDataByGoodStreamProvider
                                    : findAllRoomDataByGoodStreamProvider,
                              );

                              return Container(
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _stroke),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.vertical(
                                        top: const Radius.circular(14),
                                        bottom: Radius.circular(
                                          _storageLocationExpanded ? 0 : 14,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _storageLocationExpanded =
                                              !_storageLocationExpanded;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              color: _ink900,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            const Expanded(
                                              child: Text(
                                                'Storage Location',
                                                style: TextStyle(
                                                  color: _ink900,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              _storageLocationExpanded
                                                  ? Icons.keyboard_arrow_up_rounded
                                                  : Icons.keyboard_arrow_down_rounded,
                                              color: _ink900,
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Visibility(
                                      visible: _storageLocationExpanded,
                                      maintainState: true,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Divider(
                                            height: 1,
                                            color: _stroke,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // --- Good Stock Room & Rack ---
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
                                                              .meeting_room_outlined,
                                                      value: _roomNode,
                                                      items: list,
                                                      idOf: (x) => x.id,
                                                      textOf: (x) => x.code,
                                                      onChanged: (v) async {
                                                        setState(() {
                                                          _roomNode = v;
                                                          _rack = null;
                                                        });
                                                        await _autoPickFirstRackIfMachine(
                                                          isMachine:
                                                              isMachineCategory,
                                                          room: v,
                                                        );
                                                        if (isMachineCategory &&
                                                            _scrapRoomNode !=
                                                                null) {
                                                          await _autoPickFirstScrapRackIfMachine(
                                                            isMachine:
                                                                isMachineCategory,
                                                            room:
                                                                _scrapRoomNode,
                                                          );
                                                        }
                                                      },
                                                    );
                                                  },
                                                ),

                                                // Non-machine parent: show rack dropdown
                                                if (!isMachineCategory &&
                                                    _roomNode != null) ...[
                                                  const SizedBox(height: 12),
                                                  Builder(
                                                    builder: (context) {
                                                      final rackAv = ref.watch(
                                                        rackGoodDataByRoomDataStreamProvider(
                                                          RackByRoomArgs(
                                                            roomId:
                                                                _roomNode!.id,
                                                            itemId: "",
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
                                                            hint: 'Select rack',
                                                            icon:
                                                                Icons
                                                                    .grid_view_rounded,
                                                            value: _rack,
                                                            items: racks,
                                                            idOf: (x) => x.id,
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

                                                // Machine: show what got auto-selected
                                                if (isMachineCategory &&
                                                    _roomNode != null) ...[
                                                  const SizedBox(height: 12),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      _rack == null
                                                          ? 'Rack: (auto) not available'
                                                          : 'Rack: (auto) ${_rack!.code}',
                                                      style: const TextStyle(
                                                        color: _ink900,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],

                                                // --- Scrap Room & Scrap Rack ---
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'Scrap Location',
                                                  style: TextStyle(
                                                    color: _ink900,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),

                                                Builder(
                                                  builder: (context) {
                                                    final scrapRoomAv = ref.watch(
                                                      isMachineCategory
                                                          ? findAllMachineRoomDataByScrapStreamProvider
                                                          : findAllRoomDataByScrapStreamProvider,
                                                    );

                                                    return scrapRoomAv.when(
                                                      loading:
                                                          () =>
                                                              const LinearProgressIndicator(
                                                                minHeight: 2,
                                                              ),
                                                      error:
                                                          (e, _) => Text(
                                                            'Scrap room error: $e',
                                                          ),
                                                      data: (rooms) {
                                                        return _DropdownField<
                                                          StoreRoom
                                                        >(
                                                          label:
                                                              'Scrap Room *',
                                                          hint:
                                                              'Select scrap room',
                                                          icon:
                                                              Icons
                                                                  .meeting_room_outlined,
                                                          value: _scrapRoomNode,
                                                          items: rooms,
                                                          idOf: (x) => x.id,
                                                          textOf: (x) => x.code,
                                                          onChanged: (v) async {
                                                            setState(() {
                                                              _scrapRoomNode =
                                                                  v;
                                                              _scrapRack = null;
                                                            });
                                                            await _autoPickFirstScrapRackIfMachine(
                                                              isMachine:
                                                                  isMachineCategory,
                                                              room: v,
                                                            );
                                                          },
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),

                                                // Non-machine: show scrap rack dropdown
                                                if (!isMachineCategory &&
                                                    _scrapRoomNode != null) ...[
                                                  const SizedBox(height: 12),
                                                  Builder(
                                                    builder: (context) {
                                                      final rackAv = ref.watch(
                                                        rackDataByRoomDataStreamProvider(
                                                          RackByRoomArgs(
                                                            roomId:
                                                                _scrapRoomNode!
                                                                    .id,
                                                            itemId: "",
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
                                                              'Scrap rack error: $e',
                                                            ),
                                                        data: (racks) {
                                                          final filteredRacks =
                                                              racks
                                                                  .where(
                                                                    (r) =>
                                                                        r.id !=
                                                                        _rack
                                                                            ?.id,
                                                                  )
                                                                  .toList();

                                                          return _DropdownField<
                                                            StoreRack
                                                          >(
                                                            label:
                                                                'Scrap Rack *',
                                                            hint:
                                                                'Select scrap rack',
                                                            icon:
                                                                Icons
                                                                    .grid_view_rounded,
                                                            value: _scrapRack,
                                                            items:
                                                                filteredRacks,
                                                            idOf: (x) => x.id,
                                                            textOf:
                                                                (x) => x.code,
                                                            onChanged:
                                                                (v) => setState(
                                                                  () =>
                                                                      _scrapRack =
                                                                          v,
                                                                ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ],

                                                // Machine: show what got auto-selected
                                                if (isMachineCategory &&
                                                    _scrapRoomNode != null) ...[
                                                  const SizedBox(height: 12),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      _scrapRack == null
                                                          ? 'Scrap Rack: (auto) not available'
                                                          : 'Scrap Rack: (auto) ${_scrapRack!.code}',
                                                      style: const TextStyle(
                                                        color: _ink900,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Unit + Desc only when no item subcategories
                        if (_itemSubcategories.isEmpty) ...[
                          unitNamesAv.when(
                            loading:
                                () =>
                                    const LinearProgressIndicator(minHeight: 2),
                            error: (e, _) => Text('UnitName load error: $e'),
                            data: (paged) {
                              final list = paged.rows;
                              final safe =
                                  (_unitName != null &&
                                          list.any(
                                            (x) => x.id == _unitName!.id,
                                          ))
                                      ? list.firstWhere(
                                        (x) => x.id == _unitName!.id,
                                      )
                                      : null;

                              return _DropdownWithCreate<StoreUnitName>(
                                label: 'Unit Name',
                                hint: 'Select unit name',
                                icon: Icons.text_fields_rounded,
                                value: safe,
                                items: list,
                                textOf: (x) => '${x.name}  (${x.code})',
                                onChanged: (v) => setState(() => _unitName = v),
                                onCreateTap: _openQuickUnitNameCreate,
                                createLabel: 'Unit create',
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          _Field(
                            controller: _maxCapacity,
                            label: _parent?.isbag == true
                                ? 'Maximum Quantity (Bag Capacity)'
                                : 'Maximum Quantity',
                            hint: _parent?.isbag == true
                                ? 'Required for bag (e.g. 100)'
                                : 'Optional (e.g. 100) - limits manual indent creation',
                            icon: Icons.storage_rounded,
                            labelColor: _ink900,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              if (_parent?.isbag == true) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required for bag';
                                }
                              }
                              if (v == null || v.trim().isEmpty) return null;
                              final n = int.tryParse(v.trim());
                              if (n == null || n < 0) {
                                return 'Enter a valid number (>= 0)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            controller: _minStock,
                            label: 'Minimum Stock Alert (Refill Threshold)',
                            hint: 'Optional (e.g. 3) - triggers auto refill',
                            icon: Icons.notifications_active_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final n = int.tryParse(v.trim());
                              if (n == null || n < 0) {
                                return 'Enter a valid number (>= 0)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _Field(
                            controller: _desc,
                            label: 'Description',
                            hint: 'Optional',
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                            validator: (_) => null,
                          ),
                          const SizedBox(height: 14),
                        ],

                        _PrimaryBtn(
                          label: _busy ? 'Saving...' : 'Create Item',
                          busy: _busy,
                          onTap:
                              _busy
                                  ? null
                                  : () async {
                                    await _save();
                                  },
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

/* ============================
   Multi Select Dialog (FIXED)
   ============================ */

class _CategoryMultiSelectDialog extends StatefulWidget {
  const _CategoryMultiSelectDialog({
    required this.title,
    required this.items,
    required this.initiallySelected,
  });

  final String title;
  final List<StoreCategory> items;
  final List<StoreCategory> initiallySelected;

  @override
  State<_CategoryMultiSelectDialog> createState() =>
      _CategoryMultiSelectDialogState();
}

class _CategoryMultiSelectDialogState
    extends State<_CategoryMultiSelectDialog> {
  late final Set<String> _selectedIds;
  String _q = "";

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initiallySelected.map((e) => e.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.items
            .where((c) => c.name.toLowerCase().contains(_q.toLowerCase()))
            .toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        height: 420, // ✅ fixed to avoid "unbounded height" errors
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search...",
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  final checked = _selectedIds.contains(item.id);
                  return CheckboxListTile(
                    value: checked,
                    title: Text(item.name),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(item.id);
                        } else {
                          _selectedIds.remove(item.id);
                        }
                      });
                    },
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
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => setState(() => _selectedIds.clear()),
          child: const Text("Clear"),
        ),
        ElevatedButton(
          onPressed: () {
            final selected =
                widget.items.where((c) => _selectedIds.contains(c.id)).toList();
            Navigator.pop(context, selected);
          },
          child: const Text("Done"),
        ),
      ],
    );
  }
}

/* ============================
   UnitName Quick Create
   ============================ */

class _UnitNameQuickCreateDialog extends ConsumerStatefulWidget {
  const _UnitNameQuickCreateDialog();

  @override
  ConsumerState<_UnitNameQuickCreateDialog> createState() =>
      _UnitNameQuickCreateDialogState();
}

class _UnitNameQuickCreateDialogState
    extends ConsumerState<_UnitNameQuickCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _remark = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid");
    final dto = {
      "name": _name.text.trim(),
      "remark": _remark.text.trim(),
      "createdBy": createdBy,
    };

    setState(() => _busy = true);
    try {
      final created = await ref
          .read(storeUnitNameControllerProvider)
          .createUnitName(dto: dto);
      if (!mounted) return;
      if (created == null) return;
      Navigator.of(context, rootNavigator: true).pop<StoreUnitName>(created);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Unit Name'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Field(
                controller: _name,
                label: 'Unit Name *',
                hint: 'e.g., PCS',
                icon: Icons.text_fields_rounded,
                labelColor: _ink900,
                validator:
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _remark,
                label: 'Remark',
                hint: 'Optional',
                icon: Icons.notes_rounded,
                labelColor: _ink900,
                maxLines: 2,
                validator: (_) => null,
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

/* ============================
   Category Quick Create (FIXED parentId LIST)
   ============================ */

class _CategoryQuickCreateDialog extends ConsumerStatefulWidget {
  const _CategoryQuickCreateDialog();

  @override
  ConsumerState<_CategoryQuickCreateDialog> createState() =>
      _CategoryQuickCreateDialogState();
}

class _CategoryQuickCreateDialogState
    extends ConsumerState<_CategoryQuickCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _remark = TextEditingController();

  StoreCategory? _parent;
  StoreCategory? _sublevel1CategoryNode;
  StoreCategory? _sublevel2CategoryNode;
  StoreCategory? _sublevel3CategoryNode;

  bool _busy = false;
  bool _level1SubCategory = false;
  bool _level2SubCategory = false;
  bool _level3SubCategory = false;

  @override
  void dispose() {
    _name.dispose();
    _remark.dispose();
    super.dispose();
  }

  void _resetAllSubLevels() {
    _level1SubCategory = false;
    _level2SubCategory = false;
    _level3SubCategory = false;
    _sublevel1CategoryNode = null;
    _sublevel2CategoryNode = null;
    _sublevel3CategoryNode = null;
  }

  void _resetLevel2AndBelow() {
    _level2SubCategory = false;
    _level3SubCategory = false;
    _sublevel2CategoryNode = null;
    _sublevel3CategoryNode = null;
  }

  void _resetLevel3() {
    _level3SubCategory = false;
    _sublevel3CategoryNode = null;
  }

  // ✅ Build parentId chain list. Top-level => []
  List<String>? _computeParentChainOrNull() {
    // Top-level category
    if (_parent == null) return <String>[];

    StoreCategory attach = _parent!;

    if (_level1SubCategory) {
      if (_sublevel1CategoryNode == null) return null;
      attach = _sublevel1CategoryNode!;

      if (_level2SubCategory) {
        if (_sublevel2CategoryNode == null) return null;
        attach = _sublevel2CategoryNode!;

        if (_level3SubCategory) {
          if (_sublevel3CategoryNode == null) return null;
          attach = _sublevel3CategoryNode!;
        }
      }
    }

    // chain = parent.parentId + parent.id
    final chain = <String>[
      ...((attach.parentId) ?? const <String>[]),
      attach.id,
    ];
    return chain;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    final parentChain = _computeParentChainOrNull();
    if (parentChain == null) {
      _showError("Please select the subcategory level you enabled.");
      return;
    }

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

    // ✅ Your model: parentId is List<String>, so send list
    final dto = <String, dynamic>{
      "name": _name.text.trim(),
      "remark": _remark.text.trim(),
      "createdBy": createdBy,
      "parentId": parentChain, // [] => top-level
    };

    setState(() => _busy = true);
    try {
      final created = await ref
          .read(storeCategoryControllerProvider)
          .createCategory(dto: dto);
      if (!mounted) return;

      if (created == null) {
        _showError("Category creation failed. Please try again.");
        return;
      }

      Navigator.of(context, rootNavigator: true).pop<StoreCategory>(created);
    } catch (e) {
      if (mounted) _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAv = ref.watch(parentcategoryAllDataStreamProvider);

    return AlertDialog(
      title: const Text('Create Category / Subcategory'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                catsAv.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, _) => Text('Load error: $e'),
                  data: (parents) {
                    return _DropdownField<StoreCategory>(
                      label: 'Parent Category',
                      hint: 'None (Top-level category)',
                      icon: Icons.account_tree_rounded,
                      value: _parent,
                      items: parents,
                      idOf: (x) => x.id,
                      textOf: (x) => x.name,
                      allowNull: true, // ✅ now works
                      onChanged: (v) {
                        setState(() {
                          _parent = v;
                          _resetAllSubLevels();
                        });
                      },
                    );
                  },
                ),

                if (_parent != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _level1SubCategory,
                        onChanged: (value) {
                          setState(() {
                            _level1SubCategory = value ?? false;
                            if (!_level1SubCategory) {
                              _resetAllSubLevels();
                            }
                          });
                        },
                      ),
                      const Text(
                        "Select Subcategory",
                        style: TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  if (_level1SubCategory) ...[
                    Builder(
                      builder: (context) {
                        final subcatslevel1Av = ref.watch(
                          levelOnecategoryByIdperentDataStreamProvider(
                            _parent!.id,
                          ),
                        );

                        return subcatslevel1Av.when(
                          loading:
                              () => const LinearProgressIndicator(minHeight: 2),
                          error: (e, _) => Text('Subcategory load error: $e'),
                          data: (subcategorieslevel1) {
                            return _DropdownField<StoreCategory>(
                              label: 'Subcategory (Level 1) *',
                              hint: 'Select level 1 subcategory',
                              icon: Icons.category_rounded,
                              value: _sublevel1CategoryNode,
                              items: subcategorieslevel1,
                              idOf: (x) => x.id,
                              textOf: (x) => x.name,
                              onChanged: (v) {
                                setState(() {
                                  _sublevel1CategoryNode = v;
                                  _resetLevel2AndBelow();
                                });
                              },
                            );
                          },
                        );
                      },
                    ),

                    if (_sublevel1CategoryNode != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _level2SubCategory,
                            onChanged: (value) {
                              setState(() {
                                _level2SubCategory = value ?? false;
                                if (!_level2SubCategory) {
                                  _resetLevel2AndBelow();
                                }
                              });
                            },
                          ),
                          const Text(
                            "Select Subcategory",
                            style: TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      if (_level2SubCategory) ...[
                        Builder(
                          builder: (context) {
                            final subcatslevel2Av = ref.watch(
                              levelTwocategoryByIdperentDataStreamProvider(
                                _sublevel1CategoryNode!.id,
                              ),
                            );

                            return subcatslevel2Av.when(
                              loading:
                                  () => const LinearProgressIndicator(
                                    minHeight: 2,
                                  ),
                              error:
                                  (e, _) => Text('Subcategory load error: $e'),
                              data: (subcategorieslevel2) {
                                return _DropdownField<StoreCategory>(
                                  label: 'Subcategory (Level 2) *',
                                  hint: 'Select level 2 subcategory',
                                  icon: Icons.category_rounded,
                                  value: _sublevel2CategoryNode,
                                  items: subcategorieslevel2,
                                  idOf: (x) => x.id,
                                  textOf: (x) => x.name,
                                  onChanged: (v) {
                                    setState(() {
                                      _sublevel2CategoryNode = v;
                                      _resetLevel3();
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),

                        if (_sublevel2CategoryNode != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _level3SubCategory,
                                onChanged: (value) {
                                  setState(() {
                                    _level3SubCategory = value ?? false;
                                    if (!_level3SubCategory) {
                                      _resetLevel3();
                                    }
                                  });
                                },
                              ),
                              const Text(
                                "Select Subcategory",
                                style: TextStyle(
                                  color: _ink700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          if (_level3SubCategory) ...[
                            Builder(
                              builder: (context) {
                                final subcatslevel3Av = ref.watch(
                                  levelThreecategoryByIdperentDataStreamProvider(
                                    _sublevel2CategoryNode!.id,
                                  ),
                                );

                                return subcatslevel3Av.when(
                                  loading:
                                      () => const LinearProgressIndicator(
                                        minHeight: 2,
                                      ),
                                  error:
                                      (e, _) =>
                                          Text('Subcategory load error: $e'),
                                  data: (subcategorieslevel3) {
                                    return _DropdownField<StoreCategory>(
                                      label: 'Subcategory (Level 3) *',
                                      hint: 'Select level 3 subcategory',
                                      icon: Icons.category_rounded,
                                      value: _sublevel3CategoryNode,
                                      items: subcategorieslevel3,
                                      idOf: (x) => x.id,
                                      textOf: (x) => x.name,
                                      onChanged: (v) {
                                        setState(
                                          () => _sublevel3CategoryNode = v,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ],
                    ],
                  ],
                ],

                const SizedBox(height: 10),
                _Field(
                  controller: _name,
                  label: 'Name *',
                  hint: 'e.g., Electrical / Motors',
                  icon: Icons.category_rounded,
                  labelColor: _ink900,
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: _remark,
                  label: 'Remark',
                  hint: 'Optional',
                  icon: Icons.notes_rounded,
                  labelColor: _ink900,
                  maxLines: 2,
                  validator: (_) => null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _busy
                  ? null
                  : () => Navigator.of(context, rootNavigator: true).pop(),
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

/* ============================
   Shared UI
   ============================ */

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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.maxLines = 1,
    this.labelColor,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final int maxLines;
  final Color? labelColor;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final lc = labelColor ?? _ink900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: lc, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ink600),
            prefixIcon: maxLines > 1
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 36, left: 12, right: 8),
                    child: Icon(icon, color: _ink600),
                  )
                : Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: 0.55),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: _ink900, width: 1.3),
            ),
          ),
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
      ],
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
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: _ink900, width: 1.3),
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

class _DropdownWithCreate<T> extends StatelessWidget {
  const _DropdownWithCreate({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.textOf,
    required this.onChanged,
    required this.onCreateTap,
    required this.createLabel,
  });

  final String label;
  final String hint;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) textOf;
  final ValueChanged<T?> onChanged;
  final VoidCallback onCreateTap;
  final String createLabel;

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
        Container(
          decoration: BoxDecoration(
            color: _surfaceAlt.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke),
          ),
          padding: const EdgeInsets.only(left: 6, right: 6),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(icon, color: _ink600),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    hint: Text(
                      hint,
                      style: const TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    items: [
                      for (final it in items)
                        DropdownMenuItem(
                          value: it,
                          child: Text(
                            textOf(it),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onChanged,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    dropdownColor: _surface,
                    iconEnabledColor: _ink600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Material(
                  color: _ink900,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onCreateTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 15, color: _surface),
                          const SizedBox(width: 4),
                          Text(
                            createLabel,
                            style: const TextStyle(
                              color: _surface,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _ImagePickRow extends StatelessWidget {
  const _ImagePickRow({
    required this.pickedBytes,
    required this.pickedImage,
    required this.uploadedUrl,
    required this.typedUrl,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
  });

  final Uint8List? pickedBytes;
  final XFile? pickedImage;
  final String? uploadedUrl;
  final String typedUrl;

  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    final String urlToShow = typedUrl;

    if (pickedBytes != null) {
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

/* ============================
   Scrap Rack Selection Dialog (FIXED null-safe top-level)
   ============================ */

// ignore: must_be_immutable
