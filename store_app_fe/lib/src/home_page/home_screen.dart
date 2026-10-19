import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
// ignore: unused_import
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:store_app/main.dart'; // contains currentVersion
import 'package:universal_html/html.dart' as window;
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

import '../auth/controllers/auth_controller.dart';
// ignore: unused_import
import '../auth/controllers/users_controller.dart';
import '../auth/domains/models/auth_model.dart';
import '../auth/login_screens/user_management/edit_user_page.dart';
import '../auth/login_screens/user_management/user_profile_page.dart';
import '../auth/login_screens/user_management/view_user_page.dart';
import '../components/constants.dart';
import '../store/presentation/views/stock/stock_tab_view_page.dart';
import '../store_page/presentation/view/new_store_home_page.dart';
import '../store_page/presentation/view/scrap/store_scrap_list_page.dart';
import '../store_page/presentation/view/cart/store_cart_timer_settings_sheet.dart';

/* -------------------- Palette -------------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _stroke = Color(0xFFDFE1D6);
const _surface = Colors.white;
const _surfaceAlt = Color(0xFFFFF4E2);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = Color(0xFFFFF4E2);

/* -------------------- Helpers -------------------- */
String versionDigits(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');

/* -------------------- HomeScreen -------------------- */
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  static const String routePath = "/home";
  static const String routeName = "home";

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenConsumerState();
}

class _HomeScreenConsumerState extends ConsumerState<HomeScreen> {
  String apkUrl = "";
  bool _autoNavigatedToStore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    // _refreshPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    try {
      var type = "app";
      if (kIsWeb) type = "web";

      final res = await http.get(
        Uri.parse('${Constants.socketUrl}/update/update/$type'),
      );

      if (res.statusCode != 200) return;

      final data = json.decode(res.body) as Map<String, dynamic>;

      final serverVersion = (data['version'] ?? '').toString();

      // apkUrl may be String or Map. Prefer "normal/full/default" if it's a Map.
      String url = '';
      final rawApkUrl = data['apkUrl'];
      if (rawApkUrl is String) {
        url = rawApkUrl.trim();
      } else if (rawApkUrl is Map) {
        final n =
            rawApkUrl['normal'] ?? rawApkUrl['full'] ?? rawApkUrl['default'];
        if (n is String) url = n.trim();
      } else {
        url =
            (data['normalApkUrl'] ?? data['apkUrlNormal'] ?? '')
                .toString()
                .trim();
      }

      // fallback if backend didn’t send a usable link
      if (url.isEmpty) {
        url =
            'https://storedemobe.rrispat.in/public/v${versionDigits(currentVersion)}.apk';
      }

      apkUrl = url;

      // Compare without dots
      final serverV = versionDigits(serverVersion);
      final currentV = versionDigits(currentVersion);

