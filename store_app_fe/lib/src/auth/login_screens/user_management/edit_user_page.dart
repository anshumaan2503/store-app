import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:store_app/src/components/constants.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/users_controller.dart';
import '../../domains/models/auth_model.dart';

/* =================== Palette (from your colors) =================== */
// Primary neutrals
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

// Surfaces
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

// Accents
const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

// Page background blend
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

/* =================== Helpers for Division maps =================== */
String _divId(Map<String, dynamic> d) =>
    (d['_id'] ?? d['id'] ?? '').toString().trim();

String _divName(Map<String, dynamic> d) =>
    (d['divisionName'] ?? d['name'] ?? d['title'] ?? '').toString().trim();

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
    AppOption.storeconsumable => const Color.fromARGB(255, 178, 171, 233),
    AppOption.scrap => const Color(0xFFFD2929),
    AppOption.stock => const Color.fromARGB(255, 42, 227, 252),
  };
}

/* =================== Access Enum =================== */
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
    Access.storeitemtransfer => const Color.fromARGB(255, 73, 247, 247),
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

/* =================== Suggested defaults =================== */
final Map<AppOption, List<Access>> kSuggestedAppAccess = {
  AppOption.storeconsumable: [
    Access.storeitemview,
    Access.storeitemadd,
    Access.storeitemedit,
    Access.storeitemdelete,
    Access.storeitemtransfer,
    Access.storeitemfind,
    Access.storeitemrateview,
    Access.storeplaceview,
    Access.storeplaceadd,
    Access.storeplaceedit,
    Access.storeplacedelete,
    Access.storreceiveview,
    Access.storreceiveadd,
    Access.storreceiveedit,
    Access.storreceivereject,
    Access.storreceiveapprove,
    Access.storreceiveclose,
    Access.storreceivetostock,
    Access.historyReceiveItem,
    Access.storissueview,
    Access.storissueadd,
    Access.storissueedit,
    Access.storissuereject,
    Access.storissueapprove,
    Access.storissueclose,
    Access.storissuefromstock,
    Access.storissuereturn,
    Access.historyissueItem,
    Access.storeindentview,
    Access.storeindentdraft,
    Access.storeindentraise,
    Access.storeindentconsolidation,
    Access.storeindentapprove,
    Access.storeindentreject,
    Access.storeindenthistory,
    Access.storeexport,
    Access.storeimportData,
    Access.storeadmin,
  ],
  AppOption.scrap: [
    Access.scrapview,
    Access.scrapadd,
    Access.scrapdelete,
    Access.scrapexport,
    Access.historyScrap,
  ],
};

/* =================== EDIT PAGE =================== */

class UserEditPage extends ConsumerStatefulWidget {
  const UserEditPage({
    super.key,
    required this.initial,
    required this.currentViewerIsAdmin,
    this.isEditingSelf = false,
  });

  final AuthModel initial;
  final bool currentViewerIsAdmin;
  final bool isEditingSelf;

