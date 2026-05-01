# NestJS API — tek aşama (Prisma engine + migrate için tam node_modules)
FROM node:20-bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
COPY prisma ./prisma/
COPY docker-entrypoint.sh ./
RUN npm ci

COPY . .
# COPY . . host dosyasını tekrar kopyalar; +x kaybolabiliyor (özellikle Windows/Git).
RUN chmod +x docker-entrypoint.sh
RUN npx prisma generate && npm run build

ENV NODE_ENV=production
EXPOSE 3000
# Doğrudan çalıştırma izni olmasa bile sh ile giriş (OCI "permission denied" önlemi)
ENTRYPOINT ["/bin/sh", "/app/docker-entrypoint.sh"]
