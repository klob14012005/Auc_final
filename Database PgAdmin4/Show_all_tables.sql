SELECT
    table_name,
    column_name,
    udt_name AS data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND data_type = 'USER-DEFINED'
ORDER BY table_name;
