import { Logger } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';
import type { Server, ServerOptions } from 'socket.io';

/**
 * Socket.IO Redis adapter (realtime-queue §50, lifts the ADR 0030/0035
 * deferral): pub/sub fan-out so `/realtime` rooms span API instances. Redis
 * carries no authoritative state — if it is down at boot the caller falls back
 * to the in-memory adapter (single-instance delivery still works, REST always
 * recovers) and logs loudly so alerts fire.
 */
export class RedisIoAdapter extends IoAdapter {
  private static readonly logger = new Logger(RedisIoAdapter.name);
  private adapterConstructor: ReturnType<typeof createAdapter> | null = null;

  async connectToRedis(url: string): Promise<void> {
    const pubClient = createClient({ url });
    const subClient = pubClient.duplicate();
    pubClient.on('error', (error: Error) =>
      RedisIoAdapter.logger.error(`Redis pub client error: ${error.message}`),
    );
    subClient.on('error', (error: Error) =>
      RedisIoAdapter.logger.error(`Redis sub client error: ${error.message}`),
    );
    await Promise.all([pubClient.connect(), subClient.connect()]);
    this.adapterConstructor = createAdapter(pubClient, subClient);
  }

  override createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, options) as Server;
    if (this.adapterConstructor) server.adapter(this.adapterConstructor);
    return server;
  }
}
