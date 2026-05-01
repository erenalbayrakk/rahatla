import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { AppModule } from './app.module';
import { SocketIoAdapter } from './realtime/socket-io.adapter';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  const httpLog = new Logger('HTTP');

  app.useWebSocketAdapter(new SocketIoAdapter(app));

  const adminPanelPath = join(process.cwd(), 'admin-panel');
  app.useStaticAssets(adminPanelPath, { prefix: '/admin-panel/' });

  app.use(
    (req: { method: string; url: string }, _res: unknown, next: () => void) => {
      httpLog.log(`${req.method} ${req.url}`);
      next();
    },
  );

  app.enableCors({ origin: true, credentials: true });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port, '0.0.0.0');
}
void bootstrap();
