-- AlterEnum
ALTER TYPE "MessageType" ADD VALUE IF NOT EXISTS 'image';

-- AlterTable
ALTER TABLE "messages" ADD COLUMN "image_url" TEXT;

-- AlterTable
ALTER TABLE "group_chat_messages" ADD COLUMN "image_url" TEXT;
