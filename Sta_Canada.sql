CREATE OR REPLACE VIEW retail_base AS

SELECT
    retail_raw.REF_DATE AS Date,
    retail_raw.GEO AS location,
    CAST(retail_raw.VALUE AS DECIMAL(15,2)) AS value,
    retail_raw.Sales AS Sales,
    retail_raw.Adjustments AS Adjustments,
    retail_raw.`North American Industry Classification System (NAICS)` AS NAICS
FROM retail_raw
WHERE retail_raw.REF_DATE BETWEEN '2019' AND '2026'
  AND retail_raw.GEO IN (
                         'Canada',
                         'Ontario',
                         'Quebec',
                         'British Columbia',
                         'Alberta'
    )
  AND retail_raw.VALUE IS NOT NULL
  AND retail_raw.Sales = 'Total retail sales'
  AND retail_raw.Adjustments = 'Seasonally adjusted'
  AND retail_raw.`North American Industry Classification System (NAICS)` = 'Retail trade [44-45]';

CREATE or replace view retail_yoy as(

SELECT
    STR_TO_DATE(CONCAT(current.Date, '-01'), '%Y-%m-%d') AS Date,
    current.location,
    current.value AS current_value,
    previous.value AS previous_year_value,
    (current.value - previous.value) / previous.value * 100 AS YoY
FROM retail_base current
         LEFT JOIN retail_base previous
                   ON YEAR(STR_TO_DATE(CONCAT(current.Date, '-01'), '%Y-%m-%d'))
                          = YEAR(STR_TO_DATE(CONCAT(previous.Date, '-01'), '%Y-%m-%d')) + 1
                       AND MONTH(STR_TO_DATE(CONCAT(current.Date, '-01'), '%Y-%m-%d'))
                          = MONTH(STR_TO_DATE(CONCAT(previous.Date, '-01'), '%Y-%m-%d'))
                       AND current.location = previous.location);



create or replace view retail_mom as

SELECT
    Date,
    location,
    value AS current_value,
    LAG(value) OVER (
        PARTITION BY location
        ORDER BY Date
        ) AS previous_month_value,
    (value - LAG(value) OVER (
     PARTITION BY location
     ORDER BY Date
         )) / LAG(value) OVER (
        PARTITION BY location
        ORDER BY Date
        ) * 100 AS MoM
FROM retail_base;

CREATE OR REPLACE VIEW retail_rolling AS

SELECT
    Date,
    location,
    value,
    AVG(value) OVER (
        PARTITION BY location
        ORDER BY Date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS three_month_rolling_average
FROM retail_base;

CREATE OR REPLACE VIEW retail_ranking AS

SELECT
    Date,
    location,
    value,
    DENSE_RANK() OVER (
        PARTITION BY Date
        ORDER BY value DESC
        ) AS sales_rank
FROM retail_base
WHERE location != 'Canada';

-- ==================== E-COMMERCE ANALYSIS ====================

create or replace view retail_ecommerce as

SELECT
    retail_raw.REF_DATE AS Date,
    retail_raw.GEO AS location,
    CAST(retail_raw.VALUE AS DECIMAL(15,2)) AS value,
    retail_raw.Sales AS Sales,
    retail_raw.Adjustments AS Adjustments,
    retail_raw.`North American Industry Classification System (NAICS)` AS NAICS
FROM retail_raw
WHERE retail_raw.REF_DATE BETWEEN '2019' AND '2026'
  AND retail_raw.GEO = 'Canada'
  AND retail_raw.VALUE IS NOT NULL
  AND retail_raw.Sales = 'Retail e-commerce sales'
  AND retail_raw.Adjustments = 'Seasonally adjusted'
  AND retail_raw.`North American Industry Classification System (NAICS)` = 'Retail trade [44-45]';

create or replace view ecommerce_analysis as

select retail_base.Date Date,
       retail_base.location location,
       retail_base.Sales Total_Sales,
       retail_base.value Total_value,
       retail_ecommerce.Sales Ecommerce_Sales,
       retail_ecommerce.value Ecommerce_value,
       retail_ecommerce.value / retail_base.value * 100 ecommerce_share
from retail_base left join retail_ecommerce on retail_base.Date = retail_ecommerce.Date AND retail_base.location = retail_ecommerce.location
where retail_base.location = 'Canada';
