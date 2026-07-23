import { Controller, Get, Res } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { Response } from 'express';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Public } from '../auth/public.decorator';

type CheckState = 'up' | 'down';

@Public()
@ApiExcludeController()
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('live')
  live(): { status: string; timestamp: string } {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  @Get('ready')
  async ready(@Res() res: Response): Promise<void> {
    const database = await this.checkDatabase();
    const migrations = database === 'up' ? await this.checkMigrations() : 'down';
    const healthy = database === 'up' && migrations === 'up';

    res.status(healthy ? 200 : 503).json({
      status: healthy ? 'ready' : 'unavailable',
      checks: { database, migrations },
      timestamp: new Date().toISOString(),
    });
  }

  private async checkDatabase(): Promise<CheckState> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return 'up';
    } catch {
      return 'down';
    }
  }

  private async checkMigrations(): Promise<CheckState> {
    try {
      const [row] = await this.prisma.$queryRaw<[{ applied: bigint; pending: bigint }]>`
        SELECT
          count(*) FILTER (WHERE finished_at IS NOT NULL) AS applied,
          count(*) FILTER (WHERE finished_at IS NULL AND rolled_back_at IS NULL) AS pending
        FROM _prisma_migrations`;
      return Number(row.applied) > 0 && Number(row.pending) === 0 ? 'up' : 'down';
    } catch {
      return 'down';
    }
  }
}
