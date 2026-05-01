-- CreateEnum
CREATE TYPE "VerifySelfieStatus" AS ENUM ('none', 'pending', 'approved', 'rejected');

-- AlterTable
ALTER TABLE "profiles" ADD COLUMN     "verify_selfie_reject_reason" TEXT,
ADD COLUMN     "verify_selfie_reviewed_at" TIMESTAMP(3),
ADD COLUMN     "verify_selfie_reviewed_by" UUID,
ADD COLUMN     "verify_selfie_status" "VerifySelfieStatus" NOT NULL DEFAULT 'none',
ADD COLUMN     "verify_selfie_submitted_at" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "session_gifts" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "site_mail_settings" ALTER COLUMN "id" SET DEFAULT 'default';
