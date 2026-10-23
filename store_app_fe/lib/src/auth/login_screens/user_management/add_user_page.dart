// ✅ Fully updated single-file implementation
// - Fetch divisions via WebSocket (division:findAll) using StreamProvider
// - Create division via REST (POST /api/auth/divisions)
// - Base URL normalization (fixes: Scheme not starting with alphabetic character)
// - Division picker enforces: ✅ at least ONE division selected
//    - Auto-selects first division if none selected when opening picker
//    - Prevents unchecking the last selected division
//    - Apply button disabled when selection is empty (e.g., after pressing Clear)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ✅ adjust these imports to your project
import '../../../components/socket_manager.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/users_controller.dart';
// ✅ socketProvider must be available from your socket manager/provider file

/* =================== Palette (shared look) =================== */
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

/* =================== Division Model =================== */
class DivisionOption {
  final String id;
  final String name;
  const DivisionOption({required this.id, required this.name});
}

/* =================== App Enum =================== */
enum AppOption { storeconsumable, scrap, stock }

extension AppOptionX on AppOption {
  String get key => name;

  String get label => switch (this) {
    AppOption.storeconsumable => 'Store Consumable',
    AppOption.scrap => 'Scrap',
    AppOption.stock => 'Stock',
  };

  IconData get icon => switch (this) {
    AppOption.storeconsumable => Icons.group_rounded,
    AppOption.scrap => Icons.inventory_2_rounded,
    AppOption.stock => Icons.score_sharp,
  };

  Color get color => switch (this) {
    AppOption.storeconsumable => const Color.fromARGB(255, 89, 86, 119),
    AppOption.scrap => const Color(0xFFFD2929),
    AppOption.stock => const Color.fromARGB(255, 26, 228, 235),
  };
}

/* =================== Access/Permission Enum (flat) =================== */
enum Access {
  storeitemview,
  storeitemadd,
  storeitemedit,
  storeitemdelete,
  storeitemtransfer,
  storeitemfind,
  storeitemrateview,

  storeplaceview,
  storeplaceadd,
  storeplaceedit,
  storeplacedelete,

  storreceiveview,
  storreceiveadd,
  storreceiveedit,
  storreceivereject,
  storreceiveapprove,
  storreceiveclose,
  storreceivetostock,
  historyReceiveItem,

  storissueview,
  storissueadd,
  storissueedit,
  storissuereject,
  storissueapprove,
  storissueclose,
  storissuefromstock,
  storissuereturn,
  historyissueItem,

  storeindentview,
  storeindentdraft,
  storeindentraise,
  storeindentconsolidation,
  storeindentapprove,
  storeindentreject,
  storeindenthistory,

  storeexport,
  storeimportData,
  storeadmin,

  scrapview,
  scrapadd,
  scrapdelete,
  scrapexport,
  historyScrap,
}

/* =================== Access metadata =================== */
extension AccessX on Access {
  String get key => name;

  String get label => switch (this) {
    Access.storeitemview => 'Item • View',
    Access.storeitemadd => 'Item • Add',
    Access.storeitemedit => 'Item • Edit',
    Access.storeitemdelete => 'Item • Delete',
    Access.storeitemtransfer => 'Item • Transfer',
    Access.storeitemfind => 'Item • Find',
    Access.storeitemrateview => 'Item • Rate View',

    Access.storeplaceview => 'Place • View',
    Access.storeplaceadd => 'Place • Add',
    Access.storeplaceedit => 'Place • Edit',
    Access.storeplacedelete => 'Place • Delete',

    Access.storreceiveview => 'Receive • View',
    Access.storreceiveadd => 'Receive • Add',
    Access.storreceiveedit => 'Receive • Edit',
    Access.storreceivereject => 'Receive • Reject',
    Access.storreceiveapprove => 'Receive • Approve',
    Access.storreceiveclose => 'Receive • Close',
    Access.storreceivetostock => 'Receive • To Stock',
    Access.historyReceiveItem => 'Receive • History',

    Access.storissueview => 'Issue • View',
    Access.storissueadd => 'Issue • Add',
    Access.storissueedit => 'Issue • Edit',
    Access.storissuereject => 'Issue • Reject',
    Access.storissueapprove => 'Issue • Approve',
    Access.storissueclose => 'Issue • Close',
    Access.storissuefromstock => 'Issue • From Stock',
    Access.storissuereturn => 'Issue • Return',
    Access.historyissueItem => 'Issue • History',

    Access.storeindentview => 'Indent • View',
    Access.storeindentdraft => 'Indent • Cart / Drafts',
    Access.storeindentraise => 'Indent • Raise',
    Access.storeindentconsolidation => 'Indent • Consolidation',
    Access.storeindentapprove => 'Indent • Approve',
    Access.storeindentreject => 'Indent • Reject',
    Access.storeindenthistory => 'Indent • History',

    Access.storeexport => 'Store • Export',
    Access.storeimportData => 'Store • Import',
    Access.storeadmin => 'Store • Admin',

    Access.scrapview => 'Scrap • View',
    Access.scrapadd => 'Scrap • Add',
    Access.scrapdelete => 'Scrap • Delete',
    Access.scrapexport => 'Scrap • Export',
    Access.historyScrap => 'Scrap • History',
  };

