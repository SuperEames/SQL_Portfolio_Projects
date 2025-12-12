/*
Dataset : Medical Insurance Cost Dataset
Source : https://www.kaggle.com/datasets/mosapabdelghany/medical-insurance-cost-dataset
*/

CREATE TABLE stg_insurance (
    age         INTEGER,
    sex         TEXT,
    bmi         NUMERIC(5,2),
    children    INTEGER,
    smoker      TEXT,
    region      TEXT,
    charges     NUMERIC(10,2)
);

-- Purpose: Transform staging rows into a small star-schema for analysis.
-- Drop old tables to allow re-runs
DROP TABLE IF EXISTS dim_age_group CASCADE;
DROP TABLE IF EXISTS dim_bmi_category CASCADE;
DROP TABLE IF EXISTS dim_region CASCADE;
DROP TABLE IF EXISTS dim_smoker CASCADE;
DROP TABLE IF EXISTS dim_sex CASCADE;
DROP TABLE IF EXISTS fact_premiums CASCADE;

-- Dimension: Age Groups
CREATE TABLE dim_age_group (
    age_group_id  SERIAL PRIMARY KEY,
    age_min       INTEGER,
    age_max       INTEGER,
    label         TEXT
);

INSERT INTO dim_age_group (age_min, age_max, label) VALUES
    (18, 24, '18-24'),
    (25, 34, '25-34'),
    (35, 44, '35-44'),
    (45, 54, '45-54'),
    (55, 64, '55-64'),
    (65, 120, '65+');

-- Dimension: BMI Category (NIH-style cutoffs)
CREATE TABLE dim_bmi_category (
    bmi_cat_id  SERIAL PRIMARY KEY,
    bmi_min     NUMERIC(5,2),
    bmi_max     NUMERIC(5,2),
    label       TEXT
);

INSERT INTO dim_bmi_category (bmi_min, bmi_max, label) VALUES
    (0.00, 18.49, 'Underweight'),
    (18.50, 24.99, 'Normal'),
    (25.00, 29.99, 'Overweight'),
    (30.00, 100.00, 'Obese');

-- Dimension: Region
CREATE TABLE dim_region (
    region_id  SERIAL PRIMARY KEY,
    region     TEXT UNIQUE
);

INSERT INTO dim_region (region)
SELECT DISTINCT region
FROM stg_insurance
WHERE region IS NOT NULL;

-- Dimension: Smoker
CREATE TABLE dim_smoker (
    smoker_id  SERIAL PRIMARY KEY,
    smoker     TEXT UNIQUE
);

INSERT INTO dim_smoker (smoker)
SELECT DISTINCT smoker
FROM stg_insurance
WHERE smoker IS NOT NULL;

-- Dimension: Sex
CREATE TABLE dim_sex (
    sex_id  SERIAL PRIMARY KEY,
    sex     TEXT UNIQUE
);

INSERT INTO dim_sex (sex)
SELECT DISTINCT sex
FROM stg_insurance
WHERE sex IS NOT NULL;

-- Fact table
CREATE TABLE fact_premiums (
    fact_id        BIGSERIAL PRIMARY KEY,
    age_group_id   INTEGER NOT NULL REFERENCES dim_age_group(age_group_id),
    bmi_cat_id     INTEGER NOT NULL REFERENCES dim_bmi_category(bmi_cat_id),
    region_id      INTEGER NOT NULL REFERENCES dim_region(region_id),
    smoker_id      INTEGER NOT NULL REFERENCES dim_smoker(smoker_id),
    sex_id         INTEGER NOT NULL REFERENCES dim_sex(sex_id),
    -- Original attributes and measures
    age            INTEGER,
    bmi            NUMERIC(5,2),
    children       INTEGER,
    charges        NUMERIC(10,2)
);

