import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/group_discover_page.dart';

final groupChatRepositoryProvider = Provider<GroupChatRepository>(
  (ref) => GroupChatRepository(ref.watch(dioProvider)),
);

class GroupChatRepository {
  GroupChatRepository(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listMyRooms() async {
    try {
      final res = await _dio.get<List<dynamic>>('/group-rooms/me');
      final raw = res.data ?? [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<GroupDiscoverPage> fetchDiscoverRoomsPage({int page = 1}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/group-rooms/discover',
        queryParameters: {'page': page},
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Sunucu yanıtı boş.');
      }
      return GroupDiscoverPage.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<Map<String, dynamic>> getRoom(String roomId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/group-rooms/$roomId');
      return res.data!;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<dynamic>> listMessages(String roomId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/group-rooms/$roomId/messages');
      return res.data ?? [];
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<Map<String, dynamic>> createJoinRequest(
    String roomId, {
    String? message,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/group-rooms/$roomId/join-request',
        data: message != null && message.trim().isNotEmpty
            ? {'message': message.trim()}
            : {},
      );
      return res.data!;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<String> uploadChatImage({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/media/chat-image',
        data: form,
      );
      final url = res.data?['url'];
      if (url is! String || url.isEmpty) {
        throw ApiException('Yukleme yaniti gecersiz.');
      }
      return url;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    return ApiException.fromDio(e, baseUrl: _dio.options.baseUrl);
  }
}