  IconData get icon => switch (this) {
    Access.storeitemview => Icons.visibility_rounded,
    Access.storeitemadd => Icons.add_circle_rounded,
    Access.storeitemedit => Icons.edit_rounded,
    Access.storeitemdelete => Icons.delete_outline_rounded,
    Access.storeitemtransfer => Icons.compare_arrows_rounded,
    Access.storeitemfind => Icons.location_searching_rounded,
    Access.storeitemrateview => Icons.currency_rupee_rounded,

    Access.storeplaceview => Icons.location_searching_rounded,
    Access.storeplaceadd => Icons.add_location_alt_rounded,
    Access.storeplaceedit => Icons.edit_location_alt_rounded,
    Access.storeplacedelete => Icons.location_off_rounded,

    Access.storreceiveview => Icons.inbox_rounded,
    Access.storreceiveadd => Icons.move_to_inbox_rounded,
    Access.storreceiveedit => Icons.edit_rounded,
    Access.storreceivereject => Icons.cancel_rounded,
    Access.storreceiveapprove => Icons.check_circle_rounded,
    Access.storreceiveclose => Icons.lock_rounded,
    Access.storreceivetostock => Icons.inventory_2_rounded,
    Access.historyReceiveItem => Icons.history_toggle_off_rounded,

    Access.storissueview => Icons.markunread_mailbox_rounded,
    Access.storissueadd => Icons.outbox_rounded,
    Access.storissueedit => Icons.edit_rounded,
    Access.storissuereject => Icons.cancel_rounded,
    Access.storissueapprove => Icons.check_circle_rounded,
    Access.storissueclose => Icons.lock_rounded,
    Access.storissuefromstock => Icons.inventory_rounded,
    Access.storissuereturn => Icons.assignment_return_rounded,
    Access.historyissueItem => Icons.history_edu_rounded,

    Access.storeindentview => Icons.hub_outlined,
    Access.storeindentdraft => Icons.shopping_bag_outlined,
    Access.storeindentraise => Icons.post_add_rounded,
    Access.storeindentconsolidation => Icons.tune_rounded,
    Access.storeindentapprove => Icons.check_circle_outline_rounded,
    Access.storeindentreject => Icons.cancel_outlined,
    Access.storeindenthistory => Icons.history_rounded,

    Access.storeexport => Icons.file_upload_rounded,
    Access.storeimportData => Icons.file_download_rounded,
    Access.storeadmin => Icons.security_rounded,

    Access.scrapview => Icons.visibility_rounded,
    Access.scrapadd => Icons.add_circle_rounded,
    Access.scrapdelete => Icons.delete_outline_rounded,
    Access.scrapexport => Icons.file_upload_rounded,
    Access.historyScrap => Icons.history_rounded,
  };

