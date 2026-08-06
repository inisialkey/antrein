import { Module } from '@nestjs/common';
import { FilesModule } from '../files/files.module';
import { MembershipsModule } from '../memberships/memberships.module';
import { MeController } from './me.controller';
import { UsersService } from './users.service';

@Module({
  imports: [MembershipsModule, FilesModule],
  controllers: [MeController],
  providers: [UsersService],
})
export class UsersModule {}
