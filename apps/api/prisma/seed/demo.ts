/**
 * Demo data for a deployed environment (product brief §31 M9 "seed and demo
 * data"). Never runs automatically: `npm run seed:demo`, or against the VPS
 * database over the SSH tunnel described in docs/ops/runbook.md.
 *
 * Idempotent — every row is keyed on a natural unique (email, slug, day of
 * week…), so re-running refreshes the demo instead of duplicating it.
 *
 * Catalog, staff and schedules only: bookings, payments and queue entries are
 * created by walking the app, which is the demo. Seeding them by hand would
 * mean hand-writing reservation ranges and payment rows that the booking
 * transaction owns.
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { newId } from '../../src/common/id/id';
import { PrismaClient } from '../../src/generated/prisma/client';
import { normalizeEmail } from '../../src/modules/auth/auth.policies';
import { PasswordHasher } from '../../src/modules/auth/password.hasher';
import { slugify } from '../../src/modules/businesses/slug';
import {
  OWNER_PERMISSIONS,
  ROLE_DEFAULT_PERMISSIONS,
} from '../../src/modules/memberships/permissions';
import { timeToDb } from '../../src/modules/schedules/slots';

/** Published in the runbook — demo accounts, not a credential to protect. */
const DEMO_PASSWORD = 'DemoAntre123';

const BUSINESS_NAME = 'Barbershop Demo AntreIn';
const OUTLET_NAME = 'Outlet Kemang';

const SERVICES = [
  { name: 'Potong Rambut', durationMinutes: 45, priceAmount: 50_000, sortOrder: 1 },
  { name: 'Cukur Jenggot', durationMinutes: 30, priceAmount: 35_000, sortOrder: 2 },
  { name: 'Creambath', durationMinutes: 60, priceAmount: 90_000, sortOrder: 3 },
  { name: 'Paket Lengkap', durationMinutes: 90, priceAmount: 150_000, sortOrder: 4 },
];

const BARBERS = [
  { email: 'andi@demo.antrein.id', name: 'Andi Pratama', shift: { start: '09:00', end: '17:00' } },
  {
    email: 'sinta@demo.antrein.id',
    name: 'Sinta Larasati',
    shift: { start: '13:00', end: '21:00' },
  },
];

const CUSTOMERS = [
  { email: 'dewi@demo.antrein.id', name: 'Dewi Anggraini' },
  { email: 'rizky@demo.antrein.id', name: 'Rizky Maulana' },
];

// 1 = Monday … 6 = Saturday (database-design §22); Sunday (0) is closed.
const OPEN_DAYS = [1, 2, 3, 4, 5, 6];
const OPENS_AT = '09:00';
const CLOSES_AT = '21:00';

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL ?? '' }),
});
const hasher = new PasswordHasher();

async function upsertUser(email: string, name: string, passwordHash: string): Promise<string> {
  const emailNormalized = normalizeEmail(email);
  const user = await prisma.user.upsert({
    where: { emailNormalized },
    update: { name, passwordHash, status: 'active' },
    create: { id: newId('usr'), email, emailNormalized, name, passwordHash, status: 'active' },
  });
  return user.id;
}

