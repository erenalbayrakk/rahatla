-- CreateEnum
CREATE TYPE "GroupChatRoomStatus" AS ENUM ('open', 'closed');

-- CreateEnum
CREATE TYPE "GroupChatParticipantRole" AS ENUM ('member', 'listener', 'moderator');

-- AlterTable
ALTER TABLE "messages" ADD COLUMN "client_message_id" TEXT,
ADD COLUMN "delivered_at" TIMESTAMP(3),
ADD COLUMN "read_at" TIMESTAMP(3);

-- CreateIndex
CREATE UNIQUE INDEX "messages_session_id_client_message_id_key" ON "messages"("session_id", "client_message_id");

-- CreateTable
CREATE TABLE "group_chat_rooms" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "status" "GroupChatRoomStatus" NOT NULL DEFAULT 'open',
    "created_by_id" UUID NOT NULL,
    "closed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "group_chat_rooms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "group_chat_participants" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "GroupChatParticipantRole" NOT NULL,
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "left_at" TIMESTAMP(3),
    "removed_reason" TEXT,

    CONSTRAINT "group_chat_participants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "group_chat_messages" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "message_type" "MessageType" NOT NULL DEFAULT 'text',
    "content" TEXT,
    "client_message_id" TEXT,
    "delivered_at" TIMESTAMP(3),
    "read_at" TIMESTAMP(3),
    "hidden_by_moderation" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_chat_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "group_chat_messages_room_id_client_message_id_key" ON "group_chat_messages"("room_id", "client_message_id");

-- CreateIndex
CREATE INDEX "group_chat_messages_room_id_created_at_idx" ON "group_chat_messages"("room_id", "created_at");

-- CreateIndex
CREATE INDEX "group_chat_participants_user_id_left_at_idx" ON "group_chat_participants"("user_id", "left_at");

-- CreateIndex
CREATE UNIQUE INDEX "group_chat_participants_room_id_user_id_key" ON "group_chat_participants"("room_id", "user_id");

-- AddForeignKey
ALTER TABLE "group_chat_rooms" ADD CONSTRAINT "group_chat_rooms_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_chat_participants" ADD CONSTRAINT "group_chat_participants_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "group_chat_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_chat_participants" ADD CONSTRAINT "group_chat_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_chat_messages" ADD CONSTRAINT "group_chat_messages_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "group_chat_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_chat_messages" ADD CONSTRAINT "group_chat_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
