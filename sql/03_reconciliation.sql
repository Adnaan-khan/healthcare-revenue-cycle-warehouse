-- =====================================================================
-- 03_reconciliation.sql
-- Purpose : Check that tables relate correctly and that financial totals
--           tie out across appointments, payments, and the A/R snapshot.
-- =====================================================================

-- 1. Referential integrity: records that do not match across tables
SELECT 'Payments with no matching appointment' AS check_name,
       COUNT(*) AS record_count
FROM `healthcare_ops_demo.Payment` AS p
LEFT JOIN `healthcare_ops_demo.appointments_clean` AS ap
  ON p.appointment_id = ap.appointment_id
WHERE ap.appointment_id IS NULL

UNION ALL

SELECT 'Appointments with no payment',
       COUNT(*)
FROM `healthcare_ops_demo.appointments_clean` AS ap
LEFT JOIN `healthcare_ops_demo.Payment` AS p
  ON ap.appointment_id = p.appointment_id
WHERE p.appointment_id IS NULL;
-- Findings:
--   * 1 orphan payment (PAY99999 -> APT99999, $125.00) has no appointment.
--   * 1,647 appointments have no payment: 1,194 are No Show / Cancelled
--     visits with a $0 charge, and 453 are completed visits still unpaid.


-- 2. Overall financial summary: charged, paid, unpaid, collection rate
WITH payment_by_appointment AS (
  SELECT appointment_id, SUM(payment_amount) AS total_paid
  FROM `healthcare_ops_demo.Payment`
  GROUP BY appointment_id
)
SELECT
  COUNT(*)                                                    AS total_appointments,
  ROUND(SUM(ap.charge_amount), 2)                             AS total_charged,
  ROUND(SUM(COALESCE(p.total_paid, 0)), 2)                    AS total_paid,
  ROUND(SUM(ap.charge_amount - COALESCE(p.total_paid, 0)), 2) AS unpaid_balance,
  ROUND(SAFE_DIVIDE(SUM(COALESCE(p.total_paid, 0)),
                    SUM(ap.charge_amount)) * 100, 2)          AS collection_rate_percent
FROM `healthcare_ops_demo.appointments_clean` AS ap
LEFT JOIN payment_by_appointment AS p
  ON ap.appointment_id = p.appointment_id;
-- Result: 3,570 appointments | $513,590.30 charged | $338,806.43 paid
--         | $174,783.87 unpaid | 65.97% collection rate


-- 3. Tie-out: latest A/R snapshot balance vs. calculated unpaid balance
WITH payment_by_appointment AS (
  SELECT appointment_id, SUM(payment_amount) AS total_paid
  FROM `healthcare_ops_demo.Payment`
  GROUP BY appointment_id
),
calculated AS (
  SELECT ROUND(SUM(GREATEST(ap.charge_amount - COALESCE(p.total_paid, 0), 0)), 2) AS unpaid_from_transactions
  FROM `healthcare_ops_demo.appointments_clean` AS ap
  LEFT JOIN payment_by_appointment AS p
    ON ap.appointment_id = p.appointment_id
),
snapshot AS (
  SELECT ROUND(SUM(balance_amount), 2) AS ar_snapshot_balance
  FROM `healthcare_ops_demo.Ar_SnpShot`
  WHERE snapshot_month = (SELECT MAX(snapshot_month) FROM `healthcare_ops_demo.Ar_SnpShot`)
)
SELECT
  c.unpaid_from_transactions,
  s.ar_snapshot_balance,
  ROUND(c.unpaid_from_transactions - s.ar_snapshot_balance, 2) AS variance
FROM calculated AS c
CROSS JOIN snapshot AS s;
-- Result: $174,783.87 vs. $174,783.87 -> variance $0.00 (fully reconciled)
