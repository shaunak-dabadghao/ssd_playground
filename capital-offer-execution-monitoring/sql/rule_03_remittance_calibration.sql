-- R03+R12: Fixed Fee remittance in [4%, 35%] and <= calibration rate by risk_group, GMV, (Shopify Credit)
-- Calibration: GMV < 1.75M: RG 1-8 -> 25% no SC / 17% with SC; RG 9-10 -> 17%.
--             GMV >= 1.75M: RG 1-4 -> 25%/17%; RG 5-10 -> 17%.
-- If has_shopify_credit unknown, we use 17% where both apply (stricter).
-- Data: cog. Violation: remittance < 0.04 or > 0.35 or > calibration max.

WITH cohort AS (
  SELECT
    offer_group_id,
    shop_id,
    product_id,
    risk_group,
    gmv_usd_l52w,
    remittance_rates_array,
  FROM `shopify-dw.money_products.capital_offer_groups` AS cog
  WHERE
    cog.financing_type != 'FlexFinancing'
    AND cog.first_published_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
),
-- Max remittance (calibration rate). Policy: GMV < 1.75M RG 1-8 -> 25% no SC / 17% with SC; RG 9-10 -> 17%.
-- GMV >= 1.75M RG 1-4 -> 25%/17%; RG 5-10 -> 17%. We assume "with Shopify Credit" (stricter 17%) when unknown.
calibration AS (
  SELECT
    offer_group_id,
    shop_id,
    product_id,
    risk_group,
    gmv_usd_l52w,
    remittance_rate,
    CASE
      WHEN risk_group IS NULL OR risk_group NOT BETWEEN 1 AND 10 THEN 0.17
      WHEN (gmv_usd_l52w IS NULL OR gmv_usd_l52w < 1750000) AND risk_group IN (9, 10) THEN 0.17
      WHEN (gmv_usd_l52w IS NULL OR gmv_usd_l52w < 1750000) AND risk_group BETWEEN 1 AND 8 THEN 0.17  -- with SC
      WHEN gmv_usd_l52w >= 1750000 AND risk_group BETWEEN 5 AND 10 THEN 0.17
      WHEN gmv_usd_l52w >= 1750000 AND risk_group BETWEEN 1 AND 4 THEN 0.17  -- with SC
      ELSE 0.17
    END AS max_remittance
  FROM cohort,
    UNNEST(remittance_rates_array) AS remittance_rate
)
SELECT
  offer_group_id,
  shop_id,
  product_id,
  'R03' AS rule_id,
  remittance_rate AS actual_value,
  CONCAT('0.04 to min(0.35, ', CAST(max_remittance AS STRING), ')') AS expected_value,
  CASE
    WHEN remittance_rate < 0.04 THEN 'below_floor'
    WHEN remittance_rate > 0.35 THEN 'above_ceiling'
    WHEN remittance_rate > max_remittance THEN 'above_calibration'
    ELSE NULL
  END AS violation_type
FROM calibration
WHERE remittance_rate < 0.04
   OR remittance_rate > 0.35
   OR remittance_rate > max_remittance
ORDER BY offer_group_id, remittance_rate;
