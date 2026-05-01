import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/group_chat_repository.dart';

/// Katıldığın grup odaları ve keşfet (katılma isteği).
///
/// [embedded] true iken `Scaffold`/`AppBar` olmadan — örn. ana sayfa «Gruplar» sekmesi.
class GroupRoomsContent extends ConsumerStatefulWidget {
  const GroupRoomsContent({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<GroupRoomsContent> createState() => _GroupRoomsContentState();
}

class _GroupRoomsContentState extends ConsumerState<GroupRoomsContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _discoverItems = [];
  int _discoverPage = 0;
  int _discoverTotal = 0;
  bool _loadingMine = true;
  bool _loadingDiscover = true;
  bool _loadingMoreDiscover = false;
  String? _errorMine;
  String? _errorDiscover;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMine();
    _loadDiscover();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    setState(() {
      _loadingMine = true;
      _errorMine = null;
    });
    try {
      final list = await ref.read(groupChatRepositoryProvider).listMyRooms();
      if (!mounted) return;
      setState(() {
        _mine = list;
        _loadingMine = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMine = e.toString();
        _loadingMine = false;
      });
    }
  }

  Future<void> _loadDiscover() async {
    setState(() {
      _loadingDiscover = true;
      _errorDiscover = null;
    });
    try {
      final page = await ref.read(groupChatRepositoryProvider).fetchDiscoverRoomsPage(page: 1);
      if (!mounted) return;
      setState(() {
        _discoverItems = List<Map<String, dynamic>>.from(page.items);
        _discoverPage = page.page;
        _discoverTotal = page.total;
        _loadingDiscover = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorDiscover = e.toString();
        _loadingDiscover = false;
      });
    }
  }

  List<Widget> _tabs(BuildContext context) {
    return [
      Tab(text: trEn(context, 'Odalarım', 'My rooms')),
      Tab(text: trEn(context, 'Keşfet', 'Discover')),
    ];
  }

  Future<void> _loadMoreDiscover() async {
    if (_loadingMoreDiscover || _discoverItems.length >= _discoverTotal) return;
    setState(() => _loadingMoreDiscover = true);
    try {
      final page = await ref
          .read(groupChatRepositoryProvider)
          .fetchDiscoverRoomsPage(page: _discoverPage + 1);
      if (!mounted) return;
      setState(() {
        _discoverItems.addAll(page.items);
        _discoverPage = page.page;
        _discoverTotal = page.total;
        _loadingMoreDiscover = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMoreDiscover = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _submitJoinRequest(String roomId, String title) async {
    final messageCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trEn(ctx, 'Katıl: $title', 'Join: $title')),
        content: TextField(
          controller: messageCtrl,
          decoration: InputDecoration(
            labelText: trEn(
              ctx,
              'Kısa mesaj (isteğe bağlı)',
              'Short message (optional)',
            ),
            hintText: trEn(
              ctx,
              'Kendini kısaca tanıtabilirsin',
              'You can introduce yourself briefly',
            ),
          ),
          maxLines: 3,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(trEn(ctx, 'Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(trEn(ctx, 'Gönder', 'Send')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(groupChatRepositoryProvider).createJoinRequest(
            roomId,
            message: messageCtrl.text.trim().isEmpty ? null : messageCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trEn(
              context,
              'Katılma isteğin gönderildi. Onay sonrası odada görünürsün.',
              'Your join request was sent. You will appear in the room after approval.',
            ),
          ),
        ),
      );
      await _loadDiscover();
      await _loadMine();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      messageCtrl.dispose();
    }
  }

  Widget _tabBar(BuildContext context, ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        tabs: _tabs(context),
      ),
    );
  }

