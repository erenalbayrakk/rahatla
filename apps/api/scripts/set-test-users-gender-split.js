/**
 * E-posta veya görünen adda "test" geçen kullanıcılar:
 * sıralı listede ilk yarısı female, kalanı male.
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url || typeof url !== 'string') {
    throw new Error('DATABASE_URL tanımlı değil.');
  }

  const prisma = new PrismaClient({
    adapter: new PrismaPg(url),
  });

  const users = await prisma.user.findMany({
    where: {
      OR: [
        { email: { contains: 'test', mode: 'insensitive' } },
        {
          profile: {
            displayName: { contains: 'test', mode: 'insensitive' },
          },
        },
      ],
    },
    select: { id: true, email: true },
    orderBy: { id: 'asc' },
  });

  const n = users.length;
  if (n === 0) {
    console.log('Eşleşen kullanıcı yok (e-posta veya görünen adda "test").');
    await prisma.$disconnect();
    return;
  }

  const half = Math.floor(n / 2);
  const femaleIds = users.slice(0, half).map((u) => u.id);
  const maleIds = users.slice(half).map((u) => u.id);

  await prisma.$transaction([
    ...femaleIds.map((id) =>
      prisma.user.update({
        where: { id },
        data: { gender: 'female' },
      }),
    ),
    ...maleIds.map((id) =>
      prisma.user.update({
        where: { id },
        data: { gender: 'male' },
      }),
    ),
  ]);

  console.log(`Toplam ${n} kullanıcı güncellendi:`);
  console.log(`  Kadın (female): ${femaleIds.length}`);
  console.log(`  Erkek (male): ${maleIds.length}`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
