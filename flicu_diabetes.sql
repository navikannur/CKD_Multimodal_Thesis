CREATE TABLE icd_codes (
  icd_code VARCHAR(10) PRIMARY KEY,
  icd_code_type VARCHAR(50)
);

-- NEED TO CHANGE CORONARY 
INSERT INTO icd_codes (icd_code, icd_code_type) VALUES ('410', 'coronary_artery_disease');
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
ADD COLUMN coronary_artery_disease BOOLEAN,
ADD COLUMN diabetes_mellitus BOOLEAN;

UPDATE flicu_icustay_detail
SET coronary_artery_disease = 
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM diagnoses_icd d
            JOIN icd_codes c ON d.icd9_code = c.icd_code
            WHERE d.hadm_id = flicu_icustay_detail.hadm_id
            AND c.icd_code_type = 'coronary_artery_disease'
        ) THEN TRUE
        ELSE FALSE
    END,
    diabetes_mellitus =
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM diagnoses_icd d
            JOIN icd_codes c ON d.icd9_code = c.icd_code
            WHERE d.hadm_id = flicu_icustay_detail.hadm_id
            AND c.icd_code_type = 'diabetes_mellitus'
        ) THEN TRUE
        ELSE FALSE
    END;