      if (serverV.isNotEmpty && serverV != currentV) {
        if (!mounted) return;
        _showUpdateDialog();
      }
    } catch (_) {
      // ignore (optional: log)
    }
  }

  void _showUpdateDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Center(child: Text('Update Available')),
            content: Text(
              'A new version of the RR Ispat app is available.\n\n'
              'Please update the app to continue.\n\n'
              'Download: $apkUrl',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _downloadAndInstallApk();
                },
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadAndInstallApk() async {
    if (kIsWeb) {
      _refreshWebPage();
      return;
    }

    // Android (without importing dart:io)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final url = apkUrl.trim();
      if (url.isNotEmpty) {
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open update link')),
          );
        }
      }
      // Your existing behavior: logout after update prompt
      ref.read(authControllerProvider).logout(ref);
    }
  }

  void _refreshWebPage() {
    final webStorage = window.window.localStorage;
    webStorage.clear();
    window.window.location.reload();
  }

  static const double _sectionMaxWidth = 980.0;

  final Map<String, _AppMeta> appMeta = {
    'storeconsumable': _AppMeta(
      title: 'Store (Consumable)',
      color: Color.fromARGB(255, 36, 123, 129),
      svgAsset: 'assets/icons/supermarket.svg',
      onTap: (ctx) {
        Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const StoreDashboardShellPage()),
        );

        //  Navigator.push(
        //   ctx,
        //   MaterialPageRoute(
        //     builder: (_) => const store_new.StoreConsumableHome(),
        //   ),
        // );
      },
    ),
    'scrap': _AppMeta(
      title: 'Scrap (Consumable)',
      color: Color(0xFFFD2929),
      svgAsset: 'assets/icons/product.svg',
      onTap: (ctx) {
        Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const StoreScrapListPage()),
        );
        // Navigator.push(
        //   ctx,
        //   MaterialPageRoute(builder: (_) => const ScrapViewPage()),
        // );
      },
    ),
    'stock': _AppMeta(
      title: 'Stock',
      color: Color.fromARGB(255, 66, 255, 255),
      svgAsset: 'assets/icons/product.svg',
      onTap: (ctx) {
        Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => const StockTabViewPage()),
        );
      },
    ),
  };

  String _normalizeAppKey(String rawKey) {
    final k = rawKey.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    if (k == 'store' || k == 'storeconsumable') return 'storeconsumable';
    if (k == 'scrap' || k == 'scrapconsumable') return 'scrap';
    if (k == 'stock') return 'stock';
    return k;
  }

  List<String> appKeysFrom(dynamic apps, List<String> appWorks, bool isSuperAdmin) {
    final Set<String> uniqueKeys = {};
    if (apps is List) {
      for (final e in apps) {
        if (e is String && e.trim().isNotEmpty) {
          uniqueKeys.add(_normalizeAppKey(e));
        } else if (e is Map && e['app'] != null) {
          uniqueKeys.add(_normalizeAppKey(e['app'].toString()));
        } else {
          try {
            final appField = e?.app;
            if (appField is String && appField.trim().isNotEmpty) {
              uniqueKeys.add(_normalizeAppKey(appField));
            }
          } catch (_) {}
        }
      }
    }

    // Fallback: If no recognized app keys were assigned in DB, infer access
    if (uniqueKeys.isEmpty) {
      if (isSuperAdmin) {
        return ['storeconsumable', 'scrap', 'stock'];
      }
      final hasStorePerms = appWorks.any((w) =>
          w.startsWith('store') ||
          w.startsWith('storreceive') ||
          w.startsWith('storissue'));
      final hasScrapPerms = appWorks.any((w) => w.startsWith('scrap'));

      if (hasStorePerms || (!hasScrapPerms && appWorks.isEmpty)) {
        uniqueKeys.add('storeconsumable');
      }
      if (hasScrapPerms) {
        uniqueKeys.add('scrap');
      }
      if (uniqueKeys.isEmpty) {
        uniqueKeys.add('storeconsumable');
      }
    }

    return uniqueKeys.toList();
  }

  Widget _centerSection(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14),
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _sectionMaxWidth),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userFindOneDataStreamProvider);

    return userAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        final u = user ?? _placeholderUser;
        final isSuperAdmin = u.isSuperAdmin;
        final roleLabel = isSuperAdmin ? 'ADMIN' : 'User';

        final keys = appKeysFrom(u.apps, u.appWorks, isSuperAdmin);

        // Auto-navigate single-app Issue Requester directly into Store on login
        if (!_autoNavigatedToStore && user != null) {
          final isIssueOnly = !isSuperAdmin &&
              u.canIssue &&
              !u.canReceive &&
              (keys.length == 1 && keys.contains('storeconsumable'));
          if (isIssueOnly) {
            _autoNavigatedToStore = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoreDashboardShellPage(),
                  ),
                );
              }
            });
          }
        }

        final List<_DashTile> appTiles = [
          for (final key in keys)
            if (appMeta.containsKey(key))
              _DashTile(
                title: appMeta[key]!.title,
                color: appMeta[key]!.color,
                svgAsset: appMeta[key]!.svgAsset,
                onTap: () => appMeta[key]!.onTap(context),
                group: DashGroup.app,
                featureKey: key,
              ),
        ];

        final width = MediaQuery.of(context).size.width;
        final bool useFloatingAdminFab = isSuperAdmin && width < 560;

        return Scaffold(
          backgroundColor: _bgBottom,
          appBar: _buildAppBar(
            context,
            user: u,
            showAdminPill: isSuperAdmin && !useFloatingAdminFab,
          ),
          floatingActionButton:
              useFloatingAdminFab
                  ? _AdminFab(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UsersListPage(),
                        ),
                      );
                    },
                  )
                  : null,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_bgTop, _bgBottom],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 90),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Dashboard',
                                    style: TextStyle(
                                      color: _ink900,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .2,
                                    ),
                                  ),
                                  const Spacer(),
                                  _BadgeChip(
                                    icon: Icons.verified_user_outlined,
                                    label: roleLabel,
                                  ),
                                ],
                              ),
                            ),
                            if (appTiles.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _centerSection(
                                const _SectionHeader(
                                  title: 'Apps',
                                  icon: Icons.apps_outlined,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _centerSection(
                                _AppsAdaptive(tiles: appTiles),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Fixed Bottom Section with Copyright
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color:
                      _surfaceAlt, // You can change the background color as needed
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Column(
                      children: [
                        // Logo (if any)
                        Image.asset(
                          'assets/icons/logo.png', // Make sure to add your logo in the assets folder
                          height: 40, // Adjust the size of the logo
                        ),
                        const SizedBox(
                          height: 8,
                        ), // Space between logo and copyright text
                        // Copyright text
                        Text(
                          '© 2026 YuvaQ. All rights reserved.',
                          style: TextStyle(
                            color: _ink600,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required AuthModel user,
    required bool showAdminPill,
  }) {
    const headerHeight = 86.0;
    return PreferredSize(
      preferredSize: const Size.fromHeight(headerHeight),
      child: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink900,
        automaticallyImplyLeading: false,
        toolbarHeight: headerHeight,
        titleSpacing: 0,
        title: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: _TopBar(
              user: user,
              adminPill: showAdminPill ? _AdminPillButton(user: user) : null,
            ),
          ),
        ),
      ),
    );
  }

  AuthModel get _placeholderUser => AuthModel(
    uid: "uid",
    email: "email",
    phoneNumber: "phoneNumber",
    name: "User",
    fcmToken: "",
    isActive: true,
    isSuperAdmin: false,
    devices: const [],
    deviceHistory: const [],
    apps: const [],
    appWorks: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    imageUrl: '',
    divisionIds: [],
  );
}

/* -------------------------------- helpers & UI -------------------------------- */

class _AppMeta {
  final String title;
  final Color color;
  final String? svgAsset;
  final IconData? icon;
  final void Function(BuildContext) onTap;

  const _AppMeta({
    required this.title,
    required this.color,
    required this.onTap,
    this.svgAsset,
  }) : icon = null;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _ink700),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _ink900,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(top: 1),
            color: _stroke,
          ),
        ),
      ],
    );
  }
}

