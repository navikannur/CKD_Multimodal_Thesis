-- ------------------------------------------------------------------
-- Source: https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iii/concepts/demographics/icustay_detail.sql
-- Modifications of original that were needed: YEAR to 'YEAR', DAY to 'DAY',
-- `physionet-data.mimiciii_clinical.icustays` to mimiciii.icustays,
-- `physionet-data.mimiciii_clinical.admissions` to mimiciii.admissions, and
-- `physionet-data.mimiciii_clinical.patients` to mimiciii.patients
-- Additionally, the original has been complemented slightly (all modifications are clearly stated)
-- To create this table under the schema mimiciii with command: \i path_to_file/flicu_icustay_detail.sql
-- Modified by Lena Mondrejevski, 02/04/2022
-- (Used for paper FLICU: A Federated Learning Workflow for ICU Mortality Prediction)
-- ------------------------------------------------------------------
-- Title: Detailed information on ICUSTAY_ID
-- Description: This query provides a useful set of information regarding patient
--              ICU stays. The information is combined from the admissions, patients, and
--              icustays tables. It includes age, length of stay, sequence, and expiry flags.
-- MIMIC version: MIMIC-III v1.3
-- ------------------------------------------------------------------

-- MODIFICATION: Rename icustay_detail to flicu_icustay_detail (as originial is adjusted)
-- CREATE TABLE icustay_detail AS




CREATE TABLE flicu_icustay_detail AS

-- This query extracts useful demographic/administrative information for patient ICU stays

SELECT ie.subject_id, ie.hadm_id, ie.icustay_id

-- patient level factors
, pat.gender, pat.dod

-- hospital level factors
, adm.admittime, adm.dischtime
, DATETIME_DIFF(adm.dischtime, adm.admittime, 'DAY') as los_hospital
, DATETIME_DIFF(ie.intime, pat.dob, 'YEAR') as admission_age
, adm.ethnicity
, case when ethnicity in
  (
       'WHITE' --  40996
     , 'WHITE - RUSSIAN' --    164
     , 'WHITE - OTHER EUROPEAN' --     81
     , 'WHITE - BRAZILIAN' --     59
     , 'WHITE - EASTERN EUROPEAN' --     25
  ) then 'white'
  when ethnicity in
  (
      'BLACK/AFRICAN AMERICAN' --   5440
    , 'BLACK/CAPE VERDEAN' --    200
    , 'BLACK/HAITIAN' --    101
    , 'BLACK/AFRICAN' --     44
    , 'CARIBBEAN ISLAND' --      9
  ) then 'black'
  when ethnicity in
    (
      'HISPANIC OR LATINO' --   1696
    , 'HISPANIC/LATINO - PUERTO RICAN' --    232
    , 'HISPANIC/LATINO - DOMINICAN' --     78
    , 'HISPANIC/LATINO - GUATEMALAN' --     40
    , 'HISPANIC/LATINO - CUBAN' --     24
    , 'HISPANIC/LATINO - SALVADORAN' --     19
    , 'HISPANIC/LATINO - CENTRAL AMERICAN (OTHER)' --     13
    , 'HISPANIC/LATINO - MEXICAN' --     13
    , 'HISPANIC/LATINO - COLOMBIAN' --      9
    , 'HISPANIC/LATINO - HONDURAN' --      4
	,'SOUTH AMERICAN' --     8
  ) then 'hispanic'
  when ethnicity in
  (
      'ASIAN' --   1509
    , 'ASIAN - CHINESE' --    277
    , 'ASIAN - ASIAN INDIAN' --     85
    , 'ASIAN - VIETNAMESE' --     53
    , 'ASIAN - FILIPINO' --     25
    , 'ASIAN - CAMBODIAN' --     17
    , 'ASIAN - OTHER' --     17
    , 'ASIAN - KOREAN' --     13
    , 'ASIAN - JAPANESE' --      7
    , 'ASIAN - THAI' --      4
  ) then 'asian'
  when ethnicity in
  (
       'AMERICAN INDIAN/ALASKA NATIVE' --     51
     , 'AMERICAN INDIAN/ALASKA NATIVE FEDERALLY RECOGNIZED TRIBE' --      3
  ) then 'alaska_native'
  when ethnicity in
  (
      'UNKNOWN/NOT SPECIFIED' --   4523
    , 'UNABLE TO OBTAIN' --    814
    , 'PATIENT DECLINED TO ANSWER' --    559
	, 'OTHER' --   1512
	, 'MULTI RACE ETHNICITY' --    130v
  ) then 'unknown'
  when ethnicity in
  (
      'PORTUGUESE' --   4523
  ) then 'portuguese'
  when ethnicity in
  (
      'MIDDLE EASTERN' --     43
  ) then 'middle_eastern'
  when ethnicity in
  (
      'NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER' --     18
  ) then 'pacific_islander'
  else 'other' end as ethnicity_grouped