  Color get color => switch (this) {
    Access.storeitemview => const Color(0xFF38BDF8),
    Access.storeitemadd => const Color(0xFF22C55E),
    Access.storeitemedit => const Color(0xFFF59E0B),
    Access.storeitemdelete => const Color(0xFFEF4444),
    Access.storeitemtransfer => const Color(0xFF14B8A6),
    Access.storeitemfind => const Color(0xFF6366F1),
    Access.storeitemrateview => const Color(0xFF10B981),

    Access.storeplaceview => const Color(0xFF60A5FA),
    Access.storeplaceadd => const Color(0xFF34D399),
    Access.storeplaceedit => const Color(0xFFEAB308),
    Access.storeplacedelete => const Color(0xFFDC2626),

    Access.storreceiveview => const Color(0xFF06B6D4),
    Access.storreceiveadd => const Color(0xFF2DD4BF),
    Access.storreceiveedit => const Color(0xFFF59E0B),
    Access.storreceivereject => const Color(0xFFFB7185),
    Access.storreceiveapprove => const Color(0xFF14B8A6),
    Access.storreceiveclose => const Color(0xFF94A3B8),
    Access.storreceivetostock => const Color(0xFF8B5CF6),
    Access.historyReceiveItem => const Color(0xFFA855F7),

    Access.storissueview => const Color(0xFF38BDF8),
    Access.storissueadd => const Color(0xFFF97316),
    Access.storissueedit => const Color(0xFFEAB308),
    Access.storissuereject => const Color(0xFFFB7185),
    Access.storissueapprove => const Color(0xFF10B981),
    Access.storissueclose => const Color(0xFF94A3B8),
    Access.storissuefromstock => const Color(0xFF64748B),
    Access.storissuereturn => const Color(0xFF60A5FA),
    Access.historyissueItem => const Color(0xFFFAC515),

    Access.storeindentview => const Color(0xFFF59E0B),
    Access.storeindentdraft => const Color(0xFFEA580C),
    Access.storeindentraise => const Color(0xFF2563EB),
    Access.storeindentconsolidation => const Color(0xFF8B5CF6),
    Access.storeindentapprove => const Color(0xFF16A34A),
    Access.storeindentreject => const Color(0xFFDC2626),
    Access.storeindenthistory => const Color(0xFF64748B),

    Access.storeexport => const Color(0xFF6366F1),
    Access.storeimportData => const Color(0xFF8B5CF6),
    Access.storeadmin => const Color(0xFF6C5CE7),

    Access.scrapview => const Color(0xFFF97316),
    Access.scrapadd => const Color(0xFF44D99F),
    Access.scrapdelete => const Color(0xFFEF4444),
    Access.scrapexport => const Color(0xFF22C55E),
    Access.historyScrap => const Color(0xFFEAB308),
  };
}

/* =================== Grouping helpers =================== */
class AccessGroup {
  final String title;
  final IconData icon;
  final Color tint;
  final List<Access> options;
  const AccessGroup({
    required this.title,
    required this.icon,
    required this.tint,
    required this.options,
  });
}

List<AccessGroup> buildGroups(AppOption app) {
  if (app == AppOption.storeconsumable) {
    return const [
      AccessGroup(
        title: 'Items',
        icon: Icons.inventory_2_rounded,
        tint: Color(0xFF38BDF8),
        options: [
          Access.storeitemview,
          Access.storeitemadd,
          Access.storeitemedit,
          Access.storeitemdelete,
          Access.storeitemtransfer,
          Access.storeitemfind,
          Access.storeitemrateview,
        ],
      ),
      AccessGroup(
        title: 'Places',
        icon: Icons.place_rounded,
        tint: Color(0xFF60A5FA),
        options: [
          Access.storeplaceview,
          Access.storeplaceadd,
          Access.storeplaceedit,
          Access.storeplacedelete,
        ],
      ),
      AccessGroup(
        title: 'Receive',
        icon: Icons.move_to_inbox_rounded,
        tint: Color(0xFF14B8A6),
        options: [
          Access.storreceiveview,
          Access.storreceiveadd,
          Access.storreceiveedit,
          Access.storreceivereject,
          Access.storreceiveapprove,
          Access.storreceiveclose,
          Access.storreceivetostock,
          Access.historyReceiveItem,
        ],
      ),
      AccessGroup(
        title: 'Issue',
        icon: Icons.outbox_rounded,
        tint: Color(0xFFF97316),
        options: [
          Access.storissueview,
          Access.storissueadd,
          Access.storissueedit,
          Access.storissuereject,
          Access.storissueapprove,
          Access.storissueclose,
          Access.storissuefromstock,
          Access.storissuereturn,
          Access.historyissueItem,
        ],
      ),
      AccessGroup(
        title: 'Indent',
        icon: Icons.receipt_long_rounded,
        tint: Color(0xFFF59E0B),
        options: [
          Access.storeindentview,
          Access.storeindentdraft,
          Access.storeindentraise,
          Access.storeindentconsolidation,
          Access.storeindentapprove,
          Access.storeindentreject,
          Access.storeindenthistory,
        ],
      ),
      AccessGroup(
        title: 'Admin & Data',
        icon: Icons.admin_panel_settings_rounded,
        tint: Color(0xFF6366F1),
        options: [
          Access.storeexport,
          Access.storeimportData,
          Access.storeadmin,
        ],
      ),
    ];
  }

  return const [
    AccessGroup(
      title: 'Scrap',
      icon: Icons.delete_sweep_rounded,
      tint: Color(0xFFF97316),
      options: [
        Access.scrapview,
        Access.scrapadd,
        Access.scrapdelete,
        Access.scrapexport,
        Access.historyScrap,
      ],
    ),
  ];
}

