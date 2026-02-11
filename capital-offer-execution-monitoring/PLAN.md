---
name: Capital Offer Execution Monitoring
overview: "Design and implement an execution monitoring system that runs weekly to validate published Capital offer groups against policy rules, with product-specific rule support, using cf, cfds, and cog. Outputs: results table, weekly report, and optional alerts."
---

# Capital Offer Execution Monitoring System

## 1. Data model and scope

**Universe:** Published Capital offer groups. "Published" = rows in [capital_offer_groups](shopify-dw.money_products.capital_offer_groups) (table is publish-only). Weekly cohort = `DATE_TRUNC(first_published_at, WEEK)` or similar.

**Link logic:**

- **cog → cf:** `cog.offer_group_id = cf.offer_group_id` (financing created from an offer).
- **cf → cfds:** `cf.financing_id = cfds.financing_id`; for time-bound checks use `cfds.date` (e.g. as-of date or last day of week).
- **Product / type:** Use `product_id` and/or `financing_type` from **cf** or **cog** to branch rules (e.g. Flex vs MCA/Loan; product_id 51 = Flex per schema caveats).

**Table semantics (relevant for rules):**

- **cog:** Offer-level inputs — `gmv_usd_l52w`, `risk_group`, `factor_rates_array`, `remittance_rates_array`, `amounts_usd_array`, `aprs_array`, `monthly_fee_percentages_array`, `pricing_type`, `product_id`, `financing_type`, `first_published_at`.
- **cf:** Financing-level outcomes — `product_id`, `financing_type`, `amount_usd`, `factor_rate`, `remittance_rate`, `is_written_off`, `write_off_*`, `bank_transfer_date`, etc. Flex-specific: `amount_usd` = cumulative funded; no factor_rate/write-off.
- **cfds:** Daily state — `date`, `financing_id`, `end_status`, `payback_amount_*`, `amount_remaining_excl_factor_usd`, `amount_remaining_incl_factor_usd`, `accounts_receivable_outstanding_usd`, `cumulative_transacted_amount_usd`. Always filter by `date` (table partitioned by month on `date`).

**Recommendation:** For "offer published this week" checks, define the cohort from **cog** on `first_published_at` (or `last_unpublished_at` for still-available). For rules that need post-funding behavior, join to **cf** (and optionally **cfds** for as-of balances/status).

---

## 2. Rule framework (product-aware)

- **Rule registry:** One place (config table or code) that lists each rule with: rule_id, name, description, product_ids or product_type filter (e.g. "all", "Flex only", "MCA only"), and parameters if any.
- **Evaluation pattern:** For each rule, filter to the relevant product(s), then run a single SQL (or a parameterized template) that returns violations: e.g. `(offer_group_id, shop_id, product_id, rule_id, expected, actual, severity)`.
- **Product branching:** Implement as separate SQL fragments per product or a single query with `CASE WHEN product_id IN (...) ...` so the same pipeline can run all rules and attach `product_id`/`financing_type` to each result.

---

## 3. Violation schema (results table)

Store one row per (offer_group_id, rule_id, [optional: financing_id if post-accept]) per run:

| Column          | Type             | Purpose                                |
| --------------- | ---------------- | -------------------------------------- |
| run_id / run_ts | STRING/TIMESTAMP | Weekly run identifier                  |
| rule_id         | STRING           | Which rule failed                      |
| offer_group_id  | INT              | From cog                               |
| shop_id         | INT              | Merchant                               |
| product_id      | INT              | From cf/cog                            |
| financing_type  | STRING           | Optional                               |
| financing_id    | INT              | Optional; only if rule is post-funding |
| expected_value  | NUMERIC/STRING   | What policy says                       |
| actual_value    | NUMERIC/STRING   | What data shows                        |
| severity        | STRING           | e.g. high / medium / low               |
| metadata        | JSON/STRING      | Extra context                          |

Partition by `run_ts` (or run date); cluster by `rule_id`, `offer_group_id`.

---

## 4. Execution options

- **A – Composer/Airflow:** DAG: cohort → run rules → write results table → report → optional alert.
- **B – BigQuery-only:** Scheduled query/procedure → results table; reporting/alerts via Looker/Sheets or Cloud Functions.
- **C – Notebook / ad-hoc:** Python + BQ client for iteration; then move to A or B.

Recommendation: Start with **C**, then **A** for production weekly runs.

---

## 5. Outputs

- **Results table** (as in §3).
- **Weekly report:** Counts by rule_id, product_id, severity; top N violations.
- **Optional alerts:** Slack/PagerDuty when violation or high-severity count > threshold.

