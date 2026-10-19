import 'dart:ui';

import 'package:flutter/material.dart';

class Glass extends StatelessWidget {
  const Glass({super.key, 
    required this.child,
    required this.radius,
    required this.padding,
    this.borderTint = Colors.blueAccent,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color borderTint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0x66FFFFFF), Color(0x22FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderTint.withValues(alpha: .45)),
              boxShadow: [
                BoxShadow(
                  color: borderTint.withValues(alpha: .25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}