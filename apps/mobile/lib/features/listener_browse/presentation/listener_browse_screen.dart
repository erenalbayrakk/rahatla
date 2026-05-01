import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/mood/mood_catalog.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/calm_cta_button.dart';
import '../../../shared/widgets/soft_header.dart';
import '../domain/browse_listener.dart';
import '../domain/browse_reply_pace.dart';
import 'listener_browse_controller.dart';

class ListenerBrowseScreen extends ConsumerWidget {
  const ListenerBrowseScreen({super.key, this.supportRequestId});

  /// Destek talebi akışından gelince `go_router` `extra` ile taşınır.
  final String? supportRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncListeners = ref.watch(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter));

    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoftHeader(
            title: trEn(context, 'Dinleyenler', 'Listeners'),
            subtitle: trEn(
              context,
              'Profilindeki ruh haline uygun liste · sayfa başına 30 kişi · aşağıdan devam et',
              'Matched to your profile mood · 30 per page · load more below',
            ),
            onBack: () => context.pop(),
            trailing: IconButton(
              tooltip: trEn(context, 'Yenile', 'Refresh'),
              onPressed: () =>
                  ref.read(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter).notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(
            child: asyncListeners.when(
              data: (page) {
                final list = page.items;
                if (list.isEmpty) {
                  return _EmptyListeners(
                    supportRequestId: supportRequestId,
                    onRefresh: () => ref
                        .read(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter).notifier)
                        .refresh(),
                  );
                }
                final moodLine = page.moodFilter != null
                    ? trEn(
                        context,
                        'Liste filtresi: ${MoodCatalog.labelFor(page.moodFilter) ?? page.moodFilter}',
                        'List filter: ${MoodCatalog.labelLocalized(context, page.moodFilter!)}',
                      )
                    : trEn(
                        context,
                        'Ruh hali seçmediğin için tüm uygun dinleyenler gösteriliyor.',
                        'No mood filter: showing all matching listeners.',
                      );
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter).notifier).refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: list.length + (page.hasMore ? 1 : 0) + 1,
                    separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              moodLine,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _BrowseRandomMatchButton(
                              supportRequestId: supportRequestId,
                            ),
                          ],
                        );
                      }
                      final dataIndex = index - 1;
                      if (dataIndex < list.length) {
                        final item = list[dataIndex];
                        return _ListenerCard(
                          item: item,
                          onTap: () => _confirmAndOpenSession(
                            context,
                            ref,
                            item,
                            supportRequestId,
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () async {
                              final err = await ref
                                  .read(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter).notifier)
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
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorState(
                message: err is ApiException
                    ? err.message
                    : trEn(context, 'Liste yüklenemedi.', 'Could not load the list.'),
                onRetry: () =>
                    ref.read(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter).notifier).refresh(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndOpenSession(
    BuildContext context,
    WidgetRef ref,
    BrowseListener item,
    String? supportRequestId,
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
              child: Text(trEn(ctx, 'Evet, devam et', 'Yes, continue')),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;

    try {
      final sessionId = await ref
          .read(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter).notifier)
          .startSession(
            listenerUserId: item.userId,
            supportRequestId: supportRequestId,
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
}

class _ListenerCard extends StatelessWidget {
  const _ListenerCard({required this.item, required this.onTap});

  final BrowseListener item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratingLine = item.ratingCount > 0
        ? trEn(
            context,
            'Ortalama ${item.ratingAvg.toStringAsFixed(1)} · ${item.ratingCount} değerlendirme',
            'Average ${item.ratingAvg.toStringAsFixed(1)} · ${item.ratingCount} ratings',
          )
        : null;

    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.9)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    child: Text(
                      item.displayName.isNotEmpty
                          ? item.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              item.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.accountKind == 'listener_applicant')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  trEn(
                                    context,
                                    'Yardım eden · başvuru',
                                    'Helper · application',
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                            if (item.pinned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.push_pin_outlined,
                                      size: 14,
                                      color: theme.colorScheme.tertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      trEn(context, 'Her zaman', 'Pinned'),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.tertiary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (ratingLine != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            ratingLine,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                        if (browseReplyPaceChipLabel(
                              context,
                              item.replyPace,
                            ) !=
                            null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: 0.35),
                              ),
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.35
                                    : 0.85,
                              ),
                            ),
                            child: Text(
                              browseReplyPaceChipLabel(
                                context,
                                item.replyPace,
                              )!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.isOnline)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trEn(context, 'Çevrimiçi', 'Online'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (item.recognitionLabels.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  trEn(context, 'Yönetici takdiri', 'Recognition'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.recognitionLabels.map((label) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        color: theme.colorScheme.primary.withValues(alpha: 0.06),
                      ),
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (item.supportCategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  trEn(context, 'Destek alanları', 'Support areas'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.supportCategories.take(4).map((c) {
                    return Chip(
                      label: Text(
                        c,
                        style: theme.textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyListeners extends ConsumerStatefulWidget {
  const _EmptyListeners({
    required this.onRefresh,
    this.supportRequestId,
  });

  final Future<void> Function() onRefresh;
  final String? supportRequestId;

  @override
  ConsumerState<_EmptyListeners> createState() => _EmptyListenersState();
}

class _EmptyListenersState extends ConsumerState<_EmptyListeners> {
  var _randomLoading = false;

  Future<void> _random() async {
    if (_randomLoading) return;
    setState(() => _randomLoading = true);
    try {
      final id = await ref
          .read(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter).notifier)
          .startRandomSession(supportRequestId: widget.supportRequestId);
      if (!mounted) return;
      await context.push(RoutePaths.chat(id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _randomLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              trEn(context, 'Şu an müsait dinleyen yok', 'No available listeners right now'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              trEn(
                context,
                'Rastgele eşleşmeyi veya listeyi yenilemeyi deneyebilirsin.',
                'Try random match or pull to refresh the list.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            CalmCTAButton(
              label: _randomLoading
                  ? trEn(context, 'Atanıyor…', 'Matching…')
                  : trEn(context, 'Rastgele biriyle konuş', 'Talk to someone random'),
              onPressed: _randomLoading ? null : _random,
            ),
            const SizedBox(height: 12),
            CalmCTAButton(
              label: trEn(context, 'Yenile', 'Refresh'),
              outlined: true,
              onPressed: () => widget.onRefresh(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseRandomMatchButton extends ConsumerStatefulWidget {
  const _BrowseRandomMatchButton({this.supportRequestId});

  final String? supportRequestId;

  @override
  ConsumerState<_BrowseRandomMatchButton> createState() =>
      _BrowseRandomMatchButtonState();
}

class _BrowseRandomMatchButtonState
    extends ConsumerState<_BrowseRandomMatchButton> {
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                final id = await ref
                    .read(listenerBrowseControllerProvider(ListenerBrowseListMode.profileMoodFilter).notifier)
                    .startRandomSession(
                      supportRequestId: widget.supportRequestId,
                    );
                if (!context.mounted) return;
                await context.push(RoutePaths.chat(id));
              } on ApiException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      icon: Icon(
        Icons.shuffle_rounded,
        size: 20,
        color: theme.colorScheme.primary,
      ),
      label: Text(
        _loading
            ? trEn(context, 'Atanıyor…', 'Matching…')
            : trEn(context, 'Rastgele dinleyen ata', 'Assign random listener'),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            CalmCTAButton(
              label: trEn(context, 'Tekrar dene', 'Try again'),
              onPressed: () => onRetry(),
            ),
          ],
        ),
      ),
    );
  }
}
