import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_room_controller.dart';
import '../../widgets/store_ui_state_widgets.dart';

// Palette
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentMint = Color(0xFFB6D3CC);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

int _i(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;
const _shadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
];

const _accentPeach = Color(0xFFF3D7C0);

enum RoomTypeOption {
  goodsRoom,
  machineRoom,
}

extension RoomTypeOptionDetails on RoomTypeOption {
  String get title {
    switch (this) {
      case RoomTypeOption.goodsRoom:
        return 'Goods Room';
      case RoomTypeOption.machineRoom:
        return 'Machine Room';
    }
  }

  String get description {
    switch (this) {
      case RoomTypeOption.goodsRoom:
        return 'General goods storage';
      case RoomTypeOption.machineRoom:
        return 'Machine-specific storage';
    }
  }

  IconData get icon {
    switch (this) {
      case RoomTypeOption.goodsRoom:
        return Icons.inventory_2_outlined;
      case RoomTypeOption.machineRoom:
        return Icons.precision_manufacturing_outlined;
    }
  }

  bool get isOneRack {
    switch (this) {
      case RoomTypeOption.goodsRoom:
        return false;
      case RoomTypeOption.machineRoom:
        return true;
    }
  }
}

class RoomCreatePage extends ConsumerStatefulWidget {
  const RoomCreatePage({super.key});

  @override
  ConsumerState<RoomCreatePage> createState() => _RoomCreatePageState();
}

class _RoomCreatePageState extends ConsumerState<RoomCreatePage> {
  final _formKey = GlobalKey<FormState>();

  RoomTypeOption _selectedRoomType = RoomTypeOption.goodsRoom;

  final TextEditingController _remarkController = TextEditingController();
  late final TextEditingController _rackCountController =
      TextEditingController(text: '1');

  int _rackCount = 1;
  bool _busy = false;

  @override
  void dispose() {
    _remarkController.dispose();
    _rackCountController.dispose();
    super.dispose();
  }

