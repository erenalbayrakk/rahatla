class GroupDiscoverPage {
  const GroupDiscoverPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int pageSize;
  final int total;

  factory GroupDiscoverPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? json['rooms'] as List<dynamic>?;
    final list = raw != null
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    return GroupDiscoverPage(
      items: list,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? list.length,
    );
  }
}
