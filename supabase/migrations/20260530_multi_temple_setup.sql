-- Multi-temple support for Temple Book App
-- Safe to re-run (idempotent where possible).

begin;

-- =========================================================
-- 1) Temples and user-temple membership
-- =========================================================

create table if not exists public.temples (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  address text,
  city text,
  state text,
  pincode text,
  contact_phone text,
  contact_email text,
  upi_id text default 'temple@upi',
  logo_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_temples (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  temple_id uuid not null references public.temples(id) on delete cascade,
  role text not null default 'user' check (role in ('admin', 'committee', 'user')),
  is_primary boolean not null default false,
  joined_at timestamptz not null default now(),
  unique (profile_id, temple_id)
);

create index if not exists idx_user_temples_profile on public.user_temples(profile_id);
create index if not exists idx_user_temples_temple on public.user_temples(temple_id);
create index if not exists idx_user_temples_role on public.user_temples(temple_id, role);

-- Default temple for existing single-temple deployments
insert into public.temples (id, name, slug, is_active)
values (
  '00000000-0000-0000-0000-000000000001',
  'Default Temple',
  'default-temple',
  true
)
on conflict (slug) do nothing;

-- =========================================================
-- 2) Add temple_id to existing tables
-- =========================================================

alter table if exists public.familyheads
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.committeemembers
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.employees
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.events
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.payments
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.poojas
  add column if not exists temple_id uuid references public.temples(id) on delete cascade,
  add column if not exists pooja_date date;

alter table if exists public.contributions
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.temple_accounts
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.employee_payments
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.temple_charges
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.hall_bookings
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.pooja_bookings
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.event_media
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

alter table if exists public.notifications
  add column if not exists temple_id uuid references public.temples(id) on delete cascade;

-- Backfill existing rows with default temple
update public.familyheads set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.committeemembers set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.employees set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.events set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.payments set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.poojas set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.contributions set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.temple_accounts set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.employee_payments set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.temple_charges set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.hall_bookings set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.pooja_bookings set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.event_media set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;
update public.notifications set temple_id = '00000000-0000-0000-0000-000000000001' where temple_id is null;

-- Migrate existing profile roles into user_temples
insert into public.user_temples (profile_id, temple_id, role, is_primary)
select p.id, '00000000-0000-0000-0000-000000000001', p.role, true
from public.profiles p
where not exists (
  select 1 from public.user_temples ut
  where ut.profile_id = p.id and ut.temple_id = '00000000-0000-0000-0000-000000000001'
);

-- =========================================================
-- 3) Temple-scoped helper functions
-- =========================================================

create or replace function public.current_user_role_for_temple(p_temple_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select ut.role
      from public.user_temples ut
      where ut.profile_id = auth.uid()
        and ut.temple_id = p_temple_id
    ),
    'user'
  );
$$;

create or replace function public.user_belongs_to_temple(p_temple_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_temples ut
    where ut.profile_id = auth.uid()
      and ut.temple_id = p_temple_id
  );
$$;

-- Auto-assign new users to temple from signup metadata
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_temple_id uuid;
  v_role text := 'user';
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

  v_temple_id := coalesce(
    (new.raw_user_meta_data ->> 'temple_id')::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid
  );

  insert into public.user_temples (profile_id, temple_id, role, is_primary)
  values (new.id, v_temple_id, v_role, true)
  on conflict (profile_id, temple_id) do nothing;

  return new;
end;
$$;

-- =========================================================
-- 4) Indexes for temple-scoped queries
-- =========================================================

create index if not exists idx_familyheads_temple on public.familyheads(temple_id);
create index if not exists idx_committeemembers_temple on public.committeemembers(temple_id);
create index if not exists idx_employees_temple on public.employees(temple_id);
create index if not exists idx_events_temple on public.events(temple_id);
create index if not exists idx_payments_temple on public.payments(temple_id);
create index if not exists idx_poojas_temple on public.poojas(temple_id);
create index if not exists idx_poojas_date on public.poojas(pooja_date);

-- =========================================================
-- 5) RLS for temples and user_temples
-- =========================================================

alter table public.temples enable row level security;
alter table public.user_temples enable row level security;

drop policy if exists "temples_select_active_authenticated" on public.temples;
drop policy if exists "temples_select_active" on public.temples;
create policy "temples_select_active"
on public.temples for select
using (is_active = true);

