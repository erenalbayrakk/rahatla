ALTER TABLE "listener_profiles"
ADD COLUMN "admin_recognition_labels" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
