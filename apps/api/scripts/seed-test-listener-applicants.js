/**
 * Onay bekleyen dinleyen adayı test kullanıcıları: test1..test40 / testN@test.com
 * Şifre: 12345678 | E-posta doğrulaması: kapalı (is_verified = false)
 *
 * Çalıştır: npm run seed:test-listener-applicants  (apps/api, DATABASE_URL gerekli)
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url || typeof url !== 'string') {
    throw new Error('DATABASE_URL tanımlı değil (.env içinde).');
  }

  const prisma = new PrismaClient({
    adapter: new PrismaPg(url),
  });

  const passwordHash = await bcrypt.hash('12345678', 10);
  let created = 0;
  let skipped = 0;

  for (let n = 1; n <= 40; n++) {
    const email = `test${n}@test.com`;
    const displayName = `test${n}`;

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      skipped += 1;
      console.log(`atlandı (zaten var): ${email}`);
      continue;
    }

    await prisma.user.create({
      data: {
        email,
        passwordHash,
        role: 'listener_applicant',
        isVerified: false,
        profile: {
          create: {
            displayName,
            preferredLanguage: 'tr',
          },
        },
        listenerApplication: {
          create: {
            motivationText: `Test dinleyen başvurusu (${displayName})`,
            supportStyles: ['empatik_dinleme'],
            communicationTypes: ['text_chat'],
            availabilityJson: {},
          },
        },
      },
    });
    created += 1;
    console.log(`oluşturuldu: ${email} (${displayName})`);
  }

  await prisma.$disconnect();
  console.log(`\nÖzet: ${created} yeni, ${skipped} atlandı.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
