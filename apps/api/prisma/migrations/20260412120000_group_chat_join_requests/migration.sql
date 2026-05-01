-- CreateEnum
CREATE TYPE "GroupChatJoinRequestStatus" AS ENUM ('pending', 'approved', 'rejected');

-- CreateTable
CREATE TABLE "group_chat_join_requests" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "GroupChatJoinRequestStatus" NOT NULL DEFAULT 'pending',
    "message" VARCHAR(500),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by_id" UUID,

    CONSTRAINT "group_chat_join_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "group_chat_join_requests_room_id_status_idx" ON "group_chat_join_requests"("room_id", "status");

-- CreateIndex
CREATE INDEX "group_chat_join_requests_user_id_status_idx" ON "group_chat_join_requests"("user_id", "status");

-- AddForeignKey
ALTER TABLE "group_chat_join_requests" ADD CONSTRAINT "group_chat_join_requests_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "group_chat_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_chat_join_requests" ADD CONSTRAINT "group_chat_join_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_chat_join_requests" ADD CONSTRAINT "group_chat_join_requests_reviewed_by_id_fkey" FOREIGN KEY ("reviewed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
