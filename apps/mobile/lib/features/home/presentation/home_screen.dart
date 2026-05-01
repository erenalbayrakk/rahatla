import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../group_chat/presentation/group_rooms_screen.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../listener_browse/domain/browse_listener.dart';
import '../../listener_browse/domain/browse_reply_pace.dart';
import '../../listener_browse/presentation/listener_browse_controller.dart';
import 'home_people_filter_sheet.dart';
import '../state/home_people_filters.dart';

Future<void> _confirmAndOpenListenerSession(
  BuildContext context,
  WidgetRef ref,
  BrowseListener item,
) async {
  final theme = Theme.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(
          trEn(ctx, 'Devam etmek istiyor musun?', 'Continue?'),
        ),
        content: Text(
          trEn(
            ctx,
            '${item.displayName} ile sohbete başlayacaksın. İstediğin zaman oturumu bitirebilirsin.'
            '${item.recognitionLabels.isNotEmpty ? '\n\nTakdir: ${item.recognitionLabels.join(' · ')}' : ''}',
            'You are about to start a chat with ${item.displayName}. You can end the session anytime.'
            '${item.recognitionLabels.isNotEmpty ? '\n\nRecognition: ${item.recognitionLabels.join(' · ')}' : ''}',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(trEn(ctx, 'Vazgeç', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              trEn(ctx, 'Evet, devam et', 'Yes, continue'),
            ),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) return;

  try {
    final sessionId = await ref
        .read(
          listenerBrowseControllerProvider(ListenerBrowseListMode.homeShowAll)
              .notifier,
        )
        .startSession(
          listenerUserId: item.userId,
        );
    if (!context.mounted) return;
    await context.push(RoutePaths.chat(sessionId));
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _feedSegment = 0;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUnreadCount());
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final n = await ref.read(notificationsRepositoryProvider).fetchUnreadCount();
      if (mounted) setState(() => _unreadNotifications = n);
    } catch (_) {
      // Sessizce geç (giriş yokken vb.)
    }
  }

  /// Cihaz yerel saati. Gece (22–05) için "Günaydın" göstermeyiz.
  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) {
      return trEn(context, 'Günaydın', 'Good morning');
    }
    if (h >= 12 && h < 18) {
      return trEn(context, 'Merhaba', 'Hello');
    }
    if (h >= 18 && h < 22) {
      return trEn(context, 'İyi akşamlar', 'Good evening');
    }
    return trEn(context, 'İyi geceler', 'Good night');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final name = user?.email.split('@').first ?? trEn(context, 'sen', 'you');

    return AppScaffold(
      padding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, AppSpacing.sm, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Semantics(
                  label: 'Rahatla',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary,
                          Color.lerp(scheme.primary, scheme.tertiary, 0.25)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'R',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(context),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                Badge(
                  isLabelVisible: _unreadNotifications > 0,
                  label: Text(
                    _unreadNotifications > 99
                        ? '99+'
                        : '$_unreadNotifications',
                  ),
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () async {
                      await context.push(RoutePaths.notifications);
                      if (mounted) await _refreshUnreadCount();
                    },
                    icon: const Icon(Icons.notifications_none_rounded),
                    tooltip: trEn(context, 'Bildirimler', 'Notifications'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  label: Text(trEn(context, 'Kişiler', 'People')),
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text(trEn(context, 'Gruplar', 'Groups')),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                ),
              ],
              selected: {_feedSegment},
              onSelectionChanged: (s) {
                setState(() => _feedSegment = s.first);
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _feedSegment == 0
                ? const _HomePeopleFeedTab()
                : Container(
                    color: scheme.surface,
                    child: const GroupRoomsContent(embedded: true),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HomePeopleFeedTab extends ConsumerStatefulWidget {
  const _HomePeopleFeedTab();

  @override
  ConsumerState<_HomePeopleFeedTab> createState() => _HomePeopleFeedTabState();
}

class _HomePeopleFeedTabState extends ConsumerState<_HomePeopleFeedTab> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scheduleSearchQuery(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 360), () {
      ref.read(homePeopleFiltersProvider.notifier).setQuery(value);
    });
  }

  Future<void> _showKesifFilterSheet() async {
    await showHomePeopleFilterSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filters = ref.watch(homePeopleFiltersProvider);

    final asyncListeners = ref.watch(
      listenerBrowseControllerProvider(ListenerBrowseListMode.homeShowAll),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _scheduleSearchQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: trEn(context, 'İsme göre ara', 'Search by name'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.45 : 0.8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.25),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.22),
                      ),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _showKesifFilterSheet,
                icon: const Icon(Icons.explore_outlined),
                tooltip: trEn(context, 'Keşif', 'Discover'),
              ),
            ],
          ),
        ),
        Expanded(
          child: asyncListeners.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      err is ApiException
                          ? err.message
                          : trEn(context, 'Liste yüklenemedi.', 'Could not load the list.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref
                          .read(
                            listenerBrowseControllerProvider(
                              ListenerBrowseListMode.homeShowAll,
                            ).notifier,
                          )
                          .refresh(),
                      child: Text(
                        trEn(context, 'Yeniden dene', 'Try again'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            data: (page) {
              final list = page.items;
              final filteredOut = filters.hasActiveFilters;
              return Container(
                color: scheme.surface,
                child: RefreshIndicator(
                  edgeOffset: 8,
                  onRefresh: () => ref
                      .read(
                        listenerBrowseControllerProvider(
                          ListenerBrowseListMode.homeShowAll,
                        ).notifier,
                      )
                      .refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
                    itemCount:
                        list.length + (page.hasMore ? 1 : 0) + (list.isEmpty ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.transparent,
                    ),
                    itemBuilder: (context, index) {
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          child: Text(
                            filteredOut
                                ? trEn(
                                    context,
                                    'Seçtiğin arama veya Keşif filtresine uyan dinleyen yok. '
                                    'Bazı hesaplarda doğum tarihi veya cinsiyet alanı boş olabilir; bu durumda arama dışı kalırlar.',
                                    'No listeners match your search or Discover filters. '
                                    'Some profiles may be missing date of birth or gender and be excluded from search.',
                                  )
                                : trEn(
                                    context,
                                    'Şu an listelenecek kullanıcı yok.',
                                    'No users to show right now.',
                                  ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      if (index >= list.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () async {
                                final err = await ref
                                    .read(
                                      listenerBrowseControllerProvider(
                                        ListenerBrowseListMode.homeShowAll,
                                      ).notifier,
                                    )
                                    .loadMore();
                                if (!context.mounted) return;
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err)),
                                  );
                                }
                              },
                              icon: const Icon(Icons.expand_more_rounded),
                              label: Text(
                                trEn(
                                  context,
                                  'Daha fazla (${list.length} / ${page.total})',
                                  'Load more (${list.length} / ${page.total})',
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final item = list[index];
                      return _HomeListenerTile(
                        item: item,
                        onTap: () =>
                            _confirmAndOpenListenerSession(context, ref, item),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _homeGenderTr(BuildContext context, String api) {
  switch (api) {
    case 'female':
      return trEn(context, 'Kadın', 'Woman');
    case 'male':
      return trEn(context, 'Erkek', 'Man');
    case 'non_binary':
      return 'Non-binary';
    case 'prefer_not_to_say':
      return trEn(context, 'Cinsiyet belirtilmedi', 'Unspecified');
    default:
      return api;
  }
}

class _HomeListenerTile extends StatelessWidget {
  const _HomeListenerTile({required this.item, required this.onTap});

  final BrowseListener item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paceLabel = browseReplyPaceChipLabel(context, item.replyPace);
    var subtitle = item.accountKind == 'listener_applicant'
        ? trEn(context, 'Yardım eden · başvuru', 'Helper · application')
        : item.ratingCount > 0
            ? trEn(
                context,
                'Ortalama ${item.ratingAvg.toStringAsFixed(1)} · ${item.ratingCount} değerlendirme',
                'Average ${item.ratingAvg.toStringAsFixed(1)} · ${item.ratingCount} ratings',
              )
            : trEn(context, 'Dinleyici', 'Listener');
    final meta = <String>[];
    if (item.age != null) {
      meta.add(
        isEnglishLocale(context) ? 'Age ${item.age}' : '${item.age} yaş',
      );
    }
    if (item.gender != null) {
      meta.add(_homeGenderTr(context, item.gender!));
    }
    if (meta.isNotEmpty) {
      subtitle = '$subtitle · ${meta.join(' · ')}';
    }
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
                      item.displayName.isNotEmpty ? item.displayName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
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
                        color:
                            item.isOnline ? const Color(0xFF8BDA3E) : const Color(0xFF9EA5B3),
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
                      item.displayName,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    if (paceLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        paceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.tertiary,
                          fontWeight: FontWeight.w600,
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
  }
}
