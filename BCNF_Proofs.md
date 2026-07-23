# BCNF Normalization Proofs — StockVault Schema

> **Definition (BCNF):** A relation *R* is in Boyce-Codd Normal Form (BCNF) if and only if for every non-trivial functional dependency *X → Y* that holds on *R*, *X* is a **superkey** of *R*.
>
> A *superkey* is a set of attributes that functionally determines **all** attributes of the relation. A *candidate key* is a minimal superkey.

---

## Summary

All **15 tables** in the StockVault schema are in **BCNF**.

The schema achieves this because:
1. Every table has a well-defined **surrogate or natural primary key**.
2. All **UNIQUE constraints** define additional candidate keys (e.g., `EMAIL`, `PAN_NO`, `ISIN`, `ACC_NO`).
3. Every non-key attribute is **fully functionally dependent** on every candidate key.
4. There are **no transitive dependencies** where a non-superkey determines other attributes.
5. Foreign keys reference other tables but do not create intra-table partial or transitive dependencies.

---

## Table-by-Table BCNF Proofs

---

### 1. INVESTOR

**Attributes:** `INVESTOR_ID, FULL_NAME, EMAIL, PASSWORD_HASH, PAN_NO, AADHAR_NO, DOB, KYC_STATUS, IS_ACTIVE, CREATED_AT, INVESTOR_TYPE, RISK_PROFILE, CIN_NO`

**Candidate Keys:**
- `{INVESTOR_ID}` — Primary Key
- `{EMAIL}` — UNIQUE
- `{PAN_NO}` — UNIQUE
- `{AADHAR_NO}` — UNIQUE
- `{CIN_NO}` — UNIQUE (for non-null tuples)

**Functional Dependencies:**
```
INVESTOR_ID  → {all attributes}
EMAIL        → {all attributes}
PAN_NO       → {all attributes}
AADHAR_NO    → {all attributes}
CIN_NO       → {all attributes}   (for non-null values)
```

**BCNF Proof:**
- Every determinant (`INVESTOR_ID`, `EMAIL`, `PAN_NO`, `AADHAR_NO`, `CIN_NO`) is a candidate key, hence a superkey.
- No attribute functionally determines a proper subset of attributes without being a superkey.
- The subtype check constraint (`chk_investor_subtype_fields`) enforces a business rule but does not create a functional dependency from `INVESTOR_TYPE` to `RISK_PROFILE` or `CIN_NO` because `INVESTOR_TYPE` does not uniquely determine either attribute (e.g., `RETAIL` investors may have varying `RISK_PROFILE` values).

**Conclusion:** ✅ **INVESTOR is in BCNF.**

---

### 2. KYC_DOCUMENT

**Attributes:** `DOC_ID, DOC_NO, DOC_TYPE, ISSUE_DATE, EXPIRY_DATE, VERIFICATION_STATUS, INVESTOR_ID`

**Candidate Keys:**
- `{DOC_ID}` — Primary Key
- `{DOC_NO}` — UNIQUE

**Functional Dependencies:**
```
DOC_ID      → {all attributes}
DOC_NO      → {all attributes}
```

**BCNF Proof:**
- `INVESTOR_ID` is **not** a candidate key (one investor may submit multiple KYC documents).
- There is no dependency such as `DOC_TYPE → VERIFICATION_STATUS` because multiple documents of the same type can have different statuses.
- Every determinant is a superkey.

**Conclusion:** ✅ **KYC_DOCUMENT is in BCNF.**

---

### 3. TRADING_ACC

**Attributes:** `TA_ID, INVESTOR_ID, IS_ACTIVE, AVAIL_BALANCE, OPEN_DATE`

**Candidate Keys:**
- `{TA_ID}` — Primary Key

**Functional Dependencies:**
```
TA_ID → {all attributes}
```

**BCNF Proof:**
- `INVESTOR_ID` is **not** a candidate key (an investor may hold multiple trading accounts).
- No other attribute or combination uniquely determines all attributes.
- The only determinant is `TA_ID`, which is a superkey.

**Conclusion:** ✅ **TRADING_ACC is in BCNF.**

---

### 4. BANK_ACC

**Attributes:** `BANK_ACC_ID, ACC_NO, IFSC_CODE, BANK_NAME, BRANCH_NAME, IS_PRIMARY, INVESTOR_ID`

