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
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_repository.dart';
import '../../../core/network/api_exception.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/report_user_sheet.dart';
import '../../wallet/data/gift_catalog_provider.dart';
import '../domain/gift_catalog.dart';
import '../domain/ui_chat_message.dart';

/// Birebir oturum sohbeti — WhatsApp benzeri açık tema.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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

  Map<String, dynamic>? _session;
  bool _loading = true;
  String? _error;
  bool _ending = false;
  bool _peerTyping = false;
  Timer? _typingClearTimer;
  Timer? _typingEmitTimer;
  Timer? _countdownTimer;
  io.Socket? _socket;
  bool _socketConnected = false;

  /// `dispose` sırasında `socket.dispose()` → `onDisconnect`; o anda `mounted` true
  /// kalabildiği için `setState` assert eder. Önce true yapılır.
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
      final repo = ref.read(chatRepositoryProvider);
      final session = await repo.getSession(widget.sessionId);
      final raw = await repo.getMessages(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _messages
          ..clear()
          ..addAll(_parseMessages(raw));
        _loading = false;
      });
      _startCountdown();
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

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  int _remainingSeconds() {
    final s = _session;
    if (s == null) return 0;
    final status = s['status'] as String?;
    if (status == 'ended' || status == 'cancelled') return 0;
    final startedRaw = s['startedAt'];
    final maxDur = s['maxDurationSeconds'];
    if (startedRaw is! String || maxDur is! int) return 0;
    final started = DateTime.parse(startedRaw);
    final end = started.add(Duration(seconds: maxDur));
    final left = end.difference(DateTime.now()).inSeconds;
    return left.clamp(0, maxDur);
  }

  bool _sessionEnded() {
    final s = _session;
    if (s == null) return false;
    final status = s['status'] as String?;
    return status == 'ended' || status == 'cancelled' || _remainingSeconds() <= 0;
  }

  String _peerTitle() {
    final s = _session;
    final me = _myId;
    if (s == null || me == null) return trEn(context, 'Sohbet', 'Chat');
    final requesterId = s['requesterId'] as String?;
    final listenerName =
        s['listenerDisplayName'] as String? ?? trEn(context, 'Dinleyen', 'Listener');
    final requesterName =
        s['requesterDisplayName'] as String? ?? trEn(context, 'Kullanıcı', 'User');
    if (me == requesterId) return listenerName;
    return requesterName;
  }

  String? _peerUserId() {
    final s = _session;
    final me = _myId;
    if (s == null || me == null) return null;
    final requesterId = s['requesterId'] as String?;
    final listenerId = s['listenerId'] as String?;
    if (me == requesterId) return listenerId;
    return requesterId;
  }

  Future<void> _reportPeer() async {
    final pid = _peerUserId();
    if (pid == null) return;
    await showReportUserSheet(
      context: context,
      sessionId: widget.sessionId,
      reportedUserId: pid,
      peerLabel: _peerTitle(),
    );
  }

  Future<void> _blockPeer() async {
    final pid = _peerUserId();
    if (pid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trEn(ctx, 'Kullanıcıyı engelle', 'Block user')),
        content: Text(
          trEn(
            ctx,
            '${_peerTitle()} ile yeni sohbet başlatamazsın. Devam edilsin mi?',
            'You will not be able to start a new chat with ${_peerTitle()}. Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(trEn(ctx, 'Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(trEn(ctx, 'Engelle', 'Block')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(safetyRepositoryProvider).blockUser(pid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trEn(context, 'Kullanıcı engellendi.', 'User blocked.'))),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _peerInitial() {
    final t = _peerTitle().trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
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
        socket.emit('session:join', {'sessionId': widget.sessionId});
        if (_mayApplySocketUi) setState(() => _socketConnected = true);
      })
      ..onDisconnect((_) {
        if (_mayApplySocketUi) setState(() => _socketConnected = false);
      })
      ..onConnectError((_) {
        if (_mayApplySocketUi) setState(() => _socketConnected = false);
      })
      ..on('session:message', (data) {
        if (data is! Map) return;
        final m = UiChatMessage.fromJson(Map<String, dynamic>.from(data));
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
      ..on('session:typing', (data) {
        if (data is! Map) return;
        final sid = data['sessionId'] as String?;
        final uid = data['userId'] as String?;
        final isTyping = data['isTyping'] as bool? ?? false;
        if (sid != widget.sessionId) return;
        if (uid == null || uid == _myId) return;
        if (uid != _peerUserId()) return;
        if (!_mayApplySocketUi) return;
        setState(() => _peerTyping = isTyping);
        _typingClearTimer?.cancel();
        if (isTyping) {
          _typingClearTimer = Timer(const Duration(seconds: 4), () {
            if (_mayApplySocketUi) setState(() => _peerTyping = false);
          });
        }
      })
      ..on('session:delivered', (data) {
        if (data is! Map) return;
        final m = UiChatMessage.fromJson(Map<String, dynamic>.from(data));
        if (m == null || !_mayApplySocketUi) return;
        _mergeMessage(m);
      })
      ..on('session:read', (data) {
        if (data is! Map) return;
        final m = UiChatMessage.fromJson(Map<String, dynamic>.from(data));
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
      if (i >= 0) {
        _messages[i] = m;
      }
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
    if (text.isEmpty || _sessionEnded()) return;
    _textController.clear();
    final clientId = _uuid.v4();
    final socket = _socket;

    try {
      if (socket != null && socket.connected) {
        socket.emit('session:message', {
          'sessionId': widget.sessionId,
          'content': text,
          'clientMessageId': clientId,
        });
      } else {
        final repo = ref.read(chatRepositoryProvider);
        final map = await repo.postTextMessage(
          widget.sessionId,
          content: text,
          clientMessageId: clientId,
        );
        final m = UiChatMessage.fromJson(map);
        if (m != null && mounted) {
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
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trEn(context, 'Gönderilemedi: $e', 'Could not send: $e'))),
      );
    }
  }

  void _onComposerChanged(String _) {
    final socket = _socket;
    if (socket == null || !socket.connected || _sessionEnded()) return;
    socket.emit('session:typing', {'sessionId': widget.sessionId, 'isTyping': true});
    _typingEmitTimer?.cancel();
    _typingEmitTimer = Timer(const Duration(milliseconds: 900), () {
      socket.emit('session:typing', {'sessionId': widget.sessionId, 'isTyping': false});
    });
  }

  Future<void> _sendGift(String code) async {
    if (_sessionEnded()) return;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final map = await repo.postGift(widget.sessionId, giftCode: code);
      final m = UiChatMessage.fromJson(map);
      if (m != null && mounted) {
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
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(context, 'Hediye gönderilemedi: $e', 'Gift could not be sent: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_sessionEnded()) return;
    try {
      final x = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.isEmpty) return;
      final repo = ref.read(chatRepositoryProvider);
      final imageUrl = await repo.uploadChatImage(
        bytes: bytes,
        filename: x.name,
        contentType: x.mimeType ?? 'image/jpeg',
      );
      final clientId = _uuid.v4();
      final socket = _socket;
      if (socket != null && socket.connected) {
        socket.emit('session:image', {
          'sessionId': widget.sessionId,
          'imageUrl': imageUrl,
          'clientMessageId': clientId,
        });
      } else {
        final map = await repo.postImageMessage(
          widget.sessionId,
          imageUrl: imageUrl,
          clientMessageId: clientId,
        );
        final m = UiChatMessage.fromJson(map);
        if (m != null && mounted) {
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
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Resim gonderilemedi: $e')));
    }
  }

  Future<void> _endSession() async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await ref.read(chatRepositoryProvider).endSession(widget.sessionId);
      if (!mounted) return;
      context.go(RoutePaths.chats);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bitirilemedi: $e')));
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _weekdayTr(DateTime d) {
    final names = isEnglishLocale(context)
        ? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        : ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
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

  void _toggleEmojiPicker() {
    if (_sessionEnded()) return;
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

  Future<void> _showAttachSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(giftCatalogProvider);
              return async.when(
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          title: Text(trEn(context, 'Hediyeler', 'Gifts')),
                          subtitle: Text(trEn(context, 'Katalog boş', 'Catalog is empty')),
                        ),
                        ...SessionGiftCatalog.options.map(
                          (g) => ListTile(
                            leading: Icon(g.icon),
                            title: Text(g.label),
                            subtitle: Text(trEn(context, 'Sunucu fiyatı yok', 'No server price')),
                            onTap: () {
                              Navigator.pop(ctx);
                              _sendGift(g.code);
                            },
                          ),
                        ),
                        ..._attachSheetRest(ctx),
                      ],
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: Text(trEn(context, 'Hediyeler', 'Gifts')),
                        subtitle: Text(
                          trEn(
                            context,
                            'Bakiyenden düşer; dinleyene net tutar geçer',
                            'Deducted from your balance; listener receives net amount',
                          ),
                        ),
                      ),
                      ...items.map(
                        (g) => ListTile(
                          leading: Icon(giftIconForCode(g.code)),
                          title: Text(g.label),
                          subtitle: Text(
                            '${g.priceMinor} ${isEnglishLocale(context) ? 'units' : 'birim'}',
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _sendGift(g.code);
                          },
                        ),
                      ),
                      ..._attachSheetRest(ctx),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        trEn(
                          context,
                          'Hediye listesi yüklenemedi: $e',
                          'Gift list could not load: $e',
                        ),
                      ),
                    ),
                    ..._attachSheetRest(ctx),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _attachSheetRest(BuildContext ctx) {
    return [
      ListTile(
        leading: const Icon(Icons.photo_library_outlined),
        title: Text(trEn(context, 'Galeriden resim', 'Image from gallery')),
        onTap: () {
          Navigator.pop(ctx);
          _pickAndSendImage(ImageSource.gallery);
        },
      ),
      ListTile(
        leading: const Icon(Icons.photo_camera_outlined),
        title: Text(trEn(context, 'Kamera ile çek', 'Take photo')),
        onTap: () {
          Navigator.pop(ctx);
          _pickAndSendImage(ImageSource.camera);
        },
      ),
    ];
  }

  @override
  void dispose() {
    _suppressSocketSetState = true;
    _countdownTimer?.cancel();
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
        appBar: AppBar(title: const Text('Sohbet')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _bootstrap, child: const Text('Tekrar dene')),
              ],
            ),
          ),
        ),
      );
    }

    final ended = _sessionEnded();
    final remain = _remainingSeconds();
    final subtitle = ended
        ? trEn(context, 'Sohbet sona erdi', 'Chat ended')
        : _peerTyping
            ? trEn(context, 'yazıyor…', 'typing…')
            : trEn(
                context,
                'Kalan süre: ${_formatDuration(remain)}',
                'Time left: ${_formatDuration(remain)}',
              );

    final slots = _chatSlots();

    return Scaffold(
      backgroundColor: _composerBg(theme),
      appBar: AppBar(
        backgroundColor: _headerBg(theme),
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        shadowColor: Colors.black26,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: scheme.surfaceContainerHighest,
              child: Text(
                _peerInitial(),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _peerTitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: _peerTyping ? AppColors.lightPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!ended)
            TextButton(
              onPressed: _ending ? null : _endSession,
              child: _ending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(trEn(context, 'Bitir', 'End')),
            ),
          if (!ended && _peerUserId() != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'report') {
                  unawaited(_reportPeer());
                } else if (v == 'block') {
                  unawaited(_blockPeer());
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'report',
                  child: Text(trEn(context, 'Şikayet et', 'Report')),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Text(trEn(context, 'Engelle', 'Block')),
                ),
              ],
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
                          'Canlı bağlantı yok; mesajlar gecikebilir (REST ile yenileme)',
                          'No live connection; messages may be delayed (REST refresh)',
                        ),
                        style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: _wallpaperBase(theme),
                  child: CustomPaint(painter: _ChatWallpaperPainter()),
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
                              _weekdayTr(slot),
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
                      return _MessageBubble(
                        message: slot,
                        bubbleIn: _bubbleIn(theme),
                        bubbleOut: _bubbleOut(theme),
                        mine: _myId != null && slot.senderId == _myId,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          _ComposerBar(
            background: _composerBg(theme),
            sessionEnded: ended,
            textController: _textController,
            composerScrollController: _composerScrollController,
            focusNode: _focusNode,
            emojiPickerVisible: _emojiPickerVisible,
            onChanged: _onComposerChanged,
            onSend: _sendText,
            onGift: _showAttachSheet,
            onToggleEmoji: _toggleEmojiPicker,
          ),
          Offstage(
            offstage: !(_emojiPickerVisible && !ended),
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
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: scheme.surface,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: scheme.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.bubbleOut,
    required this.bubbleIn,
    required this.mine,
  });

  final UiChatMessage message;
  final Color bubbleOut;
  final Color bubbleIn;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      final giftLabel = _giftLabelFromSystem(message.content);
      if (giftLabel != null) {
        final (icon, tint) = _giftVisual(giftLabel);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        tint.withValues(alpha: 0.24),
                        tint.withValues(alpha: 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: tint.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(icon, size: 42, color: tint),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0C2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Hediye: $giftLabel',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF54656F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
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

    final pending = message.pending;
    final read = message.readAt != null;
    final delivered = message.deliveredAt != null;

    return Padding(
      padding: EdgeInsets.only(
        left: mine ? 48 : 4,
        right: mine ? 4 : 48,
        top: 2,
        bottom: 4,
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: DecoratedBox(
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
                      ? 'Fotograf'
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
                      if (pending)
                        Icon(Icons.schedule_rounded, size: 14, color: Colors.black.withValues(alpha: 0.35))
                      else if (read)
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
      ),
    );
  }

  String? _giftLabelFromSystem(String content) {
    final markerTr = 'bir hediye gönderdi:';
    final markerEn = 'sent a gift:';
    var idx = content.indexOf(markerTr);
    var markerLength = markerTr.length;
    if (idx < 0) {
      idx = content.indexOf(markerEn);
      markerLength = markerEn.length;
    }
    if (idx < 0) return null;
    final label = content.substring(idx + markerLength).trim();
    return label.isEmpty ? null : label;
  }

  (IconData, Color) _giftVisual(String label) {
    switch (label.toLowerCase()) {
      case 'çiçek':
      case 'cicek':
      case 'flower':
        return (Icons.local_florist_rounded, const Color(0xFF43A047));
      case 'kahve':
      case 'coffee':
        return (Icons.local_cafe_rounded, const Color(0xFF8D6E63));
      case 'yıldız':
      case 'yildiz':
      case 'star':
        return (Icons.star_rounded, const Color(0xFFF9A825));
      case 'sıcak sarılma':
      case 'sicak sarilma':
      case 'warm hug':
        return (Icons.favorite_rounded, const Color(0xFFE53935));
      default:
        return (Icons.card_giftcard_rounded, const Color(0xFF7E57C2));
    }
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.background,
    required this.sessionEnded,
    required this.textController,
    required this.composerScrollController,
    required this.focusNode,
    required this.emojiPickerVisible,
    required this.onChanged,
    required this.onSend,
    required this.onGift,
    required this.onToggleEmoji,
  });

  final Color background;
  final bool sessionEnded;
  final TextEditingController textController;
  final ScrollController composerScrollController;
  final FocusNode focusNode;
  final bool emojiPickerVisible;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onGift;
  final VoidCallback onToggleEmoji;

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
                  padding: EdgeInsets.zero,
                  fixedSize: const Size(48, 48),
                ),
                onPressed: sessionEnded ? null : onGift,
                icon: const Text(
                  '🎁',
                  style: TextStyle(fontSize: 24, height: 1),
                  textAlign: TextAlign.center,
                ),
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
                          enabled: !sessionEnded,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          onChanged: onChanged,
                          style: TextStyle(fontSize: 16, color: scheme.onSurface),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: sessionEnded
                                ? trEn(context, 'Sohbet sona erdi', 'Chat ended')
                                : trEn(context, 'Mesaj', 'Message'),
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
                        onPressed: sessionEnded ? null : onToggleEmoji,
                        icon: Icon(
                          emojiPickerVisible
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: sessionEnded
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(trEn(context, 'Kamera yakında', 'Camera coming soon'))),
                        );
                      },
                icon: const Icon(Icons.photo_camera_outlined, color: Color(0xFF54656F)),
              ),
              sessionEnded
                  ? const SizedBox(width: 40)
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
