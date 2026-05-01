import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/router/route_paths.dart';
import '../data/notifications_repository.dart';

String _formatRelativeTime(BuildContext context, DateTime utc) {
  final en = isEnglishLocale(context);
  final local = utc.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.isNegative) return en ? 'Just now' : 'Az önce';
  if (diff.inMinutes < 1) return en ? 'Just now' : 'Az önce';
  if (diff.inMinutes < 60) {
    return en
        ? '${diff.inMinutes}m ago'
        : '${diff.inMinutes} dk önce';
  }
  if (diff.inHours < 24) {
    return en
        ? '${diff.inHours}h ago'
        : '${diff.inHours} sa önce';
  }
  if (diff.inDays < 7) {
    return en
        ? '${diff.inDays}d ago'
        : '${diff.inDays} gün önce';
  }
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(notificationsRepositoryProvider).fetchList();
      final raw = data['items'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      final uc = data['unreadCount'];
      if (!mounted) return;
      setState(() {
        _items = list;
        _unreadCount = uc is num ? uc.toInt() : 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onTapItem(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;
    try {
      await ref.read(notificationsRepositoryProvider).markRead(id);
    } catch (_) {}
    if (!mounted) return;
    final data = row['dataJson'];
    String? sessionId;
    if (data is Map) {
      final sid = data['sessionId'];
      if (sid is String) sessionId = sid;
    }
    if (sessionId != null && mounted) {
      context.push(RoutePaths.chat(sessionId));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(trEn(context, 'Bildirimler', 'Notifications')),
        actions: [
          if (_unreadCount > 0 && !_loading)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                trEn(context, 'Tümünü okundu', 'Mark all read'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _load,
                              child: Text(
                                trEn(
                                  context,
                                  'Yeniden dene',
                                  'Try again',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 56,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  trEn(
                                    context,
                                    'Henüz bildirim yok',
                                    'No notifications yet',
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  trEn(
                                    context,
                                    'Hediye ve diğer güncellemeler burada görünecek.',
                                    'Gifts and other updates will appear here.',
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 8, bottom: 32),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.transparent,
                        ),
                        itemBuilder: (context, index) {
                          final row = _items[index];
                          final title = row['title'] as String? ??
                              trEn(context, 'Bildirim', 'Notification');
                          final body = row['body'] as String? ?? '';
                          final readAt = row['readAt'];
                          final isUnread = readAt == null;
                          final createdStr = row['createdAt'] as String?;
                          final created = createdStr != null
                              ? DateTime.tryParse(createdStr)
                              : null;
                          final timeStr = created != null
                              ? _formatRelativeTime(context, created)
                              : '';

                          return Material(
                            color: scheme.surface,
                            child: InkWell(
                              onTap: () => _onTapItem(row),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(top: 6, right: 12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isUnread
                                            ? theme.colorScheme.primary
                                            : Colors.transparent,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              color: scheme.onSurface,
                                              fontWeight: isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          if (body.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              body,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                          if (timeStr.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              timeStr,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: scheme.onSurfaceVariant.withValues(
                                                  alpha: 0.85,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
