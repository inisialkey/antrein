import { Module } from '@nestjs/common';
import { MembershipsModule } from '../memberships/memberships.module';
import { MeController } from './me.controller';
import { UsersService } from './users.service';

@Module({
  imports: [MembershipsModule],
  controllers: [MeController],
  providers: [UsersService],
})
export class UsersModule {}
