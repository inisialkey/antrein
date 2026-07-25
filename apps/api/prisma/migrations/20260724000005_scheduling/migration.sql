-- M5 scheduling: outlet operating hours, staff schedules + breaks, closed dates.
-- Source: docs/backend/database-design.md §22-25. CHECK constraints live here only
-- (intentional Prisma-schema drift, same as migration 004).

create table outlet_operating_hours (
    id text primary key,
    outlet_id text not null references outlets(id) on delete cascade,
    day_of_week smallint not null,
    period_order smallint not null default 0,
    opens_at time null,
    closes_at time null,
    is_closed boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table outlet_operating_hours
add constraint outlet_operating_hours_day_check
check (day_of_week between 0 and 6);

alter table outlet_operating_hours
add constraint outlet_operating_hours_time_check
check (
    (is_closed = true and opens_at is null and closes_at is null)
    or
    (is_closed = false and opens_at is not null and closes_at is not null and opens_at < closes_at)
);

create unique index outlet_operating_hours_period_uq
on outlet_operating_hours(outlet_id, day_of_week, period_order);

create table staff_schedules (
    id text primary key,
    staff_id text not null references staff_profiles(id) on delete cascade,
    day_of_week smallint not null,
    period_order smallint not null default 0,
    starts_at time null,
    ends_at time null,
    is_available boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table staff_schedules
add constraint staff_schedules_day_check
check (day_of_week between 0 and 6);

alter table staff_schedules
add constraint staff_schedules_time_check
check (
    (is_available = false and starts_at is null and ends_at is null)
    or
    (is_available = true and starts_at is not null and ends_at is not null and starts_at < ends_at)
);

create unique index staff_schedules_period_uq
on staff_schedules(staff_id, day_of_week, period_order);

create table staff_schedule_breaks (
    id text primary key,
    staff_schedule_id text not null references staff_schedules(id) on delete cascade,
    starts_at time not null,
    ends_at time not null,
    created_at timestamptz not null default now()
);

alter table staff_schedule_breaks
add constraint staff_schedule_breaks_time_check
check (starts_at < ends_at);

create table closed_dates (
    id text primary key,
    outlet_id text not null references outlets(id) on delete cascade,
    closed_date date not null,
    reason text null,
    created_by_user_id text not null references users(id),
    created_at timestamptz not null default now()
);

create unique index closed_dates_outlet_date_uq
on closed_dates(outlet_id, closed_date);

create index closed_dates_date_idx
on closed_dates(closed_date);
