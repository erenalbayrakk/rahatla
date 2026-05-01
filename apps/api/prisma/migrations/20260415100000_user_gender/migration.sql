-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('female', 'male', 'non_binary', 'prefer_not_to_say');

-- AlterTable
ALTER TABLE "users" ADD COLUMN "gender" "Gender";
