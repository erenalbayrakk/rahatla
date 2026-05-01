-- CreateEnum
CREATE TYPE "ListenerPresenceOverride" AS ENUM ('auto', 'force_online', 'force_offline');

-- AlterTable
ALTER TABLE "listener_profiles" ADD COLUMN "presence_override" "ListenerPresenceOverride" NOT NULL DEFAULT 'auto';
