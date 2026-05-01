import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  static ApiException fromDio(
    DioException e, {
    String? baseUrl,
  }) {
    final code = e.response?.statusCode;
    final data = e.response?.data;

    String? message;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.trim().isNotEmpty) {
        message = m.trim();
      } else if (m is List && m.isNotEmpty) {
        message = m.first.toString().trim();
      }
      final err = data['error'];
      if ((message == null || message.isEmpty) &&
          err is String &&
          err.trim().isNotEmpty) {
        message = err.trim();
      }
    }

    if (message == null || message.isEmpty) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Bağlantı zaman aşımına uğradı. İnternetini kontrol edip tekrar dene.';
          break;
        case DioExceptionType.connectionError:
          message = baseUrl != null && baseUrl.isNotEmpty
              ? 'Sunucuya bağlanılamadı ($baseUrl).'
              : 'Sunucuya bağlanılamadı. İnternetini ve API adresini kontrol et.';
          break;
        case DioExceptionType.cancel:
          message = 'İstek iptal edildi.';
          break;
        case DioExceptionType.badCertificate:
          message = 'Güvenli bağlantı kurulamadı (sertifika hatası).';
          break;
        case DioExceptionType.badResponse:
          message = _friendlyByStatus(code);
          break;
        case DioExceptionType.unknown:
          message = 'Beklenmeyen bir ağ hatası oluştu. Lütfen tekrar dene.';
          break;
      }
    }

    return ApiException(message, statusCode: code);
  }

  static String _friendlyByStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Gönderilen bilgilerde bir hata var. Lütfen alanları kontrol et.';
      case 401:
        return 'Oturumun geçersiz veya süresi dolmuş. Lütfen tekrar giriş yap.';
      case 403:
        return 'Bu işlem için yetkin yok.';
      case 404:
        return 'İstenen kayıt bulunamadı.';
      case 409:
        return 'Bu işlem mevcut durumla çakışıyor.';
      case 422:
        return 'Bazı alanlar geçersiz görünüyor. Lütfen bilgileri düzelt.';
      case 429:
        return 'Çok sık deneme yapıldı. Lütfen biraz bekleyip tekrar dene.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Sunucuda geçici bir sorun var. Lütfen kısa süre sonra tekrar dene.';
      default:
        return 'Bir şeyler ters gitti. Lütfen tekrar dene.';
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