**Candidate Keys:**
- `{BANK_ACC_ID}` — Primary Key
- `{ACC_NO}` — UNIQUE

**Functional Dependencies:**
```
BANK_ACC_ID → {all attributes}
ACC_NO      → {all attributes}
```

**BCNF Proof:**
- `INVESTOR_ID` is **not** a candidate key (one investor may link multiple bank accounts).
- `IFSC_CODE` is **not** a candidate key (multiple accounts may share the same IFSC).
- The partial unique index `uq_bank_acc_one_primary_per_investor` enforces at most one primary account per investor, but this is a conditional constraint, not a table-wide candidate key.
- Every determinant is a superkey.

**Conclusion:** ✅ **BANK_ACC is in BCNF.**

---

### 5. BROKER

**Attributes:** `BROKER_ID, FULL_NAME, EMAIL, PASSWORD_HASH, SEBI_LICENSE_NO, COMMISSION_RATE, IS_ACTIVE`

**Candidate Keys:**
- `{BROKER_ID}` — Primary Key
- `{EMAIL}` — UNIQUE
- `{SEBI_LICENSE_NO}` — UNIQUE

**Functional Dependencies:**
```
BROKER_ID       → {all attributes}
EMAIL           → {all attributes}
SEBI_LICENSE_NO → {all attributes}
```

**BCNF Proof:**
- Every determinant (`BROKER_ID`, `EMAIL`, `SEBI_LICENSE_NO`) is a candidate key.
- No non-key attribute determines any other attribute (e.g., `COMMISSION_RATE` does not determine `IS_ACTIVE`).

**Conclusion:** ✅ **BROKER is in BCNF.**

---

### 6. FUND_TRANSACTION

**Attributes:** `TXN_ID, TA_ID, BANK_ACC_ID, TXN_TYPE, AMT, BALANCE_AFTER, TXN_DATE_TIME`

**Candidate Keys:**
- `{TXN_ID}` — Primary Key

**Functional Dependencies:**
```
TXN_ID → {all attributes}
```

**BCNF Proof:**
- `TA_ID` is **not** a candidate key (one trading account may have many transactions).
- `BANK_ACC_ID` is **not** a candidate key (nullable and non-unique).
- The only determinant is `TXN_ID`, which is a superkey.

**Conclusion:** ✅ **FUND_TRANSACTION is in BCNF.**

---

### 7. PLAN_CATALOG

**Attributes:** `PLAN_TYPE, BROKERAGE_PERCENT, IS_ACTIVE`

**Candidate Keys:**
- `{PLAN_TYPE}` — Primary Key

**Functional Dependencies:**
```
PLAN_TYPE → {all attributes}
```

**BCNF Proof:**
- `BROKERAGE_PERCENT` is **not** a candidate key (multiple plans could theoretically share the same rate).
- The only determinant is `PLAN_TYPE`, which is a superkey.

**Conclusion:** ✅ **PLAN_CATALOG is in BCNF.**

---

### 8. BROKER_CLIENT

**Attributes:** `BC_ID, INVESTOR_ID, BROKER_ID, POA_GRANTED, IS_ACTIVE, PLAN_TYPE, PLAN_START_DATE, PLAN_END_DATE`

**Candidate Keys:**
- `{BC_ID}` — Primary Key
- `{INVESTOR_ID, BROKER_ID}` — UNIQUE

**Functional Dependencies:**
```
BC_ID                    → {all attributes}
{INVESTOR_ID, BROKER_ID} → {all attributes}
```

**BCNF Proof:**
- `INVESTOR_ID` alone is **not** a candidate key (one investor may engage with multiple brokers).
- `BROKER_ID` alone is **not** a candidate key (one broker may manage multiple investors).
- `PLAN_TYPE` alone is **not** a candidate key.
- Both determinants are superkeys.
- There is no partial dependency: non-key attributes (`POA_GRANTED`, `PLAN_TYPE`, etc.) depend on the **entire** composite key `{INVESTOR_ID, BROKER_ID}`, not on a subset.

**Conclusion:** ✅ **BROKER_CLIENT is in BCNF.**

---

### 9. SECURITY

**Attributes:** `SECURITY_ID, TICKER, COMPANY_NAME, EXCHANGE, SECURITY_TYPE, ISIN, SECTOR, IS_ACTIVE`

**Candidate Keys:**
- `{SECURITY_ID}` — Primary Key
- `{TICKER}` — UNIQUE
- `{ISIN}` — UNIQUE

