import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Gender, MessageType, Prisma, SupportCategory } from '@prisma/client';
import {
  type ReplyPaceThresholdsSec,
  AppSettingsService,
} from '../app-settings/app-settings.service';
import { resolvePinnedListenerEmail } from '../config/pinned-listener-email';
import { PrismaService } from '../prisma/prisma.service';
import { listenerProfileReadyWhere } from './listener-presence.query';

export type BrowseFilter = 'all' | 'ready';

/** Keşif listesi: son yanıtlara göre tepki süresi özeti (mobil rozet). */
export type BrowseReplyPace = 'spark' | 'swift' | 'warm' | 'easy';

const PAGE_SIZE = 30;

const REPLY_PACE_SESSIONS_SCAN = 25;
const REPLY_PACE_RECENT_EVENTS = 10;
const REPLY_PACE_MIN_SAMPLES = 2;
const REPLY_PACE_MAX_PAIR_SEC = 14 * 24 * 60 * 60;
const REPLY_PACE_CACHE_MS = 5 * 60 * 1000;

const browseSelect = {
  id: true,
  role: true,
  gender: true,
  birthDate: true,
  profile: { select: { displayName: true } },
  listenerApplication: { select: { status: true } },
  listenerProfile: {
    select: {
      supportCategories: true,
      adminRecognitionLabels: true,
      ratingAvg: true,
      ratingCount: true,
      isOnline: true,
      isAvailable: true,
      presenceOverride: true,
      availabilityMode: true,
    },
  },
} as const;

type BrowseRow = Prisma.UserGetPayload<{ select: typeof browseSelect }>;

function ageFromBirthDate(birth: Date): number {
  const t = new Date();
  const d = new Date(birth);
  let age = t.getFullYear() - d.getFullYear();
  const m = t.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && t.getDate() < d.getDate())) {
    age -= 1;
  }
  return age;
}

/** Yaş aralığı: doğum tarihi üzerinden (min yaş / max yaş birlikte veya ayrı). */
function birthDateWhereFromAgeRange(
  minAge?: number,
  maxAge?: number,
): Prisma.DateTimeNullableFilter | undefined {
  if (minAge == null && maxAge == null) return undefined;
  const cond: Prisma.DateTimeNullableFilter = { not: null };
  const now = new Date();
  if (minAge != null) {
    const lte = new Date(now);
    lte.setFullYear(lte.getFullYear() - minAge);
    cond.lte = lte;
  }
  if (maxAge != null) {
    const gte = new Date(now);
    gte.setFullYear(gte.getFullYear() - maxAge);
    cond.gte = gte;
  }
  return cond;
}

