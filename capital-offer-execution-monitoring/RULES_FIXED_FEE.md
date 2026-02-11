# Fixed Fee execution monitoring – rules

Scope: **Fixed Fee product only.** All checks filter to Fixed Fee (e.g. `financing_type != 'FlexFinancing'` or the appropriate `product_id`).

---

## Rule 1 (R01) – Fixed Fee amount range

**Policy:** Amount must be in [$200, $2,000,000] USD (Section 3.1 Product 1).

**Check:** Every offer amount and every funded amount must be ≥ 200 and ≤ 2,000,000.

**Data:**
- **Offer-level (cog):** `amounts_usd_array` – unnest and check each element.
- **Funded (cf):** `amount_usd` (and optionally `first_funding_amount_usd` for consistency).

**Violation:** offer_group_id (and financing_id if checking cf) where any amount < 200 or > 2,000,000.

**Severity:** high.

---

## Rule 2 (R02) – Fixed Fee factor rate range

**Policy:** Factor rate must be in [3%, 21%] i.e. [0.03, 0.21] (Section 3.1 Product 1).

**Check:** Every factor rate in the offer (or on the financing) must be ≥ 0.03 and ≤ 0.21.

**Data:**
- **Offer-level (cog):** `factor_rates_array` – unnest and check each element.
- **Funded (cf):** `factor_rate`.

**Violation:** offer_group_id / financing_id where any factor rate < 0.03 or > 0.21.

**Severity:** high.

---

## Rule 3 (R03 + R12) – Fixed Fee remittance: range and calibration cap

**Policy:** Remittance rate must be (1) in [4%, 35%] and (2) ≤ calibration rate for the merchant’s risk group and GMV band, and Shopify Credit status if applicable (Sections 3.1 and 6.2 iv).

**Calibration rate (policy):**
- GMV < $1.75M: risk groups 1–8 → 25% (without Shopify Credit) / 17% (with Shopify Credit); risk groups 9–10 → 17%.
- GMV ≥ $1.75M: risk groups 1–4 → 25% / 17%; risk groups 5–10 → 17%.

**Check:**
1. Every remittance rate in [0.04, 0.35].
2. Every remittance rate ≤ max_remittance(risk_group, gmv_usd_l52w, has_shopify_credit). If `has_shopify_credit` is unknown, use the stricter 17% where the policy says “with Shopify Credit”.

**Data:**
- **cog:** `remittance_rates_array`, `risk_group`, `gmv_usd_l52w`. Shopify Credit flag may require another source; if missing, assume “with SC” for the 17% cap where applicable.
- **cf:** `remittance_rate` for funded loans.

**Violation:** offer_group_id / financing_id where remittance < 0.04 or > 0.35, or where remittance > calibration max.

**Severity:** high.

---

## Rule 4 (R10) – Fixed Fee risk groups 1–10 only

**Policy:** Fixed Fee is offered to risk groups 1–10 (Section 6.1).

**Check:** `risk_group` must be in 1–10 (no NULL, no 0, no > 10).

**Data:** **cog** (and **cf** if we have risk at financing level) – `risk_group`.

**Violation:** offer_group_id where risk_group IS NULL or not between 1 and 10.

**Severity:** high.

---

## Rule 5 (R17) – Renewal paid-in threshold

**Policy:** Before a renewal Fixed Fee loan is funded, the merchant must have repaid ≥ 51% of the total payment amount on the prior financing (Section 9.4, Appendix C).

**Check:** For every renewal financing (cf where `is_renewal` = true), identify the prior financing for that shop (or the one being renewed). At the time of the new offer/funding, prior financing’s cumulative_transacted_amount_usd / payback_amount_usd ≥ 0.51. Use cfds on the prior financing at the relevant date (e.g. bank_transfer_date of the renewal or acceptance date).

**Data:** **cf** (renewal + prior financing link; may need `tops_up_financing_id` or shop + product + ordering by date), **cfds** (prior financing’s cumulative_transacted_amount_usd, payback_amount_usd at the cutoff date).

**Violation:** renewal financing_id (and offer_group_id) where prior repaid % < 51%.

**Severity:** high.

---

## Dropped rules (not in this monitor)

- **R08** – Fixed Fee GMV eligibility (dropped per product owner).
- **R13** – Currency USD, country US (dropped).
- **R14** – No staff shops (dropped).
- **R15** – AFR cap 80% (dropped).
- **R16** – Fixed Fee minimum payment schedule 30%/60%/100% (dropped).
- **R18** – High risk + high GMV bypass (checked upstream in data/offer gen; out of scope).
