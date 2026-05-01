import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/soft_header.dart';
import '../../listener_browse/presentation/listener_browse_controller.dart'
    show ListenerBrowseListMode, listenerBrowseControllerProvider;

/// Rastgele eşleşme ve ilgili bağlantılar (liste).
class RandomConnectScreen extends ConsumerWidget {
  const RandomConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppScaffold(
      padding: EdgeInsets.zero,
      body: ListView(
        padding: AppSpacing.sliverT(top: AppSpacing.sm, bottom: AppSpacing.xxxl),
        children: [
          Padding(
            padding: AppSpacing.screenH,
            child: SoftHeader(
              title: trEn(context, 'Rastgele', 'Random'),
              subtitle: trEn(
                context,
                'Hızlı bağlantı ve diğer seçenekler',
                'Quick connect and more options',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: AppSpacing.screenH,
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(Icons.shuffle_rounded, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      trEn(context, 'Rastgele dinleyen', 'Random listener'),
                    ),
                    subtitle: Text(
                      trEn(
                        context,
                        'Uygun dinleyen havuzundan anında bir eşleşme dene.',
                        'Get an instant match from the available listener pool.',
                      ),
                      style: const TextStyle(height: 1.35),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      try {
                        final id = await ref
                            .read(
                              listenerBrowseControllerProvider(
                                ListenerBrowseListMode.profileMoodFilter,
                              ).notifier,
                            )
                            .startRandomSession();
                        if (!context.mounted) return;
                        await context.push(RoutePaths.chat(id));
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
                      child: Icon(Icons.person_search_rounded, color: theme.colorScheme.secondary),
                    ),
                    title: Text(
                      trEn(context, 'Tüm dinleyenler', 'All listeners'),
                    ),
                    subtitle: Text(
                      trEn(
                        context,
                        'Listeyi inceleyip kendin seç.',
                        'Browse the list and pick someone.',
                      ),
                      style: const TextStyle(height: 1.35),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(RoutePaths.browseListeners),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.14),
                      child: Icon(Icons.support_agent_rounded, color: theme.colorScheme.tertiary),
                    ),
                    title: Text(
                      trEn(context, 'Destek isteği', 'Support request'),
                    ),
                    subtitle: Text(
                      trEn(
                        context,
                        'Eşleşme için sıraya gir veya talebini ilet.',
                        'Queue for a match or send your request.',
                      ),
                      style: const TextStyle(height: 1.35),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(RoutePaths.supportRequest),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