-- Helper: map age->age_group_id
WITH age_buckets AS (
    SELECT a.*, g.age_group_id
    FROM stg_insurance a
    JOIN dim_age_group g
      ON a.age BETWEEN g.age_min AND g.age_max
),
bmi_buckets AS (
    SELECT a.*, c.bmi_cat_id
    FROM age_buckets a
    JOIN dim_bmi_category c
      ON a.bmi >= c.bmi_min AND a.bmi <= c.bmi_max
)
INSERT INTO fact_premiums (
    age_group_id, bmi_cat_id, region_id, smoker_id, sex_id,
    age, bmi, children, charges
)
SELECT
    b.bmi_cat_id,
    b.bmi_cat_id,
    r.region_id,
    s.smoker_id,
    x.sex_id,
    b.age, b.bmi, b.children, b.charges
FROM bmi_buckets b
JOIN dim_region r ON r.region = b.region
JOIN dim_smoker s ON s.smoker = b.smoker
JOIN dim_sex x    ON x.sex    = b.sex;

-- Oops: Correct the age_group_id selection (previous SELECT mistakenly put bmi_cat twice)
-- Let's fix by updating from the age_buckets table:
WITH fixed AS (
  SELECT f.fact_id, g.age_group_id
  FROM fact_premiums f
  JOIN stg_insurance st ON st.age = f.age AND st.bmi = f.bmi AND st.children = f.children AND st.charges = f.charges
  JOIN dim_age_group g ON st.age BETWEEN g.age_min AND g.age_max
)
UPDATE fact_premiums f
  SET age_group_id = fixed.age_group_id
FROM fixed
WHERE f.fact_id = fixed.fact_id;

-- Indexes
CREATE INDEX ON fact_premiums (age_group_id);
CREATE INDEX ON fact_premiums (bmi_cat_id);
CREATE INDEX ON fact_premiums (region_id);
CREATE INDEX ON fact_premiums (smoker_id);
CREATE INDEX ON fact_premiums (sex_id);

SELECT 'stg_insurance' AS table, COUNT(*) AS rows FROM stg_insurance
UNION ALL
SELECT 'dim_age_group', COUNT(*) FROM dim_age_group
UNION ALL
SELECT 'dim_bmi_category', COUNT(*) FROM dim_bmi_category
UNION ALL
SELECT 'dim_region', COUNT(*) FROM dim_region
UNION ALL
SELECT 'dim_smoker', COUNT(*) FROM dim_smoker
UNION ALL
SELECT 'dim_sex', COUNT(*) FROM dim_sex
UNION ALL
SELECT 'fact_premiums', COUNT(*) FROM fact_premiums;

-- Null checks on keys
SELECT COUNT(*) AS null_keys
FROM fact_premiums
WHERE age_group_id IS NULL
   OR bmi_cat_id IS NULL
   OR region_id IS NULL
   OR smoker_id IS NULL
   OR sex_id IS NULL;

-- Reasonable ranges
SELECT
  MIN(age) AS min_age, MAX(age) AS max_age,
  MIN(bmi) AS min_bmi, MAX(bmi) AS max_bmi,
  MIN(charges) AS min_charges, MAX(charges) AS max_charges
FROM fact_premiums;


-- Average charges by smoker

SELECT 
    s.smoker,
    ROUND(AVG(f.charges),2) AS avg_charges, COUNT(*) AS n
FROM   
    fact_premiums f
JOIN dim_smoker s ON s.smoker_id = f.smoker_id
WHERE
    f.charges IS NOT NULL
GROUP BY 
    s.smoker
ORDER BY 
    avg_charges DESC;

/*
Here 's breakdown of the Smokers ("yes")
Average medical charges: $32,050.23
Sample size: 274 individuals
This is ~3.8x higher than non-smokers.
And Non-Smokers ("no")
Average medical charges: $8,434.27
Sample size: 1064 individuals
Much lower average costs, and also a larger group size.

-- Key Insights
Smokers have dramatically higher costs – almost 4 times higher than non-smokers.
Dataset size difference – more non-smokers (1064) than smokers (274), but the cost gap is still very large.
This result strongly suggests that smoking status is a major driver of medical costs in this dataset.

RESULTS
=======

[
  {
    "smoker": "yes",
    "avg_charges": "32050.23",
    "n": "274"
  },
  {
    "smoker": "no",
    "avg_charges": "8434.27",
    "n": "1064"
  }
]

*/

