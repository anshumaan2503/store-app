import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../components/constants.dart';

final themeDataProvider = StateNotifierProvider<ThemeNotifier, ThemeData>(
  (ref) => ThemeNotifier(),
);

class ThemeNotifier extends StateNotifier<ThemeData> {
  ThemeNotifier()
    : super(
        Constants.applyHoverTheme(
          FlexThemeData.dark(scheme: FlexScheme.flutterDash, useMaterial3: true),
        ),
      );

  void setTheme(ThemeData themeData) => state = Constants.applyHoverTheme(themeData);

  void resetTheme() =>
      state = Constants.applyHoverTheme(FlexThemeData.dark());
}
