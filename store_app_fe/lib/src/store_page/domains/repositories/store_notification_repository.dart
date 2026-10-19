import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/providers.dart';
import '../../../auth/shared/providers/token_provider.dart';
import '../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';
import '../models/store_notification_model.dart';

final storeNotificationRepositoryProvider = Provider(
  (ref) => StoreNotificationRepository(ref),
);

class StoreNotificationRepository {
  final Ref ref;
  StoreNotificationRepository(this.ref);

  Future<String> _getToken() async {
    String token = ref.read(authTokenProvider);
    if (token.isEmpty) {
      token =
          await ref.read(spRepositoryProvider).getStringValue('authToken');
      if (token.isNotEmpty) {
        ref.read(authTokenProvider.notifier).updateToken(token);
      }
    }
    return token;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _extractErrorMessage(Map<String, dynamic> data, {String fallback = 'Operation failed'}) {
    if (data['msg'] != null && data['msg'].toString().isNotEmpty) {
      return data['msg'].toString();
    }
    if (data['message'] != null) {
      if (data['message'] is List) {
        return (data['message'] as List).join(', ');
      }
      return data['message'].toString();
    }
    return fallback;
  }

  FutureEither<List<StoreNotificationModel>> getNotifications() async {
    try {
      final headers = await _headers();
      final res = await ref.read(httpClientProvider).get(
            Uri.http(Constants.serverUrl, 'api/store/notifications'),
            headers: headers,
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final list = (data['data'] as List<dynamic>?) ?? [];
        final items = list
            .map((e) => StoreNotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return Right(items);
      }

      return Left(Failure(_extractErrorMessage(data, fallback: 'Failed to load notifications'), StackTrace.current));
    } catch (e, st) {
      log('getNotifications error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<int> getUnreadCount() async {
    try {
      final headers = await _headers();
      final res = await ref.read(httpClientProvider).get(
            Uri.http(Constants.serverUrl, 'api/store/notifications/unread-count'),
            headers: headers,
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final count = (data['data']?['count'] as num?)?.toInt() ?? 0;
        return Right(count);
      }

      return Left(Failure(_extractErrorMessage(data, fallback: 'Failed to get unread count'), StackTrace.current));
    } catch (e, st) {
      log('getUnreadCount error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<bool> markAsRead(String id) async {
    try {
      final headers = await _headers();
      final res = await ref.read(httpClientProvider).patch(
            Uri.http(Constants.serverUrl, 'api/store/notifications/$id/read'),
            headers: headers,
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const Right(true);
      }

      return Left(Failure(_extractErrorMessage(data, fallback: 'Failed to mark as read'), StackTrace.current));
    } catch (e, st) {
      log('markAsRead error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<bool> markAllAsRead() async {
    try {
      final headers = await _headers();
      final res = await ref.read(httpClientProvider).patch(
            Uri.http(Constants.serverUrl, 'api/store/notifications/read-all'),
            headers: headers,
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const Right(true);
      }

      return Left(Failure(_extractErrorMessage(data, fallback: 'Failed to mark all as read'), StackTrace.current));
    } catch (e, st) {
      log('markAllAsRead error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<bool> removeNotification(String id) async {
    try {
      final headers = await _headers();
      final res = await ref.read(httpClientProvider).delete(
            Uri.http(Constants.serverUrl, 'api/store/notifications/$id'),
            headers: headers,
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const Right(true);
      }

      return Left(Failure(_extractErrorMessage(data, fallback: 'Failed to remove notification'), StackTrace.current));
    } catch (e, st) {
      log('removeNotification error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }
}
