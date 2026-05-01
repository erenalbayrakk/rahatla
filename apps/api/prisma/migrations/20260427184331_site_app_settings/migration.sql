-- CreateTable
CREATE TABLE "site_app_settings" (
    "id" TEXT NOT NULL DEFAULT 'default',
    "reply_spark_max_seconds" INTEGER NOT NULL DEFAULT 300,
    "reply_swift_max_seconds" INTEGER NOT NULL DEFAULT 1800,
    "reply_warm_max_seconds" INTEGER NOT NULL DEFAULT 21600,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "site_app_settings_pkey" PRIMARY KEY ("id")
);