/* ----------------------------- AppBar & Actions ----------------------------- */

class _TopBar extends ConsumerStatefulWidget {
  const _TopBar({required this.user, this.adminPill});
  final AuthModel user;
  final Widget? adminPill;

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  String? _normalApkUrl;
  String? _lightApkUrl;

  String get _fallbackNormal =>
      'https://storedemobe.rrispat.in/public/v${versionDigits(currentVersion)}.apk';

  String get _fallbackLight =>
      'https://storedemobe.rrispat.in/public/store_app.apk';

  Future<void> _fetchDownloadLinks() async {
    try {
      var type = "app";
      if (kIsWeb) type = "web";

      final response = await http.get(
        Uri.parse('${Constants.socketUrl}/update/update/$type'),
      );

      if (response.statusCode != 200) {
        throw Exception('Update API failed: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      String? normal;
      // String? light;

      final apkUrl = data['apkUrl'];

      if (apkUrl is String && apkUrl.trim().isNotEmpty) {
        normal = apkUrl.trim();
      }

      if (apkUrl is Map) {
        final n = apkUrl['normal'] ?? apkUrl['full'] ?? apkUrl['default'];
        // final l = apkUrl['light'] ?? apkUrl['lite'];

        if (n is String && n.trim().isNotEmpty) normal = n.trim();
        // if (l is String && l.trim().isNotEmpty) light = l.trim();
      }

      final n2 =
          data['normalApkUrl'] ?? data['apkUrlNormal'] ?? data['fullApkUrl'];
      // final l2 =
      //     data['lightApkUrl'] ?? data['apkUrlLight'] ?? data['liteApkUrl'];

      if (n2 is String && n2.trim().isNotEmpty) normal = n2.trim();
      // if (l2 is String && l2.trim().isNotEmpty) light = l2.trim();

      _normalApkUrl = normal ?? _fallbackNormal;
      // _lightApkUrl = light ?? _fallbackLight;
    } catch (e) {
      _normalApkUrl = _fallbackNormal;
      _lightApkUrl = _fallbackLight;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Using fallback download links. Error: $e')),
        );
      }
    }
  }

  // Future<void> _launchExternal(String url) async {
  //   final uri = Uri.parse(url);
  //   final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  //   if (!ok && mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Could not open download link')),
  //     );
  //   }
  // }

  Future<void> openExternalUrl(BuildContext context, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    if (kIsWeb) {
      // Web: no plugin required
      html.window.open(trimmed, '_blank');
      return;
    }

    // Mobile/Desktop: use url_launcher plugin
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid URL')));
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    ref.read(authControllerProvider).logout(ref);
  }

