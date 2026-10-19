import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../components/assets_constants.dart';

class PageNotFoundView extends StatelessWidget {
  const PageNotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SizedBox(
          height: 250,
          width: 250,
          child: Lottie.asset(AssetsConstants.error404Animation),
        ),
      ),
    );
  }
}
