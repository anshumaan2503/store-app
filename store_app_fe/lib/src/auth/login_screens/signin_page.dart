// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:install_plugin_v2/install_plugin_v2.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as window;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_app/main.dart';
import 'package:store_app/src/components/constants.dart';
import 'package:store_app/src/components/utils.dart';

import '../../home_page/home_screen.dart';
import '../../store_page/controllers/guided_tour_controller.dart';
import '../controllers/auth_controller.dart';
import 'register_page.dart';

// ---------------------- Palette (from illustration) ----------------------
// Primary neutrals
const _ink900 = Color(0xFF282321); // deep charcoal (titles/icons)
const _ink600 = Color(0xFF867471); // warm grey (subtitles/links)

// Surfaces
const _surface = Color(0xFFFFFFFF); // white card
const _surfaceAlt = Color(0xFFFFF4E2); // warm cream
const _stroke = Color(0xFFDFE1D6); // soft sage border

// Accents
const _accentMint = Color(0xFFB6D3CC); // mint
const _accentPeach = Color(0xFFF3D7C0); // peach

// Page background blend
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

// ---------------------- Login Screen ----------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  String apkUrl = "";
  bool loading = false;
  bool isLoading = false;
  double progress = 0.0;

  late final AnimationController _btnCtrl;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    WidgetsBinding.instance.addObserver(this); // register observer
    if (kIsWeb || Platform.isAndroid) {
      _checkForUpdate();
      checkAndPromptInstallOnLaunch();
    }
  }

  Future<void> _checkForUpdate() async {
    var type = "app";
    if (kIsWeb) {
      type = "web";
    }
    final response = await http.get(
      Uri.parse('${Constants.socketUrl}/update/update/$type'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final serverVersion = data['version'];
      apkUrl = data['apkUrl'];

      if (serverVersion != currentVersion) {
        _showUpdateDialog();
      }
    }
  }

  void _showUpdateDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Center(child: Text('Update Available')),
              content: Text(
                'A new version of the RR Ispat app is available.\n\nPlease update the app to continue.\n$apkUrl',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _downloadAndInstallApk();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Update Now'),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _downloadAndInstallApk() async {
    if (kIsWeb) {
      _refreshWebPage();
      return;
    }

    final url = apkUrl.trim();
    if (url.isEmpty) {
      if (mounted) showSnackBar("Update URL is empty.");
      return;
    }

    // Use app cache — faster & permission friendly
    final cacheDir = await getTemporaryDirectory();
    final filePath = '${cacheDir.path}/rrlatest.apk';
    final apkFile = File(filePath);

    // --------- FAST PATH: APK already present & looks valid ----------
    final hasValidApk = await _looksLikeValidApk(apkFile);
    if (hasValidApk) {
      await _showInstallSheet(
        filePath: filePath,
        readyImmediately: true, // skip download UI
        downloadUrl: url,
      );
      return;
    }

    // If present but corrupted, delete and continue with full flow
    if (await apkFile.exists()) {
      try {
        await apkFile.delete();
      } catch (_) {}
    }

    // --------- NORMAL PATH: download → install ----------
    await _showInstallSheet(
      filePath: filePath,
      readyImmediately: false,
      downloadUrl: url,
    );
  }

  /// Quick integrity signal: file exists, >= 2 MB, starts with "PK" (APK is a ZIP).
  Future<bool> _looksLikeValidApk(File file) async {
    try {
      if (!await file.exists()) return false;
      final len = await file.length();
      if (len < 2 * 1024 * 1024) return false; // too small -> likely broken
      final raf = await file.open();
      final header = await raf.read(2);
      await raf.close();
      return header.length == 2 &&
          header[0] == 0x50 &&
          header[1] == 0x4B; // 'P''K'
    } catch (_) {
      return false;
    }
  }

  /// Bottom sheet that either:
  /// - starts in "install ready" state (if APK already present & valid), OR
  /// - downloads first, then offers install.
  ///
  /// Keeps the sheet open (back button blocked) while waiting for user to complete install.
  /// Allows retrying "Install Now" without re-download.
  Future<void> _showInstallSheet({
    required String filePath,
    required String downloadUrl,
    required bool readyImmediately,
  }) async {
    double localProgress = 0.0;
    bool readyToInstall = readyImmediately;
    bool installing = false;
    bool waitingInstall = false;
    bool startedDownload = false;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              if (!startedDownload && !readyToInstall) {
                startedDownload = true;
                Future.microtask(() async {
                  try {
                    final dio = Dio(
                      BaseOptions(
                        connectTimeout: const Duration(seconds: 15),
                        receiveTimeout: const Duration(minutes: 5),
                        sendTimeout: const Duration(minutes: 2),
                        followRedirects: true,
                        validateStatus: (s) => s != null && s < 400,
                        headers: {
                          'Accept-Encoding': 'identity',
                          'User-Agent': 'RR-Ispat-Updater/1.0',
                        },
                      ),
                    );

                    int lastShown = 0;
                    final sw = Stopwatch()..start();

                    await dio.download(
                      downloadUrl,
                      filePath,
                      onReceiveProgress: (received, total) {
                        if (total <= 0) return;
                        final p = received / total;
                        final timeOk = sw.elapsedMilliseconds >= 100;
                        final bytesOk = (received - lastShown) >= 256 * 1024;
                        if (timeOk || bytesOk) {
                          lastShown = received;
                          sw.reset();
                          localProgress = p;
                          if (mounted) setSheetState(() {});
                        }
                      },
                    );

                    final ok = await _looksLikeValidApk(File(filePath));
                    if (!ok) {
                      try {
                        await File(filePath).delete();
                      } catch (_) {}
                      throw Exception("Downloaded file looks corrupted.");
                    }

                    localProgress = 1.0;
                    readyToInstall = true;
                    if (mounted) setSheetState(() {});
                  } on DioException catch (e) {
                    if (mounted) {
                      Navigator.of(sheetCtx).pop();
                      final code = e.response?.statusCode;
                      showSnackBar("Download failed: ${e.type} ${code ?? ''}");
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(sheetCtx).pop();
                      showSnackBar("Download failed: $e");
                    }
                  }
                });
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      !readyToInstall
                          ? "Downloading update…"
                          : (waitingInstall
                              ? "Waiting for installation…"
                              : "Update ready"),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _ink900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!readyToInstall) ...[
                      LinearProgressIndicator(
                        value:
                            (localProgress > 0 && localProgress < 1)
                                ? localProgress
                                : null,
                        backgroundColor: _stroke,
                        color: _accentMint,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (localProgress > 0 && localProgress < 1)
                            ? "${(localProgress * 100).toStringAsFixed(0)}%"
                            : "Starting…",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _ink600),
                      ),
                    ] else ...[
                      if (!waitingInstall) ...[
                        const Icon(
                          Icons.check_circle,
                          size: 28,
                          color: _accentMint,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "The update has been downloaded. Install it now?",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _ink600),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        const SizedBox(height: 4),
                        const Text(
                          "Complete the installation in the system installer. When you return, tap “I’ve installed”.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _ink600),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  installing
                                      ? null
                                      : () async {
                                        if (!waitingInstall) {
                                          installing = true;
                                          setSheetState(() {});
                                          try {
                                            final prefs =
                                                await SharedPreferences.getInstance();
                                            await prefs.setBool(
                                              'pendingInstall',
                                              true,
                                            );

                                            try {
                                              final info =
                                                  await PackageInfo.fromPlatform();
                                              await InstallPlugin.installApk(
                                                filePath,
                                                info.packageName,
                                              );
                                            } catch (e) {
                                              print("Install error: $e");
                                            }
                                            waitingInstall = true;
                                          } catch (e) {
                                            if (mounted) {
                                              showSnackBar(
                                                "Install start failed: $e",
                                              );
                                            }
                                          } finally {
                                            installing = false;
                                            if (mounted) setSheetState(() {});
                                          }
                                        } else {
                                          waitingInstall = false;
                                          readyToInstall = true;
                                          installing = false;

                                          if (mounted) {
                                            setSheetState(() {});
                                            showSnackBar(
                                              "If update didn’t complete, tap Install Now again.",
                                            );
                                          }
                                        }
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _ink900,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: () {
                                if (installing) {
                                  return const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _accentMint,
                                      ),
                                    ),
                                  );
                                }
                                if (waitingInstall) {
                                  return const Text("I’ve installed");
                                }
                                return const Text("Install Now");
                              }(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed:
                            (installing || !readyToInstall || waitingInstall)
                                ? null
                                : () async {
                                  try {
                                    await File(filePath).delete();
                                  } catch (_) {}
                                  readyToInstall = false;
                                  localProgress = 0.0;
                                  startedDownload = false;
                                  if (mounted) setSheetState(() {});
                                },
                        icon: const Icon(Icons.refresh, color: _ink600),
                        label: const Text(
                          "Re-download update",
                          style: TextStyle(color: _ink600),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _refreshWebPage() {
    final webStorage = window.window.localStorage;
    webStorage.clear();
    window.window.location.reload();
  }

  Future<void> checkAndPromptInstallOnLaunch() async {
    if (kIsWeb) return;

    try {
      final dir = await getExternalStorageDirectory();
      final apkPath = '${dir?.path}/rrlatest.apk';
      final versionPath = '${dir?.path}/rrlatest_version.txt';

      final apkFile = File(apkPath);
      final versionFile = File(versionPath);

      if (await apkFile.exists() && await versionFile.exists()) {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final String currentVersion = packageInfo.version;
        final downloadedVersion = await versionFile.readAsString();

        if (_isNewerVersion(downloadedVersion, currentVersion)) {
          try {
            await InstallPlugin.installApk(apkPath, packageInfo.packageName);
          } catch (e) {
            print("InstallPlugin failed: $e");
          }
        }
      }
    } catch (e) {
      print("Error in checkAndPromptInstallOnLaunch: $e");
    }
  }

  bool _isNewerVersion(String newVer, String currentVer) {
    final newParts = newVer.split('.').map(int.parse).toList();
    final currParts = currentVer.split('.').map(int.parse).toList();

    for (int i = 0; i < newParts.length; i++) {
      if (i >= currParts.length || newParts[i] > currParts[i]) return true;
      if (newParts[i] < currParts[i]) return false;
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ always remove
    _btnCtrl.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // Soft, professional background using palette
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: LoginCard(
                    formKey: _formKey,
                    user: _user,
                    pass: _pass,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    remember: _remember,
                    onRemember: (v) => setState(() => _remember = v),
                    btnController: _btnCtrl,
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

class LoginCard extends ConsumerStatefulWidget {
  const LoginCard({
    super.key,
    required this.formKey,
    required this.user,
    required this.pass,
    required this.obscure,
    required this.onToggleObscure,
    required this.remember,
    required this.onRemember,
    required this.btnController,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController user;
  final TextEditingController pass;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool remember;
  final ValueChanged<bool> onRemember;
  final AnimationController btnController;

  @override
  ConsumerState<LoginCard> createState() => _LoginCardConsumerState();
}

class _LoginCardConsumerState extends ConsumerState<LoginCard> {
  bool _loading = false;

  Future<void> _safeNavigateToHome() async {
    if (!mounted) return;
    try {
      ref.read(guidedTourControllerProvider).resetSession();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (r) => false,
      );
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    if (!(widget.formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    final dto = {
      'identifier': widget.user.text.trim(),
      'password': widget.pass.text,
    };

    final ok = await ref.read(authControllerProvider).loginAuth(authModel: dto);

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      await _safeNavigateToHome();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid credentials')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // delicate outer border ring
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: _surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Small, tidy illustration (kept; not required to remove)
                SizedBox(
                  height: 160,
                  child: Center(
                    child: Image.asset(
                      'assets/images/team_illustration.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please sign in to continue',
                  style: TextStyle(
                    color: _ink600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),

                // FORM
                Form(
                  key: widget.formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: widget.user,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        style: const TextStyle(color: _ink900),
                        decoration: _inputDecoration(
                          hint: 'Email / Phone',
                          icon: Icons.person_outline,
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Enter your identifier'
                                    : null,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: widget.pass,
                        obscureText: widget.obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        keyboardType: TextInputType.visiblePassword,
                        style: const TextStyle(color: _ink900),
                        decoration: _inputDecoration(
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            onPressed: widget.onToggleObscure,
                            icon: Icon(
                              widget.obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: _ink600,
                            ),
                            tooltip:
                                widget.obscure
                                    ? 'Show password'
                                    : 'Hide password',
                          ),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Enter your password';
                          if (t.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // // remember + forgot
                // Row(
                //   children: [
                //     Switch(
                //       value: widget.remember,
                //       onChanged: widget.onRemember,
                //       activeColor: _accentMint,
                //       trackOutlineColor: const MaterialStatePropertyAll<Color>(
                //         _stroke,
                //       ),
                //     ),
                //     const SizedBox(width: 6),
                //     const Text('Remember me', style: TextStyle(color: _ink900)),
                //     const Spacer(),
                //     TextButton(
                //       onPressed: () {},
                //       style: TextButton.styleFrom(foregroundColor: _ink600),
                //       child: const Text('Forgot password'),
                //     ),
                //   ],
                // ),
                // const SizedBox(height: 8),

                // Button with loader
                _AnimatedGradientButton(
                  controller: widget.btnController,
                  onPressed: _loading ? null : _submit,
                  icon: Icons.login_rounded,
                  label: _loading ? 'Please wait…' : 'Login',
                  loading: _loading,
                ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed:
                      _loading
                          ? null
                          : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                  style: TextButton.styleFrom(foregroundColor: _ink600),
                  child: const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    const radius = 14.0;
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: _stroke, width: 1),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _ink600),
      prefixIcon: Icon(icon, color: _ink600),
      suffixIcon: suffix,
      filled: true,
      fillColor: _bgTop,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: _accentMint, width: 1.4),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }
}

// Replace your existing _AnimatedGradientButton with this version.
// Same API: controller, onPressed, icon, label, loading

class _AnimatedGradientButton extends StatelessWidget {
  const _AnimatedGradientButton({
    required this.controller, // kept for compatibility (not used)
    required this.onPressed,
    required this.icon,
    required this.label,
    this.loading = false,
  });

  final AnimationController controller; // not used, but kept
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ButtonStyle(
        minimumSize: const MaterialStatePropertyAll(Size.fromHeight(54)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        // Solid, high-contrast, professional fill
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return _ink900.withOpacity(0.40);
          }
          if (states.contains(MaterialState.pressed)) {
            return _ink900.withOpacity(0.92);
          }
          if (states.contains(MaterialState.hovered)) {
            return _ink900.withOpacity(0.96);
          }
          return _ink900; // primary fill
        }),
        foregroundColor: const MaterialStatePropertyAll(Colors.white),
        // Soft, modern shadow
        elevation: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) return 2;
          return 4;
        }),
        overlayColor: MaterialStatePropertyAll(_accentMint.withOpacity(0.14)),
        padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        textStyle: const MaterialStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child:
            loading
                ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Row(
                  key: const ValueKey('content'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 10),
                    Text(label),
                  ],
                ),
      ),
    );

    // Subtle outer shadow separate from Elevation for a crisp, “card-like” feel
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000), // 8% black
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: btn,
    );
  }
}
