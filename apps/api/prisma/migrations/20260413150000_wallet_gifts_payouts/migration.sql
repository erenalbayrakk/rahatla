-- CreateEnum
CREATE TYPE "WalletLedgerType" AS ENUM ('gift_sent', 'gift_received', 'topup', 'admin_credit', 'admin_debit', 'payout_hold', 'payout_refund');

-- CreateEnum
CREATE TYPE "PayoutRequestStatus" AS ENUM ('pending', 'paid', 'rejected');

-- CreateTable
CREATE TABLE "gift_catalog_items" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "price_minor" INTEGER NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gift_catalog_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_wallets" (
    "user_id" UUID NOT NULL,
    "balance_minor" INTEGER NOT NULL DEFAULT 0,
    "currency" TEXT NOT NULL DEFAULT 'TRY',
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_wallets_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "wallet_ledger_entries" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "amount_minor" INTEGER NOT NULL,
    "type" "WalletLedgerType" NOT NULL,
    "reference_type" TEXT,
    "reference_id" UUID,
    "idempotency_key" TEXT,
    "meta_json" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallet_ledger_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payout_requests" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "amount_minor" INTEGER NOT NULL,
    "iban" TEXT NOT NULL,
    "status" "PayoutRequestStatus" NOT NULL DEFAULT 'pending',
    "admin_note" TEXT,
    "processed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payout_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "gift_catalog_items_code_key" ON "gift_catalog_items"("code");

-- CreateIndex
CREATE UNIQUE INDEX "wallet_ledger_entries_idempotency_key_key" ON "wallet_ledger_entries"("idempotency_key");

-- CreateIndex
CREATE INDEX "wallet_ledger_entries_user_id_created_at_idx" ON "wallet_ledger_entries"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "payout_requests_user_id_status_idx" ON "payout_requests"("user_id", "status");

-- AddForeignKey
ALTER TABLE "user_wallets" ADD CONSTRAINT "user_wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_ledger_entries" ADD CONSTRAINT "wallet_ledger_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payout_requests" ADD CONSTRAINT "payout_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AlterTable
ALTER TABLE "session_gifts" ADD COLUMN "price_minor" INTEGER,
ADD COLUMN "recipient_earned_minor" INTEGER,
ADD COLUMN "platform_fee_minor" INTEGER;

-- Seed gift catalog (100 minor units each)
INSERT INTO "gift_catalog_items" ("id", "code", "label", "price_minor", "active", "sort_order", "created_at", "updated_at")
VALUES
  (gen_random_uuid(), 'thanks', 'Teşekkür', 100, true, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'warm_hug', 'Sıcak sarılma', 100, true, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'coffee', 'Kahve', 100, true, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'star', 'Yıldız', 100, true, 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'flower', 'Çiçek', 100, true, 4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;
