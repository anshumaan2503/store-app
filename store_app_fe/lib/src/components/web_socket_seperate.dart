import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:store_app/src/components/socket_manager.dart';

// import '../shared/repositories/shared_preference_repository.dart';
import '../auth/shared/providers/providers.dart';
// import 'socket_manager.dart';

final webSocketStateProvider =
    StateNotifierProvider<WebSocketStateNotifier, bool>((ref) {
      return WebSocketStateNotifier(ref);
    });

class WebSocketStateNotifier extends StateNotifier<bool> {
  final Ref ref;
  WebSocketStateNotifier(this.ref) : super(false);

  void updateConnectionState(bool isConnected) {
    state = isConnected;
  }

  void initSocketConnection() async {
    final socketManager = ref.read(socketProvider);
    socketManager.initAuthConnection(ref);

    // final sharedPrefs = await ref.read(spRepositoryProvider);

    socketManager.getSocket().onConnect((_) {
      updateConnectionState(true); // Connected
    });

    socketManager.getSocket().onDisconnect((_) {
      updateConnectionState(false); // Disconnected
    });

    socketManager.getSocket().onError((error) {
      ref.read(loggerProvider).e('WebSocket Error: $error');
      updateConnectionState(false); // In case of error, mark as disconnected
    });
  }

  void disposeSocketConnection() {
    final socketManager = ref.read(socketProvider);
    socketManager.dispose(ref);
  }
}
