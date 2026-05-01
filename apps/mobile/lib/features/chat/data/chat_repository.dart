import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(dioProvider)),
);

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  /// Karşı taraftan gelen okunmamış mesaj sayısı (alt sekme rozeti).
  Future<int> fetchUnreadIncomingMessagesCount() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/sessions/me/unread-count');
      final n = res.data?['unreadCount'];
      if (n is num) return n.toInt();
      return 0;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Birebir oturumlar (sohbetler sekmesi listesi).
  Future<Map<String, dynamic>> listMineForChats() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/sessions/me');
      return res.data ?? {'items': <dynamic>[]};
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/sessions/$sessionId');
      return res.data!;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<dynamic>> getMessages(String sessionId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/sessions/$sessionId/messages');
      return res.data ?? [];
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> endSession(String sessionId) async {
    try {
      await _dio.post<void>('/sessions/$sessionId/end');
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Socket kapalıyken birebir sohbette hediye (sistem mesajı + `session_gifts` kaydı).
  Future<Map<String, dynamic>> postGift(
    String sessionId, {
    required String giftCode,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/$sessionId/gifts',
        data: {'giftCode': giftCode},
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

  Future<Map<String, dynamic>> postImageMessage(
    String sessionId, {
    required String imageUrl,
    String? clientMessageId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/$sessionId/messages',
        data: {
          'messageType': 'image',
          'content': '',
          'imageUrl': imageUrl,
          if (clientMessageId != null) 'clientMessageId': clientMessageId,
        },
      );
      return res.data!;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Socket kullanılamazsa yedek gönderim.
  Future<Map<String, dynamic>> postTextMessage(
    String sessionId, {
    required String content,
    String? clientMessageId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/sessions/$sessionId/messages',
        data: {
          'content': content,
          if (clientMessageId != null) 'clientMessageId': clientMessageId,
        },
      );
      return res.data!;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    return ApiException.fromDio(e, baseUrl: _dio.options.baseUrl);
  }
}
