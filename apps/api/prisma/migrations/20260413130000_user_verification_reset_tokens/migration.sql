-- AlterTable
ALTER TABLE "users" ADD COLUMN "email_verification_token" TEXT,
ADD COLUMN "email_verification_expires" TIMESTAMP(3),
ADD COLUMN "password_reset_token" TEXT,
ADD COLUMN "password_reset_expires" TIMESTAMP(3);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_verification_token_key" ON "users"("email_verification_token");

-- CreateIndex
CREATE UNIQUE INDEX "users_password_reset_token_key" ON "users"("password_reset_token");
