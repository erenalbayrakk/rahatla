CREATE TABLE "session_gifts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "session_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "gift_code" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "session_gifts_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "session_gifts_session_id_created_at_idx" ON "session_gifts"("session_id", "created_at");

ALTER TABLE "session_gifts" ADD CONSTRAINT "session_gifts_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "session_gifts" ADD CONSTRAINT "session_gifts_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
