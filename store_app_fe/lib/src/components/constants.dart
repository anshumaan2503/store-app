import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';

class Constants {
  // static const String serverUrl = "storebe.yuvaq.com";
  // static String socketUrl = "https://$serverUrl";

  // static const String serverUrl = "storedemobe.rrispat.in";
  // static String socketUrl = "https://$serverUrl";

  // Laptop local development IP (Wi-Fi network):
  static const String _laptopIp = "192.168.29.138:8080";
  static const String serverUrl = kIsWeb ? "localhost:8080" : _laptopIp;
  static String socketUrl = "http://$serverUrl";

  static const String fcmVapidKey =
      "BIVP6VaAC3lcDhfhB9OIellDoJSbHSoPtrCtMH_tQBRmRcRz88i1It-BZw2KdmvEJcxc07DhkEhL8JMMhzqs0rs";

  static const String webClientId =
      '66417910817-0tp2pn046499v2c5b0rqhj3tocgs3e9i.apps.googleusercontent.com';

  static ThemeData applyHoverTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final hoverColor = isDark
        ? const Color(0x3DFFFFFF) // ~24% white hover in dark mode
        : const Color(0x24000000); // ~14% black hover in light mode
    final highlightColor = isDark
        ? const Color(0x52FFFFFF) // ~32% white press in dark mode
        : const Color(0x3D000000); // ~24% black press in light mode

    final overlayStateColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return null;
      }
      if (states.contains(WidgetState.pressed)) {
        return highlightColor;
      }
      if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
        return hoverColor;
      }
      return null;
    });

    final mouseCursorState = WidgetStateProperty.resolveWith<MouseCursor?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return SystemMouseCursors.basic;
      }
      return SystemMouseCursors.click;
    });

    const defaultRadius = BorderRadius.all(Radius.circular(12.0));
    const cardRadius = BorderRadius.all(Radius.circular(16.0));
    const dialogRadius = BorderRadius.all(Radius.circular(20.0));

    return theme.copyWith(
      hoverColor: hoverColor,
      highlightColor: highlightColor,
      splashColor: highlightColor,
      focusColor: hoverColor,

      // Modern Soft Card Styling
      cardTheme: theme.cardTheme.copyWith(
        shape: const RoundedRectangleBorder(borderRadius: cardRadius),
        elevation: isDark ? 1.5 : 1.0,
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      ),

      // Modern Overlay Dialog & Bottom Sheet Styling
      dialogTheme: theme.dialogTheme.copyWith(
        shape: const RoundedRectangleBorder(borderRadius: dialogRadius),
        elevation: 8.0,
      ),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        elevation: 10.0,
      ),


      // Modern Button Themes (12px Rounded Corners) with High-Contrast Legible Colors
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          mouseCursor: mouseCursorState,
          overlayColor: overlayStateColor,
          padding: WidgetStateProperty.all(const EdgeInsets.all(8.0)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark ? Colors.white38 : Colors.black38;
            }
            return isDark ? const Color(0xFF90CAF9) : theme.colorScheme.primary;
          }),
          mouseCursor: mouseCursorState,
          overlayColor: overlayStateColor,
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)),
          shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: defaultRadius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark ? Colors.white38 : Colors.black38;
            }
            return isDark ? Colors.white : theme.colorScheme.primary;
          }),
          mouseCursor: mouseCursorState,
          overlayColor: overlayStateColor,
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0)),
          shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: defaultRadius)),
          side: WidgetStateProperty.all(BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5))),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark ? Colors.white38 : Colors.black38;
            }
            return Colors.white;
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark ? Colors.white12 : Colors.black12;
            }
            return theme.colorScheme.primary;
          }),
          mouseCursor: mouseCursorState,
          overlayColor: overlayStateColor,
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0)),
          shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: defaultRadius)),
          elevation: WidgetStateProperty.resolveWith<double>((states) {
            if (states.contains(WidgetState.hovered)) return 4.0;
            if (states.contains(WidgetState.pressed)) return 1.0;
            return 2.0;
          }),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark ? Colors.white38 : Colors.black38;
            }
            return Colors.white;
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark ? Colors.white12 : Colors.black12;
            }
            return theme.colorScheme.primary;
          }),
          mouseCursor: mouseCursorState,
          overlayColor: overlayStateColor,
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0)),
          shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: defaultRadius)),
        ),
      ),

      // Modern Chips & Status Badges
      chipTheme: theme.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(50.0))),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      ),

      // Modern Floating SnackBars
      snackBarTheme: theme.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: defaultRadius),
        elevation: 6.0,
      ),

      // Refined List Dividers
      dividerTheme: theme.dividerTheme.copyWith(
        space: 1.0,
        thickness: 1.0,
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
      ),

      // Tooltip styling
      tooltipTheme: theme.tooltipTheme.copyWith(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xE62A2834) : const Color(0xE61F2937),
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12.0),
      ),

      // Modern Smooth Scrollbars across all screens
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll<bool>(true),
        trackVisibility: const WidgetStatePropertyAll<bool>(false),
        interactive: true,
        thickness: WidgetStateProperty.resolveWith<double>((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
            return 8.0;
          }
          return 6.0;
        }),
        radius: const Radius.circular(8.0),
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.dragged)) {
            return theme.colorScheme.primary;
          }
          if (states.contains(WidgetState.hovered)) {
            return theme.colorScheme.primary.withValues(alpha: 0.9);
          }
          return isDark
              ? Colors.white.withValues(alpha: 0.35)
              : const Color(0xFF64748B).withValues(alpha: 0.45);
        }),
        trackColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        trackBorderColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        crossAxisMargin: 2.0,
        mainAxisMargin: 4.0,
        minThumbLength: 48.0,
      ),

      // Consistent High-Contrast Input Decoration (Ensures hints and labels are never opaque/obscured)
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF867471),
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF4D4542),
          fontSize: 13,
        ),
      ),

      // Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static List<ThemeData> themeDataList = [
    FlexThemeData.dark(scheme: FlexScheme.material, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.material, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.blue, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.blue, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.red, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.red, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.green, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.green, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.greyLaw, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.greyLaw, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.gold, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.gold, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.ebonyClay, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.ebonyClay, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.espresso, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.espresso, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.dellGenoa, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.dellGenoa, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.pinkM3, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.pinkM3, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.blueM3, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.blueM3, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.cyanM3, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.cyanM3, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.greenM3, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.greenM3, useMaterial3: false),
    FlexThemeData.dark(scheme: FlexScheme.yellowM3, useMaterial3: false),
    FlexThemeData.light(scheme: FlexScheme.yellowM3, useMaterial3: false),
  ].map((t) => applyHoverTheme(t)).toList();
}

// Colors
const kBackgroundColor = Color(0xff191720);
const kTextFieldFill = Color(0xff1E1C24);
// TextStyles
const kHeadline = TextStyle(
  color: Colors.white,
  fontSize: 34,
  fontWeight: FontWeight.bold,
);

const kBodyText = TextStyle(color: Colors.grey, fontSize: 15);

const kButtonText = TextStyle(
  color: Colors.black87,
  fontSize: 16,
  fontWeight: FontWeight.bold,
);

const kBodyText2 = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w500,
  color: Colors.white,
);

