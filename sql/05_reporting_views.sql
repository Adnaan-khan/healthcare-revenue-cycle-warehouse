-- =====================================================================
-- 05_reporting_views.sql
-- Purpose : Dashboard-ready views consumed by the Power BI report.
-- =====================================================================

-- 1. One row per appointment with provider, location, payer, payments,
--    unpaid balance, and payment status
CREATE OR REPLACE VIEW `healthcare_ops_demo.appointment_financials` AS
WITH payment_by_appointment AS (
  SELECT
    appointment_id,
    SUM(payment_amount)                  AS total_paid,
    STRING_AGG(DISTINCT payer_type, ', ') AS payer_type,
    MAX(payment_date)                    AS last_payment_date
  FROM `healthcare_ops_demo.Payment`
  GROUP BY appointment_id
)
SELECT
  ap.appointment_id,
  ap.patient_id,
  ap.appointment_date,
  ap.visit_type,
  ap.appointment_status,
  ap.charge_amount,

  pr.provider_name,
  pr.specialty,

  l.location_name,
  l.city,
  l.state,

  p.payer_type,
  p.last_payment_date,
  COALESCE(p.total_paid, 0)                                 AS total_paid,
  GREATEST(ap.charge_amount - COALESCE(p.total_paid, 0), 0) AS unpaid_balance,

  CASE
    WHEN COALESCE(p.total_paid, 0) = 0              THEN 'No Payment'
    WHEN COALESCE(p.total_paid, 0) < ap.charge_amount THEN 'Partially Paid'
    ELSE 'Paid in Full'
  END AS payment_status
FROM `healthcare_ops_demo.appointments_clean` AS ap
LEFT JOIN payment_by_appointment AS p          ON ap.appointment_id = p.appointment_id
LEFT JOIN `healthcare_ops_demo.Provider` AS pr ON ap.provider_id   = pr.provider_id
LEFT JOIN `healthcare_ops_demo.Location` AS l  ON ap.location_id   = l.location_id;


-- 2. Latest A/R aging snapshot with location attributes
CREATE OR REPLACE VIEW `healthcare_ops_demo.ar_aging_latest` AS
WITH latest_snapshot AS (
  SELECT MAX(snapshot_month) AS latest_month
  FROM `healthcare_ops_demo.Ar_SnpShot`
)
SELECT
  ar.ar_id,
  ar.appointment_id,
  ar.snapshot_month,
  ar.days_in_ar,
  ar.aging_bucket,
  ar.balance_amount,

  l.location_name,
  l.city,
  l.state
FROM `healthcare_ops_demo.Ar_SnpShot` AS ar
CROSS JOIN latest_snapshot AS ls
LEFT JOIN `healthcare_ops_demo.Location` AS l ON ar.location_id = l.location_id
WHERE ar.snapshot_month = ls.latest_month;
