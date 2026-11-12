-- QA366: read-only CREATE_OFFER bootstrap catalog preflight.
-- expected_database is supplied by psql (-v expected_database=...).
-- Extension-owned non-relation catalog objects are not treated as application residue.
-- Public relations remain disallowed, including extension-owned configuration tables.
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
  WHEN EXISTS (
    SELECT 1
    FROM pg_operator o
    JOIN pg_namespace n ON n.oid = o.oprnamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.classid = 'pg_operator'::regclass
          AND d.objid = o.oid
          AND d.refclassid = 'pg_extension'::regclass
          AND d.deptype = 'e'
      )
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_opclass c
    JOIN pg_namespace n ON n.oid = c.opcnamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.classid = 'pg_opclass'::regclass
          AND d.objid = c.oid
          AND d.refclassid = 'pg_extension'::regclass
          AND d.deptype = 'e'
      )
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_opfamily f
    JOIN pg_namespace n ON n.oid = f.opfnamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.classid = 'pg_opfamily'::regclass
          AND d.objid = f.oid
          AND d.refclassid = 'pg_extension'::regclass
          AND d.deptype = 'e'
      )
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_collation c
    JOIN pg_namespace n ON n.oid = c.collnamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.classid = 'pg_collation'::regclass
          AND d.objid = c.oid
          AND d.refclassid = 'pg_extension'::regclass
          AND d.deptype = 'e'
      )
  ) THEN 'not_empty'
  -- Publications are database-scoped rather than schema-scoped; any
  -- non-extension publication means this disposable database is initialized.
  WHEN EXISTS (
    SELECT 1
    FROM pg_publication p
    WHERE NOT EXISTS (
      SELECT 1 FROM pg_depend d
      WHERE d.classid = 'pg_publication'::regclass
        AND d.objid = p.oid
        AND d.refclassid = 'pg_extension'::regclass
        AND d.deptype = 'e'
    )
  ) THEN 'not_empty'
  -- Text-search dictionaries/configurations and conversions can exist
  -- without ordinary relations, so inspect their public namespace explicitly.
  WHEN EXISTS (
    SELECT 1
    FROM pg_ts_dict tsd
    JOIN pg_namespace n ON n.oid = tsd.dictnamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend dep
        WHERE dep.classid = 'pg_ts_dict'::regclass
          AND dep.objid = tsd.oid
          AND dep.refclassid = 'pg_extension'::regclass
          AND dep.deptype = 'e'
      )
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_ts_config tsc
    JOIN pg_namespace n ON n.oid = tsc.cfgnamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend dep
        WHERE dep.classid = 'pg_ts_config'::regclass
          AND dep.objid = tsc.oid
          AND dep.refclassid = 'pg_extension'::regclass
          AND dep.deptype = 'e'
      )
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_conversion conv
    JOIN pg_namespace n ON n.oid = conv.connamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend dep
        WHERE dep.classid = 'pg_conversion'::regclass
          AND dep.objid = conv.oid
          AND dep.refclassid = 'pg_extension'::regclass
          AND dep.deptype = 'e'
      )
  ) THEN 'not_empty'
  -- Large objects are database-local data and are not extension members.
  -- Even an empty large object has a metadata row and means the disposable
  -- bootstrap database is no longer pristine.
  WHEN EXISTS (
    SELECT 1
    FROM pg_largeobject_metadata
  ) THEN 'not_empty'
  -- Foreign-data wrappers and servers are database-level objects. Ignore
  -- extension-owned wrappers/servers, but reject independently created ones.
  WHEN EXISTS (
    SELECT 1
    FROM pg_foreign_data_wrapper fdw
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_depend d
      WHERE d.classid = 'pg_foreign_data_wrapper'::regclass
        AND d.objid = fdw.oid
        AND d.refclassid = 'pg_extension'::regclass
        AND d.deptype = 'e'
    )
  ) THEN 'not_empty'
  WHEN EXISTS (
    SELECT 1
    FROM pg_foreign_server srv
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_depend d
      WHERE d.classid = 'pg_foreign_server'::regclass
        AND d.objid = srv.oid
        AND d.refclassid = 'pg_extension'::regclass
        AND d.deptype = 'e'
    )
  ) THEN 'not_empty'
  -- A user mapping can remain even when its server is extension-owned;
  -- detect it independently instead of relying only on the server guard.
  WHEN EXISTS (
    SELECT 1
    FROM pg_user_mapping um
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_depend d
      WHERE d.classid = 'pg_user_mapping'::regclass
        AND d.objid = um.oid
        AND d.refclassid = 'pg_extension'::regclass
        AND d.deptype = 'e'
    )
  ) THEN 'not_empty'
  -- pg_subscription is shared across the cluster; only subscriptions owned by
  -- the current database are bootstrap residue. Connection details are not read.
  WHEN EXISTS (
    SELECT 1
    FROM pg_subscription s
    WHERE s.subdbid = (
      SELECT db.oid
      FROM pg_database db
      WHERE db.datname = current_database()
    )
  ) THEN 'not_empty'
  -- Replication slots are cluster-wide. Only logical slots carry a database OID;
  -- physical slots have no database owner and must not poison every database.
  WHEN EXISTS (
    SELECT 1
    FROM pg_replication_slots s
    WHERE s.slot_type = 'logical'
      AND s.datoid = (
        SELECT db.oid
        FROM pg_database db
        WHERE db.datname = current_database()
      )
  ) THEN 'not_empty'
  -- pg_db_role_setting is shared across databases. Only settings whose
  -- setdatabase matches current_database() are database-local residue;
  -- setdatabase = 0 represents cluster-wide role defaults and is excluded.
  WHEN EXISTS (
    SELECT 1
    FROM pg_db_role_setting s
    WHERE s.setdatabase = (
      SELECT db.oid
      FROM pg_database db
      WHERE db.datname = current_database()
    )
  ) THEN 'not_empty'
  -- Default privileges are stored per database. Both database-wide
  -- (defaclnamespace = 0) and schema-specific entries affect future objects.
  WHEN EXISTS (
    SELECT 1
    FROM pg_default_acl
  ) THEN 'not_empty'
  -- pg_parameter_acl is shared cluster-wide and has no database ownership key.
  -- It is characterized separately and is not a database-local preflight predicate.
  -- Extension configuration tables registered in pg_extension.extconfig are
  -- relations: public relations are rejected above, while non-default schemas
  -- are rejected by the namespace guard. extcondition is pg_dump row-filter
  -- metadata and is intentionally not evaluated dynamically by this preflight.
  ELSE 'empty'
END;
