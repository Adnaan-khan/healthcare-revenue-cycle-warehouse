-- =====================================================================
-- 02_data_cleaning.sql
-- Purpose : Investigate the duplicate appointment and build a clean view.
-- =====================================================================

-- 1. Show every row whose appointment_id appears more than once
SELECT *
FROM `healthcare_ops_demo.appointments`
WHERE appointment_id IN (
  SELECT appointment_id
  FROM `healthcare_ops_demo.appointments`
  GROUP BY appointment_id
  HAVING COUNT(*) > 1
);
-- Finding: the two rows are identical in every column -> a true duplicate,
--          safe to remove with DISTINCT.


-- 2. Create a de-duplicated appointments view used by all downstream queries
CREATE OR REPLACE VIEW `healthcare_ops_demo.appointments_clean` AS
SELECT DISTINCT
  appointment_id,
  location_id,
  provider_id,
  patient_id,
  appointment_date,
  visit_type,
  appointment_status,
  charge_amount
FROM `healthcare_ops_demo.appointments`;


-- 3. Validate: row count must now equal the distinct appointment_id count
SELECT
  COUNT(*)                       AS row_count,
  COUNT(DISTINCT appointment_id) AS unique_ids
FROM `healthcare_ops_demo.appointments_clean`;
-- Result: 3,570 rows / 3,570 unique ids -> duplicate removed.
