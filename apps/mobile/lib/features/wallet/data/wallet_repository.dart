import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.watch(dioProvider)),
);

class WalletSummaryDto {
  const WalletSummaryDto({
    required this.balanceMinor,
    required this.minPayoutMinor,
    required this.currency,
  });

  final int balanceMinor;
  final int minPayoutMinor;
  final String currency;

  factory WalletSummaryDto.fromJson(Map<String, dynamic> json) {
    final b = json['balance_minor'] ?? json['balanceMinor'];
    final m = json['min_payout_minor'] ?? json['minPayoutMinor'];
    final c = json['currency'] as String? ?? 'TRY';
    return WalletSummaryDto(
      balanceMinor: b is int ? b : int.tryParse('$b') ?? 0,
      minPayoutMinor: m is int ? m : int.tryParse('$m') ?? 0,
      currency: c,
    );
  }
}

class LedgerEntryDto {
  const LedgerEntryDto({
    required this.id,
    required this.amountMinor,
    required this.type,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
  });

  final String id;
  final int amountMinor;
  final String type;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;

  factory LedgerEntryDto.fromJson(Map<String, dynamic> json) {
    final am = json['amount_minor'] ?? json['amountMinor'];
    final ca = json['created_at'] ?? json['createdAt'];
    return LedgerEntryDto(
      id: json['id'] as String,
      amountMinor: am is int ? am : int.tryParse('$am') ?? 0,
      type: json['type'] as String? ?? '',
      referenceType: json['reference_type'] as String? ?? json['referenceType'] as String?,
      referenceId: json['reference_id'] as String? ?? json['referenceId'] as String?,
      createdAt: DateTime.tryParse(ca?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class LedgerPageDto {
  const LedgerPageDto({
    required this.items,
    this.nextCursor,
  });

  final List<LedgerEntryDto> items;
  final String? nextCursor;
}

class LeaderboardRowDto {
  const LeaderboardRowDto({
    required this.rank,
    required this.displayName,
    required this.totalMinor,
  });

  final int rank;
  final String displayName;
  final int totalMinor;

  factory LeaderboardRowDto.fromJson(Map<String, dynamic> json) {
    final r = json['rank'];
    final t = json['total_minor'] ?? json['totalMinor'];
    final name = json['display_name'] ?? json['displayName'];
    return LeaderboardRowDto(
      rank: r is int ? r : int.tryParse('$r') ?? 0,
      displayName: name is String && name.isNotEmpty ? name : 'Kullanıcı',
      totalMinor: t is int ? t : int.tryParse('$t') ?? 0,
    );
  }
}

class LeaderboardDto {
  const LeaderboardDto({
    required this.period,
    required this.topEarners,
    required this.topGiftSenders,
  });

  final String period;
  final List<LeaderboardRowDto> topEarners;
  final List<LeaderboardRowDto> topGiftSenders;

  factory LeaderboardDto.fromJson(Map<String, dynamic> json) {
    List<LeaderboardRowDto> parseList(Object? raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => LeaderboardRowDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final p = json['period'] as String? ?? 'today';
    return LeaderboardDto(
      period: p,
      topEarners: parseList(json['top_earners'] ?? json['topEarners']),
      topGiftSenders: parseList(json['top_gift_senders'] ?? json['topGiftSenders']),
    );
  }
}

/// Birebir sohbette alınan hediyeler (profil + detay listesi).
class ReceivedSessionGiftItemDto {
  const ReceivedSessionGiftItemDto({
    required this.id,
    required this.createdAt,
    required this.giftCode,
    required this.giftLabel,
    required this.priceMinor,
    required this.recipientEarnedMinor,
    required this.platformFeeMinor,
    required this.sessionId,
    required this.senderDisplayName,
  });

  final String id;
  final DateTime createdAt;
  final String giftCode;
  final String giftLabel;
  final int? priceMinor;
  final int? recipientEarnedMinor;
  final int? platformFeeMinor;
  final String sessionId;
  final String senderDisplayName;

  factory ReceivedSessionGiftItemDto.fromJson(Map<String, dynamic> json) {
    final ca = json['created_at'] ?? json['createdAt'];
    final pr = json['price_minor'] ?? json['priceMinor'];
    final re = json['recipient_earned_minor'] ?? json['recipientEarnedMinor'];
    final pf = json['platform_fee_minor'] ?? json['platformFeeMinor'];
    final sn = json['sender'];
    String senderName = 'Kullanıcı';
    if (sn is Map) {
      final m = Map<String, dynamic>.from(sn);
      senderName =
          m['display_name'] as String? ?? m['displayName'] as String? ?? 'Kullanıcı';
    }
    return ReceivedSessionGiftItemDto(
      id: json['id'] as String,
      createdAt: DateTime.tryParse(ca?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      giftCode: json['gift_code'] as String? ?? json['giftCode'] as String? ?? '',
      giftLabel: json['gift_label'] as String? ?? json['giftLabel'] as String? ?? '',
      priceMinor: pr is int ? pr : int.tryParse('$pr'),
      recipientEarnedMinor: re is int ? re : int.tryParse('$re'),
      platformFeeMinor: pf is int ? pf : int.tryParse('$pf'),
      sessionId: json['session_id'] as String? ?? json['sessionId'] as String? ?? '',
      senderDisplayName: senderName,
    );
  }
}

class ReceivedSessionGiftsResponseDto {
  const ReceivedSessionGiftsResponseDto({
    required this.totalRecipientEarnedMinor,
    required this.giftCount,
    required this.items,
  });

  final int totalRecipientEarnedMinor;
  final int giftCount;
  final List<ReceivedSessionGiftItemDto> items;

  factory ReceivedSessionGiftsResponseDto.fromJson(Map<String, dynamic> json) {
    final t = json['total_recipient_earned_minor'] ?? json['totalRecipientEarnedMinor'];
    final c = json['gift_count'] ?? json['giftCount'];
    final raw = json['items'];
    final items = <ReceivedSessionGiftItemDto>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          items.add(
            ReceivedSessionGiftItemDto.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return ReceivedSessionGiftsResponseDto(
      totalRecipientEarnedMinor: t is int ? t : int.tryParse('$t') ?? 0,
      giftCount: c is int ? c : int.tryParse('$c') ?? 0,
      items: items,
    );
  }
}

class GiftCatalogItemDto {
  const GiftCatalogItemDto({
    required this.code,
    required this.label,
    required this.priceMinor,
  });

  final String code;
  final String label;
  final int priceMinor;

  factory GiftCatalogItemDto.fromJson(Map<String, dynamic> json) {
    final p = json['price_minor'] ?? json['priceMinor'];
    return GiftCatalogItemDto(
      code: json['code'] as String,
      label: json['label'] as String,
      priceMinor: p is int ? p : int.tryParse('$p') ?? 0,
    );
  }
}

class WalletRepository {
  WalletRepository(this._dio);

  final Dio _dio;

  Future<List<GiftCatalogItemDto>> fetchGiftCatalog() async {
    try {
      final res = await _dio.get<List<dynamic>>('/wallet/gift-catalog');
      final list = res.data ?? [];
      return list
          .whereType<Map>()
          .map((e) => GiftCatalogItemDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<LedgerPageDto> fetchLedger({
    int take = 30,
    String? cursor,
  }) async {
    try {
      final qp = <String, dynamic>{'take': take};
      if (cursor != null && cursor.isNotEmpty) {
        qp['cursor'] = cursor;
      }
      final res = await _dio.get<Map<String, dynamic>>(
        '/wallet/ledger',
        queryParameters: qp,
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Hareket listesi boş döndü.');
      }
      final raw = data['items'];
      final items = <LedgerEntryDto>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            items.add(LedgerEntryDto.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
      final next = data['next_cursor'] ?? data['nextCursor'];
      return LedgerPageDto(
        items: items,
        nextCursor: next is String && next.isNotEmpty ? next : null,
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Sabit paketler: 100, 500, 1000, 5000 (API ile aynı).
  Future<int> topup({required int amountMinor}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/wallet/topup',
        data: <String, dynamic>{'amountMinor': amountMinor},
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Cüzdan yanıtı boş.');
      }
      final b = data['balance_minor'] ?? data['balanceMinor'];
      return b is int ? b : int.tryParse('$b') ?? 0;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<LeaderboardDto> fetchLeaderboard({required String period}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/wallet/leaderboard',
        queryParameters: <String, dynamic>{'period': period},
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Liderlik verisi boş döndü.');
      }
      return LeaderboardDto.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<WalletSummaryDto> fetchWalletMe() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/wallet/me');
      final data = res.data;
      if (data == null) {
        throw ApiException('Cüzdan yanıtı boş.');
      }
      return WalletSummaryDto.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Aldığın birebir hediyeler: toplam, adet ve son kayıtlar (limit max 100).
  Future<ReceivedSessionGiftsResponseDto> fetchReceivedSessionGifts({
    int limit = 50,
  }) async {
    try {
      final lim = limit.clamp(1, 100);
      final res = await _dio.get<Map<String, dynamic>>(
        '/wallet/received-session-gifts',
        queryParameters: <String, dynamic>{'limit': lim},
      );
      final data = res.data;
      if (data == null) {
        throw ApiException('Hediye listesi boş döndü.');
      }
      return ReceivedSessionGiftsResponseDto.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<Map<String, dynamic>> createPayoutRequest({
    required int amountMinor,
    required String iban,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/wallet/payout-requests',
        data: <String, dynamic>{
          'amountMinor': amountMinor,
          'iban': iban,
        },
      );
      return res.data ?? {};
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    return ApiException.fromDio(e, baseUrl: _dio.options.baseUrl);
  }
}
