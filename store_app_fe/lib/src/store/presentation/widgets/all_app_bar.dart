import 'dart:ui';
import 'package:flutter/material.dart';

class MyAppbar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppbar({super.key, this.onMenuTap, this.onActionTap});

  final VoidCallback? onMenuTap;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true, // ⬅ removes the default status bar space
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            leading: IconButton(
              icon: const Icon(Icons.storefront_outlined, color: Colors.white),
              onPressed:
                  onMenuTap ??
                  () {
                    Navigator.of(context).pop();
                  },
              tooltip: "Menu",
            ),
            title: const Text(
              'Store App',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                tooltip: "Notifications",
                onPressed: onActionTap ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
