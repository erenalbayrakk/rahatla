import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final supportRequestRepositoryProvider = Provider<SupportRequestRepository>(
  (ref) => SupportRequestRepository(ref.watch(dioProvider)),
);

class CreatedSupportRequest {
  const CreatedSupportRequest({required this.id});

  final String id;

  factory CreatedSupportRequest.fromJson(Map<String, dynamic> json) {
    return CreatedSupportRequest(id: json['id'] as String);
  }
}

class SupportRequestRepository {
  SupportRequestRepository(this._dio);

  final Dio _dio;

  Future<CreatedSupportRequest> create({
    required String category,
    required String languageCode,
    required String communicationPreference,
    String? note,
  }) async {
    try {
      final body = <String, dynamic>{
        'category': category,
        'languageCode': languageCode,
        'communicationPreference': communicationPreference,
      };
      final trimmed = note?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        body['note'] = trimmed;
      }
      final res = await _dio.post<Map<String, dynamic>>(
        '/support-requests',
        data: body,
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Sunucu yanıtı boş.');
      }
      return CreatedSupportRequest.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    return ApiException.fromDio(e, baseUrl: _dio.options.baseUrl);
  }
}
