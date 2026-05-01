import { ConfigService } from '@nestjs/config';

/**
 * Dinleyen listesinde her zaman üstte tutulacak hesap (superadmin / ürün sahibi).
 * `PINNED_LISTENER_EMAIL=` boş string ile kapatılabilir.
 */
export function resolvePinnedListenerEmail(
  config: ConfigService,
): string | null {
  const raw = config.get<string | undefined>('PINNED_LISTENER_EMAIL');
  if (raw === '') return null;
  const t = raw?.trim();
  if (t) return t;
  return 'albayrakerenn@gmail.com';
}