  Future<void> _openDownloadsSheet(BuildContext context) async {
    // Fetch first, then show sheet (simplest & avoids state sync issues)
    await _fetchDownloadLinks();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _DownloadsSheet(
          onNormal:
              () => openExternalUrl(context, _normalApkUrl ?? _fallbackNormal),
          onLight:
              () => openExternalUrl(context, _lightApkUrl ?? _fallbackLight),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    // print(u);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final bool compact = w < 520;

        final double avatarSize = compact ? 36 : 44;
        final double nameSize = compact ? 16 : 18;

        final actions = <Widget>[
          if (widget.adminPill != null) widget.adminPill!,
          if (u.isSuperAdmin && compact) ...[
            _HeaderAction(
              icon: Icons.tune_rounded,
              tooltip: 'Settings',
              onTap: () => showCartTimerSettingsSheet(context),
            ),
            _HeaderAction(
              icon: Icons.group_outlined,
              tooltip: 'Manage Users',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersListPage()),
                );
              },
            ),
          ],
          _HeaderAction(
            icon: Icons.edit,
            tooltip: 'Edit profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => UserEditPage(
                        initial: u,
                        currentViewerIsAdmin: false,
                        isEditingSelf: true,
                      ),
                ),
              );
            },
          ),
          _HeaderAction(
            icon: Icons.download,
            tooltip: 'Downloads',
            onTap: () => _openDownloadsSheet(context),
          ),
          _HeaderAction(
            icon: Icons.logout,
            tooltip: 'Sign out',
            onTap: () => _logout(context, ref),
          ),
        ];

        return Row(
          children: [
            buildUserAvatar(
              name: u.name,
              imageUrl: u.imageUrl,
              size: avatarSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!compact)
                    const Text(
                      'Welcome back,',
                      style: TextStyle(color: _ink600, fontSize: 12),
                    ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (u.name.isNotEmpty ? u.name : 'User').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ink900,
                            fontSize: nameSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        _RoleDotChip(
                          text: u.isSuperAdmin ? 'ADMIN' : 'STANDARD',
                        ),
                      ],
                    ],
                  ),
                  if (!compact)
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline,
                          size: 14,
                          color: _ink700,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            u.email.isNotEmpty ? u.email : u.phoneNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (compact)
              _OverflowActionsMenu(
                actions: actions.whereType<_HeaderAction>().toList(),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        );
      },
    );
  }
}

/* ----------------------------- Admin Quick Actions ----------------------------- */

class _AdminPillButton extends StatelessWidget {
  const _AdminPillButton({required this.user});
  final AuthModel user;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Settings',
          waitDuration: const Duration(milliseconds: 300),
          child: TextButton.icon(
            onPressed: () => showCartTimerSettingsSheet(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              foregroundColor: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFFEFF6FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
              ),
            ),
            icon: const Icon(
              Icons.tune_rounded,
              size: 16,
              color: Color(0xFF2563EB),
            ),
            label: const Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Manage Users',
          waitDuration: const Duration(milliseconds: 300),
          child: TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsersListPage()),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF5B67E9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.group_outlined, size: 18, color: Colors.white),
            label: const Text(
              'Users',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminFab extends StatelessWidget {
  const _AdminFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'admin-fab',
        onPressed: onTap,
        foregroundColor: Colors.white,
        backgroundColor: Colors.indigoAccent,
        elevation: 0,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
        label: const Text(
          'Manage Users',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.group_outlined),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}

/* ----------------------------- Actions / misc ----------------------------- */

class _RoleDotChip extends StatelessWidget {
  const _RoleDotChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _bgTop,
        border: Border.all(color: _stroke),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Dot(),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _ink700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: _ink700,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      waitDuration: const Duration(milliseconds: 300),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: _ink700),
        splashRadius: 22,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(8),
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _stroke),
          ),
        ),
      ),
    );
  }
}

class _OverflowActionsMenu extends StatelessWidget {
  const _OverflowActionsMenu({required this.actions});
  final List<_HeaderAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz, color: _ink700),
      itemBuilder:
          (ctx) => [
            for (int i = 0; i < actions.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(actions[i].icon, size: 18, color: _ink700),
                    const SizedBox(width: 10),
                    Text(actions[i].tooltip ?? 'Action'),
                  ],
                ),
              ),
          ],
      onSelected: (i) => actions[i].onTap?.call(),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 3,
    );
  }
}

/* ------------------------- tiles & app lists ------------------------- */

enum DashGroup { userMgmt, app }

class _DashTile {
  final String title;
  final Color color;
  final bool alwaysVisible;
  final VoidCallback? onTap;
  final DashGroup group;
  final bool monochrome;
  final String? svgAsset;
  final IconData? icon;
  final String? featureKey;

