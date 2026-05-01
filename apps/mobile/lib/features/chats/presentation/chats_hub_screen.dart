import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/router/route_paths.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/chat_unread_notifier.dart';
import '../../group_chat/data/group_chat_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/soft_header.dart';

const _kDotMuted = Color(0xFF9EA5B3);

class _InboxRow {
  const _InboxRow({
    required this.sortKey,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final DateTime sortKey;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
}

/// Birebir ve grup sohbetlere giriş (alt sekme “Sohbet”) — iletişim listesi.
class ChatsHubScreen extends ConsumerStatefulWidget {
  const ChatsHubScreen({super.key});

  @override
  ConsumerState<ChatsHubScreen> createState() => _ChatsHubScreenState();
}

class _ChatsHubScreenState extends ConsumerState<ChatsHubScreen> {
  bool _loading = true;
  String? _error;
  List<_InboxRow> _rows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatUnreadNotifierProvider.notifier).refresh();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chat = ref.read(chatRepositoryProvider);
      final groups = ref.read(groupChatRepositoryProvider);
      final sessionRes = await chat.listMineForChats();
      final groupList = await groups.listMyRooms();

      final items = <_InboxRow>[];

      final rawItems = sessionRes['items'];
      if (rawItems is List) {
        for (final e in rawItems) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final sid = m['sessionId'] as String?;
          final name = m['peerDisplayName'] as String?;
          final atStr = m['lastMessageAt'] as String?;
          final preview = m['lastMessagePreview'] as String?;
          if (sid == null || name == null) continue;
          final at = DateTime.tryParse(atStr ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          items.add(
            _InboxRow(
              sortKey: at,
              title: name,
              subtitle: preview,
              onTap: () => context.push(RoutePaths.chat(sid)),
            ),
          );
        }
      }

      for (final e in groupList) {
        final id = e['id'] as String?;
        final title = e['title'] as String?;
        if (id == null || title == null) continue;
        final atStr = e['lastMessageAt'] as String?;
        final preview = e['lastMessagePreview'] as String?;
        final at = DateTime.tryParse(atStr ?? '') ??
            DateTime.tryParse(e['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        items.add(
          _InboxRow(
            sortKey: at,
            title: title,
            subtitle: preview,
            onTap: () => context.push(RoutePaths.groupChat(id)),
          ),
        );
      }

      items.sort((a, b) => b.sortKey.compareTo(a.sortKey));

      if (!mounted) return;
      setState(() {
        _rows = items;
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

  String _initialForTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppScaffold(
      padding: EdgeInsets.zero,
      body: ColoredBox(
        color: scheme.surface,
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: SoftHeader(
                    title: trEn(context, 'Sohbetler', 'Chats'),
                    subtitle: trEn(
                      context,
                      'Birebir ve grup görüşmeleri',
                      'One-to-one and group conversations',
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                            trEn(context, 'Yeniden dene', 'Try again'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          trEn(context, 'Henüz görüşme yok', 'No conversations yet'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          trEn(
                            context,
                            'Ana sayfadan bir dinleyenle birebir başlayabilir veya grup odalarına katılabilirsin.',
                            'Start a one-to-one chat from Home or join group rooms.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: () => context.push(RoutePaths.groupRooms),
                          icon: const Icon(Icons.groups_outlined),
                          label: Text(
                            trEn(context, 'Grup odaları', 'Group rooms'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 28),
                  sliver: SliverList.separated(
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.transparent,
                    ),
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      final preview = row.subtitle?.trim();
                      final subtitle = preview != null && preview.isNotEmpty
                          ? preview
                          : trEn(context, 'Henüz mesaj yok', 'No messages yet');
                      return _ChatsInboxTile(
                        title: row.title,
                        subtitle: subtitle,
                        initial: _initialForTitle(row.title),
                        onTap: row.onTap,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatsInboxTile extends StatelessWidget {
  const _ChatsInboxTile({
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.primary.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.35 : 0.2,
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _kDotMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
