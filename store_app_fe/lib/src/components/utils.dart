import 'package:flutter/material.dart';

import '../../../main.dart';

void showSnackBar(String text) {
  final BuildContext context = globalNavigatorKey.currentContext!;
  final double screenHeight = MediaQuery.of(context).size.height;

  // Set bottom margin as a percentage of screen height (e.g., 5% of screen height)
  final double bottomMargin = screenHeight * 0.085;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent, // Set transparent background
        elevation: 0, // No elevation
        behavior:
            SnackBarBehavior.floating, // Floating behavior allows positioning
        margin: EdgeInsets.only(
          bottom: bottomMargin,
        ), // Bottom margin as percentage of screen height
        padding: const EdgeInsets.all(0), // No padding around the container
        content: Builder(
          builder: (context) {
            // Measure text size to set snackBar width
            TextSpan textSpan = TextSpan(
              text: text,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            );
            TextPainter textPainter = TextPainter(
              text: textSpan,
              maxLines: 1,
              textDirection: TextDirection.ltr,
            )..layout(
              minWidth: 0,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            );

            // Set width based on text length, with padding for neatness
            double snackBarWidth =
                textPainter.width + 40; // Add some padding around the text

            return Align(
              alignment: Alignment.bottomCenter, // Align SnackBar at the bottom
              child: Container(
                width: snackBarWidth, // Dynamically adjust width
                height: screenHeight * 0.04, // Fixed height
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary, // Background color
                  borderRadius: BorderRadius.circular(20), // Rounded corners
                ),
                alignment: Alignment.center,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            );
          },
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
