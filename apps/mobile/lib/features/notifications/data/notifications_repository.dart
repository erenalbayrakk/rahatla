import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(dioProvider)),
);

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchList() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/notifications');
      return res.data ?? {'items': <dynamic>[], 'unreadCount': 0};
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<int> fetchUnreadCount() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
      final n = res.data?['unreadCount'];
      if (n is num) return n.toInt();
      return 0;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _dio.patch<void>('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post<void>('/notifications/read-all');
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Admin filtre push için — giriş sonrası ve token yenilenince çağrılmalı.
  Future<void> registerFcmToken({
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await _dio.post<void>(
        '/notifications/fcm-token',
        data: {'fcmToken': fcmToken, 'platform': platform},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    return ApiException.fromDio(e, baseUrl: _dio.options.baseUrl);
  }
}
