import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/sorting_job_controller.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class MachineFormView extends ConsumerStatefulWidget {
  final String categoryId;

  /// ✅ We will generate machineName from this on UI side
  final String categoryName;

  /// Optional default itemId (if you want to attach machine to an item)
  final String? defaultItemId;

  const MachineFormView({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.defaultItemId,
  });

  @override
  ConsumerState<MachineFormView> createState() => _MachineFormViewState();
}

class _MachineFormViewState extends ConsumerState<MachineFormView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _remarkCtrl;
  bool isLoading = false;
  String? _itemId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _remarkCtrl = TextEditingController();
    _itemId = widget.defaultItemId;
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ machineName rule: categoryName
    final machineName = widget.categoryName.trim();

    final payload = <String, dynamic>{
      // ❌ machineCode NOT sent (backend will generate)
      "machineName": machineName,
      "categoryId": widget.categoryId,
      "itemId": (_itemId ?? "").trim(), // optional
      "remark": _remarkCtrl.text.trim(), // optional
      "isActive": _isActive,
    };
    setState(() {
      isLoading = true;
    });
    final ok = await ref
        .read(sortingJobControllerProvider.notifier)
        .addMachineToJob(machine: payload);

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // final isLoading = ref.watch(machineControllerProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          "Create Machine",
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _stroke),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 14,
                  offset: Offset(0, 6),
                  color: Color(0x14000000),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ✅ Show what will be saved
                  Text(
                    "Machine Name (auto):",
                    style: const TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stroke),
                    ),
                    child: Text(
                      widget.categoryName,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // TextFormField(
                  //   initialValue: widget.categoryId,
                  //   readOnly: true,
                  //   decoration: const InputDecoration(
                  //     labelText: "CategoryId",
                  //     border: OutlineInputBorder(),
                  //   ),
                  // ),

                  // const SizedBox(height: 12),

                  // TextFormField(
                  //   initialValue: _itemId ?? "",
                  //   decoration: const InputDecoration(
                  //     labelText: "ItemId (optional)",
                  //     border: OutlineInputBorder(),
                  //   ),
                  //   onChanged: (v) {
                  //     final t = v.trim();
                  //     _itemId = t.isEmpty ? null : t;
                  //   },
                  // ),

                  // const SizedBox(height: 12),
                  TextFormField(
                    controller: _remarkCtrl,
                    decoration: const InputDecoration(
                      labelText: "Remark (optional)",
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: _ink600),
                  ),

                  const SizedBox(height: 12),

                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text(
                      "Active",
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    activeThumbColor: _ink900,
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ink900,
                        foregroundColor: _surface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(isLoading ? "Creating..." : "Create"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
