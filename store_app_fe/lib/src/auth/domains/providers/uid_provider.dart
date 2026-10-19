import 'package:flutter_riverpod/flutter_riverpod.dart';

final uidProvider = StateNotifierProvider<UidNotifier, String>(
    (ref) => UidNotifier());

class UidNotifier extends StateNotifier<String> {
  UidNotifier() : super("");

  void updateUid(String token) => state = token;

  String getUid() => state;

  void clearUid() => state = "";
}
