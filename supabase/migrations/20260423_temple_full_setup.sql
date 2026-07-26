-- Temple Book App - Full Supabase setup
-- Run this file in Supabase SQL Editor.
-- Safe to re-run (idempotent where possible).

begin;

create extension if not exists pgcrypto;

-- =========================================================
-- 1) Existing table upgrades (based on your current schema)
-- =========================================================

alter table if exists public.familyheads
  add column if not exists dob date,
  add column if not exists gender text,
  add column if not exists age integer,
  add column if not exists kulam_subdivision text,
  add column if not exists other_temple_association text,
  add column if not exists address text,
  add column if not exists marital_status text,
  add column if not exists email text,
  add column if not exists social_media jsonb default '{}'::jsonb,
  add column if not exists work_business_info text,
  add column if not exists photo_url text,
  add column if not exists is_family_head boolean default true,
  add column if not exists parent_family_head_id bigint references public.familyheads(id),
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now(),
  add column if not exists created_by uuid;

alter table if exists public.committeemembers
  add column if not exists profile_id uuid,
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists term_start date,
  add column if not exists term_end date,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

alter table if exists public.employees
  add column if not exists phone text,
  add column if not exists joined_on date,
  add column if not exists monthly_salary numeric(12,2),
  add column if not exists address text,
  add column if not exists photo_url text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

alter table if exists public.events
  add column if not exists description text,
  add column if not exists created_by uuid,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

alter table if exists public.payments
  add column if not exists payer_user_id uuid,
  add column if not exists payment_mode text default 'UPI',
  add column if not exists upi_txn_id text,
  add column if not exists receipt_url text,
  add column if not exists paid_at timestamptz default now(),
  add column if not exists created_at timestamptz default now();

alter table if exists public.poojas
  add column if not exists category text default 'daily',
  add column if not exists scheduled_time time,
  add column if not exists amount numeric(12,2) default 0,
  add column if not exists is_active boolean default true,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

-- =========================================================
-- 2) New tables required for full feature coverage
-- =========================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'user' check (role in ('admin', 'committee', 'user')),
  gender text,
  dob date,
  phone text,
  email text,
  is_family_head boolean default true,
  family_head_id bigint references public.familyheads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (is_family_head = true or family_head_id is not null)
);