-- Average charges by region
SELECT 
    r.region, 
    ROUND(AVG(f.charges),2) AS avg_charges, COUNT(*) AS n
FROM 
    fact_premiums f
JOIN dim_region r ON r.region_id = f.region_id
WHERE
    f.charges IS NOT NULL
    AND r.region IS NOT NULL
    AND f.charges >= 0
GROUP BY 
    r.region
ORDER BY 
    avg_charges DESC;

/*
Here's the breakdown of average charges by region
Southeast Highest average charges: $14,735.41
Sample size: 364 people 
Suggests healthcare costs here are significantly above other regions.

Northeast
Average charges: $13,406.38
Sample size: 324
Second highest cost region.

Northwest
Average charges: $12,417.58
Sample size: 325
Similar to southwest.

Southwest
Lowest average charges: $12,346.94
Sample size: 325
Still close to northwest, only slightly lower.

-- Key Insights
Regional differences exist: Southeast has noticeably higher medical charges compared to other regions (about $2,400 more than Southwest on average).
Other regions are fairly close: Northeast, Northwest, and Southwest cluster together with averages between $12K–13.4K.
This suggests geography influences medical costs, possibly due to healthcare pricing differences, demographics, or lifestyle factors.

RESULTS
=======

[
  {
    "region": "southeast",
    "avg_charges": "14735.41",
    "n": "364"
  },
  {
    "region": "northeast",
    "avg_charges": "13406.38",
    "n": "324"
  },
  {
    "region": "northwest",
    "avg_charges": "12417.58",
    "n": "325"
  },
  {
    "region": "southwest",
    "avg_charges": "12346.94",
    "n": "325"
  }
]

*/

-- Average charges by BMI category and smoker

SELECT 
    c.label AS bmi_category, 
    s.smoker,
    ROUND(AVG(f.charges),2) AS avg_charges, COUNT(*) AS n
FROM 
    fact_premiums f
JOIN dim_bmi_category c ON c.bmi_cat_id = f.bmi_cat_id
JOIN dim_smoker s ON s.smoker_id = f.smoker_id
WHERE
    f.charges IS NOT NULL
    AND c.label IS NOT NULL
    AND smoker IS NOT NULL
GROUP BY 
    c.label, 
    s.smoker
ORDER BY 
    c.label, 
    s.smoker;

/*
Here's the breakdown of average charges by BMI category and smoker:
Effect of Smoker : In every BMI category, smokers have much higher charges than non-smokers.
Example:Obese non-smokers: $8,842
Obese smokers: $41,558 (almost 5× higher).

Effect of BMI: Within non-smokers:costs rise from Underweight ($5,532) → Normal ($7,686) → Overweight ($8,258) → Obese ($8,843).
This shows higher BMI tends to increase costs, even for non-smokers.
Within smokers:Underweight: $18,809 Normal: $19,942 Overweight: $22,496 Obese: $41,558 (highest overall group).

Highest-risk group
Obese smokers → $41,557.99 average charges.
Smallest group = Underweight smokers (5 people), but still high charges ($18,809).

-- Key Insights
Smoker is the strongest driver of higher costs, across all BMI categories.
Charges for smokers are 2.5×–5× higher than non-smokers in the same BMI group.
BMI adds another layer: costs rise with weight class, especially for smokers.
The most expensive combination: Obese + Smoker.
The least expensive: Underweight + Non-smoker.

RESULTS
=======

[
  {
    "bmi_category": "Normal",
    "smoker": "no",
    "avg_charges": "7685.66",
    "n": "175"
  },
  {
    "bmi_category": "Normal",
    "smoker": "yes",
    "avg_charges": "19942.22",
    "n": "50"
  },
  {
    "bmi_category": "Obese",
    "smoker": "no",
    "avg_charges": "8842.69",
    "n": "562"
  },
  {
    "bmi_category": "Obese",
    "smoker": "yes",
    "avg_charges": "41557.99",
    "n": "145"
  },
  {
    "bmi_category": "Overweight",
    "smoker": "no",
    "avg_charges": "8257.96",
    "n": "312"
  },
  {
    "bmi_category": "Overweight",
    "smoker": "yes",
    "avg_charges": "22495.87",
    "n": "74"
  },
  {
    "bmi_category": "Underweight",
    "smoker": "no",
    "avg_charges": "5532.99",
    "n": "15"
  },
  {
    "bmi_category": "Underweight",
    "smoker": "yes",
    "avg_charges": "18809.83",
    "n": "5"
  }
]

*/

