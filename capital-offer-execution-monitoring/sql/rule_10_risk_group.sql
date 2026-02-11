-- R10: Fixed Fee risk groups 1-10 only
-- Data: cog. Violation: risk_group IS NULL or not between 1 and 10.

SELECT
  offer_group_id,
  shop_id,
  product_id,
  'R10' AS rule_id,
  CAST(risk_group AS STRING) AS actual_value,
  '1 to 10' AS expected_value,
  CASE
    WHEN risk_group IS NULL THEN 'null_risk_group'
    WHEN risk_group < 1 OR risk_group > 10 THEN 'out_of_range'
    ELSE NULL
  END AS violation_type
FROM `shopify-dw.money_products.capital_offer_groups` AS cog
WHERE
  cog.financing_type != 'FlexFinancing'
  AND cog.first_published_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND (cog.risk_group IS NULL OR cog.risk_group < 1 OR cog.risk_group > 10)
ORDER BY offer_group_id;