  Widget _tabBarView(BuildContext context, ThemeData theme) {
    return TabBarView(
      controller: _tabController,
      children: [
        RefreshIndicator(
          onRefresh: _loadMine,
          child: _buildMineList(context, theme),
        ),
        RefreshIndicator(
          onRefresh: _loadDiscover,
          child: _buildDiscoverList(context, theme),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabBar(context, theme),
          Expanded(child: _tabBarView(context, theme)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(trEn(context, 'Grup odaları', 'Group rooms')),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs(context),
        ),
      ),
      body: _tabBarView(context, theme),
    );
  }

  String _roomFallbackTitle(BuildContext context) =>
      trEn(context, 'Oda', 'Room');

  String _memberCountLabel(BuildContext context, int count) {
    if (isEnglishLocale(context)) {
      return count == 1 ? '1 member' : '$count members';
    }
    return '$count üye';
  }

  String _roleSubtitle(BuildContext context, String role) {
    if (role.isEmpty) {
      return trEn(context, 'Üye', 'Member');
    }
    return role;
  }

  Widget _buildMineList(BuildContext context, ThemeData theme) {
    if (_loadingMine) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_errorMine != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_errorMine!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadMine,
            child: Text(trEn(context, 'Tekrar dene', 'Try again')),
          ),
        ],
      );
    }
    if (_mine.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.groups_outlined, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            trEn(
              context,
              'Henüz bir grup odasına dahil değilsin.',
              'You are not in any group room yet.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            trEn(
              context,
              'Keşfet sekmesinden odaya katılma isteği gönderebilirsin.',
              'You can send a join request from the Discover tab.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _mine.length,
      itemBuilder: (context, i) {
        final r = _mine[i];
        final id = r['id'] as String? ?? '';
        final title = r['title'] as String? ?? _roomFallbackTitle(context);
        final role = r['myRole'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(title.isNotEmpty ? title[0].toUpperCase() : '?'),
            ),
            title: Text(title),
            subtitle: Text(_roleSubtitle(context, role)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(RoutePaths.groupChat(id)),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverList(BuildContext context, ThemeData theme) {
    if (_loadingDiscover) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_errorDiscover != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_errorDiscover!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadDiscover,
            child: Text(trEn(context, 'Tekrar dene', 'Try again')),
          ),
        ],
      );
    }
    if (_discoverItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Text(
            trEn(
              context,
              'Şu an listelenecek açık oda yok.',
              'There are no open rooms to list right now.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      );
    }
    final hasMore = _discoverItems.length < _discoverTotal;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _discoverItems.length + (hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _discoverItems.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _loadingMoreDiscover
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  : TextButton.icon(
                      onPressed: _loadMoreDiscover,
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text(
                        trEn(
                          context,
                          'Daha fazla (${_discoverItems.length} / $_discoverTotal)',
                          'Load more (${_discoverItems.length} / $_discoverTotal)',
                        ),
                      ),
                    ),
            ),
          );
        }
        final r = _discoverItems[i];
        final id = r['id'] as String? ?? '';
        final title = r['title'] as String? ?? _roomFallbackTitle(context);
        final desc = r['description'] as String?;
        final count = r['participantCount'] as int? ?? 0;
        final isMember = r['isMember'] as bool? ?? false;
        final pending = r['hasPendingRequest'] as bool? ?? false;
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      child: Text(title.isNotEmpty ? title[0].toUpperCase() : '?'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            _memberCountLabel(context, count),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (desc != null && desc.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(desc, style: theme.textTheme.bodySmall),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: isMember
                      ? FilledButton.tonal(
                          onPressed: () => context.push(RoutePaths.groupChat(id)),
                          child: Text(trEn(context, 'Sohbete gir', 'Open chat')),
                        )
                      : pending
                          ? TextButton(
                              onPressed: null,
                              child: Text(
                                trEn(
                                  context,
                                  'İstek beklemede',
                                  'Request pending',
                                ),
                              ),
                            )
                          : FilledButton(
                              onPressed: () => _submitJoinRequest(id, title),
                              child: Text(
                                trEn(
                                  context,
                                  'Katılma isteği',
                                  'Request to join',
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tam ekran rota: başlık + geri.
class GroupRoomsScreen extends StatelessWidget {
  const GroupRoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GroupRoomsContent(embedded: false);
  }
}
