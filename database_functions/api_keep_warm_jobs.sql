-- Keeps the API path and hot data warm between sparse logins.
-- Measured Oct 2026: after ~4 min idle the first REST request took ~780 ms vs ~150 ms warm,
-- and the first login map query took ~780 ms vs ~50 ms warm.
-- Applied as migration: add_api_keep_warm_jobs
-- Remove with: SELECT cron.unschedule('keep-api-warm'); SELECT cron.unschedule('keep-data-warm');

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_prewarm;

-- Trivial endpoint the pings hit, so each ping exercises gateway -> PostgREST -> Postgres.
CREATE OR REPLACE FUNCTION public.keep_warm()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$ SELECT true $$;

GRANT EXECUTE ON FUNCTION public.keep_warm() TO anon, authenticated;

CREATE SCHEMA IF NOT EXISTS ops;
REVOKE ALL ON SCHEMA ops FROM PUBLIC, anon, authenticated;

-- Fires concurrent pings at the REST and Auth APIs so several pooled connections stay open.
-- The key is the public anon key the app already ships with.
CREATE OR REPLACE FUNCTION ops.ping_api(p_concurrency integer DEFAULT 6)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_base text := 'https://posfruqvibklcyfxmdbq.supabase.co';
  v_key  text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvc2ZydXF2aWJrbGN5ZnhtZGJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNDUzNDYsImV4cCI6MjA3NTgyMTM0Nn0.irjABUegI-qhjzJs3QLzP0xdkENcQmXxXmqN0fGHLqQ';
  v_headers jsonb;
BEGIN
  v_headers := jsonb_build_object('apikey', v_key, 'Authorization', 'Bearer ' || v_key);
  FOR i IN 1..p_concurrency LOOP
    PERFORM net.http_get(url := v_base || '/rest/v1/rpc/keep_warm', headers := v_headers, timeout_milliseconds := 5000);
  END LOOP;
  PERFORM net.http_get(url := v_base || '/auth/v1/health', headers := v_headers, timeout_milliseconds := 5000);
END;
$$;

-- Loads the tables and indexes read at login into shared buffers (skips the large external_reviews table).
CREATE OR REPLACE FUNCTION ops.prewarm_hot_relations()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT c.oid
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'i')
      AND c.relname NOT LIKE 'external_reviews%'
      AND c.relname <> 'spatial_ref_sys'
      AND pg_relation_size(c.oid) BETWEEN 1 AND 64 * 1024 * 1024
  LOOP
    PERFORM pg_prewarm(r.oid);
  END LOOP;
END;
$$;

SELECT cron.schedule('keep-api-warm', '30 seconds', $$SELECT ops.ping_api()$$);
SELECT cron.schedule('keep-data-warm', '*/5 * * * *', $$SELECT ops.prewarm_hot_relations()$$);
