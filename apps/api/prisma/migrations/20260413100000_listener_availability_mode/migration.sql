-- CreateEnum
CREATE TYPE "ListenerAvailabilityMode" AS ENUM ('available', 'automatic', 'busy');

-- AlterTable
ALTER TABLE "listener_profiles" ADD COLUMN "availability_mode" "ListenerAvailabilityMode" NOT NULL DEFAULT 'available';