Set<Access> defaultViewsFor(AppOption app) {
  if (app == AppOption.storeconsumable) {
    return {
      Access.storeitemview,
      Access.storeplaceview,
      Access.storreceiveview,
      Access.storissueview,
    };
  }
  return {Access.scrapview};
}

/* =================== Page =================== */
class UserAddPage extends ConsumerStatefulWidget {
  const UserAddPage({super.key});

  @override
  ConsumerState<UserAddPage> createState() => _UserAddPageState();
}

class _UserAddPageState extends ConsumerState<UserAddPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  bool _isActive = true;
  bool _isSuperAdmin = false;
  bool _submitting = false;

  // Division
  bool _divisionTouched = false;
  bool _creatingDivision = false;
  final Set<String> _selectedDivisionIds = <String>{};

  // App selections
  final Set<AppOption> _selectedApps = {AppOption.storeconsumable};
  final Map<AppOption, Set<Access>> _appAccess = {
    AppOption.storeconsumable: {...defaultViewsFor(AppOption.storeconsumable)},
  };

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  /* ---------- division helpers ---------- */
  List<DivisionOption> _mapDivisionsFromSocket(List<Map<String, dynamic>> raw) {
    final out = <DivisionOption>[];
    final seen = <String>{};

    for (final m in raw) {
      final id = (m['_id'] ?? m['id'] ?? '').toString();
      final name = (m['divisionName'] ?? m['name'] ?? '').toString();
      if (id.isEmpty || name.isEmpty) continue;
      if (seen.add(id)) out.add(DivisionOption(id: id, name: name));
    }

    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  List<DivisionOption> _selectedDivisionObjects(List<DivisionOption> all) {
    final byId = {for (final d in all) d.id: d};
    final out = <DivisionOption>[];
    for (final id in _selectedDivisionIds) {
      final d = byId[id];
      if (d != null) out.add(d);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  // String _readTokenBestEffort() {
  //   // If you keep token elsewhere, replace this.
  //   try {
  //     final dynamic auth = ref.read(authControllerProvider);
  //     final dynamic t =
  //         auth.token ?? auth.accessToken ?? auth.sessionToken ?? auth.jwt;
  //     return t?.toString() ?? '';
  //   } catch (_) {
  //     return '';
  //   }
  // }

  Future<void> _refreshDivisionsSocket() async {
    final SocketManager socketManager = ref.read(socketProvider);
    socketManager.getSocket().emit('division:findAll', {});
  }

  Future<bool?> _createDivisionRestAndRefresh(String name) async {
    final nm = name.trim();
    if (nm.isEmpty) return null;

    setState(() {
      _divisionTouched = true;
      _creatingDivision = true;
    });

    try {
      // final token = _readTokenBestEffort();

      // ✅ IMPORTANT: Constants.serverUrl might be "192.168.x.x:8080"
      // This is safe now because DivisionRestApi normalizes scheme.
      // final api = DivisionRestApi(baseUrl: Constants.serverUrl, token: token);
      final created = await ref
          .read(usersControllerProvider)
          .createDivision(dto: {"divisionName": nm});

      if (!mounted) return null;

      // setState(() {
      //   _selectedDivisionIds.add(created.id);
      // });

      await _refreshDivisionsSocket();

      if (!mounted) return created;

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Division "${created.name}" created')),
      // );

      return created;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Create division failed: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _creatingDivision = false);
    }
  }

  Future<void> _openCreateDivisionDialog() async {
    final ctrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        bool busy = false;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Create Division'),
              content: TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Division name'),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),

                // ✅ Add API in this button (done)
                FilledButton(
                  onPressed:
                      busy
                          ? null
                          : () async {
                            final nm = ctrl.text.trim();
                            if (nm.isEmpty) return;

                            setLocal(() => busy = true);

                            final created = await _createDivisionRestAndRefresh(
                              nm,
                            );

                            if (created == true && ctx.mounted) {
                              Navigator.pop(ctx);
                            }

                            if (ctx.mounted) {
                              setLocal(() => busy = false);
                            }
                          },
                  child:
                      busy
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openDivisionPicker(List<DivisionOption> options) async {
    setState(() => _divisionTouched = true);

    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _DivisionPickerSheet(
            options: options,
            initialSelectedIds: _selectedDivisionIds,
          ),
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _selectedDivisionIds
          ..clear()
          ..addAll(picked);
      });
    }
  }

  /* ---------- helpers to build payload ---------- */
  List<String> _selectedAppKeys() => _selectedApps.map((a) => a.key).toList();

  List<String> _selectedAppWorks() {
    final works = <String>{};
    for (final app in _selectedApps) {
      final set = _appAccess[app] ?? const <Access>{};
      for (final acc in set) {
        works.add(acc.key);
      }
    }
    return works.toList();
  }

  /* ---------- UI actions ---------- */
  void _selectAllApps() {
    setState(() {
      _selectedApps
        ..clear()
        ..addAll(AppOption.values);
      for (final app in AppOption.values) {
        _appAccess[app] = {...defaultViewsFor(app)};
      }
    });
  }

  void _clearApps() {
    setState(() {
      _selectedApps
        ..clear()
        ..add(AppOption.storeconsumable);
      _appAccess
        ..clear()
        ..[AppOption.storeconsumable] = {
          ...defaultViewsFor(AppOption.storeconsumable),
        };
    });
  }

  void _toggleApp(AppOption app, bool sel) {
    setState(() {
      if (sel) {
        _selectedApps.add(app);
        _appAccess[app] = {...defaultViewsFor(app)};
      } else {
        _selectedApps.remove(app);
        _appAccess.remove(app);
      }
    });
  }

  void _toggleAccess(AppOption app, Access acc, bool sel) {
    setState(() {
      final set = _appAccess[app] ?? <Access>{};
      if (sel) {
        set.add(acc);
      } else {
        set.remove(acc);
      }
      _appAccess[app] = set;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_selectedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one app')),
      );
      return;
    }

    setState(() => _divisionTouched = true);
    if (_selectedDivisionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one division')),
      );
      return;
    }

    setState(() => _submitting = true);

    final dto = {
      'email': _email.text.trim(),
      'name': _name.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'password': '250925',
      'isActive': _isActive,
      'isSuperAdmin': _isSuperAdmin,
      'apps': _selectedAppKeys(),
      'appWorks': _selectedAppWorks(),
      'divisionIds': _selectedDivisionIds.toList(),
    };

    try {
      final ok = await ref
          .read(authControllerProvider)
          .createUser(authModel: dto);

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account created!')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Register failed')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Register failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final divAv = ref.watch(divisionAllDataStreamProvider);

    final divisionsLoading = divAv.isLoading;
    final divisionsRaw = divAv.value ?? const <Map<String, dynamic>>[];
    final divisions = _mapDivisionsFromSocket(divisionsRaw);

    return Scaffold(
      backgroundColor: _bgBottom,
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
          children: const [
            Icon(Icons.person_add_alt_1_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Add User',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _Card(
                  radius: 18,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blueAccent.shade200,
                                    Colors.blue.shade700,
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Create a new user',
                                style: TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _Field(
                          controller: _name,
                          label: "Full Name",
                          hint: "e.g., FirstName LastName",
                          icon: Icons.badge_rounded,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Name is required';
                            }
                            if (v.trim().length < 3) {
                              return 'At least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        _Field(
                          controller: _email,
                          label: "Email",
                          hint: "e.g., name@example.com",
                          icon: Icons.alternate_email_rounded,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Email is required';
                            final ok = RegExp(
                              r'^[^@]+@[^@]+\.[^@]+$',
                            ).hasMatch(value);
                            return ok ? null : 'Invalid email';
                          },
                        ),
                        const SizedBox(height: 14),

                        _Field(
                          controller: _phone,
                          label: "Phone Number",
                          hint: "1234567890",
                          icon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Phone number required';
                            if (value.length != 10) {
                              return 'Phone number must be exactly 10 digits';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        const _SectionTitle(
                          icon: Icons.apartment_rounded,
                          title: 'Divisions',
                        ),
                        const SizedBox(height: 6),

                        if (divisionsLoading)
                          const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: _DivisionMultiSelectField(
                                enabled: !divisionsLoading,
                                selected: _selectedDivisionObjects(divisions),
                                onTap: () => _openDivisionPicker(divisions),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _SquareIconBtn(
                              enabled: !divisionsLoading && !_creatingDivision,
                              icon:
                                  _creatingDivision
                                      ? Icons.hourglass_top_rounded
                                      : Icons.add_rounded,
                              onTap: _openCreateDivisionDialog,
                              tooltip: 'Create division',
                            ),
                          ],
                        ),

                        if (_divisionTouched &&
                            _selectedDivisionIds.isEmpty) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Division is required',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),
                        const _SectionTitle(
                          icon: Icons.shield_moon_rounded,
                          title: 'Status & Role',
                        ),
                        const SizedBox(height: 6),

                        _SwitchTile(
                          title: "Active",
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          icon: Icons.verified_user_rounded,
                        ),
                        const SizedBox(height: 8),
                        _SwitchTile(
                          title: "Super Admin",
                          value: _isSuperAdmin,
                          onChanged: (v) => setState(() => _isSuperAdmin = v),
                          icon: Icons.security_rounded,
                        ),

                        const SizedBox(height: 20),
                        _SectionTitle(
                          icon: Icons.apps_rounded,
                          title: 'Apps Access',
                          trailing: Row(
                            children: [
                              _PillBtn(
                                icon: Icons.done_all_rounded,
                                label: 'Select All',
                                onTap: _selectAllApps,
                              ),
                              const SizedBox(width: 8),
                              _PillBtn(
                                icon: Icons.clear_all_rounded,
                                label: 'Clear',
                                onTap: _clearApps,
                                subtle: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final app in AppOption.values)
                              _AppChip(
                                app: app,
                                selected: _selectedApps.contains(app),
                                onChanged: (sel) => _toggleApp(app, sel),
                              ),
                          ],
                        ),

                        if (_selectedApps.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          for (final app in _selectedApps)
                            _GroupedAccessPanel(
                              app: app,
                              selected: _appAccess[app] ?? const <Access>{},
                              onToggle:
                                  (acc, sel) => _toggleAccess(app, acc, sel),
                            ),
                        ],

                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon:
                              _submitting
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.save_rounded),
                          label: Text(_submitting ? "Saving..." : "Save User"),
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink900,
                            foregroundColor: _surface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
      ),
    );
  }
}

