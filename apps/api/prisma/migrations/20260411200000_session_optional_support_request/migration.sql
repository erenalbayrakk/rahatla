-- Allow sessions opened from listener browse without a support_request row
ALTER TABLE "sessions" ALTER COLUMN "support_request_id" DROP NOT NULL;