---

## 6. Implementation order

1. Create the results table in BigQuery.
2. Define "published this week" cohort (view/CTE from cog).
3. Implement rule registry and runner.
4. Add rules R01–R18 as parameterized SQL.
5. Weekly report and optional alerts.
6. Move to Composer/scheduled job for production.

---

## 7. Dependencies and caveats

- **cfds volume:** Always filter by `date` and preferably by financing_id set from cf.
- **Flex vs non-Flex:** Branch on `product_id`/`financing_type`; many columns are NULL or different for Flex.
- **Offer vs financing:** Offer-level rules use cog only; post-funding rules use cf and cfds.

---

## 8. Policy-derived rules to check

Rules extracted from the WebBank Shopify Capital 2.0 Credit Policy (2025-2-6).

**Product / offer bounds (Section 3.1)**

- **R01 – Fixed Fee amount range:** Fixed Fee only. Min/max amount in [$200, $2,000,000] USD. cog: `amounts_usd_array`; cf: `amount_usd`.
- **R02 – Fixed Fee factor rate range:** Fixed Fee only. Factor rate in [0.03, 0.21]. cog: `factor_rates_array`; cf: `factor_rate`.
- **R03 – Fixed Fee remittance range:** Fixed Fee only. Remittance in [4%, 35%]. cog: `remittance_rates_array`; cf: `remittance_rate`.
- **R04 – Flex amount range:** Flex only. Max offer/funding in [$200, $500,000] USD. cf: `first_funding_amount_usd`; `amount_usd` is cumulative for Flex.
- **R05 – Flex minimum withdrawal:** Flex only. Each withdrawal ≥ $200. Requires draw-level data (cfds/cf or tranche table).
- **R06 – Flex APR range:** Flex only. APR in [10%, 50%]. cog: `aprs_array`.
- **R07 – Flex remittance range:** Flex only. Remittance in [4%, 35%]. cog: `remittance_rates_array`; cf: `remittance_rate`.

**Product assignment (Section 6.1)**

- **R08 – Fixed Fee GMV eligibility:** Fixed Fee only. cog: `gmv_usd_l52w` in [0, 1,750,000].
- **R09 – Flex GMV eligibility:** Flex only. cog: `gmv_usd_l52w` in [50,000, 1,750,000].
- **R10 – Fixed Fee risk groups:** Fixed Fee only. cog: `risk_group` in 1–10.
- **R11 – Flex risk groups:** Flex only. cog: `risk_group` in 1–7 only.

**Offer generation – calibration (Section 6.2 iv)**

- **R12 – Max remittance (calibration rate):** All. cog: remittance rate ≤ calibration rate by risk group and GMV (<$1.75M: RG 1–8 → 25% or 17% with SC; RG 9–10 → 17%; ≥$1.75M: RG 1–4 → 25%/17%, RG 5–10 → 17%). "With Shopify Credit" may need another source.

**Offer attributes / validators (Section 5.2.1)**

- **R13 – Currency and region:** All. cog: `currency_code` = 'USD', `shop_country_code` = 'US'.
- **R14 – No staff shops:** All. cog: `is_staff_shop` = FALSE.

**Post-origination**

- **R15 – AFR cap 80%:** All. cfds: for each financing, `afr` ≤ 0.80 on any day (filter by date).
- **R16 – Fixed Fee minimum payment schedule:** Fixed Fee only. cfds + cf: at 6/12/18 months from `bank_transfer_date`, cumulative_transacted_amount_usd ≥ 30% / 60% / 100% of payback_amount_usd.
- **R17 – Renewal paid-in threshold:** Fixed Fee only. Before renewal funding, original financing must have repaid ≥ 51% of total payment. cf + cfds: (cumulative_transacted / payback_amount) ≥ 0.51 at time of new offer/funding.

**Monitoring (Section 5.2.1, Appendix A)**

- **R18 – High risk + high GMV bypass rate:** Count offer groups with risk_group=10 and gmv_usd_l52w in (100000, 1750000). Policy allows 3% bypass; alert if weekly share exceeds expected (e.g. > 5%).

**Not checkable from cf/cog/cfds alone**

- Denylist (Section 10): need denylist data source.
- Other validators (KYC, bank, chargeback, etc.): operational; no columns in these tables.
- UCC filing (9.3): operational.
- Settlement currency USD: may be in other tables.

---

## 9. Next step

Implement the rules in §8 as parameterized SQL with product filters and run_id, and wire them into the rule runner and results table.
