import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
// import 'package:store_app/components/api_socket_constants.dart';
import 'package:store_app/src/components/constants.dart';
import '../auth/domains/providers/uid_provider.dart';
import '../auth/shared/providers/providers.dart';
import '../auth/shared/providers/token_provider.dart';
import 'api_socket_constants.dart';

final socketProvider = Provider((ref) {
  final token = ref.watch(authTokenProvider); // ✅ was read()

  final manager = SocketManager(
    io.io(
      Constants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setExtraHeaders({
            "Authorization": "Bearer $token", // ✅ uses latest token
          })
          .build(),
    ),
  );

  // ✅ dispose previous socket when provider rebuilds (token changes) or container disposes
  ref.onDispose(() {
    try {
      manager.dispose(ref);
    } catch (_) {}
  });

  return manager;
});

class SocketManager {
  final io.Socket? socket;
  bool _inited = false; // ✅ add

  SocketManager(this.socket);

  io.Socket getSocket() {
    if (socket == null) {
      throw Exception('Socket is not initialized');
    }
    return socket!;
  }

  initAuthConnection(Ref ref) {
    final currentSocket = getSocket();

    // ✅ prevent duplicate listeners on rebuilds
    if (_inited) {
      if (!currentSocket.connected) currentSocket.connect();
      return;
    }
    _inited = true;

    currentSocket.onConnect((_) {
      currentSocket.emit(ApiSocketConstants.authConnection, {
        "id": ref.read(
          uidProvider,
        ), // will work once uidProvider is set on login
      });
      ref.read(loggerProvider).i('Successfully connected to WebSocket');
    });

    currentSocket.onConnectError((e) {
      ref.read(loggerProvider).e(
            'WS connect error to [${Constants.socketUrl}]: $e',
          );
    });

    currentSocket.onError((error) {
      ref.read(loggerProvider).e(
            'WS Error [${Constants.socketUrl}]: ${error.toString()}',
          );
    });

    currentSocket.onDisconnect((_) {
      ref.read(loggerProvider).w('Disconnected from WebSocket');
    });

    // ✅ connect after listeners are attached
    currentSocket.connect();
  }

  void dispose(dynamic ref) {
    final currentSocket = getSocket();

    try {
      currentSocket.emit(ApiSocketConstants.authDispose, {
        "id": ref.read(uidProvider),
      });
    } catch (_) {}

    currentSocket.off('connect');
    currentSocket.off('connect_error');
    currentSocket.off('error');
    currentSocket.off('disconnect');
    currentSocket.disconnect(); // ✅ close connection
    currentSocket.dispose(); // existing
  }
}
