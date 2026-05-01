-- AlterTable
ALTER TABLE "profiles" ADD COLUMN "profile_image_urls" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
