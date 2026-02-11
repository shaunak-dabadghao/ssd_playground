-- R02: Fixed Fee factor rate in [3%, 21%] i.e. [0.03, 0.21]
-- Data: cog (offer-level). Filter: Fixed Fee only; cohort = published in date range.
-- Violation: any factor rate < 0.03 or > 0.21

WITH cohort AS (
  SELECT
    offer_group_id,
    shop_id,
    product_id,
    factor_rates_array,
  FROM `shopify-dw.money_products.capital_offer_groups` AS cog
  WHERE
    cog.financing_type != 'FlexFinancing'
    AND cog.first_published_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
),
unnested AS (
  SELECT
    offer_group_id,
    shop_id,
    product_id,
    rate AS factor_rate,
  FROM cohort,
    UNNEST(factor_rates_array) AS rate
)
SELECT
  offer_group_id,
  shop_id,
  product_id,
  'R02' AS rule_id,
  factor_rate AS actual_value,
  '0.03 to 0.21' AS expected_value,
  CASE
    WHEN factor_rate < 0.03 THEN 'below_min'
    WHEN factor_rate > 0.21 THEN 'above_max'
  END AS violation_type
FROM unnested
WHERE factor_rate < 0.03 OR factor_rate > 0.21
ORDER BY offer_group_id, factor_rate;
