-- App Store screenshot demo account seed.  NOT APPLIED — needs Drew's approval (prod DB write).
--
-- Prereq (dashboard, not SQL): Supabase → Authentication → Add user →
--   email + strong password, "Auto confirm" on. Store them as GitHub secrets
--   MESA_DEMO_EMAIL / MESA_DEMO_PASSWORD (gh secret set ...). Never commit them.
-- Then set :demo_email below and run this whole file in one transaction.
-- Creates: demo profile (onboarding complete), a friend profile (no login), 3 NYC lists
-- around Union Square, one upcoming trip with places, one decided group pick.
-- Output: the ids to set as repo variables SCREENSHOT_PICK_ID / _LIST_ID / _PLACE_ID.
-- Undo: delete from users where id in ('demo-appstore','demo-appstore-friend') cascades? -> see bottom.

begin;

insert into public.users (id, first_name, last_name, full_name, full_name_lower, email, phone_number,
                          profile_photo_url, supabase_uid, account_type, created_at)
select 'demo-appstore', 'Alex', 'Rivera', 'Alex Rivera', 'alex rivera', u.email, '+15555550100',
       'REPLACE_WITH_STOCK_PHOTO_URL',  -- required: app shows photo onboarding without it
       u.id::text, 'personal', now()
from auth.users u where u.email = 'REPLACE_WITH_DEMO_EMAIL';

insert into public.users (id, first_name, last_name, full_name, full_name_lower, created_at)
values ('demo-appstore-friend', 'Sam', 'Lee', 'Sam Lee', 'sam lee', now());

-- Best-rated, photographed places within ~1.5 km of Union Square
create temp table demo_places as
select id, categories, row_number() over (order by rating_count desc nulls last) rn
from public.places
where photo_urls is not null and cardinality(photo_urls) > 0 and rating >= 4.4
  and st_dwithin(location::geography, st_setsrid(st_makepoint(-73.9911, 40.7359), 4326)::geography, 1500)
limit 30;

insert into public.place_lists (id, user_id, name, description, is_public, city, created_at, updated_at) values
 ('demo-list-dinner', 'demo-appstore', 'Date night', 'Dinner spots worth dressing up for', true, 'New York', now(), now()),
 ('demo-list-coffee', 'demo-appstore', 'Coffee & laptops', 'Good wifi, better espresso', true, 'New York', now(), now()),
 ('demo-list-tiktok', 'demo-appstore', 'Saved from TikTok', 'Everything my feed told me to try', true, 'New York', now(), now());

insert into public.place_list_items (list_id, place_id, sort_order, added_by)
select case rn % 3 when 0 then 'demo-list-dinner' when 1 then 'demo-list-coffee' else 'demo-list-tiktok' end,
       id, rn, 'demo-appstore' from demo_places;

insert into public.trips (id, name, owner_id, start_date, end_date, created_at, updated_at) values
 ('demo-trip-1', 'Weekend in Brooklyn', 'demo-appstore', current_date + 10, current_date + 12, now(), now());
insert into public.trip_collaborators (trip_id, user_id, role, added_by)
values ('demo-trip-1', 'demo-appstore-friend', 'editor', 'demo-appstore');
insert into public.trip_day_places (trip_id, place_id, day_index, sort_order, added_by)
select 'demo-trip-1', id, (rn % 3)::int, rn::int, 'demo-appstore' from demo_places where rn <= 9;

with p as (
  insert into public.group_picks (creator_id, title, place_ids, decide_at, decided_place_id, decided_at, outcome, decided_reason)
  select 'demo-appstore', 'Dinner tonight?', array_agg(id order by rn), now() + interval '1 day',
         (array_agg(id order by rn))[1], now(), 'winner', 'unanimous'
  from demo_places where rn <= 4
  returning id, decided_place_id, place_ids)
, m as (insert into public.group_pick_members (pick_id, user_id)
        select id, u from p, unnest(array['demo-appstore','demo-appstore-friend']) u returning 1)
, v as (insert into public.group_pick_votes (pick_id, user_id, place_id, vote)
        select p.id, u, pl, pl = p.decided_place_id
        from p, unnest(array['demo-appstore','demo-appstore-friend']) u, unnest(p.place_ids) pl returning 1)
select p.id as screenshot_pick_id, 'demo-list-tiktok' as screenshot_list_id, p.decided_place_id as screenshot_place_id from p;

commit;

-- Undo:
-- delete from group_pick_votes where user_id like 'demo-appstore%'; delete from group_pick_members where user_id like 'demo-appstore%';
-- delete from group_picks where creator_id='demo-appstore'; delete from trip_day_places where trip_id='demo-trip-1';
-- delete from trip_collaborators where trip_id='demo-trip-1'; delete from trips where id='demo-trip-1';
-- delete from place_list_items where list_id like 'demo-list-%'; delete from place_lists where id like 'demo-list-%';
-- delete from users where id like 'demo-appstore%';  -- then delete the auth user in the dashboard
