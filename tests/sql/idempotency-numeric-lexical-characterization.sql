\set ON_ERROR_STOP on

-- QA315: characterize additional numeric lexical forms without selecting a
-- business normalization policy. All checks are read-only expressions against
-- PostgreSQL values; this script creates no rows and changes no database state.
DO $qa315$
DECLARE
  v_numeric_values numeric[] := ARRAY[
    '1'::numeric,
    '1.0'::numeric,
    '1.00'::numeric,
    '1e0'::numeric,
    '10e-1'::numeric,
    '100e-2'::numeric
  ];
  v_json_values jsonb[] := ARRAY[
    '1'::jsonb,
    '1.0'::jsonb,
    '1.00'::jsonb,
    '1e0'::jsonb,
    '10e-1'::jsonb,
    '100e-2'::jsonb
  ];
  v_numeric numeric;
  v_json jsonb;
  v_object jsonb;
  v_array jsonb;
  v_numeric_texts text[] := ARRAY[]::text[];
  v_numeric_hashes text[] := ARRAY[]::text[];
  v_json_texts text[] := ARRAY[]::text[];
  v_json_hashes text[] := ARRAY[]::text[];
  v_object_texts text[] := ARRAY[]::text[];
  v_object_hashes text[] := ARRAY[]::text[];
  v_array_texts text[] := ARRAY[]::text[];
  v_array_hashes text[] := ARRAY[]::text[];
  v_numeric_text_variants integer;
  v_numeric_hash_variants integer;
  v_json_text_variants integer;
  v_json_hash_variants integer;
  v_object_text_variants integer;
  v_object_hash_variants integer;
  v_array_text_variants integer;
  v_array_hash_variants integer;
  v_index integer;
BEGIN
  IF cardinality(v_numeric_values) <> 6 OR cardinality(v_json_values) <> 6 THEN
    RAISE EXCEPTION 'QA315 expected six lexical forms in each numeric matrix';
  END IF;

  FOR v_index IN 1..cardinality(v_numeric_values) LOOP
    v_numeric := v_numeric_values[v_index];
    IF v_numeric IS DISTINCT FROM 1::numeric THEN
      RAISE EXCEPTION 'QA315 numeric lexical form % is not equal to 1', v_numeric::text;
    END IF;
    v_numeric_texts := array_append(v_numeric_texts, v_numeric::text);
    v_numeric_hashes := array_append(v_numeric_hashes, md5(v_numeric::text));

    v_json := v_json_values[v_index];
    IF v_json IS DISTINCT FROM '1'::jsonb THEN
      RAISE EXCEPTION 'QA315 JSONB lexical form % is not equal to JSONB 1', v_json::text;
    END IF;
    v_json_texts := array_append(v_json_texts, v_json::text);
    v_json_hashes := array_append(v_json_hashes, md5(v_json::text));

    v_object := jsonb_build_object('amount', v_json);
    IF v_object IS DISTINCT FROM '{"amount":1}'::jsonb THEN
      RAISE EXCEPTION 'QA315 nested object lexical form % is not equal to the canonical numeric object', v_object::text;
    END IF;
    v_object_texts := array_append(v_object_texts, v_object::text);
    v_object_hashes := array_append(v_object_hashes, md5(v_object::text));

    v_array := jsonb_build_array(v_object);
    IF v_array IS DISTINCT FROM '[{"amount":1}]'::jsonb THEN
      RAISE EXCEPTION 'QA315 nested array lexical form % is not equal to the canonical numeric array', v_array::text;
    END IF;
    v_array_texts := array_append(v_array_texts, v_array::text);
    v_array_hashes := array_append(v_array_hashes, md5(v_array::text));
  END LOOP;

  SELECT count(DISTINCT item) INTO v_numeric_text_variants
  FROM unnest(v_numeric_texts) AS valueset(item);
  SELECT count(DISTINCT item) INTO v_numeric_hash_variants
  FROM unnest(v_numeric_hashes) AS valueset(item);
  SELECT count(DISTINCT item) INTO v_json_text_variants
  FROM unnest(v_json_texts) AS valueset(item);
  SELECT count(DISTINCT item) INTO v_json_hash_variants
  FROM unnest(v_json_hashes) AS valueset(item);
  SELECT count(DISTINCT item) INTO v_object_text_variants
  FROM unnest(v_object_texts) AS valueset(item);
  SELECT count(DISTINCT item) INTO v_object_hash_variants
  FROM unnest(v_object_hashes) AS valueset(item);
  SELECT count(DISTINCT item) INTO v_array_text_variants
  FROM unnest(v_array_texts) AS valueset(item);
  SELECT count(DISTINCT item) INTO v_array_hash_variants
  FROM unnest(v_array_hashes) AS valueset(item);

  -- Do not assert exact rendering for exponent notation across server versions.
  -- Require only the already-characterized property: equality can coexist
  -- with more than one textual serialization and therefore more than one MD5.
  IF v_numeric_text_variants < 2 OR v_numeric_hash_variants < 2 THEN
    RAISE EXCEPTION 'QA315 typed numeric forms did not expose scale-sensitive text/hash variants';
  END IF;
  IF v_json_text_variants < 2 OR v_json_hash_variants < 2 THEN
    RAISE EXCEPTION 'QA315 JSONB numeric forms did not expose scale-sensitive text/hash variants';
  END IF;
  IF v_object_text_variants < 2 OR v_object_hash_variants < 2
     OR v_array_text_variants < 2 OR v_array_hash_variants < 2 THEN
    RAISE EXCEPTION 'QA315 recursive JSONB numeric forms did not preserve lexical text/hash variants';
  END IF;
END
$qa315$;

SELECT 'QA315 numeric scale and exponent lexical-form characterization PASS' AS result;