async function main(): Promise<void> {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');

  const passwordHash = await hasher.hash(DEMO_PASSWORD);
  const now = new Date();
  const slug = slugify(BUSINESS_NAME);

  const ownerId = await upsertUser('owner@demo.antrein.id', 'Budi Santoso', passwordHash);

  const business = await prisma.business.upsert({
    where: { slug },
    update: { name: BUSINESS_NAME, status: 'active' },
    create: {
      id: newId('biz'),
      ownerUserId: ownerId,
      name: BUSINESS_NAME,
      slug,
      description: 'Barbershop demo untuk mencoba alur booking, pembayaran, dan antrean AntreIn.',
      status: 'active',
      timezone: 'Asia/Jakarta',
      verifiedAt: now,
    },
  });

  await prisma.businessPolicy.upsert({
    where: { businessId: business.id },
    update: {},
    create: { businessId: business.id },
  });

  await prisma.businessMembership.upsert({
    where: { businessId_userId: { businessId: business.id, userId: ownerId } },
    update: { role: 'owner', permissions: [...OWNER_PERMISSIONS], status: 'active' },
    create: {
      id: newId('mem'),
      businessId: business.id,
      userId: ownerId,
      role: 'owner',
      permissions: [...OWNER_PERMISSIONS],
      status: 'active',
      joinedAt: now,
    },
  });

  // Outlets carry no natural unique key — match the demo outlet by name.
  const existingOutlet = await prisma.outlet.findFirst({
    where: { businessId: business.id, name: OUTLET_NAME },
  });
  const outlet =
    existingOutlet ??
    (await prisma.outlet.create({
      data: {
        id: newId('out'),
        businessId: business.id,
        name: OUTLET_NAME,
        phoneNumber: '+622112345678',
        timezone: 'Asia/Jakarta',
        addressFormatted: 'Jl. Kemang Raya No. 21, Jakarta Selatan',
        status: 'active',
        queuePrefix: 'A',
      },
    }));

  for (let dayOfWeek = 0; dayOfWeek <= 6; dayOfWeek += 1) {
    const open = OPEN_DAYS.includes(dayOfWeek);
    const hours = {
      isClosed: !open,
      opensAt: open ? timeToDb(OPENS_AT) : null,
      closesAt: open ? timeToDb(CLOSES_AT) : null,
    };
    await prisma.outletOperatingHour.upsert({
      where: {
        outletId_dayOfWeek_periodOrder: { outletId: outlet.id, dayOfWeek, periodOrder: 0 },
      },
      update: hours,
      create: { id: newId('sch'), outletId: outlet.id, dayOfWeek, periodOrder: 0, ...hours },
    });
  }

  const serviceIds: string[] = [];
  for (const svc of SERVICES) {
    const nameNormalized = svc.name.trim().toLowerCase().replace(/\s+/g, ' ');
    const existing = await prisma.service.findFirst({
      where: { businessId: business.id, nameNormalized },
    });
    const service =
      existing ??
      (await prisma.service.create({
        data: {
          id: newId('svc'),
          businessId: business.id,
          name: svc.name,
          nameNormalized,
          durationMinutes: svc.durationMinutes,
          priceAmount: svc.priceAmount,
          currency: 'IDR',
          status: 'active',
          sortOrder: svc.sortOrder,
        },
      }));
    serviceIds.push(service.id);
  }

  for (const barber of BARBERS) {
    const userId = await upsertUser(barber.email, barber.name, passwordHash);
    const membership = await prisma.businessMembership.upsert({
      where: { businessId_userId: { businessId: business.id, userId } },
      update: { role: 'barber', permissions: ROLE_DEFAULT_PERMISSIONS.barber, status: 'active' },
      create: {
        id: newId('mem'),
        businessId: business.id,
        userId,
        role: 'barber',
        permissions: ROLE_DEFAULT_PERMISSIONS.barber,
        status: 'active',
        joinedAt: now,
      },
    });

    const staff = await prisma.staffProfile.upsert({
      where: { membershipId: membership.id },
      update: { displayName: barber.name, status: 'active' },
      create: {
        id: newId('stf'),
        businessId: business.id,
        membershipId: membership.id,
        displayName: barber.name,
        staffType: 'barber',
        status: 'active',
      },
    });

    await prisma.staffOutlet.upsert({
      where: { staffId_outletId: { staffId: staff.id, outletId: outlet.id } },
      update: {},
      create: { staffId: staff.id, outletId: outlet.id },
    });

    for (const serviceId of serviceIds) {
      await prisma.staffService.upsert({
        where: { staffId_serviceId: { staffId: staff.id, serviceId } },
        update: {},
        create: { staffId: staff.id, serviceId },
      });
    }

    for (const dayOfWeek of OPEN_DAYS) {
      const shift = {
        isAvailable: true,
        startsAt: timeToDb(barber.shift.start),
        endsAt: timeToDb(barber.shift.end),
      };
      await prisma.staffSchedule.upsert({
        where: { staffId_dayOfWeek_periodOrder: { staffId: staff.id, dayOfWeek, periodOrder: 0 } },
        update: shift,
        create: { id: newId('sch'), staffId: staff.id, dayOfWeek, periodOrder: 0, ...shift },
      });
    }
  }

  for (const customer of CUSTOMERS) {
    await upsertUser(customer.email, customer.name, passwordHash);
  }

  const accounts = [
    'owner@demo.antrein.id (owner)',
    ...BARBERS.map((b) => `${b.email} (barber)`),
    ...CUSTOMERS.map((c) => `${c.email} (customer)`),
  ];
  process.stdout.write(
    `Demo data ready.\n` +
      `  business: ${business.name} (${business.id}, /${slug})\n` +
      `  outlet:   ${outlet.name} (${outlet.id})\n` +
      `  services: ${SERVICES.length}, barbers: ${BARBERS.length}\n` +
      `  password: ${DEMO_PASSWORD}\n` +
      accounts.map((a) => `  login:    ${a}\n`).join(''),
  );
}

main()
  .catch((error: unknown) => {
    process.stderr.write(`Demo seed failed: ${(error as Error).message}\n`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
