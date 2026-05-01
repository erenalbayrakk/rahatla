import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/data/chat_unread_notifier.dart';

/// Ana uygulama: alt sekme çubuğu (Ana sayfa / Rastgele / Sohbet / Cüzdan / Liderlik / Profil).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _chatBranchIndex = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatUnreadNotifierProvider.notifier).refresh();
    });
  }

  /// 1–9 rakam; 10+ için `9+`
  static String _chatBadgeLabel(int n) {
    if (n <= 0) return '';
    if (n > 9) return '9+';
    return '$n';
  }

  Widget _chatNavIcon(IconData iconData, int unread) {
    final label = _chatBadgeLabel(unread);
    final show = unread > 0 && label.isNotEmpty;
    return Badge(
      isLabelVisible: show,
      label: show ? Text(label) : null,
      child: Icon(iconData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final unreadChats = ref.watch(chatUnreadNotifierProvider);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
          if (index == _chatBranchIndex) {
            ref.read(chatUnreadNotifierProvider.notifier).refresh();
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: isEn ? 'Home' : 'Ana sayfa',
            tooltip: isEn ? 'Home' : 'Ana sayfa',
          ),
          NavigationDestination(
            icon: const Icon(Icons.shuffle_rounded),
            selectedIcon: const Icon(Icons.shuffle_rounded),
            label: isEn ? 'Random' : 'Rastgele',
            tooltip: isEn ? 'Random connect' : 'Rastgele bağlan',
          ),
          NavigationDestination(
            icon: _chatNavIcon(Icons.chat_bubble_outline_rounded, unreadChats),
            selectedIcon: _chatNavIcon(Icons.chat_bubble_rounded, unreadChats),
            label: isEn ? 'Chats' : 'Sohbet',
            tooltip: isEn ? 'Chats' : 'Sohbetler',
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: isEn ? 'Wallet' : 'Cüzdan',
            tooltip: isEn ? 'Wallet' : 'Cüzdan',
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events_rounded),
            label: isEn ? 'Leaders' : 'Liderlik',
            tooltip: isEn ? 'Leaderboard' : 'Liderlik tablosu',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: isEn ? 'Profile' : 'Profil',
            tooltip: isEn ? 'My profile' : 'Profilim',
          ),
        ],
      ),
    );
  }
}
