import 'package:flutter/material.dart';

import '../../../main.dart';

const _snackInk900 = Color(0xFF282321);

void showSnackBar(
  String text, {
  bool isError = false,
  Duration duration = const Duration(seconds: 4),
}) {
  final BuildContext? context = globalNavigatorKey.currentContext;
  if (context == null) return;

  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final double bottomMargin = screenHeight * 0.04;

  final isWide = screenWidth > 500;
  final hMargin = isWide ? (screenWidth - 440) / 2 : 16.0;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: bottomMargin,
          left: hMargin,
          right: hMargin,
        ),
        padding: EdgeInsets.zero,
        content: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFC62828) : _snackInk900,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
}

extension EmailValidation on String {
  bool isEmailValid() {
    return RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    ).hasMatch(this);
  }
}

extension PhoneNumberValidation on String {
  bool isPhoneNumberValid() {
    return RegExp(r'(^(?:[+0]9)?[0-9]{10,12}$)').hasMatch(this);
  }
}

extension NumberToWeight on double {
  String toWeight() {
    if (this >= 1000) {
      return "${(this / 1000).toStringAsFixed(3)} MT";
    } else {
      return "${toStringAsFixed(3)} Kg";
    }
  }
}
// Future<FilePickerResult?> pickImage() async {
//   final image = await FilePicker.platform.pickFiles(type: FileType.image);
//   return image;
// }

extension RoundOfDecimal on double {
  double roundOf() {
    return double.parse(toStringAsFixed(3));
  }
}
