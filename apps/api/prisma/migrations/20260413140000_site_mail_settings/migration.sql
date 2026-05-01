-- CreateTable
CREATE TABLE "site_mail_settings" (
    "id" TEXT NOT NULL,
    "smtp_host" TEXT,
    "smtp_port" INTEGER,
    "smtp_secure" BOOLEAN,
    "smtp_user" TEXT,
    "mail_from" TEXT,
    "app_public_api_url" TEXT,
    "provider_docs_url" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "site_mail_settings_pkey" PRIMARY KEY ("id")
);