, adm.hospital_expire_flag
, DENSE_RANK() OVER (PARTITION BY adm.subject_id ORDER BY adm.admittime) AS hospstay_seq
, CASE
    WHEN DENSE_RANK() OVER (PARTITION BY adm.subject_id ORDER BY adm.admittime) = 1 THEN True
    ELSE False END AS first_hosp_stay

-- icu level factors
, ie.intime, ie.outtime
, DATETIME_DIFF(ie.outtime, ie.intime, 'DAY') as los_icu
, DENSE_RANK() OVER (PARTITION BY ie.hadm_id ORDER BY ie.intime) AS icustay_seq

-- first ICU stay *for the current hospitalization*
, CASE
    WHEN DENSE_RANK() OVER (PARTITION BY ie.hadm_id ORDER BY ie.intime) = 1 THEN True
    -- MODIFICATION: Renamed first_icu_stay to first_icu_stay_current_hosp
    --ELSE False END AS first_icu_stay
    ELSE False END AS first_icu_stay_current_hosp

-- MODIFICATION: Very first ICU stay of a patient --> One icu stay per patient!
-- first ICU stay *for the patient*
, CASE
    WHEN DENSE_RANK() OVER (PARTITION BY ie.subject_id ORDER BY ie.intime) = 1 THEN True
    ELSE False END AS first_icu_stay_patient

-- MODIFICATION: First care unit for being able to filter for NICU/PICU
-- (last care unit is irrelevant as we only consider the first ICU stay per patient and hospitalization)
, ie.first_careunit

-- MODIFICATION: Added the deathtime in the ICU for label/window extraction
, CASE 
    WHEN ie.intime <= adm.deathtime and adm.deathtime <= ie.outtime THEN adm.deathtime
    END AS deathtime_icu

-- MODIFICATION: Added the labels ICU death (1) and survival (0)
-- We identify our labels by the deathtime variable in the admission table of MIMIC-III:
-- Death during hospital admission but only within intervall of current ICU stay
, CASE 
    WHEN ie.intime <= adm.deathtime and adm.deathtime <= ie.outtime THEN 1
    ELSE 0
    END AS label_death_icu
	
FROM mimiciii.icustays ie
INNER JOIN mimiciii.admissions adm
    ON ie.hadm_id = adm.hadm_id
INNER JOIN mimiciii.patients pat
    ON ie.subject_id = pat.subject_id
	
WHERE adm.has_chartevents_data = 1
ORDER BY ie.subject_id, adm.admittime, ie.intime;


------------------------Coronart_artery_label creation ------------------------
CREATE TABLE mimiciii.diagnoses_icd_cor_art AS
SELECT
    t.subject_id,
    t.hadm_id,
    t.label_cor_art
FROM
    (SELECT
        DISTINCT subject_id, hadm_id,
        CASE
            WHEN icd.icd9_code IN ('74685', '41401', '41406', '41412', '4142', '74685') THEN 1
            ELSE 0
        END AS label_cor_art
     FROM
        mimiciii.diagnoses_icd icd) t
JOIN
    (SELECT hadm_id, MAX(label_cor_art) AS coronary_artery
     FROM (SELECT
               DISTINCT subject_id, hadm_id,
               CASE
                   WHEN icd.icd9_code IN ('74685', '41401', '41406', '41412', '4142', '74685') THEN 1
                   ELSE 0
               END AS label_cor_art
           FROM
               mimiciii.diagnoses_icd icd) col
     GROUP BY hadm_id) max_codes
ON t.hadm_id = max_codes.hadm_id AND t.label_cor_art = max_codes.coronary_artery;

ALTER TABLE mimiciii.flicu_icustay_detail ADD COLUMN label_cor_art INTEGER;

UPDATE mimiciii.flicu_icustay_detail ficu SET label_cor_art = dcor.label_cor_art
FROM mimiciii.diagnoses_icd_cor_art dcor WHERE ficu.hadm_id = dcor.hadm_id;

DROP TABLE IF EXISTS mimiciii.diagnoses_icd_cor_art;


------------------------diabetes_mellitus creation ------------------------
CREATE TABLE icd_codes (
  icd_code VARCHAR(10) PRIMARY KEY,
  icd_code_type VARCHAR(50)
);

