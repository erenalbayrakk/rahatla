import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../../core/locale/locale_text.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/socket_url.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/domain/ui_chat_message.dart';
import '../data/group_chat_repository.dart';

/// Grup odası sohbeti — REST geçmiş + `group:*` socket.
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  Color _headerBg(ThemeData t) =>
      t.brightness == Brightness.dark ? t.colorScheme.surface : const Color(0xFFF0F2F5);
  Color _wallpaperBase(ThemeData t) => t.brightness == Brightness.dark
      ? t.colorScheme.surfaceContainerLowest
      : const Color(0xFFECE5DD);
  Color _composerBg(ThemeData t) =>
      t.brightness == Brightness.dark ? t.colorScheme.surface : const Color(0xFFF0F2F5);
  Color _bubbleOut(ThemeData t) => t.brightness == Brightness.dark
      ? t.colorScheme.primaryContainer.withValues(alpha: 0.55)
      : const Color(0xFFD9FDD3);
  Color _bubbleIn(ThemeData t) =>
      t.brightness == Brightness.dark ? t.colorScheme.surfaceContainerHigh : const Color(0xFFFFFFFF);

  final _scrollController = ScrollController();
  final _composerScrollController = ScrollController();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _uuid = const Uuid();
  final _imagePicker = ImagePicker();

  bool _emojiPickerVisible = false;

  final List<UiChatMessage> _messages = [];
  final Map<String, String> _nameByUserId = {};
  final Set<String> _typingUserIds = {};

  Map<String, dynamic>? _room;
  bool _loading = true;
  String? _error;

  io.Socket? _socket;
  bool _socketConnected = false;
  Timer? _typingClearTimer;
  Timer? _typingEmitTimer;

  /// `dispose` içinde `socket.dispose()` tetiklediği `onDisconnect` hâlâ çalışır;
  /// bu sırada `mounted` true kalabildiği için `setState` patlar. Önce bunu true yap.
  bool _suppressSocketSetState = false;

  String? get _myId => ref.read(authControllerProvider).user?.id;

  bool get _mayApplySocketUi => mounted && !_suppressSocketSetState;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(groupChatRepositoryProvider);
      final room = await repo.getRoom(widget.roomId);
      final raw = await repo.listMessages(widget.roomId);
      if (!mounted) return;
      _applyRoom(room);
      setState(() {
        _room = room;
        _messages
          ..clear()
          ..addAll(_parseMessages(raw));
        _loading = false;
      });
      await _connectSocket();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _applyRoom(Map<String, dynamic> room) {
    _nameByUserId.clear();
    final parts = room['participants'];
    if (parts is List) {
      for (final p in parts) {
        if (p is Map) {
          final uid = p['userId'] as String?;
          final dn = p['displayName'] as String?;
          if (uid != null) {
            _nameByUserId[uid] = (dn != null && dn.isNotEmpty) ? dn : uid;
          }
        }
      }
    }
  }

  List<UiChatMessage> _parseMessages(List<dynamic> raw) {
    final out = <UiChatMessage>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final m = UiChatMessage.fromJson(item);
        if (m != null) out.add(m);
      }
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  bool _roomClosed() => (_room?['status'] as String?) == 'closed';

  String _roomTitle(BuildContext context) =>
      _room?['title'] as String? ?? trEn(context, 'Grup', 'Group');

  String _appBarSubtitle(BuildContext context) {
    if (_typingUserIds.isNotEmpty) {
      final names = _typingUserIds.map((id) => _nameByUserId[id] ?? '…').take(3).join(', ');
      if (isEnglishLocale(context)) {
        final c = _typingUserIds.length;
        final verb = c == 1 ? 'is typing' : 'are typing';
        return '$names $verb…';
      }
      return '$names yazıyor…';
    }
    final n = (_room?['participants'] as List?)?.length ?? 0;
    return trEn(context, '$n üye', n == 1 ? '1 member' : '$n members');
  }

  Future<void> _connectSocket() async {
    _disconnectSocket();
    final token = await ref.read(secureTokenStorageProvider).readAccessToken();
    if (token == null || token.isEmpty) return;

    final socket = io.io(
      realtimeSocketUrl(Env.apiBaseUrl),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    socket
      ..onConnect((_) {
        socket.emit('group:join', {'roomId': widget.roomId});
        if (_mayApplySocketUi) setState(() => _socketConnected = true);
      })
      ..onDisconnect((_) {
        if (_mayApplySocketUi) setState(() => _socketConnected = false);
      })
      ..onConnectError((_) {
        if (_mayApplySocketUi) setState(() => _socketConnected = false);
      })
      ..on('group:message', (data) {
        if (data is! Map) return;
        final map = Map<String, dynamic>.from(data);
        if ((map['roomId'] as String?) != widget.roomId) return;
        final m = UiChatMessage.fromJson(map);
        if (m == null || !_mayApplySocketUi) return;
        setState(() {
          final i = _messages.indexWhere((x) => x.id == m.id);
          if (i >= 0) {
            _messages[i] = m;
          } else {
            _messages.add(m);
          }
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom();
      })
      ..on('group:typing', (data) {
        if (data is! Map) return;
        if ((data['roomId'] as String?) != widget.roomId) return;
        final uid = data['userId'] as String?;
        final isTyping = data['isTyping'] as bool? ?? false;
        if (uid == null || uid == _myId) return;
        if (!_mayApplySocketUi) return;
        setState(() {
          if (isTyping) {
            _typingUserIds.add(uid);
          } else {
            _typingUserIds.remove(uid);
          }
        });
        _typingClearTimer?.cancel();
        if (_typingUserIds.isNotEmpty) {
          _typingClearTimer = Timer(const Duration(seconds: 5), () {
            if (_mayApplySocketUi) setState(() => _typingUserIds.clear());
          });
        }
      })
      ..on('group:delivered', (data) {
        if (data is! Map) return;
        final map = Map<String, dynamic>.from(data);
        if ((map['roomId'] as String?) != widget.roomId) return;
        final m = UiChatMessage.fromJson(map);
        if (m == null || !_mayApplySocketUi) return;
        _mergeMessage(m);
      })
      ..on('group:read', (data) {
        if (data is! Map) return;
        final map = Map<String, dynamic>.from(data);
        if ((map['roomId'] as String?) != widget.roomId) return;
        final m = UiChatMessage.fromJson(map);
        if (m == null || !_mayApplySocketUi) return;
        _mergeMessage(m);
      });

    socket.connect();
    _socket = socket;
  }

  void _mergeMessage(UiChatMessage m) {
    if (!_mayApplySocketUi) return;
    setState(() {
      final i = _messages.indexWhere((x) => x.id == m.id);
      if (i >= 0) _messages[i] = m;
    });
  }

  void _disconnectSocket() {
    _socket?.dispose();
    _socket = null;
    if (_mayApplySocketUi) setState(() => _socketConnected = false);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _roomClosed()) return;
    final socket = _socket;
    if (socket == null || !socket.connected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(
              context,
              'Mesaj göndermek için canlı bağlantı gerekli',
              'You need a live connection to send messages',
            ),
          ),
        ),
      );
      return;
    }
    _textController.clear();
    final clientId = _uuid.v4();
    socket.emit('group:message', {
      'roomId': widget.roomId,
      'content': text,
      'clientMessageId': clientId,
    });
  }

  Future<void> _sendImage(ImageSource source) async {
    if (_roomClosed()) return;
    final socket = _socket;
    if (socket == null || !socket.connected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(
              context,
              'Resim göndermek için canlı bağlantı gerekli',
              'You need a live connection to send images',
            ),
          ),
        ),
      );
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      final imageUrl = await ref.read(groupChatRepositoryProvider).uploadChatImage(
            bytes: bytes,
            filename: picked.name,
            contentType: picked.mimeType ?? 'image/jpeg',
          );
      socket.emit('group:image', {
        'roomId': widget.roomId,
        'imageUrl': imageUrl,
        'clientMessageId': _uuid.v4(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            trEn(context, 'Resim gönderilemedi: $e', 'Could not send image: $e'),
          ),
        ),
      );
    }
  }

  void _onComposerChanged(String _) {
    final socket = _socket;
    if (socket == null || !socket.connected || _roomClosed()) return;
    socket.emit('group:typing', {'roomId': widget.roomId, 'isTyping': true});
    _typingEmitTimer?.cancel();
    _typingEmitTimer = Timer(const Duration(milliseconds: 900), () {
      socket.emit('group:typing', {'roomId': widget.roomId, 'isTyping': false});
    });
  }

  void _toggleEmojiPicker() {
    if (_roomClosed()) return;
    setState(() {
      _emojiPickerVisible = !_emojiPickerVisible;
      if (_emojiPickerVisible) {
        _focusNode.unfocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      }
    });
  }

  void _showMembers() {
    final parts = _room?['participants'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: parts is! List || parts.isEmpty
              ? ListTile(
                  title: Text(trEn(ctx, 'Üye listesi yok', 'No members to show')),
                )
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        trEn(ctx, 'Üyeler', 'Members'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ...parts.map((p) {
                      if (p is! Map) return const SizedBox.shrink();
                      final name = p['displayName'] as String? ?? '?';
                      final role = p['role'] as String? ?? '';
                      return ListTile(
                        title: Text(name),
                        subtitle: role.isEmpty ? null : Text(role),
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }

  String _weekdayLocalized(BuildContext context, DateTime d) {
    if (isEnglishLocale(context)) {
      const names = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return names[d.weekday - 1];
    }
    const names = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    return names[d.weekday - 1];
  }

  List<Object> _chatSlots() {
    final slots = <Object>[];
    DateTime? lastDay;
    for (final m in _messages) {
      if (m.isSystem) {
        slots.add(m);
        continue;
      }
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || day != lastDay) {
        lastDay = day;
        slots.add(day);
      }
      slots.add(m);
    }
    return slots;
  }

  bool _showSenderLabel(int index, List<Object> slots, UiChatMessage m) {
    if (_myId != null && m.senderId == _myId) return false;
    for (var j = index - 1; j >= 0; j--) {
      final prev = slots[j];
      if (prev is UiChatMessage && !prev.isSystem) {
        return prev.senderId != m.senderId;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _suppressSocketSetState = true;
    _typingClearTimer?.cancel();
    _typingEmitTimer?.cancel();
    _disconnectSocket();
    _scrollController.dispose();
    _composerScrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(trEn(context, 'Grup', 'Group')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _bootstrap,
                  child: Text(trEn(context, 'Tekrar dene', 'Try again')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final closed = _roomClosed();
    final slots = _chatSlots();

    return Scaffold(
      backgroundColor: _composerBg(theme),
      appBar: AppBar(
        backgroundColor: _headerBg(theme),
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _roomTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: scheme.onSurface,
              ),
            ),
            Text(
              _appBarSubtitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: _typingUserIds.isNotEmpty ? AppColors.lightPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: trEn(context, 'Üyeler', 'Members'),
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showMembers,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_socketConnected)
            Material(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, size: 18, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trEn(
                          context,
                          'Canlı bağlantı yok; mesaj gönderemezsin.',
                          'No live connection; you cannot send messages.',
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (closed)
            Material(
              color: Colors.grey.shade200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  trEn(
                    context,
                    'Bu oda kapatıldı; yeni mesaj gönderilemez.',
                    'This room is closed; new messages cannot be sent.',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: _wallpaperBase(theme),
                  child: CustomPaint(painter: _GroupWallpaperPainter()),
                ),
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    if (slot is DateTime) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE1F4FB).withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              _weekdayLocalized(context, slot),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF54656F),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    if (slot is UiChatMessage) {
                      final mine = _myId != null && slot.senderId == _myId;
                      final showName = _showSenderLabel(index, slots, slot);
                      final senderLabel = _nameByUserId[slot.senderId];
                      return _GroupMessageBubble(
                        message: slot,
                        mine: mine,
                        bubbleOut: _bubbleOut(theme),
                        bubbleIn: _bubbleIn(theme),
                        showSenderName: showName,
                        senderLabel: senderLabel,
                        imagePlaceholder: trEn(context, 'Fotoğraf', 'Photo'),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          _GroupComposerBar(
            background: _composerBg(theme),
            disabled: closed,
            textController: _textController,
            composerScrollController: _composerScrollController,
            focusNode: _focusNode,
            emojiPickerVisible: _emojiPickerVisible,
            onChanged: _onComposerChanged,
            onSend: _sendText,
            onMembers: _showMembers,
            onImageGallery: () => _sendImage(ImageSource.gallery),
            onImageCamera: () => _sendImage(ImageSource.camera),
            onToggleEmoji: _toggleEmojiPicker,
            hintMessage: trEn(context, 'Mesaj', 'Message'),
            hintRoomClosed: trEn(context, 'Oda kapalı', 'Room closed'),
            labelGallery: trEn(context, 'Galeriden resim', 'Photo from gallery'),
            labelCamera: trEn(context, 'Kamera ile çek', 'Take with camera'),
          ),
          Offstage(
            offstage: !(_emojiPickerVisible && !closed),
            child: EmojiPicker(
              textEditingController: _textController,
              scrollController: _composerScrollController,
              config: Config(
                height: 280,
                checkPlatformCompatibility: true,
                locale: Localizations.localeOf(context),
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: scheme.surface,
                  emojiSizeMax: 28 *
                      (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: scheme.surface,
                  indicatorColor: AppColors.lightPrimary,
                  iconColor: scheme.onSurfaceVariant,
                  iconColorSelected: scheme.onSurface,
                ),
                bottomActionBarConfig: BottomActionBarConfig(backgroundColor: scheme.surface),
                searchViewConfig: SearchViewConfig(backgroundColor: scheme.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF000000).withValues(alpha: 0.04);
    const step = 48.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (var x = 0.0; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x + (y / step % 2) * 24, y), 2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({
    required this.message,
    required this.mine,
    required this.bubbleOut,
    required this.bubbleIn,
    required this.showSenderName,
    required this.senderLabel,
    required this.imagePlaceholder,
  });

  final UiChatMessage message;
  final bool mine;
  final Color bubbleOut;
  final Color bubbleIn;
  final bool showSenderName;
  final String? senderLabel;
  final String imagePlaceholder;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0C2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF54656F)),
            ),
          ),
        ),
      );
    }

    final bg = mine ? bubbleOut : bubbleIn;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomLeft: Radius.circular(mine ? 8 : 2),
      bottomRight: Radius.circular(mine ? 2 : 8),
    );

    final read = message.readAt != null;
    final delivered = message.deliveredAt != null;

    return Padding(
      padding: EdgeInsets.only(
        left: mine ? 48 : 4,
        right: mine ? 4 : 48,
        top: showSenderName && !mine ? 6 : 2,
        bottom: 4,
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSenderName && !mine && senderLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  senderLabel!,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF54656F)),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      message.content.isEmpty && message.isImage
                          ? imagePlaceholder
                          : message.content,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.35,
                        color: Color(0xFF111B21),
                      ),
                    ),
                    if (message.isImage && message.imageUrl != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          message.imageUrl!,
                          width: 220,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _fmtTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 4),
                          if (read)
                            const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF53BDEB))
                          else if (delivered)
                            const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF8696A0))
                          else
                            Icon(Icons.done_rounded, size: 15, color: Colors.black.withValues(alpha: 0.35)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _GroupComposerBar extends StatelessWidget {
  const _GroupComposerBar({
    required this.background,
    required this.disabled,
    required this.textController,
    required this.composerScrollController,
    required this.focusNode,
    required this.emojiPickerVisible,
    required this.onChanged,
    required this.onSend,
    required this.onMembers,
    required this.onImageGallery,
    required this.onImageCamera,
    required this.onToggleEmoji,
    required this.hintMessage,
    required this.hintRoomClosed,
    required this.labelGallery,
    required this.labelCamera,
  });

  final Color background;
  final bool disabled;
  final TextEditingController textController;
  final ScrollController composerScrollController;
  final FocusNode focusNode;
  final bool emojiPickerVisible;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onMembers;
  final VoidCallback onImageGallery;
  final VoidCallback onImageCamera;
  final VoidCallback onToggleEmoji;
  final String hintMessage;
  final String hintRoomClosed;
  final String labelGallery;
  final String labelCamera;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                onPressed: disabled ? null : onMembers,
                icon: const Icon(Icons.groups_outlined),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                onPressed: disabled
                    ? null
                    : () async {
                        final source = await showModalBottomSheet<ImageSource>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.photo_library_outlined),
                                  title: Text(labelGallery),
                                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_camera_outlined),
                                  title: Text(labelCamera),
                                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (source == ImageSource.gallery) {
                          onImageGallery();
                        } else if (source == ImageSource.camera) {
                          onImageCamera();
                        }
                      },
                icon: const Icon(Icons.image_outlined),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          scrollController: composerScrollController,
                          focusNode: focusNode,
                          enabled: !disabled,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          onChanged: onChanged,
                          style: TextStyle(fontSize: 16, color: scheme.onSurface),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: disabled ? hintRoomClosed : hintMessage,
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: disabled ? null : onToggleEmoji,
                        icon: Icon(
                          emojiPickerVisible ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              disabled
                  ? const SizedBox(width: 48)
                  : IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.lightPrimary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onSend,
                      icon: const Icon(Icons.send_rounded, size: 20),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