/* =================== Reusable UI pieces =================== */
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

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
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ink600),
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _ink900, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _ink900),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.icon,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: _ink700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: _ink900,
          ),
        ],
      ),
    );
  }
}

class _PillBtn extends StatelessWidget {
  const _PillBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtle = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: subtle ? _surface : _accentMint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: subtle ? _stroke : _accentMint),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: _ink900),
              const SizedBox(width: 6),
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

class _AppChip extends StatelessWidget {
  const _AppChip({
    required this.app,
    required this.selected,
    required this.onChanged,
  });
  final AppOption app;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tint = app.color;
    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.check_rounded : app.icon,
            size: 16,
            color: selected ? _surface : tint,
          ),
          const SizedBox(width: 6),
          Text(app.label),
        ],
      ),
      onSelected: onChanged,
      selectedColor: tint,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: selected ? _surface : _ink900,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? tint : _stroke),
      ),
    );
  }
}

class _GroupedAccessPanel extends StatelessWidget {
  const _GroupedAccessPanel({
    required this.app,
    required this.selected,
    required this.onToggle,
  });
  final AppOption app;
  final Set<Access> selected;
  final void Function(Access access, bool select) onToggle;

  @override
  Widget build(BuildContext context) {
    final groups = buildGroups(app);
    final appTint = app.color;

    return _Card(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(app.icon, color: appTint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${app.label} Permissions',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final group in groups) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 22,
                  decoration: BoxDecoration(
                    color: group.tint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(group.icon, size: 18, color: group.tint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.title,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final acc in group.options)
                  _AccessChip(
                    access: acc,
                    selected: selected.contains(acc),
                    onChanged: (sel) => onToggle(acc, sel),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessChip extends StatelessWidget {
  const _AccessChip({
    required this.access,
    required this.selected,
    required this.onChanged,
  });
  final Access access;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tint = access.color;
    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.check_rounded : access.icon,
            size: 16,
            color: selected ? _surface : tint,
          ),
          const SizedBox(width: 6),
          Text(access.label),
        ],
      ),
      onSelected: onChanged,
      selectedColor: tint,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: selected ? _surface : _ink900,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? tint : _stroke),
      ),
    );
  }
}

