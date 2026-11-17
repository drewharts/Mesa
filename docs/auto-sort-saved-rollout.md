# Auto-sorted Saved: plan for shipping to everyone

Status: prototype behind admin + TestFlight + PostHog flag `auto_sort_saved` (PR #265).

## What the prototype does
- On a place page, the bookmark saves an unsaved place in one tap. The place sorts itself into Saved by city, then type, then cuisine. A small banner reads "Saved to New York City · Restaurants" and has an **Add to list** button.
- Tapping the bookmark on a place that's already saved opens the existing list picker. Its top row is now "Saved" (unsave there), and it still lists every user list plus +, which creates a list. Manual lists are unchanged.
- A one-tap save writes a row to the existing `favorites` table (the same write the picker's Favorites row already does). That table has `timestamp`, so "Saved this week" works for saves.

## Can it ship without migrations? Yes
- **Storage:** `favorites` (user_id, place_id, timestamp) has no row cap, RLS is on and the app already reads and writes it. No new table is needed.
- **Sorting:** on device, from data the app already loads. That's `get_all_user_places` (falling back to chunked reads), plus `external_places` and `favorites` timestamps.
- **No backend change is required.**

## Recommended (optional) data work, roughly in order
1. **Fix the `get_all_user_places` RPC.** It references columns that don't exist (`description_text`, `user_ratings_total`, `x`, `created_at`), so every call falls back to slower multi-query reads. `create or replace function` is a function change, not a schema migration, but it's still a production DB change. Needs Drew's OK.
2. **Backfill `places.city`.** It's empty for about 65% of rows. Fill it from the stored address or Google address components with a backend job. That's a data update, not a schema change. Better cities make better groups and fewer regions showing up as cities.
3. **Later, if wanted:** add `created_at` to `place_list_items` (a real migration) so list adds count toward "recently added". Also consider renaming the concept: a `saved_places` view over `favorites` keeps the old name out of new code.

## Rollout via PostHog
1. Add tracking first: `place_saved` already fires from the favorites write. Add `saved_add_to_list_tapped`, `saved_library_opened`, `saved_group_opened`, and list creations.
2. Ship an App Store build where the gate is the **flag only** (drop the admin and TestFlight checks). Flag off means today's behavior exactly.
3. Ramp the flag: internal cohort, then 5%, 25%, 50%, 100% over about 2 weeks. Watch saves per active user, list creations, Saved opens, crash-free rate and D7 retention against control.
4. Kill switch: turning the flag off brings back the list picker on the bookmark. Saved rows stay in `favorites` and still show (as Favorites) in builds that have that tab.

## Risks
- **Favorites meaning:** App Store builds before the profile redesign still show a **Favorites** tab and map filter. One-tap saves would show up there as "Favorites". Ship the profile redesign first (or together), or relabel that tab "Saved".
- **City quality:** heuristic address parsing. Expect some regions shown as cities, cities spelled differently not merging (Athens and Athina), and a long tail of 1-place cities. The backfill above fixes most of it.
- **Performance:** users with thousands of places pull every place to the phone. Today that's fine (~1,000 places). Beyond that, add a paged or server-side endpoint.
- **PostHog outages:** the flag defaults off, so the old flow is safe.
- **Discoverability:** users who relied on choosing a list at save time now need the banner's Add to list. Watch list-creation rates.