**Functional Dependencies:**
```
SECURITY_ID → {all attributes}
TICKER      → {all attributes}
ISIN        → {all attributes}
```

**BCNF Proof:**
- `EXCHANGE` is **not** a candidate key (multiple securities trade on the same exchange).
- `SECURITY_TYPE` is **not** a candidate key.
- Every determinant is a superkey.
- Note: `SECURITY_TYPE` determines which subtype table (`EQUITY` or `MUTUAL_FUND`) a row extends into, but this is an inter-table ISA constraint, not an intra-table functional dependency.

**Conclusion:** ✅ **SECURITY is in BCNF.**

---

### 10. EQUITY

**Attributes:** `SECURITY_ID, MARKET_CAP, PE_RATIO, EPS`

**Candidate Keys:**
- `{SECURITY_ID}` — Primary Key

**Functional Dependencies:**
```
SECURITY_ID → {all attributes}
```

**BCNF Proof:**
- This is a **subtype/ISA** table. `SECURITY_ID` references `SECURITY(SECURITY_ID)`.
- No non-key attribute determines another (e.g., `MARKET_CAP` does not determine `PE_RATIO`).
- The only determinant is the primary key.

**Conclusion:** ✅ **EQUITY is in BCNF.**

---

### 11. MUTUAL_FUND

**Attributes:** `SECURITY_ID, AMC_NAME, SCHEME_CATEGORY, NAV, NAV_DATE, EXPENSE_RATIO`

**Candidate Keys:**
- `{SECURITY_ID}` — Primary Key

**Functional Dependencies:**
```
SECURITY_ID → {all attributes}
```

**BCNF Proof:**
- This is a **subtype/ISA** table. `SECURITY_ID` references `SECURITY(SECURITY_ID)`.
- `AMC_NAME` is **not** a candidate key (one AMC may offer multiple schemes).
- The only determinant is the primary key.

**Conclusion:** ✅ **MUTUAL_FUND is in BCNF.**

---

### 12. HOLDING

**Attributes:** `HOLDING_ID, INVESTOR_ID, SECURITY_ID, QUANTITY, AVG_COST_PRICE, CURRENT_VALUE, LAST_UPDATED`

**Candidate Keys:**
- `{HOLDING_ID}` — Primary Key
- `{INVESTOR_ID, SECURITY_ID}` — UNIQUE

**Functional Dependencies:**
```
HOLDING_ID               → {all attributes}
{INVESTOR_ID, SECURITY_ID} → {all attributes}
```

**BCNF Proof:**
- `INVESTOR_ID` alone is **not** a candidate key (one investor holds multiple securities).
- `SECURITY_ID` alone is **not** a candidate key (one security is held by multiple investors).
- Both determinants are superkeys.
- There is no partial dependency: `QUANTITY`, `AVG_COST_PRICE`, etc. depend on the **entire** composite key, not on `INVESTOR_ID` or `SECURITY_ID` individually.

**Conclusion:** ✅ **HOLDING is in BCNF.**

---

### 13. ORDER_RECORD

**Attributes:** `ORDER_ID, SECURITY_ID, TA_ID, PLACED_BY_BROKER, SIDE, ORDER_TYPE, QUANTITY, LIMIT_PRICE, STOP_LOSS_PRICE, STATUS, PLACED_AT`

**Candidate Keys:**
- `{ORDER_ID}` — Primary Key

**Functional Dependencies:**
```
ORDER_ID → {all attributes}
```

**BCNF Proof:**
- `TA_ID` is **not** a candidate key (one trading account may place many orders).
- `SECURITY_ID` is **not** a candidate key.
- `PLACED_BY_BROKER` is **not** a candidate key (nullable and non-unique).
- The only determinant is `ORDER_ID`, which is a superkey.

**Conclusion:** ✅ **ORDER_RECORD is in BCNF.**

---

### 14. TRADE

**Attributes:** `TRADE_ID, ORDER_ID, TRADE_REF, FILL_PRICE, FILLED_QTY, TRADE_DATETIME, BROKERAGE_FEE, EXCHANGE_CHARGES, STT, NET_AMOUNT`

**Candidate Keys:**
- `{TRADE_ID}` — Primary Key
- `{TRADE_REF}` — UNIQUE (for non-null tuples)

