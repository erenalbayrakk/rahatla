/**
 * gender = female olan tüm kullanıcıların doğum tarihini,
 * bugün itibarıyla yaşları 26 olacak şekilde ayarlar.
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

function birthDateForAge(years) {
  const d = new Date();
  d.setHours(12, 0, 0, 0);
  d.setFullYear(d.getFullYear() - years);
  return d;
}

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url || typeof url !== 'string') {
    throw new Error('DATABASE_URL tanımlı değil.');
  }

  const prisma = new PrismaClient({
    adapter: new PrismaPg(url),
  });

  const birthDate = birthDateForAge(26);

  const res = await prisma.user.updateMany({
    where: { gender: 'female' },
    data: { birthDate },
  });

  console.log(`female: ${res.count} kullanıcı — birthDate → 26 yaş (referans: ${birthDate.toISOString().slice(0, 10)})`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
