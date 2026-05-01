import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/locale_text.dart';
import '../../../core/network/api_exception.dart';
import '../data/wallet_repository.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  var _period = LeaderboardPeriod.today;
  var _loading = true;
  String? _error;
  LeaderboardDto? _data;

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
      final d = await ref
          .read(walletRepositoryProvider)
          .fetchLeaderboard(period: _period.apiValue);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setPeriod(LeaderboardPeriod p) async {
    if (_period == p) return;
    setState(() => _period = p);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(trEn(context, 'Liderlik', 'Leaderboard')),
      ),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(
                child: SegmentedButton<LeaderboardPeriod>(
                  segments: [
                    ButtonSegment(
                      value: LeaderboardPeriod.today,
                      label: Text(trEn(context, 'Bugün', 'Today')),
                    ),
                    ButtonSegment(
                      value: LeaderboardPeriod.month,
                      label: Text(trEn(context, 'Bu ay', 'This month')),
                    ),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) {
                    if (s.isNotEmpty) unawaited(_setPeriod(s.first));
                  },
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
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LeaderSection(
                        title: trEn(
                          context,
                          'En çok kazananlar',
                          'Top earners',
                        ),
                        subtitle: trEn(
                          context,
                          'Dönem içinde kazanılan hediye tutarı',
                          'Gift value earned in this period',
                        ),
                        rows: _data?.topEarners ?? [],
                        theme: theme,
                      ),
                      const SizedBox(height: 24),
                      _LeaderSection(
                        title: trEn(
                          context,
                          'En çok hediye gönderenler',
                          'Top gift senders',
                        ),
                        subtitle: trEn(
                          context,
                          'Dönem içinde gönderilen hediyelerin toplamı',
                          'Total gifts sent in this period',
                        ),
                        rows: _data?.topGiftSenders ?? [],
                        theme: theme,
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
}

enum LeaderboardPeriod {
  today,
  month;

  String get apiValue => switch (this) {
        LeaderboardPeriod.today => 'today',
        LeaderboardPeriod.month => 'month',
      };
}

class _LeaderSection extends StatelessWidget {
  const _LeaderSection({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.theme,
  });

  final String title;
  final String subtitle;
  final List<LeaderboardRowDto> rows;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  trEn(context, 'Henüz kayıt yok', 'No entries yet'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
              itemBuilder: (context, i) {
                final r = rows[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    child: Text(
                      '${r.rank}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    r.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    trEn(
                      context,
                      '${r.totalMinor} birim',
                      '${r.totalMinor} units',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
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
