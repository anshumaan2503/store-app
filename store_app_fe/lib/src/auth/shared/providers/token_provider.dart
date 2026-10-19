import 'package:flutter_riverpod/flutter_riverpod.dart';

final authTokenProvider = StateNotifierProvider<AuthTokenNotifier, String>(
    (ref) => AuthTokenNotifier());

class AuthTokenNotifier extends StateNotifier<String> {
  AuthTokenNotifier() : super("");

  void updateToken(String token) {
    state = token;
  }

  String getToken() => state;

  void clearToken() => state = "";
}