drop policy if exists "temples_write_admin" on public.temples;
create policy "temples_write_admin"
on public.temples for all
using (
  exists (
    select 1 from public.user_temples ut
    where ut.profile_id = auth.uid() and ut.role = 'admin'
  )
)
with check (
  exists (
    select 1 from public.user_temples ut
    where ut.profile_id = auth.uid() and ut.role = 'admin'
  )
);

drop policy if exists "user_temples_select_own_or_admin" on public.user_temples;
create policy "user_temples_select_own_or_admin"
on public.user_temples for select
using (
  profile_id = auth.uid()
  or public.current_user_role_for_temple(temple_id) = 'admin'
);

drop policy if exists "user_temples_insert_admin" on public.user_temples;
create policy "user_temples_insert_admin"
on public.user_temples for insert
with check (
  profile_id = auth.uid()
  or public.current_user_role_for_temple(temple_id) = 'admin'
);

drop policy if exists "user_temples_update_admin" on public.user_temples;
create policy "user_temples_update_admin"
on public.user_temples for update
using (public.current_user_role_for_temple(temple_id) = 'admin')
with check (public.current_user_role_for_temple(temple_id) = 'admin');

-- =========================================================
-- 6) Update RLS on data tables to scope by temple membership
-- =========================================================

-- Family heads
drop policy if exists "familyheads_select_all_authenticated" on public.familyheads;
create policy "familyheads_select_temple_member"
on public.familyheads for select
using (public.user_belongs_to_temple(temple_id));

drop policy if exists "familyheads_write_admin_only" on public.familyheads;
create policy "familyheads_write_temple_admin"
on public.familyheads for all
using (public.current_user_role_for_temple(temple_id) = 'admin')
with check (public.current_user_role_for_temple(temple_id) = 'admin');

-- Committee
drop policy if exists "committee_select_all_authenticated" on public.committeemembers;
create policy "committee_select_temple_member"
on public.committeemembers for select
using (public.user_belongs_to_temple(temple_id));

drop policy if exists "committee_write_admin_only" on public.committeemembers;
create policy "committee_write_temple_admin"
on public.committeemembers for all
using (public.current_user_role_for_temple(temple_id) = 'admin')
with check (public.current_user_role_for_temple(temple_id) = 'admin');

-- Employees
drop policy if exists "employees_select_all_authenticated" on public.employees;
create policy "employees_select_temple_member"
on public.employees for select
using (public.user_belongs_to_temple(temple_id));

drop policy if exists "employees_write_admin_only" on public.employees;
create policy "employees_write_temple_admin"
on public.employees for all
using (public.current_user_role_for_temple(temple_id) = 'admin')
with check (public.current_user_role_for_temple(temple_id) = 'admin');

-- Events
drop policy if exists "events_select_all_authenticated" on public.events;
create policy "events_select_temple_member"
on public.events for select
using (public.user_belongs_to_temple(temple_id));

drop policy if exists "events_write_admin_committee" on public.events;
create policy "events_write_temple_admin_committee"
on public.events for all
using (public.current_user_role_for_temple(temple_id) in ('admin', 'committee'))
with check (public.current_user_role_for_temple(temple_id) in ('admin', 'committee'));

-- Payments
drop policy if exists "payments_select_all_authenticated" on public.payments;
create policy "payments_select_temple_member"
on public.payments for select
using (public.user_belongs_to_temple(temple_id));

drop policy if exists "payments_write_admin_committee" on public.payments;
create policy "payments_write_temple_admin_committee"
on public.payments for all
using (public.current_user_role_for_temple(temple_id) in ('admin', 'committee'))
with check (public.current_user_role_for_temple(temple_id) in ('admin', 'committee'));

-- Poojas
drop policy if exists "poojas_select_all_authenticated" on public.poojas;
create policy "poojas_select_temple_member"
on public.poojas for select
using (public.user_belongs_to_temple(temple_id));

drop policy if exists "poojas_write_admin_committee" on public.poojas;
create policy "poojas_write_temple_admin_committee"
on public.poojas for all
using (public.current_user_role_for_temple(temple_id) in ('admin', 'committee'))
with check (public.current_user_role_for_temple(temple_id) in ('admin', 'committee'));

commit;