-- Children impact: average charges by number of children, split by smoker.

SELECT 
    f.children, 
    s.smoker, 
    ROUND(AVG(f.charges),2) AS avg_charges, COUNT(*) AS n
FROM 
    fact_premiums f
JOIN dim_smoker s ON s.smoker_id = f.smoker_id
WHERE
    f.children IS NOT NULL
    AND s.smoker IS NOT NULL 
GROUP BY 
    f.children, 
    s.smoker
ORDER BY 
    f.children, 
    s.smoker;

/*
Here 's the breakdown of average charges by number of children, split by smoker status:
Smoker vs Non-Smoker:Across all children counts, smokers always pay far higher charges.
Example:
    0 children: smokers → $31,341 vs non-smokers → $7,612.
    2 children: smokers → $33,844 vs non-smokers → $9,493.

Impact of Children
For non-smokers:Charges gradually rise with children (up to 4 children, $12,121).
Slight drop at 5 children ($8,184), but sample size is very small (17).

For smokers:Charges are high across all groups (~$26K–34K), not strongly tied to number of children.
Exception: only 1 smoker with 5 children ($19K), so that number is not reliable.

Highest-risk group:Smokers with 2 children → $33,844 average charges.
Non-smokers with 4 children → $12,121, the highest among non-smokers.

-- Key Insights
Smokers dominates costs: number of children has some effect, but smokers is still the biggest driver.
Non-smokers show a gradual increase in charges as children increase (likely due to family-related health expenses).
Smokers remain expensive regardless of children, but the effect of children is much weaker.

RESULTS
=======

[
  {
    "children": 0,
    "smoker": "no",
    "avg_charges": "7611.79",
    "n": "459"
  },
  {
    "children": 0,
    "smoker": "yes",
    "avg_charges": "31341.36",
    "n": "115"
  },
  {
    "children": 1,
    "smoker": "no",
    "avg_charges": "8303.11",
    "n": "263"
  },
  {
    "children": 1,
    "smoker": "yes",
    "avg_charges": "31822.65",
    "n": "61"
  },
  {
    "children": 2,
    "smoker": "no",
    "avg_charges": "9493.09",
    "n": "185"
  },
  {
    "children": 2,
    "smoker": "yes",
    "avg_charges": "33844.24",
    "n": "55"
  },
  {
    "children": 3,
    "smoker": "no",
    "avg_charges": "9614.52",
    "n": "118"
  },
  {
    "children": 3,
    "smoker": "yes",
    "avg_charges": "32724.92",
    "n": "39"
  },
  {
    "children": 4,
    "smoker": "no",
    "avg_charges": "12121.34",
    "n": "22"
  },
  {
    "children": 4,
    "smoker": "yes",
    "avg_charges": "26532.28",
    "n": "3"
  },
  {
    "children": 5,
    "smoker": "no",
    "avg_charges": "8183.85",
    "n": "17"
  },
  {
    "children": 5,
    "smoker": "yes",
    "avg_charges": "19023.26",
    "n": "1"
  }
]

*/

-- Age group & BMI category interaction on average charges.

SELECT 
    g.label AS age_group, c.label AS bmi_category,
    ROUND(AVG(f.charges),2) AS avg_charges, COUNT(*) AS n
FROM 
    fact_premiums f
