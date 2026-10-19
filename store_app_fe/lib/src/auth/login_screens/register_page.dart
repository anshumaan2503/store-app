// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as window;
import 'package:install_plugin_v2/install_plugin_v2.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart';
import '../../components/constants.dart';
import '../../components/utils.dart';
import '../controllers/auth_controller.dart';

// ---------------------- Palette (same as Login) ----------------------
const _ink900 = Color(0xFF282321); // deep charcoal (titles/icons)
const _ink600 = Color(0xFF867471); // warm grey (subtitles/links)

const _surface = Color(0xFFFFFFFF); // white card
const _surfaceAlt = Color(0xFFFFF4E2); // warm cream
const _stroke = Color(0xFFDFE1D6); // soft sage border

const _accentMint = Color(0xFFB6D3CC); // mint
const _accentPeach = Color(0xFFF3D7C0); // peach

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenConsumerState();
}

class _RegisterScreenConsumerState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agree = false;
  String apkUrl = "";
  bool loading = false;
  bool isLoading = false;
  double progress = 0.0;

  late final AnimationController _ctaCtrl; // kept for API compatibility
  bool _success = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // (not used visually anymore, kept to avoid logic changes)
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb || Platform.isAndroid) {
      _checkForUpdate();
      checkAndPromptInstallOnLaunch();
    }
  }

  Future<void> _checkForUpdate() async {
    var type = "app";
    if (kIsWeb) type = "web";
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
    final cacheDir = await getTemporaryDirectory();
    final filePath = '${cacheDir.path}/rrlatest.apk';
    final apkFile = File(filePath);

    final hasValidApk = await _looksLikeValidApk(apkFile);
    if (hasValidApk) {
      await _showInstallSheet(
        filePath: filePath,
        readyImmediately: true,
        downloadUrl: url,
      );
      return;
    }
    if (await apkFile.exists()) {
      try {
        await apkFile.delete();
      } catch (_) {}
    }
    await _showInstallSheet(
      filePath: filePath,
      readyImmediately: false,
      downloadUrl: url,
    );
  }

  Future<bool> _looksLikeValidApk(File file) async {
    try {
      if (!await file.exists()) return false;
      final len = await file.length();
      if (len < 2 * 1024 * 1024) return false;
      final raf = await file.open();
      final header = await raf.read(2);
      await raf.close();
      return header.length == 2 && header[0] == 0x50 && header[1] == 0x4B;
    } catch (_) {
      return false;
    }
  }

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
                      const Text(
                        "Starting…",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _ink600),
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
                                        Colors.white,
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
    WidgetsBinding.instance.removeObserver(this);
    _ctaCtrl.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pass.text.trim() != _confirm.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() {
      _success = false;
      _loading = true;
    });

    final dto = {
      'email': _email.text.trim(),
      'name': _name.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'password': _pass.text,
      "isActive": false,
      "isSuperAdmin": false,
      "app": [],
      "appWorks": [],
    };

    try {
      final ok = await ref
          .read(authControllerProvider)
          .createAuth(authModel: dto);
      if (!mounted) return;

      if (ok) {
        setState(() => _success = true);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Register failed')));
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // New soft background (no photo)
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
                constraints: const BoxConstraints(maxWidth: 520),
                child: _PaperCard(
                  child: _RegisterForm(
                    formKey: _formKey,
                    name: _name,
                    email: _email,
                    phone: _phone,
                    pass: _pass,
                    confirm: _confirm,
                    obscure1: _obscure1,
                    obscure2: _obscure2,
                    toggle1: () => setState(() => _obscure1 = !_obscure1),
                    toggle2: () => setState(() => _obscure2 = !_obscure2),
                    agree: _agree,
                    onAgree: (v) => setState(() => _agree = v),
                    ctaCtrl: _ctaCtrl,
                    success: _success,
                    onSubmit: _submit,
                    loading: _loading,
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

// Clean white card matching Login
class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: child,
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.name,
    required this.email,
    required this.phone,
    required this.pass,
    required this.confirm,
    required this.obscure1,
    required this.obscure2,
    required this.toggle1,
    required this.toggle2,
    required this.agree,
    required this.onAgree,
    required this.ctaCtrl,
    required this.success,
    required this.onSubmit,
    required this.loading,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name, email, phone, pass, confirm;
  final bool obscure1, obscure2, agree, success, loading;
  final VoidCallback toggle1, toggle2, onSubmit;
  final ValueChanged<bool> onAgree;
  final AnimationController ctaCtrl;

  InputDecoration _deco(String hint, IconData icon, {Widget? suffix}) {
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

  @override
  Widget build(BuildContext context) {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: kIsWeb ? Constants.webClientId : null,
      serverClientId: kIsWeb ? null : Constants.webClientId,
    );

    Future<void> continueWithGoogle(BuildContext context) async {
      try {
        final account = await googleSignIn.signInSilently();
        final user = account ?? await googleSignIn.signIn();
        if (user == null) return;
        final auth = await user.authentication;
        final idToken = auth.idToken;
        if (idToken == null) throw Exception("No Google ID token");

        final res = await http.post(
          Uri.parse('${Constants.socketUrl}/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Welcome, ${data["user"]["name"]}!')),
          );
        } else {
          final err = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err['error'] ?? 'Google login failed')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    // Widget googleButton(BuildContext context) {
    //   return OutlinedButton.icon(
    //     onPressed: () => continueWithGoogle(context),
    //     icon: Image.asset('assets/images/google_logo.png', height: 18),
    //     label: const Text('Continue with Google'),
    //     style: OutlinedButton.styleFrom(
    //       foregroundColor: _ink900,
    //       side: const BorderSide(color: _stroke),
    //       shape: const StadiumBorder(),
    //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    //       textStyle: const TextStyle(fontWeight: FontWeight.w700),
    //       backgroundColor: Colors.white,
    //     ),
    //   );
    // }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Illustration (optional; adjust to your asset)
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _accentPeach.withOpacity(.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _stroke),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/images/register_header.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Create account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _ink900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fill the details to get started',
          style: TextStyle(
            color: _ink600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),

        // FORM
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: name,
                style: const TextStyle(color: _ink900),
                textInputAction: TextInputAction.next,
                decoration: _deco('Full name', Icons.badge_outlined),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Enter your name'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                style: const TextStyle(color: _ink900),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _deco('Email address', Icons.alternate_email),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                  return ok ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                style: const TextStyle(color: _ink900),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: _deco('Phone (optional)', Icons.phone_android),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pass,
                style: const TextStyle(color: _ink900),
                obscureText: obscure1,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.password],
                decoration: _deco(
                  'Password',
                  Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: toggle1,
                    icon: Icon(
                      obscure1 ? Icons.visibility : Icons.visibility_off,
                      color: _ink600,
                    ),
                    tooltip: obscure1 ? 'Show password' : 'Hide password',
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a password';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirm,
                style: const TextStyle(color: _ink900),
                obscureText: obscure2,
                decoration: _deco(
                  'Confirm Password',
                  Icons.verified_user_outlined,
                  suffix: IconButton(
                    onPressed: toggle2,
                    icon: Icon(
                      obscure2 ? Icons.visibility : Icons.visibility_off,
                      color: _ink600,
                    ),
                    tooltip: obscure2 ? 'Show password' : 'Hide password',
                  ),
                ),
                validator:
                    (v) => (v != pass.text) ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Terms (kept but subtle)
        Row(
          children: [
            Checkbox(
              value: agree,
              onChanged: (v) => onAgree(v ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: _stroke),
              activeColor: _accentMint,
              checkColor: _ink900,
            ),
            const Expanded(
              child: Text(
                'I agree to the Terms & Privacy Policy',
                style: TextStyle(color: _ink600, fontSize: 13),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Primary CTA (professional, no shimmer)
        _ShimmerButton(
          controller: ctaCtrl, // kept for API compatibility
          success: success,
          label: loading ? 'Please wait…' : 'Create Account',
          icon: Icons.check_circle_outline,
          onPressed: loading ? null : onSubmit,
          loading: loading,
        ),

        // const SizedBox(height: 10),
        // googleButton(context),
        const SizedBox(height: 8),
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: _ink600),
          child: const Text('Already have an account? Sign in'),
        ),
      ],
    );
  }
}

/// Professional solid button (keeps the same class & params; no flashy animation)
class _ShimmerButton extends StatelessWidget {
  const _ShimmerButton({
    required this.controller, // not used; kept for compatibility
    required this.success,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final AnimationController controller; // kept
  final bool success;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
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
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return _ink900.withOpacity(.40);
          }
          if (states.contains(MaterialState.pressed)) {
            return _ink900.withOpacity(.92);
          }
          if (states.contains(MaterialState.hovered)) {
            return _ink900.withOpacity(.96);
          }
          return _ink900;
        }),
        foregroundColor: const MaterialStatePropertyAll(Colors.white),
        overlayColor: MaterialStatePropertyAll(_accentMint.withOpacity(0.14)),
        elevation: MaterialStatePropertyAll(loading ? 2 : 4),
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
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : success
                ? const Icon(
                  Icons.check,
                  key: ValueKey('ok'),
                  color: Colors.white,
                )
                : Row(
                  key: const ValueKey('content'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(label),
                  ],
                ),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: btn,
    );
  }
}
