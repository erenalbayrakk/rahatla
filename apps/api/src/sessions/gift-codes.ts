/** Birebir sohbette izin verilen hediye kodları (client ile aynı). */
export const SESSION_GIFT_CODES = [
  'thanks',
  'warm_hug',
  'coffee',
  'star',
  'flower',
] as const;

export type SessionGiftCode = (typeof SESSION_GIFT_CODES)[number];

export const SESSION_GIFT_LABELS: Record<SessionGiftCode, string> = {
  thanks: 'Teşekkür',
  warm_hug: 'Sıcak sarılma',
  coffee: 'Kahve',
  star: 'Yıldız',
  flower: 'Çiçek',
};

export function isSessionGiftCode(v: string): v is SessionGiftCode {
  return (SESSION_GIFT_CODES as readonly string[]).includes(v);
}
