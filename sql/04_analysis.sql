-- =====================================================================
-- 04_analysis.sql
-- Purpose : Revenue cycle analysis by provider, location, A/R aging, month.
-- =====================================================================

-- 1. Financial performance by provider
WITH payment_by_appointment AS (
  SELECT appointment_id, SUM(payment_amount) AS total_paid
  FROM `healthcare_ops_demo.Payment`
  GROUP BY appointment_id
)
SELECT
  pr.provider_name,
  pr.specialty,
  COUNT(*)                                                    AS appointment_count,
  ROUND(SUM(ap.charge_amount), 2)                             AS total_charged,
  ROUND(SUM(COALESCE(p.total_paid, 0)), 2)                    AS total_paid,
  ROUND(SUM(ap.charge_amount - COALESCE(p.total_paid, 0)), 2) AS unpaid_balance,
  ROUND(SAFE_DIVIDE(SUM(COALESCE(p.total_paid, 0)),
                    SUM(ap.charge_amount)) * 100, 2)          AS collection_rate_percent
FROM `healthcare_ops_demo.appointments_clean` AS ap
LEFT JOIN payment_by_appointment AS p  ON ap.appointment_id = p.appointment_id
LEFT JOIN `healthcare_ops_demo.Provider` AS pr ON ap.provider_id = pr.provider_id
GROUP BY pr.provider_name, pr.specialty
ORDER BY total_charged DESC;


-- 2. Financial performance by location
WITH payment_by_appointment AS (
  SELECT appointment_id, SUM(payment_amount) AS total_paid
  FROM `healthcare_ops_demo.Payment`
  GROUP BY appointment_id
)
SELECT
  l.location_name,
  l.city,
  l.state,
  COUNT(*)                                                    AS appointment_count,
  ROUND(SUM(ap.charge_amount), 2)                             AS total_charged,
  ROUND(SUM(COALESCE(p.total_paid, 0)), 2)                    AS total_paid,
  ROUND(SUM(ap.charge_amount - COALESCE(p.total_paid, 0)), 2) AS unpaid_balance,
  ROUND(SAFE_DIVIDE(SUM(COALESCE(p.total_paid, 0)),
                    SUM(ap.charge_amount)) * 100, 2)          AS collection_rate_percent
FROM `healthcare_ops_demo.appointments_clean` AS ap
LEFT JOIN payment_by_appointment AS p  ON ap.appointment_id = p.appointment_id
LEFT JOIN `healthcare_ops_demo.Location` AS l ON ap.location_id = l.location_id
GROUP BY l.location_name, l.city, l.state
ORDER BY unpaid_balance DESC;


-- 3. A/R aging distribution for the latest snapshot
WITH latest_snapshot AS (
  SELECT MAX(snapshot_month) AS latest_month
  FROM `healthcare_ops_demo.Ar_SnpShot`
)
SELECT
  ar.aging_bucket,
  COUNT(*)                         AS ar_accounts,
  ROUND(SUM(ar.balance_amount), 2) AS total_ar_balance,
  ROUND(SAFE_DIVIDE(SUM(ar.balance_amount),
                    SUM(SUM(ar.balance_amount)) OVER ()) * 100, 2) AS percent_of_total_ar
FROM `healthcare_ops_demo.Ar_SnpShot` AS ar
CROSS JOIN latest_snapshot AS ls
WHERE ar.snapshot_month = ls.latest_month
GROUP BY ar.aging_bucket
ORDER BY
  CASE ar.aging_bucket
    WHEN '0-30'   THEN 1
    WHEN '31-60'  THEN 2
    WHEN '61-90'  THEN 3
    WHEN '91-120' THEN 4
    WHEN '121+'   THEN 5
    ELSE 6
  END;


-- 4. Locations with the most aged A/R (over 90 days) -> follow-up priority
WITH latest_snapshot AS (
  SELECT MAX(snapshot_month) AS latest_month
  FROM `healthcare_ops_demo.Ar_SnpShot`
)
SELECT
  l.location_name,
  l.city,
  l.state,
  COUNT(*)                         AS accounts_over_90_days,
  ROUND(SUM(ar.balance_amount), 2) AS balance_over_90_days
FROM `healthcare_ops_demo.Ar_SnpShot` AS ar
CROSS JOIN latest_snapshot AS ls
LEFT JOIN `healthcare_ops_demo.Location` AS l ON ar.location_id = l.location_id
WHERE ar.snapshot_month = ls.latest_month
  AND ar.days_in_ar > 90
GROUP BY l.location_name, l.city, l.state
ORDER BY balance_over_90_days DESC;
-- Finding: Clayton Primary Care carries the most A/R over 90 days (~$15.0K).


-- 5. Appointment volume and charges by month and status
SELECT
  DATE_TRUNC(appointment_date, MONTH) AS appointment_month,
  appointment_status,
  COUNT(*)                            AS appointment_count,
  ROUND(SUM(charge_amount), 2)        AS total_charged
FROM `healthcare_ops_demo.appointments_clean`
GROUP BY appointment_month, appointment_status
ORDER BY appointment_month, appointment_status;
