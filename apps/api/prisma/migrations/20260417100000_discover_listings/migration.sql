-- CreateTable
CREATE TABLE "discover_listings" (
    "user_id" UUID NOT NULL,
    "visible_in_discover" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "discover_listings_pkey" PRIMARY KEY ("user_id")
);

-- AddForeignKey
ALTER TABLE "discover_listings" ADD CONSTRAINT "discover_listings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: mevcut kullanıcılar keşfette görünür (varsayılan)
INSERT INTO "discover_listings" ("user_id", "visible_in_discover", "created_at", "updated_at")
SELECT "id", true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM "users";
