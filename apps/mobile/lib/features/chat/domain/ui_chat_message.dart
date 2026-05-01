class UiChatMessage {
  UiChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.messageType = 'text',
    this.imageUrl,
    this.clientMessageId,
    this.deliveredAt,
    this.readAt,
    this.pending = false,
  });

  final String id;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String messageType;
  final String? imageUrl;
  final String? clientMessageId;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool pending;

  bool get isSystem => messageType == 'system';
  bool get isImage => messageType == 'image' && imageUrl != null;

  UiChatMessage copyWith({
    String? id,
    String? senderId,
    String? content,
    DateTime? createdAt,
    String? messageType,
    String? imageUrl,
    String? clientMessageId,
    DateTime? deliveredAt,
    DateTime? readAt,
    bool? pending,
  }) {
    return UiChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      messageType: messageType ?? this.messageType,
      imageUrl: imageUrl ?? this.imageUrl,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      pending: pending ?? this.pending,
    );
  }

  static UiChatMessage? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final senderId = json['senderId'] as String?;
    final content = json['content'] as String?;
    final createdAtRaw = json['createdAt'] as String?;
    if (id == null || senderId == null || createdAtRaw == null) {
      return null;
    }
    final mtRaw = json['messageType'] ?? json['message_type'];
    final messageType = mtRaw is String ? mtRaw : 'text';
    return UiChatMessage(
      id: id,
      senderId: senderId,
      content: content ?? '',
      createdAt: DateTime.parse(createdAtRaw),
      messageType: messageType,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      clientMessageId: json['clientMessageId'] as String?,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
    );
  }
}
