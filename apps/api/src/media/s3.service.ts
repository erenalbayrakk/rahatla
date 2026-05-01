import { randomUUID } from 'node:crypto';
import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';

@Injectable()
export class S3Service {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicBaseUrl?: string;

  constructor(private readonly config: ConfigService) {
    const region = this.config.get<string>('S3_REGION') ?? 'auto';
    const endpoint = this.config.get<string>('S3_ENDPOINT');
    const accessKeyId = this.config.get<string>('S3_ACCESS_KEY_ID');
    const secretAccessKey = this.config.get<string>('S3_SECRET_ACCESS_KEY');
    const bucket = this.config.get<string>('S3_BUCKET');
    if (!endpoint || !accessKeyId || !secretAccessKey || !bucket) {
      throw new Error(
        'S3 config eksik: S3_ENDPOINT, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_BUCKET gerekli.',
      );
    }
    this.bucket = bucket;
    this.publicBaseUrl = this.config.get<string>('S3_PUBLIC_BASE_URL');
    this.client = new S3Client({
      region,
      endpoint,
      forcePathStyle: true,
      credentials: { accessKeyId, secretAccessKey },
    });
  }

  async uploadChatImage(params: {
    buffer: Buffer;
    mimeType: string;
    uploaderId: string;
  }) {
    const ext = this.extensionForMime(params.mimeType);
    const key = `chat-images/${params.uploaderId}/${Date.now()}-${randomUUID()}.${ext}`;
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: params.buffer,
        ContentType: params.mimeType,
      }),
    );
    return { key, url: this.publicUrlFor(key) };
  }

  async uploadProfileImage(params: {
    buffer: Buffer;
    mimeType: string;
    userId: string;
  }) {
    const ext = this.extensionForMime(params.mimeType);
    const key = `profile-images/${params.userId}/${Date.now()}-${randomUUID()}.${ext}`;
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: params.buffer,
        ContentType: params.mimeType,
      }),
    );
    return { key, url: this.publicUrlFor(key) };
  }

  async uploadVerifySelfie(params: {
    buffer: Buffer;
    mimeType: string;
    userId: string;
  }) {
    const ext = this.extensionForMime(params.mimeType);
    const key = `verify-selfies/${params.userId}/${Date.now()}-${randomUUID()}.${ext}`;
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: params.buffer,
        ContentType: params.mimeType,
      }),
    );
    return { key, url: this.publicUrlFor(key) };
  }

  private extensionForMime(mimeType: string): string {
    switch (mimeType) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        throw new InternalServerErrorException('Desteklenmeyen görsel türü');
    }
  }

  private publicUrlFor(key: string): string {
    if (this.publicBaseUrl && this.publicBaseUrl.trim() !== '') {
      return `${this.publicBaseUrl.replace(/\/+$/, '')}/${key}`;
    }
    const endpoint = this.config
      .getOrThrow<string>('S3_ENDPOINT')
      .replace(/\/+$/, '');
    return `${endpoint}/${this.bucket}/${key}`;
  }
}
