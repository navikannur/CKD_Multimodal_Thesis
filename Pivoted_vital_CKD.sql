[1:56 pm, 27/04/2023] Aakruti: CREATE TABLE pivoted_vital AS

with ce as
(
  select ce.icustay_id
    , ce.charttime
    , (case when itemid in (211,220045) and valuenum > 0 and valuenum < 300 then valuenum else null end) as heartrate
    , (case when itemid in (51,442,455,6701,220179,220050) and valuenum > 0 and valuenum < 400 then valuenum else null end) as sysbp
    , (case when itemid in (8368,8440,8441,8555,220180,220051) and valuenum > 0 and valuenum < 300 then valuenum else null end) as diasbp
    , (case when itemid in (456,52,6702,443,220052,220181,225312) and valuenum > 0 and valuenum < 300 then valuenum else null end) as meanbp
    , (case when itemid in (615,618,220210,224690) and valuenum > 0 and valuenum < 70 then valuenum else null end) as resprate
    , (case when itemid i…
[2:10 pm, 27/04/2023] Aakruti: CREATE TABLE pivoted_vital AS

with ce as
(
  select ce.icustay_id
    , ce.charttime
    , (case when itemid in (211,220045) and valuenum > 0 and valuenum < 300 then valuenum else null end) as heartrate
    , (case when itemid in (51,442,455,6701,220179,220050) and valuenum > 0 and valuenum < 400 then valuenum else null end) as sysbp
    , (case when itemid in (8368,8440,8441,8555,220180,220051) and valuenum > 0 and valuenum < 300 then valuenum else null end) as diasbp
    , (case when itemid in (456,52,6702,443,220052,220181,225312) and valuenum > 0 and valuenum < 300 then valuenum else null end) as meanbp
    , (case when itemid in (615,618,220210,224690) and valuenum > 0 and valuenum < 70 then valuenum else null end) as resprate
    , (case when itemid in (223761,678) and valuenum > 70 and valuenum < 120 then (valuenum-32)/1.8 -- converted to degC in valuenum call
               when itemid in (223762,676) and valuenum > 10 and valuenum < 50  then valuenum else null end) as tempc
    , (case when itemid in (646,220277) and valuenum > 0 and valuenum <= 100 then valuenum else null end) as spo2
    , (case when itemid in (807,811,1529,3745,3744,225664,220621,226537) and valuenum > 0 then valuenum else null end) as glucose
	, (case when itemid in (3799) and valuenum < 5 then valuenum else null end) as rbc
	, (case when itemid in (227471) and valuenum < 1.03 then valuenum else null end) as specificgravity
	, (case when itemid in (6870) and valuenum < 3 then valuenum else null end) as pedaledema
	, (CASE
    WHEN value = 'Poor' THEN 1
    WHEN value = 'Fair' THEN 2
    WHEN value = 'Good' THEN 3
    WHEN value = 'Very Good' THEN 4
    ELSE NULL
	END) AS appetite_numeric
  FROM mimiciii.chartevents ce
  -- exclude rows marked as error
  where (ce.error IS NULL OR ce.error != 1)
  and ce.icustay_id IS NOT NULL
  and ce.itemid in
  (
  -- HEART RATE
  211, --"Heart Rate"
  220045, --"Heart Rate"

  -- Systolic/diastolic

  51, --	Arterial BP [Systolic]
  442, --	Manual BP [Systolic]
  455, --	NBP [Systolic]
  6701, --	Arterial BP #2 [Systolic]
  220179, --	Non Invasive Blood Pressure systolic
  220050, --	Arterial Blood Pressure systolic

  8368, --	Arterial BP [Diastolic]
  8440, --	Manual BP [Diastolic]
  8441, --	NBP [Diastolic]
  8555, --	Arterial BP #2 [Diastolic]
  220180, --	Non Invasive Blood Pressure diastolic
  220051, --	Arterial Blood Pressure diastolic


  -- MEAN ARTERIAL PRESSURE
  456, --"NBP Mean"
  52, --"Arterial BP Mean"
  6702, --	Arterial BP Mean #2
  443, --	Manual BP Mean(calc)
  220052, --"Arterial Blood Pressure mean"
  220181, --"Non Invasive Blood Pressure mean"
  225312, --"ART BP mean"

  -- RESPIRATORY RATE
  618,--	Respiratory Rate
  615,--	Resp Rate (Total)
  220210,--	Respiratory Rate
  224690, --	Respiratory Rate (Total)


  -- spo2, peripheral
  646, 220277,

  -- glucose, both lab and fingerstick
  807,--	Fingerstick glucose
  811,--	glucose (70-105)
  1529,--	glucose
  3745,--	Bloodglucose
  3744,--	Blood glucose
  225664,--	glucose finger stick
  220621,--	glucose (serum)
  226537,--	glucose (whole blood)

  -- TEMPERATURE
  223762, -- "Temperature Celsius"
  676,	-- "Temperature C"
  223761, -- "Temperature Fahrenheit"
  678, --	"Temperature F"
  3799, 
  227471,
  6870,
  225120
  )
)
select
    ce.icustay_id
  , ce.charttime
  , avg(heartrate) as heartrate
  , avg(sysbp) as sysbp
  , avg(diasbp) as diasbp
  , avg(meanbp) as meanbp
  , avg(resprate) as resprate
  , avg(tempc) as tempc
  , avg(spo2) as spo2
  , avg(glucose) as glucose
  , avg(rbc) as rbc
  , avg(specificgravity) as specificgravity
  , avg(pedaledema) as pedaledema
  , percentile_cont(0.5) WITHIN GROUP (ORDER BY appetite_numeric) as appetite_median
from ce
group by ce.icustay_id, ce.charttime
order by ce.icustay_id, ce.charttime;