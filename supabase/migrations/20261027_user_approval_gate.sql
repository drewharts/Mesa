-- Invite / approval gate (Mesa 4.95)
-- New signups land as 'pending' and can't read or write app data until Drew approves them.
-- Every existing user is grandfathered as 'approved'.
-- NOT APPLIED. Apply only with Drew's approval, and only after (or together with) shipping a
-- build that shows the waiting screen; older builds will just look empty for pending users.

begin;

-- 1. Status columns. Adding with DEFAULT 'approved' backfills every existing row as approved,
--    then the default flips to 'pending' for everyone who signs up afterwards.
alter table public.users
  add column if not exists approval_status text not null default 'approved'
    check (approval_status in ('pending', 'approved', 'rejected')),
  add column if not exists approval_reviewed_at timestamptz,
  add column if not exists approval_reviewed_by text;
alter table public.users alter column approval_status set default 'pending';
create index if not exists idx_users_approval_pending on public.users (created_at desc)
  where approval_status = 'pending';

-- 2. Helpers (case-insensitive on ids, like app_uid()).
create or replace function public.is_mesa_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from users
    where upper(id) = 'C9DFA19E-B1B0-4EF1-8697-E448BC606CC7'
      and (lower(supabase_uid) = lower(auth.uid()::text) or lower(id) = lower(auth.uid()::text))
  )
$$;

create or replace function public.is_approved()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from users
    where (lower(supabase_uid) = lower(auth.uid()::text) or lower(id) = lower(auth.uid()::text))
      and approval_status = 'approved'
  )
$$;

-- 3. Nobody can approve themselves: the client may insert/update its own row, but
--    approval_status is forced to 'pending' on insert and frozen on update unless the
--    caller is the admin or a server role (service_role / postgres bypass).
create or replace function public.guard_user_approval()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if current_user in ('postgres', 'service_role', 'supabase_admin') or public.is_mesa_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.approval_status := 'pending';
    new.approval_reviewed_at := null;
    new.approval_reviewed_by := null;
  else
    new.approval_status := old.approval_status;
    new.approval_reviewed_at := old.approval_reviewed_at;
    new.approval_reviewed_by := old.approval_reviewed_by;
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_user_approval on public.users;
create trigger trg_guard_user_approval
  before insert or update on public.users
  for each row execute function public.guard_user_approval();

-- 4. RLS. RESTRICTIVE policies are AND-ed with the existing permissive ones, so nothing
--    changes for approved users.
--    users: pending/rejected people are invisible to everyone but themselves and the admin
--    (so they never show up in search, suggestions or follows).
drop policy if exists users_approved_visible on public.users;
create policy users_approved_visible on public.users as restrictive for select to authenticated, anon
  using (approval_status = 'approved'
         or lower(supabase_uid) = lower(auth.uid()::text)
         or lower(id) = lower(auth.uid()::text)
         or (select public.is_mesa_admin()));

--    Every other RLS-enabled public table: only approved users can read or write.
do $$
declare t record;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
      and c.relname not in ('users', 'spatial_ref_sys', 'world_cities')
  loop
    execute format('drop policy if exists approved_only on public.%I', t.relname);
    execute format(
      'create policy approved_only on public.%I as restrictive for all to authenticated '
      'using ((select public.is_approved())) with check ((select public.is_approved()))',
      t.relname);
  end loop;
end $$;

-- 5. RPCs for the app.
create or replace function public.get_my_approval_status()
returns text language sql stable security definer set search_path = public as $$
  select approval_status from users
  where lower(supabase_uid) = lower(auth.uid()::text) or lower(id) = lower(auth.uid()::text)
  order by (approval_status = 'approved') desc
  limit 1
$$;

create or replace function public.admin_list_users_for_review(p_status text default 'pending')
returns table (
  id text, full_name text, email text, phone_number text, profile_photo_url text,
  instagram_username text, tiktok_username text, account_type text,
  created_at timestamp, approval_status text, sign_in_provider text
) language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_mesa_admin() then raise exception 'not authorized'; end if;
  return query
    select u.id, u.full_name, u.email, u.phone_number, u.profile_photo_url,
           u.instagram_username, u.tiktok_username, u.account_type,
           u.created_at, u.approval_status,
           (select au.raw_app_meta_data->>'provider' from auth.users au
             where lower(au.id::text) = lower(coalesce(u.supabase_uid, u.id)) limit 1)
    from users u
    where u.approval_status = p_status
    order by u.created_at desc
    limit 500;
end $$;

create or replace function public.admin_set_user_approval(p_user_id text, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_mesa_admin() then raise exception 'not authorized'; end if;
  if p_status not in ('pending', 'approved', 'rejected') then raise exception 'bad status'; end if;
  update users set approval_status = p_status,
                   approval_reviewed_at = now(),
                   approval_reviewed_by = public.app_uid()
  where lower(id) = lower(p_user_id);
end $$;

revoke all on function public.get_my_approval_status() from public, anon;
revoke all on function public.admin_list_users_for_review(text) from public, anon;
revoke all on function public.admin_set_user_approval(text, text) from public, anon;
grant execute on function public.get_my_approval_status() to authenticated;
grant execute on function public.admin_list_users_for_review(text) to authenticated;
grant execute on function public.admin_set_user_approval(text, text) to authenticated;
grant execute on function public.is_approved() to authenticated;
grant execute on function public.is_mesa_admin() to authenticated;

-- 6. KNOWN GAPS (not changed here, see PR):
--    * places, place_lists, place_list_items have policies but RLS is DISABLED on them today,
--      so step 4 does not cover them. Enabling RLS there is a separate, riskier change.
--    * ~90 SECURITY DEFINER RPCs (get_recommended_users, get_map_places_in_viewport, ...)
--      bypass RLS. The app-side waiting screen is the real gate for those.
commit;
