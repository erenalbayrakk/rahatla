import 'package:flutter/material.dart';

/// Sunucu koduna göre ikon (API kataloğu ile birlikte kullanılır).
IconData giftIconForCode(String code) {
  switch (code) {
    case 'thanks':
      return Icons.waving_hand_outlined;
    case 'warm_hug':
      return Icons.volunteer_activism_outlined;
    case 'coffee':
      return Icons.local_cafe_outlined;
    case 'star':
      return Icons.star_outline_rounded;
    case 'flower':
      return Icons.local_florist_outlined;
    default:
      return Icons.card_giftcard_outlined;
  }
}

/// API `SESSION_GIFT_CODES` ile aynı kodlar.
class SessionGiftCatalog {
  SessionGiftCatalog._();

  static const List<SessionGiftOption> options = [
    SessionGiftOption(code: 'thanks', label: 'Teşekkür', icon: Icons.waving_hand_outlined),
    SessionGiftOption(code: 'warm_hug', label: 'Sarılma', icon: Icons.volunteer_activism_outlined),
    SessionGiftOption(code: 'coffee', label: 'Kahve', icon: Icons.local_cafe_outlined),
    SessionGiftOption(code: 'star', label: 'Yıldız', icon: Icons.star_outline_rounded),
    SessionGiftOption(code: 'flower', label: 'Çiçek', icon: Icons.local_florist_outlined),
  ];
}

class SessionGiftOption {
  const SessionGiftOption({
    required this.code,
    required this.label,
    required this.icon,
  });

  final String code;
  final String label;
  final IconData icon;
}
