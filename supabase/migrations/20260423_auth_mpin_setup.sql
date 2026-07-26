-- Temple Book App - Authentication + MPIN setup
-- Run after 20260423_temple_full_setup.sql

begin;

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.user_mpin_auth (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  mpin_hash text not null,
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_mpin_auth_locked_until on public.user_mpin_auth(locked_until);

create or replace function public.set_user_mpin(p_mpin text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_mpin is null or p_mpin !~ '^\d{4}$' then
    raise exception 'MPIN must be exactly 4 digits';
  end if;

  insert into public.user_mpin_auth(profile_id, mpin_hash, failed_attempts, locked_until, updated_at)
  values (v_uid, extensions.crypt(p_mpin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (profile_id)
  do update
    set mpin_hash = excluded.mpin_hash,
        failed_attempts = 0,
        locked_until = null,
        updated_at = now();
end;
$$;

create or replace function public.has_user_mpin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.user_mpin_auth m where m.profile_id = auth.uid()
  );
$$;

create or replace function public.verify_user_mpin(p_mpin text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.user_mpin_auth%rowtype;
begin
  if v_uid is null then
    return false;
  end if;

  select * into v_row
  from public.user_mpin_auth
  where profile_id = v_uid;

  if not found then
    return false;
  end if;

  if v_row.locked_until is not null and v_row.locked_until > now() then
    return false;
  end if;

  if v_row.mpin_hash = extensions.crypt(p_mpin, v_row.mpin_hash) then
    update public.user_mpin_auth
      set failed_attempts = 0,
          locked_until = null,
          updated_at = now()
    where profile_id = v_uid;
    return true;
  end if;

  update public.user_mpin_auth
    set failed_attempts = failed_attempts + 1,
        locked_until = case
          when failed_attempts + 1 >= 5 then now() + interval '5 minutes'
          else null
        end,
        updated_at = now()
  where profile_id = v_uid;

  return false;
end;
$$;

grant execute on function public.set_user_mpin(text) to authenticated;
grant execute on function public.has_user_mpin() to authenticated;
grant execute on function public.verify_user_mpin(text) to authenticated;

alter table public.user_mpin_auth enable row level security;

drop policy if exists "user_mpin_select_own_or_admin" on public.user_mpin_auth;
create policy "user_mpin_select_own_or_admin"
on public.user_mpin_auth for select
using (profile_id = auth.uid() or public.current_user_role() = 'admin');

drop policy if exists "user_mpin_update_own_or_admin" on public.user_mpin_auth;
create policy "user_mpin_update_own_or_admin"
on public.user_mpin_auth for update
using (profile_id = auth.uid() or public.current_user_role() = 'admin')
with check (profile_id = auth.uid() or public.current_user_role() = 'admin');

drop policy if exists "user_mpin_insert_own_or_admin" on public.user_mpin_auth;
create policy "user_mpin_insert_own_or_admin"
on public.user_mpin_auth for insert
with check (profile_id = auth.uid() or public.current_user_role() = 'admin');

commit;