**Functional Dependencies:**
```
TRADE_ID   → {all attributes}
TRADE_REF  → {all attributes}   (for non-null values)
```

**BCNF Proof:**
- `ORDER_ID` is **not** a candidate key (one order may generate multiple trades, e.g., partial fills).
- Both determinants are superkeys.
- No non-key attribute determines another (e.g., `FILL_PRICE` does not determine `BROKERAGE_FEE`, which is computed independently).

**Conclusion:** ✅ **TRADE is in BCNF.**

---

### 15. CAPITAL_GAINS_RECORD

**Attributes:** `CG_ID, BUY_TRADE_ID, SELL_TRADE_ID, BUY_PRICE, SELL_PRICE, QUANTITY, TAX_AMOUNT, HOLDING_DAYS`

**Candidate Keys:**
- `{CG_ID}` — Primary Key

**Functional Dependencies:**
```
CG_ID → {all attributes}
```

**BCNF Proof:**
- `BUY_TRADE_ID` is **not** a candidate key (one buy trade may match multiple sell lots).
- `SELL_TRADE_ID` is **not** a candidate key.
- `{BUY_TRADE_ID, SELL_TRADE_ID}` is **not** declared as UNIQUE in the schema (business logic may imply uniqueness, but the schema does not enforce it as a candidate key).
- The only declared determinant is `CG_ID`, which is a superkey.

**Conclusion:** ✅ **CAPITAL_GAINS_RECORD is in BCNF.**

---

## Global Schema Assessment

| Table | Candidate Key(s) | BCNF Status |
|-------|-----------------|-------------|
| INVESTOR | `INVESTOR_ID`, `EMAIL`, `PAN_NO`, `AADHAR_NO`, `CIN_NO` | ✅ BCNF |
| KYC_DOCUMENT | `DOC_ID`, `DOC_NO` | ✅ BCNF |
| TRADING_ACC | `TA_ID` | ✅ BCNF |
| BANK_ACC | `BANK_ACC_ID`, `ACC_NO` | ✅ BCNF |
| BROKER | `BROKER_ID`, `EMAIL`, `SEBI_LICENSE_NO` | ✅ BCNF |
| FUND_TRANSACTION | `TXN_ID` | ✅ BCNF |
| PLAN_CATALOG | `PLAN_TYPE` | ✅ BCNF |
| BROKER_CLIENT | `BC_ID`, `(INVESTOR_ID, BROKER_ID)` | ✅ BCNF |
| SECURITY | `SECURITY_ID`, `TICKER`, `ISIN` | ✅ BCNF |
| EQUITY | `SECURITY_ID` | ✅ BCNF |
| MUTUAL_FUND | `SECURITY_ID` | ✅ BCNF |
| HOLDING | `HOLDING_ID`, `(INVESTOR_ID, SECURITY_ID)` | ✅ BCNF |
| ORDER_RECORD | `ORDER_ID` | ✅ BCNF |
| TRADE | `TRADE_ID`, `TRADE_REF` | ✅ BCNF |
| CAPITAL_GAINS_RECORD | `CG_ID` | ✅ BCNF |

---

## Why the Schema Naturally Achieves BCNF

1. **Surrogate Keys:** Most tables use `IDENTITY` or `UUID` primary keys, eliminating composite-key partial-dependency risks.

2. **Natural Keys as Alternate Keys:** Business identifiers (`PAN_NO`, `EMAIL`, `ISIN`, `ACC_NO`, `SEBI_LICENSE_NO`) are enforced via `UNIQUE` constraints, ensuring they are candidate keys and not just attributes with accidental uniqueness.

3. **ISA Hierarchy Separation:** `EQUITY` and `MUTUAL_FUND` store subtype-specific attributes in separate tables rather than cramming them into `SECURITY` with NULLs, avoiding the "one wide sparse table" anti-pattern that often violates normalization.

4. **Associative Entities:** Many-to-many relationships (`INVESTOR ↔ BROKER`, `INVESTOR ↔ SECURITY`) are resolved into bridge tables (`BROKER_CLIENT`, `HOLDING`) with their own surrogate keys and composite unique constraints, keeping dependencies clean.

5. **No Transitive Dependencies:** Attributes like `BROKERAGE_PERCENT` live in `PLAN_CATALOG`, not duplicated in `BROKER_CLIENT`. Foreign keys reference them rather than copying values, preventing update anomalies.

---

*End of BCNF Proofs*