JOIN dim_age_group g ON g.age_group_id = f.age_group_id
JOIN dim_bmi_category c ON c.bmi_cat_id = f.bmi_cat_id
WHERE
    f.charges IS NOT NULL 
    AND g.label IS NOT NULL
    AND c.label IS NOT NULL 
    AND f.charges >= 0
GROUP BY 
    g.label, 
    c.label
ORDER BY 
    g.label, 
    c.label;

/*
Here's the breakdown of age group and BMI category interaction on average charges:
-- Age increases charges: In every BMI category, average charges rise with age.
Example (Obese):
    18–24 → $11,383
    25–34 → $12,525
    35–44 → $15,796
    45–54 → $17,310
    55–64 → $20,089
Clear upward trend with age.

-- BMI effect within age groups :
    Obese individuals consistently have the highest costs in each age group.
    Underweight sometimes spikes (25–34 group has $13,722, but only 5 people, so not reliable).
    Normal and Overweight usually sit in the middle.

-- Strongest risk group :
    Obese, age 55–64 → $20,089 average charges, 147 people.
    Safest group: Young (18–24) + Underweight → $3,772 average charges, but very small sample size (7 people).

-- Key Insights
Both age and BMI independently raise medical costs → the combination has a compounding effect.
Obese patients show a steady rise in charges with age, reaching nearly 2× more than obese young adults by age 55–64.
Normal-weight young adults have the lowest costs, supporting the dataset’s pattern that healthy weight + younger age → lower costs.
Sample sizes (n) matter: small groups (like underweight) may show unusual spikes due to limited data.

RESULT
======

[
  {
    "age_group": "18-24",
    "bmi_category": "Normal",
    "avg_charges": "5832.64",
    "n": "55"
  },
  {
    "age_group": "18-24",
    "bmi_category": "Obese",
    "avg_charges": "11383.93",
    "n": "142"
  },
  {
    "age_group": "18-24",
    "bmi_category": "Overweight",
    "avg_charges": "7316.73",
    "n": "74"
  },
  {
    "age_group": "18-24",
    "bmi_category": "Underweight",
    "avg_charges": "3771.62",
    "n": "7"
  },
  {
    "age_group": "25-34",
    "bmi_category": "Normal",
    "avg_charges": "8959.50",
    "n": "55"
  },
  {
    "age_group": "25-34",
    "bmi_category": "Obese",
    "avg_charges": "12524.89",
    "n": "129"
  },
  {
    "age_group": "25-34",
    "bmi_category": "Overweight",
    "avg_charges": "7663.47",
    "n": "82"
  },
  {
    "age_group": "25-34",
    "bmi_category": "Underweight",
    "avg_charges": "13722.00",
    "n": "5"
  },
  {
    "age_group": "35-44",
    "bmi_category": "Normal",
    "avg_charges": "11056.63",
    "n": "42"
  },
  {
    "age_group": "35-44",
    "bmi_category": "Obese",
    "avg_charges": "15795.71",
    "n": "127"
  },
  {
    "age_group": "35-44",
    "bmi_category": "Overweight",
    "avg_charges": "10422.90",
    "n": "87"
  },
  {
    "age_group": "35-44",
    "bmi_category": "Underweight",
    "avg_charges": "9414.57",
    "n": "4"
  },
  {
    "age_group": "45-54",
    "bmi_category": "Normal",
    "avg_charges": "14007.83",
    "n": "47"
  },
  {
    "age_group": "45-54",
    "bmi_category": "Obese",
    "avg_charges": "17309.87",
    "n": "162"
  },
  {
    "age_group": "45-54",
    "bmi_category": "Overweight",
    "avg_charges": "14050.99",
    "n": "76"
  },
  {
    "age_group": "45-54",
    "bmi_category": "Underweight",
    "avg_charges": "9817.65",
    "n": "2"
  },
  {
    "age_group": "55-64",
    "bmi_category": "Normal",
    "avg_charges": "15607.18",
    "n": "26"
  },
  {
    "age_group": "55-64",
    "bmi_category": "Obese",
    "avg_charges": "20088.56",
    "n": "147"
  },
  {
    "age_group": "55-64",
    "bmi_category": "Overweight",
    "avg_charges": "16368.18",
    "n": "67"
  },
  {
    "age_group": "55-64",
    "bmi_category": "Underweight",
    "avg_charges": "12369.58",
    "n": "2"
  }
]

*/

