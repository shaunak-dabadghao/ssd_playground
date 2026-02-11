-- R01: Fixed Fee amount in [$200, $2,000,000] USD
-- Data: cog (offer-level). Filter: Fixed Fee only; cohort = published in date range.
-- Violation: any offer amount < 200 or > 2,000,000

WITH cohort AS (
  SELECT
    offer_group_id,
    shop_id,
    product_id,
    financing_type,
    amounts_usd_array,
  FROM `shopify-dw.money_products.capital_offer_groups` AS cog
  WHERE
    -- Fixed Fee only (exclude Flex)
    cog.financing_type != 'FlexFinancing'
    -- Cohort: e.g. published in last 7 days; adjust as needed
    AND cog.first_published_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
),
unnested AS (
  SELECT
    offer_group_id,
    shop_id,
    product_id,
    amount_usd,
  FROM cohort,
    UNNEST(amounts_usd_array) AS amount_usd
)
SELECT
  offer_group_id,
  shop_id,
  product_id,
  'R01' AS rule_id,
  amount_usd AS actual_value,
  '200 to 2000000' AS expected_value,
  CASE
    WHEN amount_usd < 200 THEN 'below_min'
    WHEN amount_usd > 2000000 THEN 'above_max'
  END AS violation_type
FROM unnested
WHERE amount_usd < 200 OR amount_usd > 2000000
ORDER BY offer_group_id, amount_usd;
