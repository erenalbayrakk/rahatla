import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/browse_listener.dart';

final listenerBrowseRepositoryProvider = Provider<ListenerBrowseRepository>(
  (ref) => ListenerBrowseRepository(ref.watch(dioProvider)),
);

class ListenerBrowseRepository {
  ListenerBrowseRepository(this._dio);

  final Dio _dio;

  Future<BrowsePage> fetchBrowse({
    String filter = 'all',
    int page = 1,
    /// `all` → sunucu profil ruh halini listeye uygulamaz (tüm uygun dinleyenler).
    String? mood,
    String? q,
    int? minAge,
    int? maxAge,
    String? gender,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/listeners/browse',
        queryParameters: {
          'filter': filter,
          'page': page,
          if (mood != null && mood.isNotEmpty) 'mood': mood,
          if (q != null && q.isNotEmpty) 'q': q,
          if (minAge != null) 'minAge': minAge,
          if (maxAge != null) 'maxAge': maxAge,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
        },
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Sunucu yanıtı boş.');
      }
      return BrowsePage.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<SessionFromSelection> createSessionFromSelection({
    required String listenerUserId,
    String? supportRequestId,
    String type = 'text_chat',
  }) async {
    try {
      final body = <String, dynamic>{
        'listenerUserId': listenerUserId,
        'type': type,
      };
      if (supportRequestId != null && supportRequestId.isNotEmpty) {
        body['supportRequestId'] = supportRequestId;
      }
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/from-selection',
        data: body,
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Sunucu yanıtı boş.');
      }
      return SessionFromSelection.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<SessionFromSelection> createSessionFromRandom({
    String? supportRequestId,
    String type = 'text_chat',
  }) async {
    try {
      final body = <String, dynamic>{'type': type};
      if (supportRequestId != null && supportRequestId.isNotEmpty) {
        body['supportRequestId'] = supportRequestId;
      }
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/from-random',
        data: body,
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Sunucu yanıtı boş.');
      }
      return SessionFromSelection.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    return ApiException.fromDio(e, baseUrl: _dio.options.baseUrl);
  }
}
