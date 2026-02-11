# Capital Offer Execution Monitoring

Weekly execution monitoring for Shopify Capital offer generation: check that **published offers** adhere to the WebBank Shopify Capital 2.0 Credit Policy.

**Scope:** **Fixed Fee product only.** Flex will have a separate monitoring system.

## Data sources (BigQuery)

| Alias | Table | Purpose |
|-------|--------|--------|
| **cog** | `shopify-dw.money_products.capital_offer_groups` | Published offer groups; link via `offer_group_id` to cf |
| **cf** | `shopify-dw.money_products.capital_financings` | Financings; link via `financing_id` to cfds, `offer_group_id` to cog |
| **cfds** | `shopify-dw.money_products.capital_financing_daily_summary` | Daily per-financing state (filter by `date`) |

## Contents

- **[PLAN.md](./PLAN.md)** – Full design: data model, rule framework, violation schema, execution options, and policy-derived rules.
- **[RULES_FIXED_FEE.md](./RULES_FIXED_FEE.md)** – **Selected Fixed Fee rules:** spec and check logic for the 5 rules we monitor.
- **[sql/](./sql/)** – BigQuery SQL for each rule (offer-level and post-funding).

## Fixed Fee rules we monitor (selected)

| # | Rule ID | Description |
|---|---------|-------------|
| 1 | R01 | Fixed Fee amount in [$200, $2,000,000] USD |
| 2 | R02 | Fixed Fee factor rate in [3%, 21%] |
| 3 | R03+R12 | Fixed Fee remittance: [4%, 35%] and ≤ calibration rate by risk group, GMV, Shopify Credit |
| 4 | R10 | Fixed Fee risk groups 1–10 only |
| 5 | R17 | Renewal: ≥51% of prior total payment repaid before new funding |

**Dropped (out of scope for this system):** R08 (GMV), R13 (currency/region), R14 (staff shop), R15 (AFR cap), R16 (payment schedule), R18 (high risk + high GMV bypass; checked upstream).

## Next steps

1. Create results table and “published this week” cohort.
2. Run rule SQL (e.g. weekly) and write violations to results table.
3. Weekly report and optional alerts.
