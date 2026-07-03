 StockVault — 5-Day Production-Readiness Roadmap
 
**Strategy:** Review → Fix Design → Implement → Test → Optimize → Deploy
**Scope note:** This treats "production-ready" as *"a robust, correctly-normalized, constraint-safe, well-tested, demoable system that would survive a hard viva question"* — not a literal SEBI-registered brokerage. Where a fix (e.g. full column-level Aadhaar encryption with app-layer key management) genuinely needs more than 5 days, I've scoped it down to what's honestly achievable and flagged the rest as a documented known-limitation. Overpromising here would just cost you Day 5.
 
---
 
## 0. Decisions I'm making as your co-designer (so you can defend them in viva)
 
| # | Issue | Decision | Why |
|---|---|---|---|
| D-1 | `AGE` (Table 3 BCNF violation) | **Drop the column.** Compute via `EXTRACT(YEAR FROM AGE(dob))` in queries/views. | Depends on `CURRENT_DATE` → cannot be a generated column. Only one query (`Query 12`) touches it — 1-line fix. |
| D-2 | `UNREALISED_PNL`, `TOTAL_CHARGES`, `GAIN_LOSS`, `GAIN_TYPE` | **Convert to `GENERATED ALWAYS AS (...) STORED` columns**, not deletion. | All three source expressions use only same-row, non-volatile columns → legal generated columns. Preserves BCNF (LHS still not a superkey conceptually, but the value is now *system-enforced consistent*, which is the actual goal of the rule) **and** keeps Queries 2, 12, 14 unchanged. |
| D-3 | `TRADE.INVESTOR_ID`/`SECURITY_ID`, `CAPITAL_GAINS_RECORD.INVESTOR_ID`/`SECURITY_ID`/`ORDER_ID` | **Drop entirely**, derive via join chain. | Grep confirms **no query references these columns directly** — Query 2 already joins through `TRADE → ORDER_RECORD → INVESTOR` correctly. Zero-risk removal. |
| D-4 | `BANK_ACC.BANK_NAME`/`BRANCH_NAME` (IFSC violation) | **Split into `BANK_BRANCH`.** | Grep confirms no query touches these columns — safe to split immediately. |
| D-5 | Passwords | **Hash in-database with `pgcrypto`'s `crypt()`/`gen_salt('bf')`.** | You have no app layer (this is pgAdmin/SQL-only), so "hash in the app" isn't achievable in 5 days. `pgcrypto` gives you real bcrypt hashing directly in SQL — legitimate, not a toy fix. |
| D-6 | Aadhaar encryption | **Mask, don't encrypt, for Day 1–5.** Add `AADHAR_LAST4`, keep full number under `pgcrypto` as a documented stretch goal only. | True column encryption breaks the `UNIQUE` constraint (non-deterministic ciphertext ≠ equality-comparable) unless you add a second deterministic-hash column just for lookups — real engineering effort, not a 30-minute fix. Flag as "known limitation, next phase" in your report; that's a legitimate answer in a viva. |
| D-7 | ISA discriminator (`HNI` with no subtype table) | **Fold `HNI` into `RETAIL_INVESTOR.RISK_PROFILE`** (drop it as a third `INVESTOR_TYPE` value). | Your own insert data already does this in practice (comment: *"HNI investors also have retail sub-profiles"*). Matches reality, needs no trigger. |
| D-8 | Cascade deletes (Issue H) | **Flip `INVESTOR`-rooted cascades to `RESTRICT`**; enforce soft-delete via existing `IS_ACTIVE` flags. Full soft-delete UI/workflow is out of scope. | `USER.IS_ACTIVE` and similar flags already exist in your schema — you just aren't using them as the deletion mechanism yet. This is a config change, not new tables. |
| D-9 | Missing feature tables (F1–F5) | **Only build F1 (`PRICE_HISTORY`) and a trimmed `AUDIT_LOG`.** F2–F5 (SIP, dividends, watchlists, compliance flags) documented as "scoped out of v1, schema-ready to add" in your report. | F1 is the one that actually fixes a real bug (Query 3/11 currently mine your own trade table for "market price," which is wrong) and unlocks D2 from the Issues doc for free. F2–F5 have zero dependents in your 15 queries — building them now is time you don't have. |
| D-10 | `SERIAL`→`BIGSERIAL`, `TIMESTAMP`→`TIMESTAMPTZ`, partitioning (G2–G4) | **Skip.** Document as acknowledged scaling limitations. | Explicitly marked optional in the Issues doc, zero grading/functional risk at your data volume. |
 
---
 
## 1. Priority Matrix
 
