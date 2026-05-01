import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/soft_header.dart';
import '../data/wallet_repository.dart';

class _TopupOption {
  const _TopupOption({
    required this.balance,
    required this.priceTl,
  });

  /// API `amountMinor` ile aynı (cüzdana eklenecek bakiye miktarı).
  final int balance;

  /// Gösterim için TL fiyatı (şimdilik sabit paket tablosu).
  final int priceTl;
}

/// Alt sekme «Cüzdan»: bakiye özeti ve sabit paketlerle yükleme.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  WalletSummaryDto? _summary;
  var _loading = true;
  String? _error;
  int? _busyAmount;

  static const _topupOptions = [
    _TopupOption(balance: 100, priceTl: 50),
    _TopupOption(balance: 500, priceTl: 239),
    _TopupOption(balance: 1000, priceTl: 398),
    _TopupOption(balance: 5000, priceTl: 1000),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sum = await ref.read(walletRepositoryProvider).fetchWalletMe();
      if (!mounted) return;
      setState(() {
        _summary = sum;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = null;
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndTopup(_TopupOption opt) async {
    if (_busyAmount != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx);
        final isEn = isEnglishLocale(ctx);
        return AlertDialog(
          title: Text(isEn ? 'Payment confirmation' : 'Ödeme onayı'),
          content: Text(
            isEn
                ? 'Balance top-up will initially be completed via secure payment through Apple (App Store) or Google Play.\n\n'
                    'Your selection: ${opt.balance} balance · ${opt.priceTl} TRY\n\n'
                    'Do you confirm?'
                : 'Bakiye yükleme, ilk aşamada Apple (App Store) veya Google Play '
                    'üzerinden güvenli ödeme ile gerçekleştirilecektir.\n\n'
                    'Seçiminiz: ${opt.balance} bakiye · ${opt.priceTl} TL\n\n'
                    'Onaylıyor musunuz?',
            style: t.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(isEn ? 'Cancel' : 'Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(isEn ? 'Yes, confirm' : 'Evet, onaylıyorum'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    await _topup(opt.balance);
  }

  Future<void> _topup(int amountMinor) async {
    if (_busyAmount != null) return;
    setState(() => _busyAmount = amountMinor);
    try {
      await ref.read(walletRepositoryProvider).topup(amountMinor: amountMinor);
      try {
        final sum = await ref.read(walletRepositoryProvider).fetchWalletMe();
        if (mounted) setState(() => _summary = sum);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnglishLocale(context)
                ? '$amountMinor balance added.'
                : '$amountMinor bakiye yüklendi.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busyAmount = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEn = isEnglishLocale(context);

    return ColoredBox(
      color: scheme.surface,
      child: AppScaffold(
        padding: EdgeInsets.zero,
        body: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: SoftHeader(
                    title: isEn ? 'Wallet' : 'Cüzdan',
                    subtitle: isEn ? 'Top up balance' : 'Bakiye yükleme',
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
                          onPressed: _refresh,
                          child: Text(isEn ? 'Try again' : 'Yeniden dene'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          elevation: 0,
                          color: scheme.surfaceContainerLowest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  isEn ? 'Current balance' : 'Mevcut bakiye',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_summary?.balanceMinor ?? 0} ${_summary?.currency ?? 'TRY'} ${isEn ? 'units' : 'birim'}',
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if ((_summary?.minPayoutMinor ?? 0) > 0) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    isEn
                                        ? 'Minimum payout: ${_summary!.minPayoutMinor} units'
                                        : 'Minimum çekim: ${_summary!.minPayoutMinor} birim',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isEn ? 'Select top-up amount' : 'Yükleme tutarı seç',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, c) {
                            final w = (c.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _topupOptions.map((opt) {
                                final amt = opt.balance;
                                final busy = _busyAmount == amt;
                                final anyBusy = _busyAmount != null;
                                return SizedBox(
                                  width: w.clamp(120.0, 400.0),
                                  height: 68,
                                  child: FilledButton.tonal(
                                    onPressed: anyBusy && !busy
                                        ? null
                                        : () => _confirmAndTopup(opt),
                                    child: busy
                                        ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme
                                                  .colorScheme.primary,
                                            ),
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                isEn
                                                    ? '${opt.balance} balance'
                                                    : '${opt.balance} bakiye',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${opt.priceTl} TL',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: theme
                                                      .colorScheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isEn
                              ? 'Once payment integration is connected, these amounts will be confirmed via store or card.'
                              : 'Ödeme entegrasyonu bağlandığında bu tutarlar mağaza veya kart ile onaylanacaktır.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