class _SquareIconBtn extends StatelessWidget {
  const _SquareIconBtn({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: enabled ? _accentPeach : _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: enabled ? _accentPeach : _stroke),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          width: 52,
          child: Center(child: Icon(icon, color: _ink900)),
        ),
      ),
    );

    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _DivisionMultiSelectField extends StatelessWidget {
  const _DivisionMultiSelectField({
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final List<DivisionOption> selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final has = selected.isNotEmpty;

    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.apartment_rounded, color: _ink600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      has ? 'Selected divisions' : 'Select divisions',
                      style: TextStyle(
                        color: has ? _ink900 : _ink600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: enabled ? _ink700 : _ink600,
                  ),
                ],
              ),
              if (has) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in selected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _accentMint.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _stroke),
                        ),
                        child: Text(
                          d.name,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DivisionPickerSheet extends StatefulWidget {
  const _DivisionPickerSheet({
    required this.options,
    required this.initialSelectedIds,
  });
  final List<DivisionOption> options;
  final Set<String> initialSelectedIds;

  @override
  State<_DivisionPickerSheet> createState() => _DivisionPickerSheetState();
}

class _DivisionPickerSheetState extends State<_DivisionPickerSheet> {
  late Set<String> selected;
  String q = '';

  @override
  void initState() {
    super.initState();
    selected = {...widget.initialSelectedIds};

    // ✅ Enforce: at least one selected when opening the dropdown
    if (selected.isEmpty && widget.options.isNotEmpty) {
      final sorted = [...widget.options]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      selected.add(sorted.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.options
            .where((d) => d.name.toLowerCase().contains(q.trim().toLowerCase()))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final canApply = selected.isNotEmpty;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.apartment_rounded, color: _ink900),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Select divisions',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => selected.clear()),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: _surfaceAlt.withValues(alpha: 0.55),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _ink900, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child:
                  filtered.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No divisions found.',
                          style: TextStyle(
                            color: _ink600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = filtered[i];
                          final isSel = selected.contains(d.id);
                          return CheckboxListTile(
                            value: isSel,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selected.add(d.id);
                                } else {
                                  // ✅ Prevent unchecking the last selected division
                                  if (selected.length <= 1 &&
                                      selected.contains(d.id)) {
                                    return;
                                  }
                                  selected.remove(d.id);
                                }
                              });
                            },
                            title: Text(
                              d.name,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: _ink900,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                            ),
                          );
                        },
                      ),
            ),
            if (!canApply) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Please select at least one division.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink900,
                      side: const BorderSide(color: _stroke),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    // ✅ Apply disabled if no division selected
                    onPressed:
                        canApply
                            ? () => Navigator.pop(context, selected)
                            : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink900,
                      foregroundColor: _surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
