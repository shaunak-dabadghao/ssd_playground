-- R17: Renewal - prior financing must have repaid >= 51% of total payment before new funding
-- Data: cf (renewals + prior), cfds (prior's cumulative_transacted and payback at cutoff date).
-- We need: renewal financings (is_renewal = true), link to prior financing (same shop; prior completed or superseded by this one).
-- Prior repaid % = cumulative_transacted_amount_usd / payback_amount_usd at renewal's bank_transfer_date (or day before).

WITH renewal_financings AS (
  SELECT
    cf.financing_id,
    cf.offer_group_id,
    cf.shop_id,
    cf.bank_transfer_date,
    cf.is_renewal,
  FROM `shopify-dw.money_products.capital_financings` AS cf
  WHERE
    cf.financing_type != 'FlexFinancing'
    AND cf.is_renewal = TRUE
    AND cf.bank_transfer_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)  -- cohort window
),
-- Prior financing: same shop, bank_transfer_date < renewal's, order by date desc take first.
prior_financings AS (
  SELECT
    r.financing_id AS renewal_financing_id,
    r.offer_group_id,
    r.shop_id,
    r.bank_transfer_date AS renewal_fund_date,
    p.financing_id AS prior_financing_id,
    p.payback_amount_usd AS prior_payback_usd,
  FROM renewal_financings r
  INNER JOIN `shopify-dw.money_products.capital_financings` p
    ON p.shop_id = r.shop_id
    AND p.financing_type != 'FlexFinancing'
    AND p.bank_transfer_date < r.bank_transfer_date
  QUALIFY ROW_NUMBER() OVER (PARTITION BY r.financing_id ORDER BY p.bank_transfer_date DESC) = 1
),
-- Prior's cfds row at the day before renewal funded (or on renewal fund date) for cumulative_transacted and payback.
prior_state AS (
  SELECT
    pf.renewal_financing_id,
    pf.offer_group_id,
    pf.shop_id,
    pf.prior_financing_id,
    pf.prior_payback_usd,
    cfds.cumulative_transacted_amount_usd AS prior_cumulative_transacted_usd,
    cfds.payback_amount_usd AS cfds_payback_usd,
  FROM prior_financings pf
  INNER JOIN `shopify-dw.money_products.capital_financing_daily_summary` cfds
    ON cfds.financing_id = pf.prior_financing_id
    AND cfds.date = DATE_SUB(pf.renewal_fund_date, INTERVAL 1 DAY)  -- day before renewal funded
)
SELECT
  renewal_financing_id AS financing_id,
  offer_group_id,
  shop_id,
  'R17' AS rule_id,
  SAFE_DIVIDE(prior_cumulative_transacted_usd, prior_payback_usd) AS actual_value,
  '>= 0.51' AS expected_value,
  'renewal_paid_in_below_51pct' AS violation_type
FROM prior_state
WHERE prior_payback_usd IS NOT NULL AND prior_payback_usd > 0
  AND SAFE_DIVIDE(prior_cumulative_transacted_usd, prior_payback_usd) < 0.51
ORDER BY offer_group_id;
