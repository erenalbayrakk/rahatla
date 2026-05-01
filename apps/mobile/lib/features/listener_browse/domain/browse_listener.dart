class BrowsePage {
  const BrowsePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    this.moodFilter,
  });

  final List<BrowseListener> items;
  final int page;
  final int pageSize;
  final int total;
  /// Sunucunun uyguladığı ruh hali filtresi (`SupportCategory` anahtarı).
  final String? moodFilter;

  bool get hasMore => items.length < total;

  factory BrowsePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    return BrowsePage(
      items: raw
          .map(
            (e) =>
                BrowseListener.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 30,
      total: (json['total'] as num?)?.toInt() ?? raw.length,
      moodFilter: json['moodFilter'] as String?,
    );
  }

  BrowsePage copyWith({
    List<BrowseListener>? items,
    int? page,
    int? pageSize,
    int? total,
    String? moodFilter,
  }) {
    return BrowsePage(
      items: items ?? this.items,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      moodFilter: moodFilter ?? this.moodFilter,
    );
  }
}

class BrowseListener {
  const BrowseListener({
    required this.userId,
    required this.displayName,
    required this.recognitionLabels,
    required this.ratingAvg,
    required this.ratingCount,
    required this.supportCategories,
    required this.isOnline,
    required this.isAvailable,
    this.accountKind = 'approved_listener',
    this.availabilityMode,
    this.pinned = false,
    this.age,
    this.gender,
    this.replyPace,
  });

  final String userId;
  final String displayName;
  /// Yönetici panelinden verilen kısa takdir ifadeleri (puan değil).
  final List<String> recognitionLabels;
  final double ratingAvg;
  final int ratingCount;
  final List<String> supportCategories;
  final bool isOnline;
  final bool isAvailable;
  /// API role: `approved_listener` | `listener_applicant` | `admin` (pin).
  final String accountKind;
  /// API `ListenerAvailabilityMode` (`available` | `automatic` | `busy`).
  final String? availabilityMode;
  /// Sunucuda sabitlenmiş dinleyen (liste başında, filtre dışı).
  final bool pinned;

  final int? age;
  final String? gender;

  /// API: `spark` | `swift` | `warm` | `easy` — son yanıtlara göre tema.
  final String? replyPace;

  factory BrowseListener.fromJson(Map<String, dynamic> json) {
    return BrowseListener(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      recognitionLabels:
          (json['recognitionLabels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      ratingAvg: (json['ratingAvg'] as num).toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      supportCategories:
          (json['supportCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isOnline: json['isOnline'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? false,
      accountKind: json['accountKind'] as String? ?? 'approved_listener',
      availabilityMode: json['availabilityMode'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      replyPace: json['replyPace'] as String?,
    );
  }
}

class SessionFromSelection {
  const SessionFromSelection({required this.id});

  final String id;

  factory SessionFromSelection.fromJson(Map<String, dynamic> json) {
    return SessionFromSelection(id: json['id'] as String);
  }
}