create table if not exists public.contributions (
  id bigint generated always as identity primary key,
  family_head_id bigint not null references public.familyheads(id) on delete cascade,
  paid_by_profile_id uuid references public.profiles(id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  purpose text,
  paid_at timestamptz not null default now(),
  payment_id bigint references public.payments(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.temple_accounts (
  id bigint generated always as identity primary key,
  account_name text not null,
  upi_id text not null,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.employee_payments (
  id bigint generated always as identity primary key,
  employee_id bigint not null references public.employees(id) on delete cascade,
  month_year date not null,
  amount numeric(12,2) not null check (amount > 0),
  paid_on date not null default current_date,
  payment_mode text default 'bank_transfer',
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.temple_charges (
  id bigint generated always as identity primary key,
  charge_type text not null check (charge_type in ('electricity', 'water', 'other')),
  account_or_bill_number text not null,
  amount numeric(12,2) not null check (amount >= 0),
  due_date date,
  paid_date date,
  status text not null default 'pending' check (status in ('pending', 'paid', 'overdue')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.hall_bookings (
  id bigint generated always as identity primary key,
  booked_by_profile_id uuid references public.profiles(id) on delete set null,
  event_name text not null,
  event_date date not null,
  from_time time,
  to_time time,
  advance_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2),
  status text not null default 'requested' check (status in ('requested', 'approved', 'cancelled', 'completed')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.pooja_bookings (
  id bigint generated always as identity primary key,
  pooja_id bigint not null references public.poojas(id) on delete cascade,
  booked_by_profile_id uuid references public.profiles(id) on delete set null,
  booking_date date not null,
  amount numeric(12,2) not null default 0,
  payment_id bigint references public.payments(id) on delete set null,
  status text not null default 'booked' check (status in ('booked', 'cancelled', 'completed')),
  created_at timestamptz not null default now()
);

create table if not exists public.event_media (
  id bigint generated always as identity primary key,
  event_id bigint not null references public.events(id) on delete cascade,
  file_url text not null,
  file_type text not null check (file_type in ('photo', 'document')),
  file_size_kb integer not null check (file_size_kb > 0 and file_size_kb <= 100),
  uploaded_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  profile_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  image_url text,
  notification_date date not null default current_date,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- =========================================================
-- 3) Utility functions and triggers
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_familyheads_updated_at on public.familyheads;
create trigger trg_familyheads_updated_at
before update on public.familyheads
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_committeemembers_updated_at on public.committeemembers;
create trigger trg_committeemembers_updated_at
before update on public.committeemembers
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_employees_updated_at on public.employees;
create trigger trg_employees_updated_at
before update on public.employees
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_events_updated_at on public.events;
create trigger trg_events_updated_at
before update on public.events
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_poojas_updated_at on public.poojas;
create trigger trg_poojas_updated_at
before update on public.poojas
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_temple_accounts_updated_at on public.temple_accounts;
create trigger trg_temple_accounts_updated_at
before update on public.temple_accounts
for each row execute procedure public.set_updated_at();

-- Auto-create profile row when new auth user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, email, phone, is_family_head)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    'user',
    new.email,
    new.raw_user_meta_data ->> 'phone',
    true
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Role helper
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select p.role from public.profiles p where p.id = auth.uid()), 'user');
$$;

-- Upcoming birthdays helper (today to next 7 days)
create or replace view public.upcoming_birthdays as
select
  fh.id,
  fh.name,
  fh.photo_url,
  fh.dob,
  make_date(
    extract(year from current_date)::int,
    extract(month from fh.dob)::int,
    extract(day from fh.dob)::int
  ) as birthday_this_year
from public.familyheads fh
where fh.dob is not null
  and (
    make_date(extract(year from current_date)::int, extract(month from fh.dob)::int, extract(day from fh.dob)::int)
    between current_date and (current_date + interval '7 day')::date
  );

-- =========================================================
-- 4) Indexes
-- =========================================================

create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_profiles_family_head on public.profiles(family_head_id);
create index if not exists idx_familyheads_parent on public.familyheads(parent_family_head_id);
create index if not exists idx_payments_payer_user on public.payments(payer_user_id);
create index if not exists idx_events_date on public.events(date);
create index if not exists idx_hall_bookings_event_date on public.hall_bookings(event_date);
create index if not exists idx_pooja_bookings_date on public.pooja_bookings(booking_date);
create index if not exists idx_notifications_profile_date on public.notifications(profile_id, notification_date);

-- =========================================================
-- 5) Row Level Security (RLS) policies
-- =========================================================

alter table public.profiles enable row level security;
alter table public.familyheads enable row level security;
alter table public.committeemembers enable row level security;
alter table public.employees enable row level security;
alter table public.employee_payments enable row level security;
alter table public.events enable row level security;
alter table public.event_media enable row level security;
alter table public.payments enable row level security;
alter table public.poojas enable row level security;
alter table public.pooja_bookings enable row level security;
alter table public.temple_accounts enable row level security;
alter table public.temple_charges enable row level security;
alter table public.hall_bookings enable row level security;
alter table public.contributions enable row level security;
alter table public.notifications enable row level security;

-- Profiles
drop policy if exists "profiles_select_self_or_admin_committee" on public.profiles;
create policy "profiles_select_self_or_admin_committee"
on public.profiles for select
using (id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

drop policy if exists "profiles_update_self_or_admin" on public.profiles;
create policy "profiles_update_self_or_admin"
on public.profiles for update
using (id = auth.uid() or public.current_user_role() = 'admin')
with check (id = auth.uid() or public.current_user_role() = 'admin');

drop policy if exists "profiles_insert_admin_only" on public.profiles;
create policy "profiles_insert_admin_only"
on public.profiles for insert
with check (public.current_user_role() = 'admin');

-- Family heads: read all authenticated, write admin only
drop policy if exists "familyheads_select_all_authenticated" on public.familyheads;
create policy "familyheads_select_all_authenticated"
on public.familyheads for select
using (auth.role() = 'authenticated');

drop policy if exists "familyheads_write_admin_only" on public.familyheads;
create policy "familyheads_write_admin_only"
on public.familyheads for all
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

-- Committee members: read all authenticated, write admin only
drop policy if exists "committee_select_all_authenticated" on public.committeemembers;
create policy "committee_select_all_authenticated"
on public.committeemembers for select
using (auth.role() = 'authenticated');

drop policy if exists "committee_write_admin_only" on public.committeemembers;
create policy "committee_write_admin_only"
on public.committeemembers for all
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

-- Employees & employee payments: view admin+committee, write admin only
drop policy if exists "employees_select_admin_committee" on public.employees;
create policy "employees_select_admin_committee"
on public.employees for select
using (public.current_user_role() in ('admin', 'committee'));

drop policy if exists "employees_write_admin_only" on public.employees;
create policy "employees_write_admin_only"
on public.employees for all
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "employee_payments_select_admin_committee" on public.employee_payments;
create policy "employee_payments_select_admin_committee"
on public.employee_payments for select
using (public.current_user_role() in ('admin', 'committee'));

drop policy if exists "employee_payments_write_admin_only" on public.employee_payments;
create policy "employee_payments_write_admin_only"
on public.employee_payments for all
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

-- Events/media: read all authenticated, write admin+committee
drop policy if exists "events_select_all_authenticated" on public.events;
create policy "events_select_all_authenticated"
on public.events for select
using (auth.role() = 'authenticated');

drop policy if exists "events_write_admin_committee" on public.events;
create policy "events_write_admin_committee"
on public.events for all
using (public.current_user_role() in ('admin', 'committee'))
with check (public.current_user_role() in ('admin', 'committee'));

drop policy if exists "event_media_select_all_authenticated" on public.event_media;
create policy "event_media_select_all_authenticated"
on public.event_media for select
using (auth.role() = 'authenticated');

drop policy if exists "event_media_write_admin_committee" on public.event_media;
create policy "event_media_write_admin_committee"
on public.event_media for all
using (public.current_user_role() in ('admin', 'committee'))
with check (public.current_user_role() in ('admin', 'committee'));

-- Payments: user can insert/select own, admin+committee can see all
drop policy if exists "payments_select_own_or_admin_committee" on public.payments;
create policy "payments_select_own_or_admin_committee"
on public.payments for select
using (payer_user_id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

drop policy if exists "payments_insert_own_or_admin_committee" on public.payments;
create policy "payments_insert_own_or_admin_committee"
on public.payments for insert
with check (payer_user_id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

drop policy if exists "payments_update_admin_committee" on public.payments;
create policy "payments_update_admin_committee"
on public.payments for update
using (public.current_user_role() in ('admin', 'committee'))
with check (public.current_user_role() in ('admin', 'committee'));

-- Poojas: read all authenticated, write admin+committee
drop policy if exists "poojas_select_all_authenticated" on public.poojas;
create policy "poojas_select_all_authenticated"
on public.poojas for select
using (auth.role() = 'authenticated');

drop policy if exists "poojas_write_admin_committee" on public.poojas;
create policy "poojas_write_admin_committee"
on public.poojas for all
using (public.current_user_role() in ('admin', 'committee'))
with check (public.current_user_role() in ('admin', 'committee'));

-- Pooja bookings: user own + admin/committee
drop policy if exists "pooja_bookings_select_own_or_admin_committee" on public.pooja_bookings;
create policy "pooja_bookings_select_own_or_admin_committee"
on public.pooja_bookings for select
using (booked_by_profile_id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

drop policy if exists "pooja_bookings_insert_own_or_admin_committee" on public.pooja_bookings;
create policy "pooja_bookings_insert_own_or_admin_committee"
on public.pooja_bookings for insert
with check (booked_by_profile_id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

drop policy if exists "pooja_bookings_update_admin_committee" on public.pooja_bookings;
create policy "pooja_bookings_update_admin_committee"
on public.pooja_bookings for update
using (public.current_user_role() in ('admin', 'committee'))
with check (public.current_user_role() in ('admin', 'committee'));

-- Temple accounts/charges: read all authenticated, write admin only
drop policy if exists "temple_accounts_select_all_authenticated" on public.temple_accounts;
create policy "temple_accounts_select_all_authenticated"
on public.temple_accounts for select
using (auth.role() = 'authenticated');

drop policy if exists "temple_accounts_write_admin_only" on public.temple_accounts;
create policy "temple_accounts_write_admin_only"
on public.temple_accounts for all
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

drop policy if exists "temple_charges_select_all_authenticated" on public.temple_charges;
create policy "temple_charges_select_all_authenticated"
on public.temple_charges for select
using (auth.role() = 'authenticated');

drop policy if exists "temple_charges_write_admin_committee" on public.temple_charges;
create policy "temple_charges_write_admin_committee"
on public.temple_charges for all
using (public.current_user_role() in ('admin', 'committee'))
with check (public.current_user_role() in ('admin', 'committee'));

-- Hall bookings: read all authenticated, insert own, update admin+committee
drop policy if exists "hall_bookings_select_all_authenticated" on public.hall_bookings;
create policy "hall_bookings_select_all_authenticated"
on public.hall_bookings for select
using (auth.role() = 'authenticated');

drop policy if exists "hall_bookings_insert_own_or_admin_committee" on public.hall_bookings;
create policy "hall_bookings_insert_own_or_admin_committee"
on public.hall_bookings for insert
with check (booked_by_profile_id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

drop policy if exists "hall_bookings_update_admin_committee" on public.hall_bookings;
create policy "hall_bookings_update_admin_committee"
on public.hall_bookings for update
using (public.current_user_role() in ('admin', 'committee'))
with check (public.current_user_role() in ('admin', 'committee'));

-- Contributions: user can create own contribution, read own; admin+committee all
drop policy if exists "contributions_select_own_or_admin_committee" on public.contributions;
create policy "contributions_select_own_or_admin_committee"
on public.contributions for select
using (paid_by_profile_id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

drop policy if exists "contributions_insert_own_or_admin_committee" on public.contributions;
create policy "contributions_insert_own_or_admin_committee"
on public.contributions for insert
with check (paid_by_profile_id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

-- Notifications: user reads own, admin+committee can read/write all
drop policy if exists "notifications_select_own_or_admin_committee" on public.notifications;
create policy "notifications_select_own_or_admin_committee"
on public.notifications for select
using (profile_id = auth.uid() or public.current_user_role() in ('admin', 'committee'));

drop policy if exists "notifications_write_admin_committee" on public.notifications;
create policy "notifications_write_admin_committee"
on public.notifications for all
using (public.current_user_role() in ('admin', 'committee'))
with check (public.current_user_role() in ('admin', 'committee'));

commit;

-- =========================================================
-- OPTIONAL: one-time seed examples (run manually if needed)
-- =========================================================
-- insert into public.temple_accounts(account_name, upi_id, is_default)
-- values ('Temple Main Account', 'temple@upi', true);

-- update public.profiles set role = 'admin' where email = 'admin@temple.org';
-- update public.profiles set role = 'committee' where email = 'committee1@temple.org';
