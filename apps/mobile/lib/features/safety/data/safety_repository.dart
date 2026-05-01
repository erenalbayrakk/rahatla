import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(ref.watch(dioProvider)),
);

class SafetyRepository {
  SafetyRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> submitReport({
    required String reportedUserId,
    String? sessionId,
    required String reason,
    String? description,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/safety/reports',
        data: {
          'reportedUserId': reportedUserId,
          if (sessionId != null) 'sessionId': sessionId,
          'reason': reason,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> blockUser(String blockedId) async {
    try {
      await _dio.post<void>('/safety/blocks', data: {'blockedId': blockedId});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    return ApiException.fromDio(e, baseUrl: _dio.options.baseUrl);
  }
}
