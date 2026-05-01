import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSupportRequestDto } from './dto/create-support-request.dto';

@Injectable()
export class SupportRequestsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(requesterId: string, dto: CreateSupportRequestDto) {
    return this.prisma.supportRequest.create({
      data: {
        requesterId,
        category: dto.category,
        languageCode: dto.languageCode,
        communicationPreference: dto.communicationPreference,
        requesterNote:
          dto.note != null && dto.note.trim() !== '' ? dto.note.trim() : null,
        status: 'queued',
      },
      select: {
        id: true,
        requesterId: true,
        category: true,
        languageCode: true,
        communicationPreference: true,
        requesterNote: true,
        status: true,
        createdAt: true,
      },
    });
  }
}