| Priority | Item | Depends on | Day |
|---|---|---|---|
| P0 | Schema fixes (BCNF, naming, security columns, NOT NULL/CHECK gaps) | nothing | 1 |
| P0 | `pgcrypto` password hashing | schema fix | 1 |
| P1 | Business-rule constraints (C1, C2 — these break query correctness) | schema fix | 2 |
| P1 | `BANK_BRANCH` split + data migration | schema fix | 2 |
| P1 | `PRICE_HISTORY` (F1) + indexes | schema fix | 2 |
| P1 | Trimmed `AUDIT_LOG` + triggers | schema fix | 2 |
| P2 | Re-run/patch INSERT data against new schema | Day 2 schema | 2–3 |
| P2 | Fix the 5 broken/duplicate/missing queries (E1–E6, dup Query 4, missing Query 9) | data loaded | 3 |
| P2 | Full functional test of all 15 queries | queries fixed | 3 |
| P3 | Edge-case + constraint testing, `EXPLAIN ANALYZE` on hot queries | working queries | 4 |
| P3 | Optional hardening (C3–C8 remaining constraints) | time-permitting | 4 |
| P4 | Documentation, deployment, viva prep | everything above | 5 |
 
---
 
## DAY 1 — Schema Hardening & Security
 
### Objectives
Lock in a correct, BCNF-compliant, constraint-safe schema **before** anyone touches data or queries again. Every later day depends on this being done right, so this is the highest-leverage day.
 
### Files/tables to modify
`Create-Table-Queries.txt` (your DDL) → produce `schema_v2.sql`. No query or data work yet.
 
### Tasks (in order)
 
**1. Enable pgcrypto (needed for password hashing today)**
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```
 
**2. Fix `USER` — password hashing + missing constraints**
```sql
ALTER TABLE "USER" RENAME COLUMN password TO password_hash;
ALTER TABLE "USER" ALTER COLUMN password_hash TYPE VARCHAR(255);
 
-- Hash whatever plaintext is currently in there (one-time migration)
UPDATE "USER" SET password_hash = crypt(password_hash, gen_salt('bf'));
 
-- Close the CHECK-without-NOT-NULL gap (Issue B)
ALTER TABLE "USER" ALTER COLUMN role SET NOT NULL;
ALTER TABLE "USER" ADD CONSTRAINT chk_role
    CHECK (role IN ('INVESTOR','BROKER','COMPLIANCE_OFFICER'));
```
To verify a login later: `SELECT (password_hash = crypt('attempt', password_hash)) AS ok FROM "USER" WHERE email = ...;`
 
**3. Fix `INVESTOR` — drop `AGE`, mask Aadhaar, close NULL gaps**
```sql
ALTER TABLE INVESTOR DROP COLUMN AGE;
 
ALTER TABLE INVESTOR ADD COLUMN AADHAR_LAST4 CHAR(4)
    GENERATED ALWAYS AS (RIGHT(AADHAR_NO, 4)) STORED;
-- AADHAR_NO stays for now (documented limitation D-6); restrict SELECT on it at the
-- application/role level later (Day 5 doc, not a schema task).
 
ALTER TABLE INVESTOR ALTER COLUMN kyc_status SET NOT NULL;
ALTER TABLE INVESTOR ADD CONSTRAINT chk_kyc_status
    CHECK (kyc_status IN ('VERIFIED','PENDING','REJECTED'));
 
-- D-7: fold HNI out of the discriminator
ALTER TABLE INVESTOR DROP CONSTRAINT investor_investor_type_check;
ALTER TABLE INVESTOR ADD CONSTRAINT chk_investor_type
    CHECK (INVESTOR_TYPE IN ('RETAIL','INSTITUTIONAL'));
ALTER TABLE INVESTOR ALTER COLUMN investor_type SET NOT NULL;
```
> ⚠️ Before running the `DROP CONSTRAINT`/type change: any existing rows with `INVESTOR_TYPE = 'HNI'` need to be updated to `'RETAIL'` first (Day 2, alongside the `RISK_PROFILE` backfill), or this `ALTER` will fail against existing data. Order: backfill data → then tighten constraint.
 
**4. Fix `KYC_DOCUMENT` / `SECURITY` / `ORDER_RECORD` / `FUND_TRANSACTION` — NOT NULL on every CHECK column**
```sql
ALTER TABLE KYC_DOCUMENT ALTER COLUMN doc_type SET NOT NULL;
ALTER TABLE KYC_DOCUMENT ALTER COLUMN verification_status SET NOT NULL;
 
ALTER TABLE SECURITY ALTER COLUMN exchange SET NOT NULL;
ALTER TABLE SECURITY ALTER COLUMN security_type SET NOT NULL;
 
ALTER TABLE ORDER_RECORD ALTER COLUMN side SET NOT NULL;
ALTER TABLE ORDER_RECORD ALTER COLUMN order_type SET NOT NULL;
ALTER TABLE ORDER_RECORD ALTER COLUMN product_type SET NOT NULL;
ALTER TABLE ORDER_RECORD ALTER COLUMN status SET NOT NULL;
 