-- Top 10 highest charges 

SELECT 
    f.charges, 
    f.age, 
    f.bmi, 
    f.children, 
    s.smoker, 
    x.sex, 
    r.region
FROM 
    fact_premiums f
JOIN dim_smoker s ON s.smoker_id = f.smoker_id
JOIN dim_sex x    ON x.sex_id = f.sex_id
JOIN dim_region r ON r.region_id = f.region_id
WHERE
    f.charges IS NOT NULL
    AND f.age IS NOT NULL
    AND f.bmi IS NOT NULL
    AND f.children IS NOT NULL
    AND s.smoker IS NOT NULL
    AND x.sex IS NOT NULL
    AND r.region IS NOT NULL
    AND f.charges >= 0
ORDER BY 
    f.charges DESC
LIMIT 10;

/*
Here 's the breakdown of the top 10 highest charges:
Smokers (every row has smoker = 'yes').
Obese BMI range (all BMI ≥ 30; several > 40).
Mostly mid–older ages (44–64 dominate; a few at 28–33).
Regions skewed to the Southeast (also Southwest/Northwest/Northeast appear).
Children count varies (0–3) and doesn’t explain the extreme charges.
Example rows you have:
    $63,770 — age 54, BMI 47.41, 0 children, female, southeast, smoker.
    $62,593 — age 45, BMI 30.36, 0 children, male, southeast, smoker.
    $60,021 — age 52, BMI 34.49, 3 children, male, northwest, smoker.

-- key Insights
Smoking is the common factor among the costliest cases (10/10).
High BMI compounds costs: every top-10 case is obese; several are morbidly obese (BMI ≥ 40).
Age matters: most are 44–64, reinforcing the trend that charges rise with age.
Geography: the Southeast appears most often among the most expensive cases.

RESULT
======

[
  {
    "charges": "63770.43",
    "age": 54,
    "bmi": "47.41",
    "children": 0,
    "smoker": "yes",
    "sex": "female",
    "region": "southeast"
  },
  {
    "charges": "62592.87",
    "age": 45,
    "bmi": "30.36",
    "children": 0,
    "smoker": "yes",
    "sex": "male",
    "region": "southeast"
  },
  {
    "charges": "60021.40",
    "age": 52,
    "bmi": "34.49",
    "children": 3,
    "smoker": "yes",
    "sex": "male",
    "region": "northwest"
  },
  {
    "charges": "58571.07",
    "age": 31,
    "bmi": "38.10",
    "children": 1,
    "smoker": "yes",
    "sex": "female",
    "region": "northeast"
  },
  {
    "charges": "55135.40",
    "age": 33,
    "bmi": "35.53",
    "children": 0,
    "smoker": "yes",
    "sex": "female",
    "region": "northwest"
  },
  {
    "charges": "52590.83",
    "age": 60,
    "bmi": "32.80",
    "children": 0,
    "smoker": "yes",
    "sex": "male",
    "region": "southwest"
  },
  {
    "charges": "51194.56",
    "age": 28,
    "bmi": "36.40",
    "children": 1,
    "smoker": "yes",
    "sex": "male",
    "region": "southwest"
  },
  {
    "charges": "49577.66",
    "age": 64,
    "bmi": "36.96",
    "children": 2,
    "smoker": "yes",
    "sex": "male",
    "region": "southeast"
  },
  {
    "charges": "48970.25",
    "age": 59,
    "bmi": "41.14",
    "children": 1,
    "smoker": "yes",
    "sex": "male",
    "region": "southeast"
  },
  {
    "charges": "48885.14",
    "age": 44,
    "bmi": "38.06",
    "children": 0,
    "smoker": "yes",
    "sex": "female",
    "region": "southeast"
  }
]

*/
