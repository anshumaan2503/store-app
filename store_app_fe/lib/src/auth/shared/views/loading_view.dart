import 'package:flutter/material.dart';

import '../widgets/loader_widget.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Loader());
  }
}
