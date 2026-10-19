import 'package:flutter/material.dart';

/// Centralized UI Tokens & Styling Helpers for Store App
/// Ensures 100% preservation of existing theme colors and icons while elevating visual depth.

class AppRadii {
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double pill = 50.0;

  static const BorderRadius borderS8 = BorderRadius.all(Radius.circular(s8));
  static const BorderRadius borderS12 = BorderRadius.all(Radius.circular(s12));
  static const BorderRadius borderS16 = BorderRadius.all(Radius.circular(s16));
  static const BorderRadius borderS20 = BorderRadius.all(Radius.circular(s20));
  static const BorderRadius borderPill = BorderRadius.all(Radius.circular(pill));
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingPage = EdgeInsets.symmetric(horizontal: lg, vertical: md);
}

class AppShadows {
  static List<BoxShadow> soft(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: isDark ? Colors.black.withValues(alpha: 0.20) : Colors.black.withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 2),
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> hover(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark ? Colors.black.withValues(alpha: 0.50) : Colors.black.withValues(alpha: 0.12),
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: 2,
      ),
    ];
  }

  static List<BoxShadow> glass(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

class AppGlassDecoration {
  static BoxDecoration container(
    BuildContext context, {
    BorderRadius? borderRadius,
    Color? customColor,
    Border? border,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = customColor ??
        (isDark ? const Color(0xCC1E1C24) : const Color(0xCCFFFFFF));
    final defaultBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0,
        );

    return BoxDecoration(
      color: baseColor,
      borderRadius: borderRadius ?? AppRadii.borderS16,
      border: defaultBorder,
      boxShadow: AppShadows.glass(context),
    );
  }
}

class AppAnimationTokens {
  static const Duration hover = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration transition = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration modal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration pulse = Duration(milliseconds: 1400);

  static const Curve cubic = Curves.easeInOutCubic;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve entrance = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;
}

class AppPillBadgeStyle {
  static BoxDecoration decoration({
    required Color color,
    required BuildContext context,
    bool isSoft = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isSoft
          ? color.withValues(alpha: isDark ? 0.22 : 0.12)
          : color,
      borderRadius: AppRadii.borderPill,
      border: Border.all(
        color: color.withValues(alpha: isDark ? 0.45 : 0.30),
        width: 1.0,
      ),
    );
  }
}
