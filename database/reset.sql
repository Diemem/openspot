-- ============================================================
-- OpenSpot Nuclear Reset — skips extension-owned objects
-- ⚠️  WARNING: All app data will be lost
-- ============================================================

-- Drop auth trigger first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop everything NOT owned by an extension in one shot
DO $$
DECLARE
  r RECORD;
BEGIN
  -- Tables
  FOR r IN
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename NOT IN (
        SELECT c.relname FROM pg_depend d
        JOIN pg_extension e ON e.oid = d.refobjid
        JOIN pg_class c ON c.oid = d.objid
        WHERE d.deptype = 'e' AND c.relkind IN ('r','v','m')
      )
  LOOP
    EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;

  -- Views
  FOR r IN
    SELECT table_name FROM information_schema.views
    WHERE table_schema = 'public'
      AND table_name NOT IN (
        SELECT c.relname FROM pg_depend d
        JOIN pg_extension e ON e.oid = d.refobjid
        JOIN pg_class c ON c.oid = d.objid
        WHERE d.deptype = 'e' AND c.relkind IN ('r','v','m')
      )
  LOOP
    EXECUTE 'DROP VIEW IF EXISTS public.' || quote_ident(r.table_name) || ' CASCADE';
  END LOOP;

  -- Functions
  FOR r IN
    SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        JOIN pg_extension e ON e.oid = d.refobjid
        WHERE d.objid = p.oid AND d.deptype = 'e'
      )
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS public.' || quote_ident(r.proname) || '(' || r.args || ') CASCADE';
  END LOOP;

  -- Sequences
  FOR r IN
    SELECT sequence_name FROM information_schema.sequences
    WHERE sequence_schema = 'public'
      AND sequence_name NOT IN (
        SELECT c.relname FROM pg_depend d
        JOIN pg_extension e ON e.oid = d.refobjid
        JOIN pg_class c ON c.oid = d.objid
        WHERE d.deptype = 'e'
      )
  LOOP
    EXECUTE 'DROP SEQUENCE IF EXISTS public.' || quote_ident(r.sequence_name) || ' CASCADE';
  END LOOP;

  -- Enum types
  FOR r IN
    SELECT t.typname FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typtype = 'e'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        JOIN pg_extension e ON e.oid = d.refobjid
        WHERE d.objid = t.oid AND d.deptype = 'e'
      )
  LOOP
    EXECUTE 'DROP TYPE IF EXISTS public.' || quote_ident(r.typname) || ' CASCADE';
  END LOOP;

END;
$$;

-- Verify
SELECT COUNT(*) AS tables_remaining
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT IN (
    SELECT c.relname FROM pg_depend d
    JOIN pg_extension e ON e.oid = d.refobjid
    JOIN pg_class c ON c.oid = d.objid
    WHERE d.deptype = 'e'
  );

-- Should be 0. Now run schema.sql then seed.sql
