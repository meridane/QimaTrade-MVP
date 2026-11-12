-- QA364: read-only CREATE_OFFER bootstrap catalog preflight.
-- expected_database is supplied by psql (-v expected_database=...).
-- Extension-owned routines/types are not treated as application residue.
SELECT CASE
  WHEN current_database() <> :'expected_database' THEN 'wrong_database'
  WHEN EXISTS (
    SELECT 1
    FROM pg_namespace n
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'public')
      AND n.nspname NOT LIKE 'pg_toast%'
      AND n.nspname NOT LIKE 'pg_temp_%'
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f', 'c')
      AND (
        c.relkind <> 'c'
        OR NOT EXISTS (
          SELECT 1
          FROM pg_type t
          JOIN pg_depend d
            ON d.classid = 'pg_type'::regclass
           AND d.objid = t.oid
           AND d.refclassid = 'pg_extension'::regclass
           AND d.deptype = 'e'
          WHERE t.typrelid = c.oid
        )
      )
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.classid = 'pg_proc'::regclass
          AND d.objid = p.oid
          AND d.refclassid = 'pg_extension'::regclass
          AND d.deptype = 'e'
      )
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typtype IN ('b', 'd', 'e', 'r', 'm')
      AND t.typelem = 0
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        WHERE d.classid = 'pg_type'::regclass
          AND d.objid = t.oid
          AND d.refclassid = 'pg_extension'::regclass
          AND d.deptype = 'e'
      )
  ) THEN 'not_empty'
  ELSE 'empty'
END;
