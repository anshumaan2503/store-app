import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domains/models/auth_model.dart';

final authModelProvider = StateNotifierProvider<AuthModelNotifier, AuthModel?>(
    (ref) => AuthModelNotifier());

class AuthModelNotifier extends StateNotifier<AuthModel?> {
  AuthModelNotifier() : super(null);

  void setAuthModel(AuthModel? authModel) => state = authModel;

  AuthModel? getAuthModel() => state;

  void clearAuthModel() => state = null;
}
