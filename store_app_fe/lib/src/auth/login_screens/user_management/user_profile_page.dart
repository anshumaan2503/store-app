// profile_page.dart
// ---------------------------------------------------------------------
// Professional UI pass using your color palette (no logic changes).
// - Light background gradient (_bgTop -> _bgBottom), no images
// - Polished white hero card with floating avatar + chips
// - Responsive sections: stacked on phones, two-column on wide
// - Existing upload (base64) + edit navigation preserved
// - Added profile image preview on tap
// ---------------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:store_app/src/auth/login_screens/user_management/edit_user_page.dart';

import '../../../auth/controllers/users_controller.dart';
import '../../../components/constants.dart';
import '../../domains/models/auth_model.dart';
import '../../widgets/app_bar_page.dart';

/* -------------------- Palette (your scheme) -------------------- */
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

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paged = ref.watch(userFindOneDataStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _bgBottom,
      appBar: const GlassAppBar(title: Text('Profile'), showBackButton: true),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgTop, _bgBottom],
              ),
            ),
            child: paged.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: _ink900),
                    ),
                  ),
              data: (user) {
                if (user == null) {
                  return const Center(
                    child: Text(
                      'No user found',
                      style: TextStyle(color: _ink900),
                    ),
                  );
                }

                return SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final isWide = c.maxWidth >= 760;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 88, 16, 24),
                            child: Column(
                              children: [
                                _HeroCard(user: user),
                                const SizedBox(height: 18),
                                if (isWide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _SectionCard(
                                          title: 'Account',
                                          icon: Icons.person_outline,
                                          children: [
                                            _InfoRow(_KV('Email', user.email)),
                                            _InfoRow(
                                              _KV('Phone', user.phoneNumber),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _SectionCard(
                                          title: 'Meta',
                                          icon: Icons.info_outline,
                                          children: [
                                            _InfoRow(
                                              _KV(
                                                'Active',
                                                user.isActive ? 'Yes' : 'No',
                                              ),
                                            ),
                                            _InfoRow(
                                              _KV(
                                                'Created',
                                                _fmtDate(user.createdAt),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      _SectionCard(
                                        title: 'Account',
                                        icon: Icons.person_outline,
                                        children: [
                                          _InfoRow(_KV('Email', user.email)),
                                          _InfoRow(
                                            _KV('Phone', user.phoneNumber),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _SectionCard(
                                        title: 'Meta',
                                        icon: Icons.info_outline,
                                        children: [
                                          _InfoRow(
                                            _KV(
                                              'Active',
                                              user.isActive ? 'Yes' : 'No',
                                            ),
                                          ),
                                          _InfoRow(
                                            _KV(
                                              'Created',
                                              _fmtDate(user.createdAt),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Image.asset('assets/icons/logo.png', height: 40),
                const SizedBox(height: 8),
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
        ],
      ),
    );
  }
}

/* ============================== HERO CARD ============================== */

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.user});
  final AuthModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name = (user.name.trim().isNotEmpty) ? user.name : 'No Name';
    final String email = user.email;
    final bool isActive = user.isActive ? user.isActive : false;

    final String displayLetter =
        name.isNotEmpty
            ? name[0].toUpperCase()
            : (email.isNotEmpty ? email[0].toUpperCase() : 'U');

    String? imageUrl;
    try {
      if ((user.imageUrl).isNotEmpty) {
        imageUrl = user.imageUrl;
      }
    } catch (_) {}

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _stroke, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 66, 16, 16),
            child: Column(
              children: [
                Text(
                  name.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink900,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: isActive ? 'ACTIVE' : 'INACTIVE',
                      icon: isActive ? Icons.verified : Icons.block,
                      fg:
                          isActive
                              ? const Color(0xFF155724)
                              : const Color(0xFF7E1C1C),
                      bg:
                          isActive
                              ? const Color(0xFFD4EDDA)
                              : const Color(0xFFF9D6D5),
                      border:
                          isActive
                              ? const Color(0xFFB7E4C7)
                              : const Color(0xFFF1B0B7),
                    ),
                    if (email.isNotEmpty)
                      _StatusChip(
                        label: email,
                        icon: Icons.mail_outline,
                        fg: _ink700,
                        bg: _bgTop,
                        border: _stroke,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _PrimaryButton.icon(
                  icon: Icons.edit_rounded,
                  label: 'Edit Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => UserEditPage(
                              initial: user,
                              currentViewerIsAdmin: false,
                              isEditingSelf: true,
                            ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  height: 3,
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [_accentPeach, _accentMint],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -44,
          left: 0,
          right: 0,
          child: Center(
            child: _AvatarBase64(
              size: 96,
              displayLetter: displayLetter,
              initialUrl: imageUrl,
              uid: user.uid,
              onSuccess: () => ref.invalidate(userFindOneDataStreamProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color fg, bg, border;

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
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: .2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================ AVATAR ============================ */

class _AvatarBase64 extends StatefulWidget {
  const _AvatarBase64({
    required this.displayLetter,
    required this.uid,
    this.initialUrl,
    this.size = 76,
    required this.onSuccess,
  });

  final String displayLetter;
  final String uid;
  final String? initialUrl;
  final double size;
  final VoidCallback onSuccess;

  @override
  State<_AvatarBase64> createState() => _AvatarBase64State();
}

class _AvatarBase64State extends State<_AvatarBase64> {
  final _picker = ImagePicker();
  bool _busy = false;
  Uint8List? _localBytes;
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
  }

  Future<String> uploadUserPhotoBase64({
    required String baseUrl,
    required String uid,
    required Uint8List bytes,
    String filename = 'avatar.jpg',
  }) async {
    String mime = 'image/jpeg';
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) mime = 'image/png';
    if (lower.endsWith('.webp')) mime = 'image/webp';

    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    final uri = Uri.parse('${Constants.socketUrl}/api/auth/$uid/image/base64');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'base64': dataUrl}),
    );

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Upload failed: ${body['msg'] ?? body['error'] ?? res.body}',
      );
    }

    final photoUrl =
        (body['imageUrl'] ??
                body['user']?['imageUrl'] ??
                body['entity']?['imageUrl'])
            ?.toString();

    if (photoUrl == null || photoUrl.isEmpty) {
      throw Exception('Upload OK but no photoUrl returned');
    }

    return photoUrl;
  }

  Future<void> _pick(ImageSource src) async {
    final x = await _picker.pickImage(
      source: src,
      imageQuality: 88,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (x == null) return;

    final bytes = await x.readAsBytes();
    setState(() {
      _localBytes = bytes;
      _busy = true;
    });

    try {
      final newUrl = await uploadUserPhotoBase64(
        baseUrl: Constants.socketUrl,
        uid: widget.uid,
        bytes: bytes,
        filename: x.name,
      );
      if (!mounted) return;

      setState(() {
        _url = newUrl;
        _busy = false;
      });

      widget.onSuccess();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  void _showSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Material(
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
                        style: TextStyle(color: _ink900),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pick(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.photo_library_outlined,
                        color: _ink900,
                      ),
                      title: const Text(
                        'Choose from Gallery',
                        style: TextStyle(color: _ink900),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pick(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showPreview() {
    final hasImage = (_localBytes != null) || ((_url ?? '').trim().isNotEmpty);

    if (!hasImage) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .82),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * .9,
            height: MediaQuery.of(context).size.height * .75,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stroke),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Profile Image Preview',
                          style: TextStyle(
                            color: _ink900,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _stroke),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: Colors.black,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: SizedBox.expand(
                          child:
                              _localBytes != null
                                  ? Image.memory(
                                    _localBytes!,
                                    fit: BoxFit.contain,
                                  )
                                  : Image.network(
                                    Uri.encodeFull((_url ?? '').trim()),
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) {
                                      return Center(
                                        child: Text(
                                          widget.displayLetter,
                                          style: const TextStyle(
                                            fontSize: 72,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    Widget inner;
    if (_localBytes != null) {
      inner = ClipOval(
        child: Image.memory(
          _localBytes!,
          width: s,
          height: s,
          fit: BoxFit.cover,
        ),
      );
    } else if (_url != null && _url!.isNotEmpty) {
      inner = ClipOval(
        child: Image.network(
          _url!,
          width: s,
          height: s,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => Center(
                child: Text(
                  widget.displayLetter,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _ink900,
                  ),
                ),
              ),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    } else {
      inner = Center(
        child: Text(
          widget.displayLetter,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _ink900,
          ),
        ),
      );
    }

    final hasImage = (_localBytes != null) || ((_url ?? '').trim().isNotEmpty);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: (_busy || !hasImage) ? null : _showPreview,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _accentMint.withValues(alpha: .55),
                  _surfaceAlt.withValues(alpha: .45),
                ],
              ),
              border: Border.all(color: _stroke, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: inner,
              ),
            ),
          ),
        ),
        // if (hasImage)
        //   Positioned(
        //     left: -2,
        //     bottom: -2,
        //     child: GestureDetector(
        //       onTap: (_busy || !hasImage) ? null : _showPreview,
        //       child: Container(
        //         width: 30,
        //         height: 30,
        //         decoration: BoxDecoration(
        //           shape: BoxShape.circle,
        //           color: _surface,
        //           border: Border.all(color: _stroke),
        //           boxShadow: const [
        //             BoxShadow(
        //               color: Color(0x14000000),
        //               blurRadius: 8,
        //               offset: Offset(0, 4),
        //             ),
        //           ],
        //         ),
        //         child: const Icon(
        //           Icons.visibility_outlined,
        //           size: 16,
        //           color: _ink900,
        //         ),
        //       ),
        //     ),
        //   ),
        Positioned(
          right: -2,
          bottom: -2,
          child: GestureDetector(
            onTap: _busy ? null : _showSheet,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _surface,
                border: Border.all(color: _stroke),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 16,
                color: _ink900,
              ),
            ),
          ),
        ),
        if (_busy)
          Positioned.fill(
            child: ClipOval(
              child: Container(
                color: Colors.black.withValues(alpha: .08),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/* ============================== CONTENT CARDS ============================== */

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, icon: icon),
            const SizedBox(height: 12),
            ..._withDividers(children),
          ],
        ),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: _stroke,
          ),
        );
      }
    }
    return out;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _ink900, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _ink900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 2,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.kv);
  final _KV kv;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _bgTop,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              kv.key,
              style: const TextStyle(
                color: _ink600,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: .2,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              kv.value,
              style: const TextStyle(
                color: _ink900,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== BUTTON (CTA) ============================== */

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton._({required this.onPressed, required this.child});
  final VoidCallback onPressed;
  final Widget child;

  factory _PrimaryButton.icon({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return _PrimaryButton._(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _ink900),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        splashColor: _accentMint.withValues(alpha: .18),
        highlightColor: _accentPeach.withValues(alpha: .10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/* =============================== UTILITIES =============================== */

class _KV {
  final String key;
  final String value;
  final bool copyable;
  final String? raw;

  _KV(this.key, this.value) : raw = null, copyable = false;
}

String _fmtDate(DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year}  ${two(d.hour)}:${two(d.minute)}';
}