@Injectable()
export class ListenersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly appSettings: AppSettingsService,
  ) {}

  /** Dinleyen başına kısa süreli önbellek — keşif sayfası tekrarlarında DB yükünü keser. */
  private readonly replyPaceCache = new Map<
    string,
    { storedAtMs: number; pace: BrowseReplyPace | null }
  >();

  /**
   * Birebir dinleyen listesi. İsteği yapan kullanıcının profilindeki `moodCategory`
   * ile eşleşen dinleyenler (aynı `supportCategories` veya boş kategori = genel).
   * Sayfa boyutu en fazla 30. Grup odaları bu endpoint ile ilgili değildir.
   */
  async browse(params: {
    filter: BrowseFilter;
    seekerUserId: string;
    moodQuery?: string;
    page: number;
    q?: string;
    minAge?: number;
    maxAge?: number;
    gender?: Gender;
  }) {
    const page = Math.max(1, params.page);
    const seeker = await this.prisma.user.findUnique({
      where: { id: params.seekerUserId },
      select: { profile: { select: { moodCategory: true } } },
    });

    let mood: SupportCategory | null = seeker?.profile?.moodCategory ?? null;
    /** `mood=all` → profil ruh hali filtresi uygulanmaz (ana sayfa “tüm dinleyenler”). */
    if (params.moodQuery === 'all') {
      mood = null;
    } else if (
      params.moodQuery != null &&
      params.moodQuery !== '' &&
      (Object.values(SupportCategory) as string[]).includes(params.moodQuery)
    ) {
      mood = params.moodQuery as SupportCategory;
    }

    const profileParts: Prisma.ListenerProfileWhereInput[] = [];
    if (params.filter === 'ready') {
      profileParts.push(listenerProfileReadyWhere());
    }
    if (mood) {
      profileParts.push({
        OR: [
          { supportCategories: { has: mood } },
          { supportCategories: { isEmpty: true } },
        ],
      });
    }

    const listenerProfileWhere: Prisma.UserWhereInput['listenerProfile'] =
      profileParts.length === 0
        ? { isNot: null }
        : profileParts.length === 1
          ? { is: profileParts[0] }
          : { is: { AND: profileParts } };
    const approvedWhere: Prisma.UserWhereInput = {
      role: 'approved_listener',
      status: 'active',
      listenerProfile: listenerProfileWhere,
    };
    const applicantWhere: Prisma.UserWhereInput = {
      role: 'listener_applicant',
      status: 'active',
      listenerApplication: { isNot: null },
    };
    const where: Prisma.UserWhereInput =
      params.filter === 'ready'
        ? approvedWhere
        : { OR: [approvedWhere, applicantWhere] };

    const qTrim = params.q?.trim() ?? '';
    const ageWhere = birthDateWhereFromAgeRange(
      params.minAge,
      params.maxAge,
    );
    const extraAnd: Prisma.UserWhereInput[] = [
      {
        OR: [
          { discoverListing: null },
          { discoverListing: { is: { visibleInDiscover: true } } },
        ],
      },
    ];
    if (qTrim.length > 0) {
      extraAnd.push({
        profile: {
          displayName: { contains: qTrim, mode: 'insensitive' },
        },
      });
    }
    if (params.gender != null) {
      extraAnd.push({ gender: params.gender });
    }
    if (ageWhere != null) {
      extraAnd.push({ birthDate: ageWhere });
    }

    const pinnedEmail = resolvePinnedListenerEmail(this.config);
    const pinnedRow =
      pinnedEmail != null
        ? await this.prisma.user.findFirst({
            where: {
              email: { equals: pinnedEmail, mode: 'insensitive' },
              status: 'active',
              listenerProfile: { isNot: null },
              role: { in: ['approved_listener', 'admin'] },
              OR: [
                { discoverListing: null },
                { discoverListing: { is: { visibleInDiscover: true } } },
              ],
            },
            select: browseSelect,
          })
        : null;

    const hasDemographicOrSearch =
      qTrim.length > 0 ||
      params.gender != null ||
      ageWhere != null;

    const usePin =
      pinnedRow != null &&
      pinnedRow.id !== params.seekerUserId &&
      !hasDemographicOrSearch;

    let listWhere: Prisma.UserWhereInput = usePin
      ? { AND: [where, { id: { not: pinnedRow.id } }] }
      : where;
    if (extraAnd.length > 0) {
      listWhere = { AND: [listWhere, ...extraAnd] };
    }

    const baseTotal = await this.prisma.user.count({ where: listWhere });
    const total = usePin ? baseTotal + 1 : baseTotal;

    const virtualOffset = (page - 1) * PAGE_SIZE;
    let rows: BrowseRow[];

    if (usePin && virtualOffset === 0) {
      rows = await this.prisma.user.findMany({
        where: listWhere,
        select: browseSelect,
        orderBy: { id: 'asc' },
        skip: 0,
        take: PAGE_SIZE - 1,
      });
    } else if (usePin) {
      const mainSkip = virtualOffset - 1;
      rows = await this.prisma.user.findMany({
        where: listWhere,
        select: browseSelect,
        orderBy: { id: 'asc' },
        skip: mainSkip,
        take: PAGE_SIZE,
      });
    } else {
      rows = await this.prisma.user.findMany({
        where: listWhere,
        select: browseSelect,
        orderBy: { id: 'asc' },
        skip: virtualOffset,
        take: PAGE_SIZE,
      });
    }

    const mapRow = (u: BrowseRow) => {
      const lp = u.listenerProfile;
      const displayName =
        u.profile?.displayName?.trim() ||
        `Dinleyen ${u.id.replace(/-/g, '').slice(0, 8)}`;
      const o = lp?.presenceOverride;
      const effectiveOnline =
        o === 'force_offline'
          ? false
          : o === 'force_online'
            ? true
            : (lp?.isOnline ?? false);
      return {
        userId: u.id,
        displayName,
        accountKind: u.role,
        recognitionLabels: lp?.adminRecognitionLabels ?? [],
        ratingAvg: Number(lp?.ratingAvg ?? 0),
        ratingCount: lp?.ratingCount ?? 0,
        supportCategories: lp?.supportCategories ?? [],
        isOnline: effectiveOnline,
        isAvailable: lp?.isAvailable ?? false,
        availabilityMode: lp?.availabilityMode ?? null,
        gender: u.gender,
        age: u.birthDate != null ? ageFromBirthDate(u.birthDate) : null,
        pinned: false as boolean,
      };
    };

    let items = rows.map((u) => mapRow(u));
    if (usePin && virtualOffset === 0) {
      const pinnedItem = {
        ...mapRow(pinnedRow),
        pinned: true,
      };
      items.unshift(pinnedItem);
    }

    items = await this.attachReplyPaces(items);

    return {
      items,
      page,
      pageSize: PAGE_SIZE,
      total,
      moodFilter: mood,
    };
  }

  private async attachReplyPaces<
    T extends { userId: string },
  >(items: T[]): Promise<Array<T & { replyPace: BrowseReplyPace | null }>> {
    if (items.length === 0) return [];
    const paceMap = await this.batchReplyPace(items.map((i) => i.userId));
    return items.map((it) => ({
      ...it,
      replyPace: paceMap.get(it.userId) ?? null,
    }));
  }

  /** Admin eşik değişince eski rozetleri düşürmek için. */
  clearReplyPaceCache(): void {
    this.replyPaceCache.clear();
  }

  /** Sayfadaki dinleyen id’leri için okunmamış önbelleği atlayarak hesaplar. */
  private async batchReplyPace(
    ids: string[],
  ): Promise<Map<string, BrowseReplyPace | null>> {
    const thresholds = await this.appSettings.getReplyPaceThresholdsSec();
    const out = new Map<string, BrowseReplyPace | null>();
    const uncached: string[] = [];
    const now = Date.now();
    for (const id of ids) {
      const hit = this.replyPaceCache.get(id);
      if (hit && now - hit.storedAtMs < REPLY_PACE_CACHE_MS) {
        out.set(id, hit.pace);
      } else {
        uncached.push(id);
      }
    }
    const chunkSize = 6;
    for (let i = 0; i < uncached.length; i += chunkSize) {
      const chunk = uncached.slice(i, i + chunkSize);
      const computed = await Promise.all(
        chunk.map((id) =>
          this.computeReplyPaceUncached(id, thresholds),
        ),
      );
      for (let j = 0; j < chunk.length; j++) {
        const pace = computed[j];
        this.replyPaceCache.set(chunk[j], {
          storedAtMs: Date.now(),
          pace,
        });
        out.set(chunk[j], pace);
      }
    }
    return out;
  }

  /**
   * Son oturumlardaki mesajlardan: karşı mesaja verilen yanıtların gecikmesi.
   * En güncel 10 yanıt olayının medyan gecikmesine göre kademe üretir.
   */
  private async computeReplyPaceUncached(
    listenerId: string,
    thresholds: ReplyPaceThresholdsSec,
  ): Promise<BrowseReplyPace | null> {
    const sessions = await this.prisma.session.findMany({
      where: {
        status: { not: 'cancelled' },
        OR: [{ listenerId }, { requesterId: listenerId }],
      },
      select: { id: true },
      orderBy: { updatedAt: 'desc' },
      take: REPLY_PACE_SESSIONS_SCAN,
    });
    if (sessions.length === 0) return null;

    const sessionIds = sessions.map((s) => s.id);
    const msgs = await this.prisma.message.findMany({
      where: { sessionId: { in: sessionIds } },
      select: {
        sessionId: true,
        senderId: true,
        createdAt: true,
        messageType: true,
      },
      orderBy: [{ sessionId: 'asc' }, { createdAt: 'asc' }],
    });

    const bySession = new Map<
      string,
      Array<{ senderId: string; createdAt: Date; messageType: MessageType }>
    >();
    for (const m of msgs) {
      const arr = bySession.get(m.sessionId) ?? [];
      arr.push(m);
      bySession.set(m.sessionId, arr);
    }

    type Ev = { replyAt: number; delaySec: number };
    const events: Ev[] = [];

    for (const sid of sessionIds) {
      const row = bySession.get(sid);
      if (!row || row.length < 2) continue;
      for (let i = 0; i < row.length - 1; i++) {
        if (row[i].senderId === listenerId) continue;
        if (row[i].messageType === MessageType.system) continue;
        for (let j = i + 1; j < row.length; j++) {
          if (row[j].senderId === listenerId) {
            const delaySec =
              (row[j].createdAt.getTime() - row[i].createdAt.getTime()) / 1000;
            if (delaySec >= 0 && delaySec <= REPLY_PACE_MAX_PAIR_SEC) {
              events.push({
                replyAt: row[j].createdAt.getTime(),
                delaySec,
              });
            }
            break;
          }
        }
      }
    }

    events.sort((a, b) => b.replyAt - a.replyAt);
    const slice = events.slice(0, REPLY_PACE_RECENT_EVENTS);
    if (slice.length < REPLY_PACE_MIN_SAMPLES) return null;

    const delays = slice.map((e) => e.delaySec).sort((a, b) => a - b);
    const median = this.medianFromSorted(delays);
    return this.tierFromMedianSeconds(median, thresholds);
  }

  private medianFromSorted(nums: number[]): number {
    if (nums.length === 0) return 0;
    const mid = Math.floor(nums.length / 2);
    return nums.length % 2 === 1
      ? nums[mid]
      : (nums[mid - 1] + nums[mid]) / 2;
  }

  private tierFromMedianSeconds(
    sec: number,
    t: ReplyPaceThresholdsSec,
  ): BrowseReplyPace {
    if (sec <= t.spark) return 'spark';
    if (sec <= t.swift) return 'swift';
    if (sec <= t.warm) return 'warm';
    return 'easy';
  }

  /**
   * Müsait / çevrimiçi dinleyenler arasından, gezginin ruh haline uygun olanlardan
   * rastgele bir `user.id` döner.
   * Sabitlenmiş admin dinleyen uygunsa havuza dahildir.
   */
  async pickRandomListenerId(seekerUserId: string): Promise<string | null> {
    const seeker = await this.prisma.user.findUnique({
      where: { id: seekerUserId },
      select: { profile: { select: { moodCategory: true } } },
    });

    const mood = seeker?.profile?.moodCategory ?? null;

    const availability = listenerProfileReadyWhere();

    const listenerProfileWhere: Prisma.UserWhereInput['listenerProfile'] =
      mood != null
        ? {
            is: {
              AND: [
                availability,
                {
                  OR: [
                    { supportCategories: { has: mood } },
                    { supportCategories: { isEmpty: true } },
                  ],
                },
              ],
            },
          }
        : { is: availability };

    const pinnedEmail = resolvePinnedListenerEmail(this.config);

    const approvedWhere: Prisma.UserWhereInput = {
      id: { not: seekerUserId },
      status: 'active',
      role: 'approved_listener',
      listenerProfile: listenerProfileWhere,
    };

    const orBranches: Prisma.UserWhereInput[] = [approvedWhere];
    if (pinnedEmail != null) {
      orBranches.push({
        id: { not: seekerUserId },
        status: 'active',
        role: 'admin',
        email: { equals: pinnedEmail, mode: 'insensitive' },
        listenerProfile: listenerProfileWhere,
      });
    }

    const rows = await this.prisma.user.findMany({
      where: orBranches.length === 1 ? orBranches[0] : { OR: orBranches },
      select: { id: true },
    });

    if (rows.length === 0) return null;

    for (let i = rows.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [rows[i], rows[j]] = [rows[j], rows[i]];
    }

    return rows[0].id;
  }
}
