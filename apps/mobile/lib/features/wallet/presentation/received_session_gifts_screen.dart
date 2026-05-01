import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/network/api_exception.dart';
import '../data/wallet_repository.dart';

String _formatMinor(int? v) {
  if (v == null) return '—';
  final s = v.abs().toString();
  final neg = v < 0;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

String _formatDateTime(DateTime d) {
  final l = d.toLocal();
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${p2(l.day)}.${p2(l.month)}.${l.year} ${p2(l.hour)}:${p2(l.minute)}';
}

class ReceivedSessionGiftsScreen extends ConsumerStatefulWidget {
  const ReceivedSessionGiftsScreen({super.key});

  @override
  ConsumerState<ReceivedSessionGiftsScreen> createState() =>
      _ReceivedSessionGiftsScreenState();
}

class _ReceivedSessionGiftsScreenState
    extends ConsumerState<ReceivedSessionGiftsScreen> {
  var _loading = true;
  String? _error;
  ReceivedSessionGiftsResponseDto? _data;

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
          .fetchReceivedSessionGifts(limit: 100);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(trEn(context, 'Aldığın hediyeler', 'Received gifts')),
      ),
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildBody(context, theme, _data!),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ReceivedSessionGiftsResponseDto data,
  ) {
    if (data.giftCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 48),
          Icon(
            Icons.card_giftcard_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                trEn(
                  context,
                  'Henüz aldığın hediye yok.\nBirebir sohbetlerde sana gönderilen hediyeler burada listelenir.',
                  'You have no received gifts yet.\nGifts sent to you in one-on-one chats are listed here.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(
                  Icons.savings_outlined,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trEn(context, 'Toplam aldığın (net)', 'Total received (net)'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatMinor(data.totalRecipientEarnedMinor)} ${isEnglishLocale(context) ? 'units' : 'birim'}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isEnglishLocale(context)
                            ? '${data.giftCount} gifts'
                            : '${data.giftCount} hediye',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          trEn(context, 'Kayıtlar', 'Records'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...data.items.map(
          (g) => _GiftTile(
            gift: g,
            theme: theme,
          ),
        ),
      ],
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({
    required this.gift,
    required this.theme,
  });

  final ReceivedSessionGiftItemDto gift;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final title = gift.giftLabel.isNotEmpty ? gift.giftLabel : gift.giftCode;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _formatDateTime(gift.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        children: [
          _row(trEn(context, 'Gönderen', 'Sender'), gift.senderDisplayName, theme),
          const SizedBox(height: 6),
          _row(
            trEn(context, 'Sana geçen (net)', 'Net credited to you'),
            '${_formatMinor(gift.recipientEarnedMinor)} ${isEnglishLocale(context) ? 'units' : 'birim'}',
            theme,
          ),
          const SizedBox(height: 6),
          _row(
            trEn(context, 'Hediye fiyatı', 'Gift price'),
            '${_formatMinor(gift.priceMinor)} ${isEnglishLocale(context) ? 'units' : 'birim'}',
            theme,
          ),
          const SizedBox(height: 6),
          _row(
            trEn(context, 'Platform payı', 'Platform fee'),
            '${_formatMinor(gift.platformFeeMinor)} ${isEnglishLocale(context) ? 'units' : 'birim'}',
            theme,
          ),
          const SizedBox(height: 6),
          _row(trEn(context, 'Kod', 'Code'), gift.giftCode, theme, mono: true),
          const SizedBox(height: 6),
          _row(trEn(context, 'Oturum', 'Session'), gift.sessionId, theme, mono: true),
        ],
      ),
    );
  }

  static Widget _row(
    String k,
    String v,
    ThemeData theme, {
    bool mono = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            k,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: (mono
                    ? theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      )
                    : theme.textTheme.bodyMedium)
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