  @override
  ConsumerState<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends ConsumerState<UserEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.initial.email,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initial.phoneNumber,
  );

  // Self password change (at least 6 chars) — optional
  final _newPsw = TextEditingController();
  final _confirmPsw = TextEditingController();

  bool _isActive = true;
  bool _isSuperAdmin = false;
  bool _submitting = false;
  bool _resetting = false;

  // avatar state
  final _picker = ImagePicker();
  bool _avatarBusy = false;
  Uint8List? _avatarLocalBytes;
  String? _photoUrl;

  // selection state (apps/permissions)
  final Set<AppOption> _selectedApps = {};
  final Map<AppOption, Set<Access>> _appAccess = {};

  // Division multi-select
  final Set<String> _selectedDivisionIds = <String>{};
  Set<String> _missingDivisionIds = <String>{};
  bool _divisionReconciled = false;

  bool get _admin => widget.currentViewerIsAdmin;
  bool get _self => widget.isEditingSelf;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initial.isActive;
    _isSuperAdmin = widget.initial.isSuperAdmin;

    _hydrateFromModel(widget.initial.apps, widget.initial.appWorks);

    final img = widget.initial.imageUrl;
    _photoUrl = (img.trim().isNotEmpty == true) ? img.trim() : null;

    _selectedDivisionIds
      ..clear()
      ..addAll(
        (widget.initial.divisionIds).map(
          (e) => e.toString(),
        ),
      );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _newPsw.dispose();
    _confirmPsw.dispose();
    super.dispose();
  }

  // Best-effort token getter for protected APIs (photo upload)
  String _readTokenBestEffort() {
    try {
      final dynamic auth = ref.read(authControllerProvider);
      final dynamic t =
          auth.token ?? auth.accessToken ?? auth.sessionToken ?? auth.jwt;
      return t?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _normalizeHttpBase(String base) {
    var b = base.trim();
    if (b.isEmpty) return b;

    if (b.startsWith('ws://')) b = 'http://${b.substring(5)}';
    if (b.startsWith('wss://')) b = 'https://${b.substring(6)}';

    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      b = 'http://$b';
    }

    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b;
  }

  void _hydrateFromModel(List<String> apps, List<String> appWorks) {
    _selectedApps.clear();
    _appAccess.clear();

    for (final key in apps) {
      final app = AppOption.values.firstWhere(
        (a) => a.key == key,
        orElse: () => AppOption.storeconsumable,
      );
      _selectedApps.add(app);
    }

    for (final app in _selectedApps) {
      final allowed = kSuggestedAppAccess[app] ?? const <Access>[];

      final worksForApp =
          appWorks
              .map((w) {
                for (final a in Access.values) {
                  if (a.key == w) return a;
                }
                return null;
              })
              .whereType<Access>()
              .where((a) => allowed.contains(a))
              .toSet();

      _appAccess[app] = worksForApp.isNotEmpty ? worksForApp : {...allowed};
    }

    if (_selectedApps.isEmpty) {
      _selectedApps.add(AppOption.storeconsumable);
      _appAccess[AppOption.storeconsumable] = {
        ...?kSuggestedAppAccess[AppOption.storeconsumable]?.toSet(),
      };
    }
  }

  List<String> _appsArray() => _selectedApps.map((a) => a.key).toList();

  List<String> _appWorksArray() {
    final s = <String>{};
    for (final app in _selectedApps) {
      final set = _appAccess[app] ?? const <Access>{};
      s.addAll(set.map((e) => e.key));
    }
    return s.toList();
  }

  void _toggleApp(AppOption app, bool sel) {
    if (!_admin) return;

    setState(() {
      if (sel) {
        _selectedApps.add(app);
        _appAccess[app] ??= {...(kSuggestedAppAccess[app] ?? const <Access>[])};
      } else {
        if (_selectedApps.length <= 1 && _selectedApps.contains(app)) return;
        _selectedApps.remove(app);
        _appAccess.remove(app);
      }
    });
  }

  void _toggleAccess(AppOption app, Access acc, bool sel) {
    if (!_admin) return;

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

    // ✅ VALIDATE FORM (includes Division validation via FormField below)
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) {
      // optional UX: show snackbar for division quickly
      if (_admin && _selectedDivisionIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one division')),
        );
      }
      return;
    }

    // If self is changing password, validate BEFORE update call.
    if (_self && (_newPsw.text.isNotEmpty || _confirmPsw.text.isNotEmpty)) {
      final np = _newPsw.text.trim();
      final cp = _confirmPsw.text.trim();

      if (np.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 6 characters')),
        );
        return;
      }
      if (np != cp) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      final dto = {
        'id': widget.initial.uid,
        'email': _email.text.trim(),
        'name': _name.text.trim(),
        'phoneNumber': _phone.text.trim(),

        // ✅ send division IDs (admin can edit; non-admin keeps existing)
        'divisionIds':
            _admin
                ? _selectedDivisionIds.toList()
                : (widget.initial.divisionIds),

        'isActive': _admin ? _isActive : widget.initial.isActive,
        'isSuperAdmin': _admin ? _isSuperAdmin : widget.initial.isSuperAdmin,
        'apps': _admin ? _appsArray() : widget.initial.apps,
        'appWorks': _admin ? _appWorksArray() : widget.initial.appWorks,
      };

      final ok = await ref
          .read(authControllerProvider)
          .updateUser(authModel: dto);

      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Update failed')));
        return;
      }

      // Optional password change (self)
      if (_self && (_newPsw.text.isNotEmpty || _confirmPsw.text.isNotEmpty)) {
        final body = {
          "userId": widget.initial.uid,
          "newPassword": _newPsw.text.trim(),
        };
        final pwdOk = await ref
            .read(authControllerProvider)
            .resetPasswordUser(authModel: body);

        if (!mounted) return;

        if (!pwdOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password change failed')),
          );
          return;
        }
      }

      if (!mounted) return;

      ref.invalidate(userFindOneDataStreamProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User updated')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPasswordAdmin() async {
    if (!_admin) return;

    setState(() => _resetting = true);
    try {
      final body = {"userId": widget.initial.uid, "newPassword": '250925'};
      final ok = await ref
          .read(authControllerProvider)
          .resetPasswordUser(authModel: body);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Password reset to 250925' : 'Reset failed'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset failed: $e')));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _pickAvatar(ImageSource src) async {
    final x = await _picker.pickImage(
      source: src,
      imageQuality: 88,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (x == null) return;

    final bytes = await x.readAsBytes();

    setState(() {
      _avatarLocalBytes = bytes;
      _avatarBusy = true;
    });

    try {
      final base = _normalizeHttpBase(Constants.socketUrl);
      final newUrl = await _uploadUserPhotoBase64(
        baseUrl: base,
        uid: widget.initial.uid,
        bytes: bytes,
        filename: x.name,
        bearerToken: _readTokenBestEffort(),
      );

      if (!mounted) return;

      setState(() => _photoUrl = newUrl);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<String> _uploadUserPhotoBase64({
    required String baseUrl,
    required String uid,
    required Uint8List bytes,
    required String bearerToken,
    String filename = 'avatar.jpg',
  }) async {
    if (baseUrl.isEmpty) {
      throw Exception(
        'Base URL is empty. Check Constants.socketUrl (must be HTTP).',
      );
    }

    String mime = 'image/jpeg';
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) mime = 'image/png';
    if (lower.endsWith('.webp')) mime = 'image/webp';

    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    final uri = Uri.parse('$baseUrl/api/auth/$uid/image/base64');

    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (bearerToken.isNotEmpty) 'Authorization': 'Bearer $bearerToken',
          },
          body: jsonEncode({'base64': dataUrl}),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic> bodyJson = {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) bodyJson = decoded;
    } catch (_) {}

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg =
          (bodyJson['msg'] ?? bodyJson['error'] ?? utf8.decode(res.bodyBytes))
              .toString();
      throw Exception(msg);
    }

    final url =
        (bodyJson['imageUrl'] ??
                bodyJson['user']?['imageUrl'] ??
                bodyJson['entity']?['imageUrl'])
            ?.toString();

    if (url == null || url.isEmpty) {
      throw Exception('Upload OK but no imageUrl returned');
    }

    return url;
  }

  void _showAvatarSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Container(
              color: _surface,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.camera_alt_outlined,
                        color: _ink900,
                      ),
                      title: const Text(
                        'Take Photo',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAvatar(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.photo_library_outlined,
                        color: _ink900,
                      ),
                      title: const Text(
                        'Choose from Gallery',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAvatar(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  /* ================= Division UI helpers ================= */

  Future<Set<String>?> _openDivisionMultiSelectDialog({
    required BuildContext context,
    required List<Map<String, dynamic>> all,
    required Set<String> selectedIds,
  }) async {
    return showDialog<Set<String>>(
      context: context,
      builder:
          (_) => _DivisionMultiSelectDialog(
            all: all,
            initiallySelected: selectedIds,
          ),
    );
  }

  // ✅ compact dropdown field + ✅ supports Form error rendering
  Widget _buildMultiSelectField({
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled,
    required VoidCallback? onTap,
    required Widget? chips,
    String? errorText, // ✅ NEW
  }) {
    final hasSelection = _selectedDivisionIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              constraints: const BoxConstraints(minHeight: 44),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              prefixIcon: Icon(icon, color: _ink600, size: 20),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              suffixIcon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: enabled ? _ink600 : _ink600.withValues(alpha: .4),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 44,
              ),
              filled: true,
              fillColor: _surface,

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _ink900, width: 1.2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _stroke.withValues(alpha: .7)),
              ),

              // ✅ error UI
              errorText: errorText,
              errorStyle: const TextStyle(
                color: Color(0xFF7E1C1C),
                fontWeight: FontWeight.w600,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7E1C1C)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF7E1C1C),
                  width: 1.2,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hasSelection ? '${_selectedDivisionIds.length} selected' : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: hasSelection ? _ink900 : _ink600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        if (chips != null) ...[const SizedBox(height: 10), chips],
      ],
    );
  }

  Widget? _buildDivisionChips(
    List<Map<String, dynamic>> divisions, {
    VoidCallback? onSelectionChanged, // ✅ NEW
  }) {
    final idToName = <String, String>{
      for (final d in divisions)
        if (_divId(d).isNotEmpty) _divId(d): _divName(d),
    };

    final validSelectedIds = _selectedDivisionIds
        .where((id) => (idToName[id]?.trim().isNotEmpty == true))
        .toList();

    if (validSelectedIds.isEmpty) return null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in validSelectedIds)
          Chip(
            label: Text(
              idToName[id]!,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: _surfaceAlt,
            side: const BorderSide(color: _stroke),
            deleteIcon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: _ink700,
            ),
            onDeleted:
                !_admin
                    ? null
                    : () {
                      setState(() {
                        _selectedDivisionIds.remove(id);
                        _missingDivisionIds.remove(id);
                      });
                      onSelectionChanged?.call(); // ✅ revalidate
                    },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }

  // ✅ NEW: Division validation integrated into Form
  Widget _divisionValidatedField(
    AsyncValue<List<Map<String, dynamic>>> divisionsAv,
  ) {
    return FormField<int>(
      validator: (_) {
        if (_admin && _selectedDivisionIds.isEmpty) {
          return 'Select at least one division';
        }
        return null;
      },
      builder: (state) {
        return _divisionField(
          divisionsAv,
          errorText: state.errorText,
          onSelectionChanged:
              () => state.didChange(_selectedDivisionIds.length),
        );
      },
    );
  }

  Widget _divisionHeaderPill(
    AsyncValue<List<Map<String, dynamic>>> divisionsAv,
  ) {
    if (_selectedDivisionIds.isEmpty) return const SizedBox.shrink();

    return divisionsAv.when(
      loading:
          () => _StatusPill(
            label: 'Divisions: ${_selectedDivisionIds.length}',
            icon: Icons.account_tree_outlined,
            fg: _ink700,
            bg: _surfaceAlt,
            border: _stroke,
          ),
      error:
          (_, __) => _StatusPill(
            label: 'Divisions: ${_selectedDivisionIds.length}',
            icon: Icons.account_tree_outlined,
            fg: _ink700,
            bg: _surfaceAlt,
            border: _stroke,
          ),
      data: (divisions) {
        final idToName = <String, String>{
          for (final d in divisions)
            if (_divId(d).isNotEmpty) _divId(d): _divName(d),
        };

        final names =
            _selectedDivisionIds
                .map((id) => idToName[id]?.trim() ?? '')
                .where((name) => name.isNotEmpty)
                .toList();

        final label =
            names.length == 1
                ? names.first
                : 'Divisions: ${_selectedDivisionIds.length}';
        return _StatusPill(
          label: label,
          icon: Icons.account_tree_outlined,
          fg: _ink700,
          bg: _surfaceAlt,
          border: _stroke,
        );
      },
    );
  }

  // ✅ UPDATED: accepts errorText + onSelectionChanged
  Widget _divisionField(
    AsyncValue<List<Map<String, dynamic>>> divisionsAv, {
    String? errorText,
    VoidCallback? onSelectionChanged,
  }) {
    return divisionsAv.when(
      loading:
          () => _buildMultiSelectField(
            label: 'Division',
            hint: 'Loading divisions...',
            icon: Icons.account_tree_outlined,
            enabled: false,
            onTap: null,
            chips:
                _selectedDivisionIds.isEmpty ? null : const SizedBox.shrink(),
            errorText: errorText,
          ),
      error:
          (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMultiSelectField(
                label: 'Division',
                hint: 'Failed to load divisions',
                icon: Icons.account_tree_outlined,
                enabled: false,
                onTap: null,
                chips:
                    _selectedDivisionIds.isEmpty
                        ? null
                        : const SizedBox.shrink(),
                errorText: errorText,
              ),
              const SizedBox(height: 6),
              Text(
                'Division load error: $e',
                style: const TextStyle(
                  color: Color(0xFF7E1C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      data: (divisions) {
        // reconcile once
        if (!_divisionReconciled) {
          final availableIds =
              divisions.map(_divId).where((x) => x.isNotEmpty).toSet();
          final missing =
              _selectedDivisionIds
                  .where((id) => !availableIds.contains(id))
                  .toSet();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _missingDivisionIds = missing;
              _divisionReconciled = true;
            });
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMultiSelectField(
              label: 'Division',
              hint: 'Select one or more divisions',
              icon: Icons.account_tree_outlined,
              enabled: _admin,
              errorText: errorText,
              onTap:
                  !_admin
                      ? null
                      : () async {
                        final picked = await _openDivisionMultiSelectDialog(
                          context: context,
                          all: divisions,
                          selectedIds: _selectedDivisionIds,
                        );
                        if (picked == null) return;

                        setState(() {
                          _selectedDivisionIds
                            ..clear()
                            ..addAll(picked);

                          final availableIds =
                              divisions
                                  .map(_divId)
                                  .where((x) => x.isNotEmpty)
                                  .toSet();
                          _missingDivisionIds =
                              _selectedDivisionIds
                                  .where((id) => !availableIds.contains(id))
                                  .toSet();
                        });

                        onSelectionChanged?.call(); // ✅ revalidate
                      },
              chips:
                  _selectedDivisionIds.isEmpty
                      ? null
                      : _buildDivisionChips(
                        divisions,
                        onSelectionChanged: onSelectionChanged,
                      ),
            ),
            if (_missingDivisionIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              _StatusPill(
                label: 'Missing division IDs: ${_missingDivisionIds.length}',
                icon: Icons.warning_amber_rounded,
                fg: const Color(0xFF7E1C1C),
                bg: const Color(0xFFF9D6D5),
                border: const Color(0xFFF1B0B7),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;

    // must return AsyncValue<List<Map<String, dynamic>>> (as in your existing code)
    final divisionsAv = ref.watch(divisionAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _bgBottom,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.manage_accounts_rounded, color: _ink900),
            const SizedBox(width: 8),
            Text(
              widget.isEditingSelf ? 'Edit Profile' : 'Edit User',
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW > 720 ? 720 : maxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== Header Card =====
                    _Card(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Row(
                        children: [
                          _Avatar(
                            bytes: _avatarLocalBytes,
                            url: _photoUrl,
                            busy: _avatarBusy,
                            onTap: _showAvatarSheet,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.initial.name.isNotEmpty
                                      ? widget.initial.name
                                      : 'User',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatusPill(
                                      label: _isActive ? 'ACTIVE' : 'INACTIVE',
                                      icon:
                                          _isActive
                                              ? Icons.verified
                                              : Icons.block,
                                      fg:
                                          _isActive
                                              ? const Color(0xFF155724)
                                              : const Color(0xFF7E1C1C),
                                      bg:
                                          _isActive
                                              ? const Color(0xFFD4EDDA)
                                              : const Color(0xFFF9D6D5),
                                      border:
                                          _isActive
                                              ? const Color(0xFFB7E4C7)
                                              : const Color(0xFFF1B0B7),
                                    ),
                                    if ((widget.initial.email).isNotEmpty)
                                      _StatusPill(
                                        label: widget.initial.email,
                                        icon: Icons.mail_outline,
                                        fg: _ink700,
                                        bg: _surfaceAlt,
                                        border: _stroke,
                                      ),
                                    _divisionHeaderPill(divisionsAv),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== Form Card =====
                    _Card(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionTitle('Basic Info', Icons.person_outline),
                            const SizedBox(height: 10),

                            _buildField(
                              controller: _name,
                              enabled: true,
                              label: "Full Name",
                              hint: "e.g., FirstName LastName",
                              icon: Icons.badge_rounded,
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return 'Name is required';
                                if (t.length < 3) {
                                  return 'At least 3 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            _buildField(
                              controller: _email,
                              enabled: true,
                              label: "Email",
                              hint: "name@example.com",
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

                            _buildField(
                              controller: _phone,
                              enabled: true,
                              label: "Phone Number",
                              hint: "1234567890",
                              icon: Icons.phone_iphone_rounded,
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) {
                                  return 'Phone number required';
                                }
                                if (value.length != 10) {
                                  return 'Phone must be exactly 10 digits';
                                }
                                return null;
                              },
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),

                            // ✅ Division multi-select (validated: at least one)
                            const SizedBox(height: 14),
                            _divisionValidatedField(divisionsAv),

                            if (_admin) ...[
                              const SizedBox(height: 18),
                              _SectionTitle('Admin', Icons.verified_user),
                              const SizedBox(height: 6),
                              _SwitchTile(
                                title: 'Active',
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                              ),
                              _SwitchTile(
                                title: 'Super Admin',
                                value: _isSuperAdmin,
                                onChanged:
                                    (v) => setState(() => _isSuperAdmin = v),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    if (_admin) ...[
                      const SizedBox(height: 16),
                      _Card(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle('Apps Access', Icons.apps_rounded),
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
                              const SizedBox(height: 10),
                              for (final app in _selectedApps)
                                _AccessPanel(
                                  app: app,
                                  selected: _appAccess[app] ?? const <Access>{},
                                  onToggle:
                                      (acc, sel) =>
                                          _toggleAccess(app, acc, sel),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    if (_admin) ...[
                      _Card(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              'Password',
                              Icons.lock_person_outlined,
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed:
                                  _resetting ? null : _resetPasswordAdmin,
                              icon:
                                  _resetting
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.refresh_rounded),
                              label: Text(
                                _resetting ? 'Resetting...' : 'Reset to 250925',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _ink900,
                                foregroundColor: _surface,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_self) ...[
                      _Card(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              'Change Password',
                              Icons.lock_outline,
                            ),
                            const SizedBox(height: 10),
                            PasswordField(
                              controller: _newPsw,
                              label: "New Password (optional)",
                              icon: Icons.lock_reset_rounded,
                              optional: true,
                            ),
                            const SizedBox(height: 12),
                            PasswordField(
                              controller: _confirmPsw,
                              label: "Confirm new password (optional)",
                              icon: Icons.lock_outline_rounded,
                              optional: true,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
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
                        label: Text(_submitting ? "Saving..." : "Save"),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          backgroundColor: _ink900,
                          foregroundColor: _surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
    );
  }

  /* ======= Field builder (palette UI) ======= */
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surface,
            hintStyle: const TextStyle(color: _ink600),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _ink900, width: 1.2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _stroke.withValues(alpha: .7)),
            ),
          ),
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/* =================== Reusable UI Bits =================== */

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _ink600),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [_accentPeach, _accentMint],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
        ),
        value: value,
        onChanged: onChanged,
        secondary: const Icon(Icons.tune_rounded, color: _ink600),
        activeThumbColor: _ink900,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.bytes,
    required this.url,
    required this.busy,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String? url;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (bytes != null) {
      child = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (url != null && url!.isNotEmpty) {
      child = Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => const Icon(Icons.person_outline, color: _ink600),
        loadingBuilder:
            (ctx, c, p) =>
                p == null
                    ? c
                    : const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
      );
    } else {
      child = const Icon(Icons.person_outline, color: _ink600);
    }

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _surface,
              border: Border.all(color: _stroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: child),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: _surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: busy ? null : onTap,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child:
                      busy
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                            color: _ink900,
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ======= App Chip ======= */
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
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      backgroundColor: tint.withValues(alpha: .10),
      selectedColor: tint.withValues(alpha: .25),
      side: BorderSide(color: tint.withValues(alpha: .40)),
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder:
                (child, anim) => ScaleTransition(scale: anim, child: child),
            child:
                selected
                    ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('tick'),
                      size: 16,
                      color: _surface,
                    )
                    : const SizedBox(
                      key: ValueKey('notick'),
                      width: 0,
                      height: 0,
                    ),
          ),
          if (selected) const SizedBox(width: 6),
          Icon(app.icon, size: 16, color: selected ? _surface : tint),
          const SizedBox(width: 6),
          Text(
            app.label,
            style: TextStyle(
              color: selected ? _surface : tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/* ======= Access Panel (grouped) ======= */
class _AccessPanel extends StatelessWidget {
  const _AccessPanel({
    required this.app,
    required this.selected,
    required this.onToggle,
  });

  final AppOption app;
  final Set<Access> selected;
  final void Function(Access access, bool select) onToggle;

  @override
  Widget build(BuildContext context) {
    final tint = app.color;
    final Map<String, List<Access>> grouped = _groupAccessByFeature(app);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _Card(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(app.icon, color: tint),
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
                TextButton(
                  onPressed: () {
                    final all = grouped.values.expand((v) => v).toList();
                    final allSelected = all.every(selected.contains);
                    for (final a in all) {
                      onToggle(a, !allSelected);
                    }
                  },
                  child: Text(
                    grouped.values.expand((v) => v).every(selected.contains)
                        ? 'Clear All'
                        : 'Select All',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final entry in grouped.entries) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 22,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final allSel = entry.value.every(selected.contains);
                      for (final a in entry.value) {
                        onToggle(a, !allSel);
                      }
                    },
                    child: Text(
                      entry.value.every(selected.contains) ? 'Clear' : 'Select',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final acc in entry.value)
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
      ),
    );
  }

  Map<String, List<Access>> _groupAccessByFeature(AppOption app) {
    if (app == AppOption.storeconsumable) {
      return {
        'Items': [
          Access.storeitemview,
          Access.storeitemadd,
          Access.storeitemedit,
          Access.storeitemdelete,
          Access.storeitemtransfer,
          Access.storeitemfind,
          Access.storeitemrateview,
        ],
        'Places': [
          Access.storeplaceview,
          Access.storeplaceadd,
          Access.storeplaceedit,
          Access.storeplacedelete,
        ],
        'Receive': [
          Access.storreceiveview,
          Access.storreceiveadd,
          Access.storreceiveedit,
          Access.storreceivereject,
          Access.storreceiveapprove,
          Access.storreceiveclose,
          Access.storreceivetostock,
          Access.historyReceiveItem,
        ],
        'Issue': [
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
        'Indent': [
          Access.storeindentview,
          Access.storeindentdraft,
          Access.storeindentraise,
          Access.storeindentconsolidation,
          Access.storeindentapprove,
          Access.storeindentreject,
          Access.storeindenthistory,
        ],
        'Admin / Data': [
          Access.storeexport,
          Access.storeimportData,
          Access.storeadmin,
        ],
      };
    }
    return {
      'Scrap Management': [
        Access.scrapview,
        Access.scrapadd,
        Access.scrapdelete,
        Access.scrapexport,
        Access.historyScrap,
      ],
    };
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
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      backgroundColor: tint.withValues(alpha: .10),
      selectedColor: tint.withValues(alpha: .25),
      side: BorderSide(color: tint.withValues(alpha: .40)),
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder:
                (child, anim) => ScaleTransition(scale: anim, child: child),
            child:
                selected
                    ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('tick'),
                      size: 16,
                      color: _surface,
                    )
                    : const SizedBox(
                      key: ValueKey('notick'),
                      width: 0,
                      height: 0,
                    ),
          ),
          if (selected) const SizedBox(width: 6),
          Icon(access.icon, size: 16, color: selected ? _surface : tint),
          const SizedBox(width: 6),
          Text(
            access.label,
            style: TextStyle(
              color: selected ? _surface : tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/* ======= Password Field (optional supported) ======= */
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.optional = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool optional;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  void _toggleObscure() => setState(() => _obscure = !_obscure);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          keyboardType: TextInputType.visiblePassword,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: Icon(widget.icon, color: _ink600),
            suffixIcon: IconButton(
              onPressed: _toggleObscure,
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: _ink600,
              ),
              tooltip: _obscure ? 'Show password' : 'Hide password',
            ),
            filled: true,
            fillColor: _surface,
            hintStyle: const TextStyle(color: _ink600),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _ink900, width: 1.2),
            ),
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) {
              return widget.optional ? null : 'Enter your password';
            }
            if (t.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }
}

/* =================== Division Dialog =================== */
class _DivisionMultiSelectDialog extends StatefulWidget {
  const _DivisionMultiSelectDialog({
    required this.all,
    required this.initiallySelected,
  });

  final List<Map<String, dynamic>> all;
  final Set<String> initiallySelected;

  @override
  State<_DivisionMultiSelectDialog> createState() =>
      _DivisionMultiSelectDialogState();
}

class _DivisionMultiSelectDialogState
    extends State<_DivisionMultiSelectDialog> {
  late final Set<String> _sel = {...widget.initiallySelected};
  final TextEditingController _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _q.text.trim().toLowerCase();
    final filtered =
        query.isEmpty
            ? widget.all
            : widget.all.where((d) {
              final name = _divName(d).toLowerCase();
              final id = _divId(d).toLowerCase();
              return name.contains(query) || id.contains(query);
            }).toList();

    return AlertDialog(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Select Divisions',
        style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search division...',
                hintStyle: const TextStyle(color: _ink600),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _ink600,
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                filled: true,
                fillColor: _surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
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
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final d = filtered[i];
                  final id = _divId(d);
                  final name = _divName(d);
                  final checked = _sel.contains(id);

                  return CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _sel.add(id);
                        } else {
                          _sel.remove(id);
                        }
                      });
                    },
                    activeColor: _ink900,
                    checkColor: _surface,
                    title: Text(
                      name.isNotEmpty ? name : id,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: _ink900),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: _ink900),
          onPressed: () => setState(() => _sel.clear()),
          child: const Text('Clear'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: _ink900),
          onPressed:
              () => setState(() {
                _sel.addAll(widget.all.map(_divId).where((x) => x.isNotEmpty));
              }),
          child: const Text('Select All'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _ink900,
            foregroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // ✅ NEW: guard - do not allow Done with empty selection
          onPressed: () {
            if (_sel.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select at least one division')),
              );
              return;
            }
            Navigator.pop(context, _sel);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
