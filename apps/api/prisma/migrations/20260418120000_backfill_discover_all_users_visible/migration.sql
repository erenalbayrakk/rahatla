-- Tabloda satırı olmayan tüm kullanıcıları keşfet tablosuna ekle (görünür).
INSERT INTO "discover_listings" ("user_id", "visible_in_discover", "created_at", "updated_at")
SELECT "u"."id", true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "users" AS "u"
WHERE NOT EXISTS (
  SELECT 1 FROM "discover_listings" AS "d" WHERE "d"."user_id" = "u"."id"
);

-- Mevcut tüm satırlarda keşfet görünürlüğünü true yap.
UPDATE "discover_listings"
SET "visible_in_discover" = true,
    "updated_at" = CURRENT_TIMESTAMP;