  Future<void> _submitRoom() async {
    if (_busy) return;
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final rackCount = _selectedRoomType.isOneRack ? 1 : _rackCount;
    if (!_selectedRoomType.isOneRack && rackCount < 1) {
      showStoreSnackBar(
        context,
        "Number of racks must be at least 1",
        isError: true,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
      final remark = _remarkController.text.trim();

      final isGoods = _selectedRoomType == RoomTypeOption.goodsRoom;
      final primaryName = isGoods ? "Goods Room" : "Machine Room";
      final scrapName = isGoods ? "Scrap Room" : "Scrap Machine Room";

      // 1. Primary room payload (Goods Room or Goods Machine Room)
      final primaryPayload = <String, dynamic>{
        "remark": remark,
        "createdBy": createdBy,
        "rackmake": rackCount,
        "isScrap": false,
        "isOneRack": _selectedRoomType.isOneRack,
      };

      // 2. Corresponding scrap room payload (Scrap Room or Scrap Machine Room)
      final scrapPayload = <String, dynamic>{
        "remark": remark,
        "createdBy": createdBy,
        "rackmake": rackCount,
        "isScrap": true,
        "isOneRack": _selectedRoomType.isOneRack,
      };

      // Step 1: Create primary room
      final primarySuccess = await ref
          .read(storeRoomControllerProvider)
          .multirackRoom(storeRoom: primaryPayload, showFeedback: false);

      if (!mounted) return;

      if (!primarySuccess) {
        showStoreSnackBar(
          context,
          "Failed to create $primaryName. Please try again.",
          isError: true,
        );
        return;
      }

      // Step 2: Automatically create corresponding scrap room
      final scrapSuccess = await ref
          .read(storeRoomControllerProvider)
          .multirackRoom(storeRoom: scrapPayload, showFeedback: false);

      if (!mounted) return;

      if (!scrapSuccess) {
        showStoreSnackBar(
          context,
          "$primaryName created successfully, but failed to create corresponding $scrapName.",
          isError: true,
        );
        Navigator.pop(context, true);
        return;
      }

      showStoreSnackBar(
        context,
        "$primaryName and $scrapName created successfully.",
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showStoreSnackBar(context, "Failed to create room: $e", isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Create Room',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _stroke),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C000000),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Room Type",
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Select room type. The corresponding Scrap Room will be created automatically.",
                              style: TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Room Type Cards (2 Options: Goods Room & Machine Room)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 520;
                                final cards = RoomTypeOption.values.map((type) {
                                  final isSelected =
                                      _selectedRoomType == type;
                                  return _RoomTypeCard(
                                    type: type,
                                    isSelected: isSelected,
                                    enabled: !_busy,
                                    onTap: () {
                                      setState(() {
                                        _selectedRoomType = type;
                                      });
                                    },
                                  );
                                }).toList();

                                if (isWide) {
                                  return Row(
                                    children: [
                                      Expanded(child: cards[0]),
                                      const SizedBox(width: 12),
                                      Expanded(child: cards[1]),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      cards[0],
                                      const SizedBox(height: 10),
                                      cards[1],
                                    ],
                                  );
                                }
                              },
                            ),

                            const SizedBox(height: 24),
                            const Divider(color: _stroke, height: 1),
                            const SizedBox(height: 22),

                            // Rack Count or Machine Informational UI
                            if (!_selectedRoomType.isOneRack) ...[
                              TextFormField(
                                controller: _rackCountController,
                                keyboardType: TextInputType.number,
                                enabled: !_busy,
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Number of Racks to Create *',
                                  labelStyle: const TextStyle(
                                    color: _ink700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  hintText: 'Enter number of racks',
                                  hintStyle: const TextStyle(color: _ink600),
                                  prefixIcon: const Icon(
                                    Icons.shelves,
                                    color: _ink600,
                                  ),
                                  filled: true,
                                  fillColor: _surfaceAlt.withValues(alpha: 0.55),
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
                                    borderSide: const BorderSide(
                                      color: _ink900,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (!_selectedRoomType.isOneRack) {
                                    final count =
                                        int.tryParse(value?.trim() ?? '');
                                    if (count == null || count < 1) {
                                      return 'Please enter a valid number of racks (at least 1)';
                                    }
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  _rackCount = int.tryParse(value.trim()) ?? 1;
                                },
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFA5D6A7),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF2E7D32),
                                      size: 22,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '1 rack will be created for this machine room.',
                                        style: TextStyle(
                                          color: Color(0xFF1B5E20),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Remark Field
                            TextFormField(
                              controller: _remarkController,
                              enabled: !_busy,
                              maxLines: 2,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Remark (Optional)',
                                labelStyle: const TextStyle(
                                  color: _ink700,
                                  fontWeight: FontWeight.w600,
                                ),
                                hintText: 'Enter remark',
                                hintStyle: const TextStyle(color: _ink600),
                                prefixIcon: const Icon(
                                  Icons.notes_rounded,
                                  color: _ink600,
                                ),
                                filled: true,
                                fillColor: _surfaceAlt.withValues(alpha: 0.55),
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
                                  borderSide: const BorderSide(
                                    color: _ink900,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _submitRoom,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _ink900,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      _ink900.withValues(alpha: 0.6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_home_rounded,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Create Room',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
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
    );
  }
}

class _RoomTypeCard extends StatelessWidget {
  final RoomTypeOption type;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _RoomTypeCard({
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
                ? _accentPeach.withValues(alpha: 0.35)
                : _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _ink900 : _stroke,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _ink900.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _ink900
                      : _surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _ink900 : _stroke,
                  ),
                ),
                child: Icon(
                  type.icon,
                  size: 22,
                  color: isSelected ? Colors.white : _ink900,
                ),
              ),
              const SizedBox(width: 12),
              // Title and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.title,
                      style: TextStyle(
                        color: _ink900,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.description,
                      style: const TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Radio indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _ink900 : _stroke,
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
