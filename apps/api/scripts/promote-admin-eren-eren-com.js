/**
 * Tek seferlik: eren@eren.com → admin, şifre ammahmut (min 8 karakter).
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const EMAIL = 'eren@eren.com';
const DISPLAY_NAME = 'ammahmut';
const PASSWORD = 'ammahmut';

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url || typeof url !== 'string') {
    throw new Error('DATABASE_URL tanımlı değil.');
  }

  const prisma = new PrismaClient({
    adapter: new PrismaPg(url),
  });

  const email = EMAIL.trim().toLowerCase();
  const passwordHash = await bcrypt.hash(PASSWORD, 10);

  const existing = await prisma.user.findUnique({
    where: { email },
    select: { id: true },
  });

  if (existing) {
    await prisma.user.update({
      where: { email },
      data: {
        role: 'admin',
        passwordHash,
        status: 'active',
      },
    });
    await prisma.profile.upsert({
      where: { userId: existing.id },
      create: {
        userId: existing.id,
        displayName: DISPLAY_NAME,
        preferredLanguage: 'tr',
      },
      update: { displayName: DISPLAY_NAME },
    });
    console.log('Güncellendi: admin rolü + şifre + görünen ad.');
  } else {
    await prisma.user.create({
      data: {
        email,
        passwordHash,
        role: 'admin',
        status: 'active',
        isVerified: false,
        profile: {
          create: {
            displayName: DISPLAY_NAME,
            preferredLanguage: 'tr',
          },
        },
      },
    });
    console.log('Oluşturuldu: yeni admin kullanıcı.');
  }

  console.log(`E-posta: ${email}`);
  console.log(`Görünen ad: ${DISPLAY_NAME}`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
