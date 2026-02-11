# SQL rule checks (Fixed Fee)

Each file runs one rule against BigQuery. Output columns: `offer_group_id`, `shop_id`, `product_id`, `rule_id`, `actual_value`, `expected_value`, `violation_type`.

**Cohort:** Offer-level rules (R01, R02, R03, R10) filter to `first_published_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)`. Change the interval or replace with a parameter for your run window.

**Fixed Fee filter:** `financing_type != 'FlexFinancing'`. If your taxonomy uses `product_id` instead, replace the filter (e.g. `product_id = <fixed_fee_product_id>`).

**How to run:** Execute in BigQuery (console, `bq query`, or scheduled query). To load into a results table, wrap in `INSERT INTO <results_table> (run_ts, rule_id, offer_group_id, ...) SELECT CURRENT_TIMESTAMP(), ... FROM (...)`.

| File | Rule | Table(s) |
|------|------|----------|
| rule_01_amount_range.sql | R01 | cog |
| rule_02_factor_rate.sql | R02 | cog |
| rule_03_remittance_calibration.sql | R03+R12 | cog |
| rule_10_risk_group.sql | R10 | cog |
| rule_17_renewal_threshold.sql | R17 | cf, cfds |