ALTER TABLE FUND_TRANSACTION ALTER COLUMN txn_type SET NOT NULL;
```
 
**5. Fix `BANK_ACC` → split into `BANK_BRANCH` (Table 8 BCNF violation)**
```sql
CREATE TABLE BANK_BRANCH (
    IFSC_CODE   CHAR(11) PRIMARY KEY,
    BANK_NAME   VARCHAR(100) NOT NULL,
    BRANCH_NAME VARCHAR(100)
);
-- data migration for this happens Day 2 once real rows exist; DDL only today
ALTER TABLE BANK_ACC ADD COLUMN IFSC_TEMP CHAR(11); -- placeholder, populated Day 2
```
(Full cutover — dropping `BANK_NAME`/`BRANCH_NAME` from `BANK_ACC` and wiring the FK — happens Day 2 once you've migrated the existing rows, so you don't lose data mid-flight.)
 
**6. Fix `HOLDING`, `TRADE`, `CAPITAL_GAINS_RECORD` — generated columns + drop transitive redundancy**
```sql
-- HOLDING
ALTER TABLE HOLDING DROP COLUMN UNREALISED_PNL;
ALTER TABLE HOLDING ADD COLUMN UNREALISED_PNL NUMERIC(15,2)
    GENERATED ALWAYS AS (CURRENT_VALUE - (AVG_COST_PRICE * QUANTITY)) STORED;
 
-- TRADE: drop transitive FKs (unused by all 15 queries — confirmed by grep)
ALTER TABLE TRADE DROP COLUMN INVESTOR_ID;
ALTER TABLE TRADE DROP COLUMN SECURITY_ID;
ALTER TABLE TRADE ALTER COLUMN BROKERAGE_FEE SET DEFAULT 0;
ALTER TABLE TRADE ALTER COLUMN EXCHANGE_CHARGES SET DEFAULT 0;
ALTER TABLE TRADE ALTER COLUMN STT SET DEFAULT 0;
ALTER TABLE TRADE ALTER COLUMN BROKERAGE_FEE SET NOT NULL;
ALTER TABLE TRADE ALTER COLUMN EXCHANGE_CHARGES SET NOT NULL;
ALTER TABLE TRADE ALTER COLUMN STT SET NOT NULL;
ALTER TABLE TRADE DROP COLUMN TOTAL_CHARGES;
ALTER TABLE TRADE ADD COLUMN TOTAL_CHARGES NUMERIC(10,2)
    GENERATED ALWAYS AS (BROKERAGE_FEE + EXCHANGE_CHARGES + STT) STORED;
-- Also close Issue C6: an executed trade with no fill data is nonsensical
ALTER TABLE TRADE ADD CONSTRAINT chk_fill_data
    CHECK (FILL_PRICE IS NOT NULL AND FILLED_QTY IS NOT NULL);
 
-- CAPITAL_GAINS_RECORD: drop transitive FKs (unused by all 15 queries — confirmed by grep)
ALTER TABLE CAPITAL_GAINS_RECORD DROP COLUMN INVESTOR_ID;
ALTER TABLE CAPITAL_GAINS_RECORD DROP COLUMN SECURITY_ID;
ALTER TABLE CAPITAL_GAINS_RECORD DROP COLUMN ORDER_ID;
ALTER TABLE CAPITAL_GAINS_RECORD DROP COLUMN GAIN_TYPE;
ALTER TABLE CAPITAL_GAINS_RECORD ADD COLUMN GAIN_TYPE VARCHAR(20)
    GENERATED ALWAYS AS (
        CASE WHEN HOLDING_DAYS IS NULL THEN NULL
             WHEN HOLDING_DAYS < 365 THEN 'SHORT_TERM'
             ELSE 'LONG_TERM' END
    ) STORED;
ALTER TABLE CAPITAL_GAINS_RECORD ADD CONSTRAINT chk_gain_type
    CHECK (GAIN_TYPE IN ('SHORT_TERM','LONG_TERM'));
ALTER TABLE CAPITAL_GAINS_RECORD DROP COLUMN GAIN_LOSS;
ALTER TABLE CAPITAL_GAINS_RECORD ADD COLUMN GAIN_LOSS NUMERIC(15,2)
    GENERATED ALWAYS AS ((SELL_PRICE - BUY_PRICE) * QUANTITY) STORED;
