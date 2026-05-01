import { Prisma } from '@prisma/client';

/**
 * Yalnızca `availabilityMode === automatic` iken uygulanan socket / admin presence kuralları.
 */
export function listenerAutomaticPresenceWhere(): Prisma.ListenerProfileWhereInput {
  return {
    OR: [
      { presenceOverride: 'force_online' },
      {
        presenceOverride: 'force_offline',
        isAvailable: true,
      },
      {
        presenceOverride: 'auto',
        OR: [{ isOnline: true }, { isAvailable: true }],
      },
    ],
  };
}

/**
 * “Hazır / rastgele dinleyen” havuzu:
 * - `busy` dışarıda
 * - `available` her zaman dahil
 * - `automatic` → presence + çevrimiçi / müsaitlik kuralları
 */
export function listenerProfileReadyWhere(): Prisma.ListenerProfileWhereInput {
  return {
    AND: [
      { NOT: { availabilityMode: 'busy' } },
      {
        OR: [
          { availabilityMode: 'available' },
          {
            AND: [
              { availabilityMode: 'automatic' },
              listenerAutomaticPresenceWhere(),
            ],
          },
        ],
      },
    ],
  };
}
