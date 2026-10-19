import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// === Your existing palette ===
const _ink900 = Color(0xFF282321);
const _ink600 = Color(0xFF867471);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = Color(0xFFFFF4E2);
const _accentPeach = Color(0xFFF3D7C0);
const _accentMint = Color(0xFFB6D3CC);

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.height = 56,
    this.showBackButton = true,
    this.backgroundColor,
  });

  final Widget title;
  final List<Widget>? actions;
  final double height;
  final bool showBackButton;
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final bgColor =
        backgroundColor ??
        const LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(0, 0, 200, 200));

    // Force light system icons (black text, battery, etc.) since background is light
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
        border: Border(bottom: BorderSide(color: _stroke, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showBackButton && Navigator.canPop(context))
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _RoundedButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.maybePop(context),
                  ),
                )
              else
                const SizedBox(width: 52),

              // Title
              Expanded(
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink900,
                    letterSpacing: .2,
                  ),
                  textAlign: TextAlign.center,
                  child: title,
                ),
              ),

              // Actions
              if (actions != null && actions!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      actions!
                          .map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _RoundedButton(
                                background: _accentMint.withValues(alpha: .25),
                                child: w,
                              ),
                            ),
                          )
                          .toList(),
                )
              else
                const SizedBox(width: 52),
            ],
          ),
        ),
      ),
    );
  }
}

/* ----------------------- Helper: Rounded Buttons ----------------------- */

class _RoundedButton extends StatelessWidget {
  const _RoundedButton({this.icon, this.child, this.onTap, this.background});

  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? _bgBottom,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _accentPeach.withValues(alpha: .3),
        highlightColor: Colors.transparent,
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: background ?? _bgBottom,
            border: Border.all(color: _stroke),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: child ?? Icon(icon ?? Icons.arrow_back_rounded, color: _ink900, size: 20),
          ),
        ),
      ),
    );
  }
}