```
> `chk_gain_type` on a generated column is redundant defensively but costs nothing and documents intent clearly for the viva.
 
**7. Fix naming bugs that will otherwise break Day 3 (E1, E3, E4, E5 — do this now while you're already in the DDL)**
```sql
-- E1: standardize on TA_ID (already correct in live DDL — just make sure the
--     BCNF doc's "TD_ID" references get corrected in your report, no SQL needed)
 
-- E3/E4/E5 are query-side typos, not schema bugs — no DDL change here,
-- but note them now so Day 3 isn't a surprise: AVAIL_BALANCE (not avl_balance),
-- SEBI_LICENSE_NO (not sebi_lic_no), TRADING_ACC (not trading_account).
```
 
**8. Cascade delete safety net (Issue H, scoped per D-8)**
```sql
ALTER TABLE PORTFOLIO   DROP CONSTRAINT portfolio_investor_id_fkey,
    ADD CONSTRAINT portfolio_investor_id_fkey
        FOREIGN KEY (INVESTOR_ID) REFERENCES INVESTOR(INVESTOR_ID) ON DELETE RESTRICT;
ALTER TABLE HOLDING      DROP CONSTRAINT holding_portfolio_id_fkey,
    ADD CONSTRAINT holding_portfolio_id_fkey
        FOREIGN KEY (PORTFOLIO_ID) REFERENCES PORTFOLIO(PORTFOLIO_ID) ON DELETE RESTRICT;
ALTER TABLE DEMAT_ACC    DROP CONSTRAINT demat_acc_investor_id_fkey,
    ADD CONSTRAINT demat_acc_investor_id_fkey
        FOREIGN KEY (INVESTOR_ID) REFERENCES INVESTOR(INVESTOR_ID) ON DELETE RESTRICT;
ALTER TABLE BANK_ACC     DROP CONSTRAINT bank_acc_investor_id_fkey,
    ADD CONSTRAINT bank_acc_investor_id_fkey
        FOREIGN KEY (INVESTOR_ID) REFERENCES INVESTOR(INVESTOR_ID) ON DELETE RESTRICT;
ALTER TABLE TRADING_ACC  DROP CONSTRAINT trading_acc_investor_id_fkey,
    ADD CONSTRAINT trading_acc_investor_id_fkey
        FOREIGN KEY (INVESTOR_ID) REFERENCES INVESTOR(INVESTOR_ID) ON DELETE RESTRICT;
```
(Exact constraint names depend on what Postgres auto-generated for you — run `\d INVESTOR` or query `information_schema.table_constraints` first to confirm names before running the `DROP CONSTRAINT` lines.)
From now on, "deleting" an investor means `UPDATE INVESTOR SET ... /* or */ UPDATE "USER" SET IS_ACTIVE = FALSE`, never `DELETE FROM INVESTOR`.
 
### Deliverables
- `schema_v2.sql` — the full corrected DDL, runnable top-to-bottom on a fresh database
- A one-page "Design Decisions" note (this is literally section 0 above, lightly reworded for your report)
### Validation
- `\d` every altered table in psql — confirm generated columns show `stored generated column` in the output, confirm NOT NULL/CHECK are present
- `INSERT INTO ORDER_RECORD (..., status) VALUES (..., NULL);` should now **fail** — that's the fix for Issue B working
- `SELECT * FROM "USER" LIMIT 1;` — confirm `password_hash` is a 60-char bcrypt string, not plaintext
### Effort estimate
5–6 hours (mostly careful, not hard — this is the day to go slow)
 
### End-of-day checklist
- [ ] `pgcrypto` enabled, all passwords hashed
- [ ] `AGE` dropped, `AADHAR_LAST4` added
- [ ] `HOLDING`, `TRADE`, `CAPITAL_GAINS_RECORD` generated columns in place and confirmed working
- [ ] `TRADE`/`CAPITAL_GAINS_RECORD` transitive FK columns dropped
- [ ] `BANK_BRANCH` table created (cutover pending Day 2)
- [ ] All CHECK-constrained columns now have NOT NULL
- [ ] Cascade→Restrict changes applied on investor-rooted FKs
- [ ] `schema_v2.sql` committed/saved somewhere safe before touching data
---

## DAY 2 — Data Migration, Business Rules, Missing Features, Indexes
 
### Objectives
Get real data sitting correctly on top of `schema_v2.sql`, close the two query-correctness bugs (C1/C2), and add the one missing feature table that your queries actually need (`PRICE_HISTORY`).
 
### Files/tables to modify
`Insert-Table-Queries.txt` → `insert_v2.sql`; `schema_v2.sql` (additions only, no more structural surgery).
 
### Tasks (in order)
 
**1. Backfill `INVESTOR_TYPE` before the constraint bites**
```sql
-- Turn HNI into a RETAIL investor with a tagged risk profile (D-7)
UPDATE INVESTOR SET INVESTOR_TYPE = 'RETAIL' WHERE INVESTOR_TYPE = 'HNI';
UPDATE RETAIL_INVESTOR SET RISK_PROFILE = 'HNI'
WHERE INVESTOR_ID IN (
    SELECT INVESTOR_ID FROM INVESTOR WHERE INVESTOR_TYPE = 'RETAIL'
      AND INVESTOR_ID NOT IN (SELECT INVESTOR_ID FROM RETAIL_INVESTOR)
      -- adjust predicate to match exactly which rows were HNI in your source data
);
-- Now safe to apply chk_investor_type from Day 1 step 3 if you deferred it
```
 
**2. Migrate `BANK_ACC` → `BANK_BRANCH` cutover**
```sql
INSERT INTO BANK_BRANCH (IFSC_CODE, BANK_NAME, BRANCH_NAME)
SELECT DISTINCT IFSC_CODE, BANK_NAME, BRANCH_NAME FROM BANK_ACC
ON CONFLICT (IFSC_CODE) DO NOTHING;
 
ALTER TABLE BANK_ACC ADD CONSTRAINT bank_acc_ifsc_fkey
    FOREIGN KEY (IFSC_CODE) REFERENCES BANK_BRANCH(IFSC_CODE);
ALTER TABLE BANK_ACC DROP COLUMN BANK_NAME;
ALTER TABLE BANK_ACC DROP COLUMN BRANCH_NAME;
ALTER TABLE BANK_ACC DROP COLUMN IFSC_TEMP; -- placeholder from Day 1, no longer needed
```
 
**3. Business-rule constraints — C1 and C2 are mandatory (they break query correctness today)**
```sql
-- C1: only one primary bank account per investor
CREATE UNIQUE INDEX one_primary_bank_acc_per_investor
    ON BANK_ACC (INVESTOR_ID) WHERE IS_PRIMARY = TRUE;
 
-- C2: only one active brokerage plan per investor — this one matters a lot,
-- Query 13 assumes exactly this and will silently return duplicate rows without it
CREATE UNIQUE INDEX one_active_plan_per_investor
    ON CLIENT_PLAN (INVESTOR_ID) WHERE IS_ACTIVE = TRUE;
```
Before creating these, run a check for existing violations, since a unique partial index will fail to create if duplicates already exist:
```sql
SELECT investor_id, COUNT(*) FROM BANK_ACC WHERE is_primary
    GROUP BY investor_id HAVING COUNT(*) > 1;
SELECT investor_id, COUNT(*) FROM CLIENT_PLAN WHERE is_active
    GROUP BY investor_id HAVING COUNT(*) > 1;
```
If either returns rows, deactivate all but the most recent plan/account per investor before the index creation.
 
**4. Order-type consistency (C7 — cheap, closes a real gap)**
```sql
ALTER TABLE ORDER_RECORD ADD CONSTRAINT chk_limit_price
    CHECK (ORDER_TYPE NOT IN ('LIMIT','SL') OR LIMIT_PRICE IS NOT NULL);
ALTER TABLE ORDER_RECORD ADD CONSTRAINT chk_sl_price
    CHECK (ORDER_TYPE NOT IN ('SL','SL-M') OR STOP_LOSS_PRICE IS NOT NULL);
```
 
**5. `PRICE_HISTORY` (F1) — the one missing feature table your queries actually need**
```sql
CREATE TABLE PRICE_HISTORY (
    PRICE_ID    BIGSERIAL PRIMARY KEY,
    SECURITY_ID INT NOT NULL REFERENCES SECURITY(SECURITY_ID),
    PRICE_DATE  DATE NOT NULL,
    OPEN_PRICE  NUMERIC(15,4),
    HIGH_PRICE  NUMERIC(15,4),
    LOW_PRICE   NUMERIC(15,4),
    CLOSE_PRICE NUMERIC(15,4),
    VOLUME      BIGINT,
    UNIQUE (SECURITY_ID, PRICE_DATE)
);
```
Seed it with ~52 weeks of synthetic daily closes per security (a simple Python/SQL script generating a random walk around each security's current price is enough for a course project — realism isn't the point, having an authoritative price source instead of mining your own trade table is). This single table fixes Query 3 and Query 11's actual design flaw (they currently approximate "market price" from your own platform's execution history, which is architecturally wrong) and removes the staleness problem in `HOLDING.CURRENT_VALUE` (Issue D2) for free once Day 3 rewires those two queries to use it.
 
**6. Trimmed `AUDIT_LOG` (A3) — scoped to the 3 tables that actually matter for a trading platform**
```sql
CREATE TABLE AUDIT_LOG (
    AUDIT_ID    BIGSERIAL PRIMARY KEY,
    TABLE_NAME  VARCHAR(50) NOT NULL,
    RECORD_ID   BIGINT NOT NULL,
    ACTION      VARCHAR(10) CHECK (ACTION IN ('INSERT','UPDATE','DELETE')) NOT NULL,
    CHANGED_BY  INT REFERENCES "USER"(USER_ID),
    CHANGED_AT  TIMESTAMPTZ DEFAULT NOW(),
    OLD_VALUES  JSONB,
    NEW_VALUES  JSONB
);
 
CREATE OR REPLACE FUNCTION log_status_change() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO AUDIT_LOG(TABLE_NAME, RECORD_ID, ACTION, OLD_VALUES, NEW_VALUES)
    VALUES (TG_TABLE_NAME, NEW.order_id, 'UPDATE',
            to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
 
CREATE TRIGGER trg_order_status_audit
AFTER UPDATE OF status ON ORDER_RECORD
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION log_status_change();
```
Apply the same pattern (a couple hours of copy-adjust) to `KYC_DOCUMENT.VERIFICATION_STATUS` changes — that covers the two audit trails an examiner is most likely to ask about (order tampering, wrongful KYC rejection). Skip `USER` role-change auditing unless you finish early.
 
**7. Indexes (G1 — mandatory once real query volume is tested Day 4, cheap to do now)**
```sql
CREATE INDEX idx_trade_order_id       ON TRADE(ORDER_ID);
CREATE INDEX idx_order_investor_id    ON ORDER_RECORD(INVESTOR_ID);
CREATE INDEX idx_order_security_id    ON ORDER_RECORD(SECURITY_ID);
CREATE INDEX idx_holding_portfolio_id ON HOLDING(PORTFOLIO_ID);
CREATE INDEX idx_holding_security_id  ON HOLDING(SECURITY_ID);
CREATE INDEX idx_cgr_sell_trade_id    ON CAPITAL_GAINS_RECORD(SELL_TRADE_ID);
CREATE INDEX idx_cgr_buy_trade_id     ON CAPITAL_GAINS_RECORD(BUY_TRADE_ID);
CREATE INDEX idx_price_hist_sec_date  ON PRICE_HISTORY(SECURITY_ID, PRICE_DATE DESC);
```
 
**8. Re-run/patch INSERT data**
Because Day 1 dropped `AGE`, `TRADE.INVESTOR_ID`/`SECURITY_ID`, `CAPITAL_GAINS_RECORD.INVESTOR_ID`/`SECURITY_ID`/`ORDER_ID`, and `BANK_ACC.BANK_NAME`/`BRANCH_NAME`, and made `UNREALISED_PNL`/`TOTAL_CHARGES`/`GAIN_LOSS`/`GAIN_TYPE` generated (you can no longer `INSERT` values into those columns — Postgres will reject it), your existing `Insert-Table-Queries.txt` will fail to load as-is. Strip the now-generated/dropped columns out of every affected `INSERT INTO` column list and value tuple, producing `insert_v2.sql`.
 
### Deliverables
- `insert_v2.sql` loading cleanly against `schema_v2.sql`
- `PRICE_HISTORY` populated with ~1 year of synthetic daily prices per security
- `AUDIT_LOG` capturing order-status and KYC-status changes
### Validation
- Full DDL + insert script runs top-to-bottom on a fresh database with zero errors
- Manually flip an `ORDER_RECORD.STATUS`, confirm a row lands in `AUDIT_LOG`
- Try inserting a second `IS_PRIMARY = TRUE` bank account for the same investor — must fail
- Try inserting a `LIMIT` order with `LIMIT_PRICE = NULL` — must fail
### Effort estimate
6–7 hours (data migration + trigger testing is the slow part)
 
### End-of-day checklist
- [ ] `HNI` backfilled before constraint applied
- [ ] `BANK_BRANCH` cutover complete, old columns dropped
- [ ] C1/C2 unique partial indexes created and violation-free
- [ ] `PRICE_HISTORY` created and seeded
- [ ] `AUDIT_LOG` + 2 triggers working
- [ ] All FK-touching indexes created
- [ ] `insert_v2.sql` loads clean end-to-end
---

## DAY 3 — Query Fixes & Functional Testing
 
### Objectives
Get all query bugs fixed, decide on the missing Query 9, and confirm every one of the (now genuinely) 15 queries returns sane, expected output against the migrated schema.
 
### Files/tables to modify
`QUERIES__2_.sql` → `queries_v2.sql`
 
### Tasks (in order)
 
**1. Delete the duplicate Query 4 draft** (lines referencing `trading.plan`) — keep only the version joining `trading.brokerage_plan`.
 
**2. Fix naming bugs (E3, E4, E5, E6)** — these are the ones that currently throw `column does not exist`:
- Query 11: `t.price` → `t.fill_price` (appears **twice**, in both the `yearly_range` and `latest_price` CTEs)
- Query 12: `ta.avl_balance` → `ta.avail_balance`
- Query 12: `trading.trading_account` → `trading.trading_account` — wait, confirm actual table name is `TRADING_ACC`, so `trading.trading_account ta` → `trading.trading_acc ta`
- Query 13: `b.sebi_lic_no` → `b.sebi_license_no`
**3. Rewire Query 3 and Query 11 to use `PRICE_HISTORY` instead of mining `TRADE`** — this is the actual architectural fix, not just a typo patch:
```sql
-- Query 11 rebuilt on real market data
WITH yearly_range AS (
    SELECT SECURITY_ID,
           MAX(HIGH_PRICE) AS high_52w,
           MIN(LOW_PRICE)  AS low_52w,
           COUNT(*)        AS trade_count_52w
    FROM PRICE_HISTORY
    WHERE PRICE_DATE >= CURRENT_DATE - INTERVAL '52 weeks'
    GROUP BY SECURITY_ID
),
latest_price AS (
    SELECT DISTINCT ON (SECURITY_ID)
           SECURITY_ID, CLOSE_PRICE AS last_price, PRICE_DATE
    FROM PRICE_HISTORY
    ORDER BY SECURITY_ID, PRICE_DATE DESC
)
-- ...rest of the query unchanged, just swap the source CTEs
```
Apply the equivalent swap to Query 3's `recent_trades` CTE.
 
**4. Fix Query 12's `i.age` reference (D-1)**
```sql
-- replace:  i.age,
-- with:
EXTRACT(YEAR FROM AGE(i.dob)) AS age,
```
 
**5. Write the missing Query 9.** Looking at what the other 14 already cover (KYC status, tax liability, price volatility, brokerage cost comparison, MF drift, sector concentration, MF NAV tracking, holding-period tax classification, portfolio P&L ranking, momentum signals, investor 360, active plan lookup, monthly trade reconciliation, equity concentration risk) — the clear gap is **order execution efficiency**, since `ORDER_RECORD.STATUS` (`OPEN`/`EXECUTED`/`CANCELLED`/`PARTIAL`) isn't analyzed anywhere and it's also the column `chk_limit_price`/`chk_sl_price` now protect:
 
```sql
-- ===========================================================
-- QUERY 9 : Broker Order Execution Efficiency
-- ===========================================================
-- Problem Statement: Compliance and ops need to know each broker's
-- order fill rate — how many placed orders actually execute vs. get
-- cancelled or sit partially filled — to flag brokers with unusually
-- high cancellation rates for review.
 
SELECT
    b.broker_id,
    b.full_name AS broker_name,
    COUNT(o.order_id) AS total_orders,
    COUNT(o.order_id) FILTER (WHERE o.status = 'EXECUTED')  AS executed,
    COUNT(o.order_id) FILTER (WHERE o.status = 'CANCELLED') AS cancelled,
    COUNT(o.order_id) FILTER (WHERE o.status = 'PARTIAL')   AS partial,
    ROUND(
        COUNT(o.order_id) FILTER (WHERE o.status = 'EXECUTED')::numeric
        / NULLIF(COUNT(o.order_id), 0) * 100, 2
    ) AS fill_rate_pct
FROM trading.broker b
LEFT JOIN trading.order_record o ON o.placed_by_broker = b.broker_id
GROUP BY b.broker_id, b.full_name
ORDER BY fill_rate_pct ASC NULLS LAST;
```
 
**6. Run every query, one at a time, against the migrated data.** For each: confirm it returns rows (not empty — empty usually means a join/filter bug), spot-check 2–3 rows by hand against the raw tables, confirm no runtime errors.
 
### Deliverables
- `queries_v2.sql` with all 15 queries (14 fixed + Query 9 written), zero duplicates
- A short test log: query # → pass/fail → sample row output
### Validation/testing
- `EXPLAIN` (not yet `ANALYZE`, that's Day 4) each query — confirm no sequential scan warnings on tables >1000 rows given the Day 2 indexes
- Cross-check Query 2's tax totals against Query 8's holding-period classification for at least one investor — the numbers should tell a consistent story
### Effort estimate
5–6 hours
 
### End-of-day checklist
- [ ] Duplicate Query 4 removed
- [ ] E3/E4/E5/E6 naming bugs fixed
- [ ] Query 3 & 11 rewired onto `PRICE_HISTORY`
- [ ] Query 12's `i.age` fixed
- [ ] Query 9 written and tested
- [ ] All 15 queries execute cleanly with sane output
---
 
## DAY 4 — Performance, Edge Cases, Stress Testing
 
### Objectives
Move from "it runs" to "it's correct under adversarial and boundary conditions," and get real `EXPLAIN ANALYZE` numbers you can cite in your report/viva.
 
### Files/tables to modify
None structurally — this is a test-and-observe day. Optional: add C3–C8 remaining constraints if time allows.
 
### Tasks (in order)
 
**1. NULL/zero-division edge cases** — deliberately test the `NULLIF(...)` guards already in your queries:
- Insert a `HOLDING` row with `AVG_COST_PRICE = 0`, confirm Query 5/7/8's percentage calcs return `NULL` not an error
- Insert a `PORTFOLIO` with zero holdings, confirm Query 15 doesn't divide by zero
**2. Constraint violation testing** — for every constraint added Day 1/2, write one `INSERT`/`UPDATE` that should fail and confirm it does:
- Duplicate primary bank account per investor (C1)
- Two active plans for one investor (C2)
- `LIMIT` order with no `LIMIT_PRICE` (C7)
- `NULL` order status (Issue B)
- Attempted `DELETE FROM INVESTOR` — confirm `RESTRICT` blocks it (Issue H)
**3. `EXPLAIN ANALYZE` the 3–4 heaviest queries** (Query 2, 6, 8, 12 — the ones with multiple CTEs/joins):
```sql
EXPLAIN ANALYZE
<paste query 12 here>;
```
Record actual execution time and confirm indexes from Day 2 are being used (`Index Scan`, not `Seq Scan`, on the FK join columns). If a seq scan shows up on a large table, that's a missing index — add it now.
 
**4. Optional: remaining business-rule constraints (C3–C8)** if Days 1–3 finished on schedule:
```sql
ALTER TABLE FUND_TRANSACTION ADD CONSTRAINT chk_amt_positive CHECK (AMT > 0);
ALTER TABLE TRADING_ACC ADD CONSTRAINT chk_balance_nonneg CHECK (AVAIL_BALANCE >= 0);
ALTER TABLE HOLDING ADD CONSTRAINT chk_qty_nonneg CHECK (QUANTITY >= 0);
ALTER TABLE BROKER ADD CONSTRAINT chk_commission_bounds
    CHECK (COMMISSION_RATE >= 0 AND COMMISSION_RATE <= 100);
ALTER TABLE BROKERAGE_PLAN ADD CONSTRAINT chk_brokerage_pct_bounds
    CHECK (BROKERAGE_PERCENT >= 0 AND BROKERAGE_PERCENT <= 100);
```
If time is tight, skip these and just list them in your report as "identified, deferred" — don't let this bleed into Day 5.
 
### Deliverables
- A test results table (constraint → attempted violation → pass/fail)
- `EXPLAIN ANALYZE` output for the 4 heaviest queries, before/after index comparison if you have time to drop-and-recreate one index to show the difference
### Validation/testing
This *is* the validation day — the deliverable and the testing are the same artifact.
 
### Effort estimate
5 hours
 
### End-of-day checklist
- [ ] All edge cases produce `NULL`/graceful results, not errors
- [ ] Every added constraint has a confirmed-failing test case
- [ ] `EXPLAIN ANALYZE` captured for Query 2, 6, 8, 12
- [ ] No sequential scans on FK joins for tables of meaningful size
- [ ] (Optional) C3–C8 added if time allowed
---
 
## DAY 5 — Documentation, Deployment, Viva Prep
 
### Objectives
Package everything so it's demoable, defensible, and submittable.
 
### Tasks (in order)
 
**1. Update the BCNF proof document** to reflect the *generated-column* decision (D-2) instead of blind deletion — this is a genuinely stronger academic answer than the original draft: you're showing you understand that BCNF's real goal is *preventing update anomalies*, and a `GENERATED STORED` column achieves that without sacrificing query ergonomics. Add one paragraph explaining why generated columns satisfy the spirit of the rule even though the FD technically still "exists" — the anomaly, not the FD, is what BCNF cares about eliminating in practice.
 
**2. Update the ERD** to reflect: `BANK_BRANCH` as a new entity, `AGE` removed from `INVESTOR`, `PRICE_HISTORY`/`AUDIT_LOG` as new entities, `HNI` removed as a discriminator value.
 
**3. Write the "Known Limitations" section** — this is what turns unfinished scope into a strength rather than a gap:
- Full Aadhaar column encryption (D-6) — schema supports it, deferred due to uniqueness-constraint complexity
- F2–F5 feature tables (SIP, dividends, watchlists, compliance flags) — scoped out of v1, no dependents in current queries
- `SERIAL`→`BIGSERIAL`, `TIMESTAMPTZ`, partitioning — acknowledged, not urgent at current volume
**4. Deploy** to a hosted Postgres instance (Supabase, Neon, Render, or ElephantSQL free tier all work fine for a course project):
- Run `schema_v2.sql`, then `insert_v2.sql`, then confirm `queries_v2.sql` runs clean against the hosted instance (not just local — connection/extension availability for `pgcrypto` can differ by host, check this early in the day, not at 11pm)
- Take a fresh `pg_dump` backup once everything loads clean
**5. Prepare the demo script** — pick 4–5 queries that best show off the fixes (suggest: Query 1 for the NOT NULL fix, Query 9 as the new addition, Query 11 to show the `PRICE_HISTORY` architecture fix, Query 13 to show the C2 constraint actually preventing the bug it used to have) and rehearse running them live.
 
**6. Final review pass** — re-read the Priority Matrix from section 1, confirm every P0/P1 item is checked off; P2/P3 should be done; P4 stretch items are fine to leave documented-not-built.
 
### Deliverables
- Final `schema_v2.sql`, `insert_v2.sql`, `queries_v2.sql`
- Updated ERD + BCNF proof document
- "Known Limitations" writeup
- Deployed, working instance + `pg_dump` backup
- Demo script
### Validation/testing
- Full fresh-clone test: on a clean machine/database, run all three SQL files top-to-bottom with zero manual intervention
- Have someone else (or you, cold, tomorrow morning) run the demo script without your help
### Effort estimate
5–6 hours
 
### End-of-day checklist
- [ ] BCNF doc updated with the generated-column rationale
- [ ] ERD updated
- [ ] Known Limitations section written
- [ ] Deployed and backed up
- [ ] Demo script rehearsed at least once, live, on the deployed instance
- [ ] Every P0/P1 item from the Priority Matrix confirmed complete
---
 
## Quick reference — what NOT to do this week
 
Don't let scope creep pull you into: app-layer bcrypt (you have no app layer — do it in SQL via `pgcrypto`, that's a legitimate answer), full audit logging on every table (2 triggers on the tables an examiner would actually ask about is enough), building all five F1–F5 feature tables (only F1 has query dependents), or partitioning/`BIGSERIAL` migrations (zero functional benefit at your data volume, pure time sink). If Day 3 or 4 runs long, the first things to cut are the optional C3–C8 constraints and the F2–F5 documentation depth — not the schema fixes or the query test pass.







