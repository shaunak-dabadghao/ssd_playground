# Capital Offer Execution Monitoring

Weekly execution monitoring for Shopify Capital offer generation: check that **published offers** adhere to the WebBank Shopify Capital 2.0 Credit Policy.

## Data sources (BigQuery)

| Alias | Table | Purpose |
|-------|--------|--------|
| **cog** | `shopify-dw.money_products.capital_offer_groups` | Published offer groups; link via `offer_group_id` to cf |
| **cf** | `shopify-dw.money_products.capital_financings` | Financings; link via `financing_id` to cfds, `offer_group_id` to cog |
| **cfds** | `shopify-dw.money_products.capital_financing_daily_summary` | Daily per-financing state (filter by `date`) |

## Contents

- **[PLAN.md](./PLAN.md)** – Full design: data model, rule framework, violation schema, execution options, and **18 policy-derived rules (R01–R18)** with check logic.
- Rules are product-aware (Fixed Fee vs Flex); some are offer-level (cog), others post-funding (cf + cfds).

## Rule summary (from policy 2025-2-6)

| ID | Scope | Summary |
|----|--------|--------|
| R01–R03 | Fixed Fee | Amount [$200, $2M], factor rate [3%, 21%], remittance [4%, 35%] |
| R04–R07 | Flex | Amount [$200, $500K], min withdrawal $200, APR [10%, 50%], remittance [4%, 35%] |
| R08–R11 | Product assignment | GMV and risk-group eligibility (Flex: GMV $50K–$1.75M, RG 1–7) |
| R12 | All | Max remittance ≤ calibration rate by risk group & GMV |
| R13–R14 | All | USD + US only; no staff shops |
| R15–R17 | Post-origination | AFR ≤ 80%; Fixed Fee min payment schedule; renewal paid-in ≥ 51% |
| R18 | Monitoring | High risk + high GMV bypass rate (RG 10, GMV $100K–$1.75M) |

## Next steps

1. Create results table and “published this week” cohort.
2. Implement rule runner and parameterized SQL for each rule.
3. Add weekly report and optional alerts.
