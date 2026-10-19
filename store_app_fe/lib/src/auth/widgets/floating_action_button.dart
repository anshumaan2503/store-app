import 'dart:ui';
import 'package:flutter/material.dart';

class GlassFAB extends StatelessWidget {
  const GlassFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Icon icon;
  final Text label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.white.withValues(alpha: 0.15), // transparent glass
          elevation: 0,
          onPressed: onPressed,
          icon: icon,
          label: label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
      ),
    );
  }
}
