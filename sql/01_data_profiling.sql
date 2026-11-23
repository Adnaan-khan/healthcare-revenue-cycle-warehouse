-- =====================================================================
-- 01_data_profiling.sql
-- Purpose : Profile the raw tables loaded into BigQuery before any cleaning.
-- Dataset : healthcare_ops_demo (simulated data, no PHI)
-- =====================================================================

-- 1. Review the schema of every table in the dataset
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable,
  ordinal_position
FROM `healthcare_ops_demo.INFORMATION_SCHEMA.COLUMNS`
ORDER BY table_name, ordinal_position;


-- 2. Row counts, distinct primary keys, and missing primary keys per table
--    If total_rows > unique_ids, the table contains duplicate keys.
SELECT 'appointments' AS table_name,
       COUNT(*)                        AS total_rows,
       COUNT(DISTINCT appointment_id)  AS unique_ids,
       COUNTIF(appointment_id IS NULL) AS missing_ids
FROM `healthcare_ops_demo.appointments`

UNION ALL

SELECT 'Provider',
       COUNT(*),
       COUNT(DISTINCT provider_id),
       COUNTIF(provider_id IS NULL)
FROM `healthcare_ops_demo.Provider`

UNION ALL

SELECT 'Location',
       COUNT(*),
       COUNT(DISTINCT location_id),
       COUNTIF(location_id IS NULL)
FROM `healthcare_ops_demo.Location`

UNION ALL

SELECT 'Payment',
       COUNT(*),
       COUNT(DISTINCT payment_id),
       COUNTIF(payment_id IS NULL)
FROM `healthcare_ops_demo.Payment`

UNION ALL

SELECT 'Ar_SnpShot',
       COUNT(*),
       COUNT(DISTINCT ar_id),
       COUNTIF(ar_id IS NULL)
FROM `healthcare_ops_demo.Ar_SnpShot`;

-- Finding: appointments has 3,571 rows but 3,570 unique appointment_ids
--          -> one duplicate appointment record.
