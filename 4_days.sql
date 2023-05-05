CREATE TABLE icustay_4days AS
SELECT *
FROM flicu_icustay_detail
WHERE los_icu >= 4;

CREATE TABLE pivoted_lab_4days AS
SELECT *
FROM ckd_pivoted_lab
WHERE icustay_id IN (
  SELECT icustay_id
  FROM flicu_icustay_detail
  WHERE los_icu >= 4
);

CREATE TABLE pivoted_vital_4days AS
SELECT *
FROM pivoted_vital
WHERE icustay_id IN (
  SELECT icustay_id
  FROM flicu_icustay_detail
  WHERE los_icu >= 4
);