INSERT INTO icd_codes (icd_code, icd_code_type)
VALUES 
    ('24900', 'diabetes_mellitus'),
    ('24901', 'diabetes_mellitus'),
    ('24910', 'diabetes_mellitus'),
    ('24911', 'diabetes_mellitus'),
    ('24920', 'diabetes_mellitus'),
    ('24921', 'diabetes_mellitus'),
    ('24930', 'diabetes_mellitus'),
    ('24931', 'diabetes_mellitus'),
    ('24940', 'diabetes_mellitus'),
    ('24941', 'diabetes_mellitus'),
    ('24950', 'diabetes_mellitus'),
    ('24951', 'diabetes_mellitus'),
    ('24960', 'diabetes_mellitus'),
    ('24961', 'diabetes_mellitus'),
    ('24970', 'diabetes_mellitus'),
    ('24971', 'diabetes_mellitus'),
    ('24980', 'diabetes_mellitus'),
    ('24981', 'diabetes_mellitus'),
    ('24990', 'diabetes_mellitus'),
    ('24991', 'diabetes_mellitus'),
    ('25000', 'diabetes_mellitus'),
    ('25001', 'diabetes_mellitus'),
    ('25002', 'diabetes_mellitus'),
    ('25003', 'diabetes_mellitus'),
    ('64800', 'diabetes_mellitus'),
    ('64801', 'diabetes_mellitus'),
    ('64802', 'diabetes_mellitus'),
    ('64803', 'diabetes_mellitus'),
    ('64804', 'diabetes_mellitus'),
    ('7751', 'diabetes_mellitus');

ALTER TABLE flicu_icustay_detail
ADD COLUMN diabetes_mellitus INTEGER;

UPDATE flicu_icustay_detail
SET diabetes_mellitus =
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM diagnoses_icd d
            JOIN icd_codes c ON d.icd9_code = c.icd_code
            WHERE d.hadm_id = flicu_icustay_detail.hadm_id
            AND c.icd_code_type = 'diabetes_mellitus'
        ) THEN 1
        ELSE 0
    END;
DROP TABLE IF EXISTS mimiciii.icd_codes;

-----------------------------------CKD label-----------------------------------
CREATE TABLE ckd_icd_codes (
icd_code VARCHAR(10) PRIMARY KEY,
icd_code_type VARCHAR(50)
);

INSERT INTO ckd_icd_codes (icd_code, icd_code_type)
VALUES
('5851', 'chronic_kidney_disease'),
('5852', 'chronic_kidney_disease'),
('5853', 'chronic_kidney_disease'),
('5854', 'chronic_kidney_disease'),
('5855', 'chronic_kidney_disease'),
('5859', 'chronic_kidney_disease');

ALTER TABLE flicu_icustay_detail
ADD COLUMN ckd INTEGER;

UPDATE flicu_icustay_detail
SET ckd =
CASE
WHEN EXISTS (
SELECT 1
FROM diagnoses_icd d
JOIN ckd_icd_codes c ON d.icd9_code = c.icd_code
WHERE d.hadm_id = flicu_icustay_detail.hadm_id
AND c.icd_code_type = 'chronic_kidney_disease'
) THEN 1
ELSE 0
END;
DROP TABLE IF EXISTS mimiciii.ckd_icd_codes;


-- Create table for anemia ICD9 codes
CREATE TABLE anemia (
  icd_code VARCHAR(10) PRIMARY KEY,
  icd_code_type VARCHAR(50)
);

-- Insert ICD9 codes for anemia
INSERT INTO anemia (icd_code, icd_code_type)
VALUES 
    ('2839', 'anemia'),
    ('2800', 'anemia'),
    ('2801', 'anemia'),
    ('2808', 'anemia'),
    ('2809', 'anemia'),
    ('2810', 'anemia'),
    ('2811', 'anemia'),
    ('2812', 'anemia'),
    ('2813', 'anemia'),
    ('2814', 'anemia'),
    ('2818', 'anemia'),
    ('2819', 'anemia'),
    ('2822', 'anemia'),
    ('2823', 'anemia'),
    ('28310', 'anemia'),
    ('28319', 'anemia'),
    ('28409', 'anemia'),
    ('28489', 'anemia'),
    ('2849', 'anemia'),
    ('2850', 'anemia'),
    ('2851', 'anemia'),
    ('7735', 'anemia'),
    ('7765', 'anemia');

-- Add new column to flicu_icustay_detail for anemia flag
ALTER TABLE flicu_icustay_detail
ADD COLUMN anemia_flag INTEGER;

-- Update anemia flag based on ICD9 codes in diagnoses_icd table
UPDATE flicu_icustay_detail
SET anemia_flag =
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM diagnoses_icd d
            JOIN anemia a ON d.icd9_code = a.icd_code
            WHERE d.hadm_id = flicu_icustay_detail.hadm_id
            AND a.icd_code_type = 'anemia'
        ) THEN 1
        ELSE 0
    END;

-- Drop temporary table for anemia ICD9 codes
DROP TABLE IF EXISTS anemia;