  const _DashTile({
    required this.title,
    required this.color,
    required this.group,
    this.onTap,
    this.svgAsset,
    this.featureKey,
  }) : monochrome = false, alwaysVisible = false, icon = null;
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _ink900),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- avatar helpers ------------------------- */

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return 'U';
  final first = parts.first.isNotEmpty ? parts.first[0] : '';
  final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

Widget buildUserAvatar({
  required String name,
  required String? imageUrl,
  double size = 46,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  // print(imageUrl);

  final hasUrl = imageUrl != null && imageUrl.trim().isNotEmpty;
  // print(hasUrl);
  final avatar =
      hasUrl
          ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: size,
            height: size,
            loadingBuilder: (context, child, progress) {
              // Debugging the loading process
              if (progress == null) {
                print('Image loaded successfully: $imageUrl');
                return child;
              }

              // Show a loading indicator while the image is loading
              print(
                'Image loading: ${progress.expectedTotalBytes}, loaded: ${progress.cumulativeBytesLoaded}',
              );
              return Center(
                child: SizedBox(
                  width: size * 0.38,
                  height: size * 0.38,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              // Debugging the error process
              print('Image loading error: $error');
              print('Stack trace: $stack');

              return Center(
                child: Text(
                  _initials(name).toUpperCase(),
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.42,
                    letterSpacing: .5,
                  ),
                ),
              );
            },
          )
          : Center(
            child: Text(
              _initials(name).toUpperCase(),
              style: TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.42,
                letterSpacing: .5,
              ),
            ),
          );

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _surface,
      border: Border.all(color: _stroke),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 10,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipOval(child: avatar),
      ),
    ),
  );
}

/* ------------------------- Adaptive Apps ------------------------- */

class _AppsAdaptive extends StatelessWidget {
  const _AppsAdaptive({required this.tiles});
  final List<_DashTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        if (w < 520) {
          return AppListMenu(tiles: tiles);
        } else if (w < 760) {
          return _IosGrid(tiles: tiles, iconSize: 64);
        } else {
          return _IosGrid(tiles: tiles, iconSize: 74);
        }
      },
    );
  }
}

class AppListMenu extends StatelessWidget {
  const AppListMenu({super.key, required this.tiles});
  final List<_DashTile> tiles;

  @override
  Widget build(BuildContext context) {
    return _InsetGroup(
      children: [
        for (final t in tiles)
          _CupertinoCell(
            leading: _SquircleIcon(tile: t),
            title: Text(
              t.title,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: _surface),
            onTap: t.onTap,
          ),
      ],
    );
  }
}

class _InsetGroup extends StatelessWidget {
  const _InsetGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i != 0)
              Divider(height: 1, thickness: 1, color: _stroke.withValues(alpha: .9)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _CupertinoCell extends StatelessWidget {
  const _CupertinoCell({
    required this.leading,
    required this.title,
    this.trailing,
    this.onTap,
  });
  final Widget leading;
  final Widget title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: title),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _SquircleIcon extends StatelessWidget {
  const _SquircleIcon({required this.tile});
  final _DashTile tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tile.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child:
              tile.svgAsset != null
                  ? SvgPicture.asset(tile.svgAsset!, fit: BoxFit.contain)
                  : Icon(tile.icon, size: 20, color: _ink900),
        ),
      ),
    );
  }
}

/* ------------------ iOS-like grid ------------------ */

class _IosGrid extends StatelessWidget {
  const _IosGrid({required this.tiles, required this.iconSize});
  final List<_DashTile> tiles;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 16,
      runSpacing: 18,
      children: tiles.map((t) => _IosAppIcon(tile: t, size: iconSize)).toList(),
    );
  }
}

class _IosAppIcon extends StatelessWidget {
  const _IosAppIcon({required this.tile, required this.size});
  final _DashTile tile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = tile.color.withValues(alpha: .12);

    return SizedBox(
      width: size + 18,
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _stroke),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: size * .52,
                  height: size * .52,
                  child:
                      tile.svgAsset != null
                          ? SvgPicture.asset(
                            tile.svgAsset!,
                            fit: BoxFit.contain,
                          )
                          : Icon(tile.icon, size: size * .5, color: _ink900),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tile.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink900,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------- Downloads sheet ------------------------- */

class _DownloadsSheet extends StatelessWidget {
  const _DownloadsSheet({required this.onNormal, required this.onLight});

  final VoidCallback onNormal;
  final VoidCallback onLight;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.download_rounded),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Downloads',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    iconColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onNormal();
                  },
                  icon: const Icon(Icons.system_update_alt_rounded),
                  label: const Text('Normal download'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    iconColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onLight();
                  },
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Light weight download'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
