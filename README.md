# StockVault: Relational Database Design, BCNF Normalization & Advanced Financial Analytics

StockVault is a comprehensive, production-ready relational database solution engineered for a multi-asset trading and portfolio management platform. Built on **PostgreSQL**, the system manages the complete lifecycle of financial operations—ranging from user onboarding, KYC compliance tracking, and broker infrastructure to order routing, multi-asset security tracking (Equities, Mutual Funds), portfolio tracking, and capital gains tax auditing.

This repository provides the entire database engineering workflow, including foundational Entity-Relationship Diagram (ERD) blueprints, rigorous mathematical Boyce-Codd Normal Form (BCNF) validation proofs, full DDL implementation scripts, synthetic high-fidelity datasets, and 15 complex business intelligence queries.

---

## 📂 Repository Structure

The repository contains the following core assets:

1.  **`202401077_ERD_Relational_BCNF-Proofs.pdf`** The theoretical framework and normalization dossier. Contains the structural ER Diagram, functional dependency (FD) maps, candidate key derivations, identification of BCNF anomalies, and mathematical validation of lossless decompositions.
2.  **`Create-Table-Queries.txt`** The DDL engineering script defining the underlying database structure. Initializes the isolated `trading` schema namespace and constructs **22 distinct relational tables** integrated with strict constraints (`PRIMARY KEY`, `UNIQUE`, `FOREIGN KEY`, `CHECK`).
3.  **`Insert-Table-Queries.txt`** The data ingestion script. Populates the schema with a rich, synchronized mock dataset containing **30 to 40 diverse rows per table** to reliably simulate transaction flows and trigger meaningful results across all analytics.
4.  **`QUERIES (2).sql`** The analytical engine. Features **15 state-of-the-art business intelligence SQL queries** addressing complex reporting requirements, operational bottlenecks, compliance surveillance, and risk management.

---

## 📐 Schema Architecture & Relationships

All entities are contained securely within the `trading` schema namespace. The architecture maps out modern financial platform dynamics through cleanly isolated operational layers:

* **Identity & Onboarding:** Features an abstract base `USER` table subtyped into specific platform roles (`INVESTOR`, `BROKER`, and `COMPLIANCE_OFFICER`) to uphold strict data segregation and access control.
* **Compliance & Audit Trails:** Tracks individual verification vectors via the `KYC_DOCUMENT` ledger, monitoring statuses (`VERIFIED`, `PENDING`, `REJECTED`) for automated compliance checking.
* **Market Instruments:** Accommodates diverse asset classes by separating static financial instrument markers into specialized tracks, such as `EQUITY` metadata (EPS, P/E Ratios) and `MUTUAL_FUND` entities (NAV history, Expense Ratios).
* **Order & Trade Execution Engine:** Models order routing cycles from initial `ORDER_RECORD` capture (type, status, limit constraints) down to step-by-step full or partial order execution tracking within the `TRADE` log.
* **Portfolio Ledger & Accounting:** Aggregates running asset counts via `HOLDING` records, while automatically breaking down tax treatments within the `CAPITAL_GAINS_RECORD` ledger.

---

## 🧮 Normalization & BCNF Analysis Insights

To ensure maximum structural integrity, remove update/delete anomalies, and avoid structural layout issues, a comprehensive Functional Dependency (FD) audit was conducted over the initial schema draft. 

### Summary Metrics
* **Total Tables Checked:** 22  
* **Tables Fully Compliant with BCNF:** 17  
* **Tables Flagged with BCNF Violations:** 5 (`INVESTOR`, `BANK_ACC`, `HOLDING`, `TRADE`, `CAPITAL_GAINS_RECORD`)  
* **Total Relational Violations Resolved:** 7  
* **Decomposition Outcome:** 100% Lossless Join and Dependency-Preserving

### Structural Anti-Patterns & Academic Fixes
The BCNF anomalies caught and mitigated during formal verification fell into two main structural database design issues:

1.  **Storage of Derived / Computed Attributes** * *The Issue:* Storing attributes that are direct mathematical functions of other existing primitive values (e.g., storing `AGE` alongside `DOB`, `UNREALISED_PNL` calculated from quantities and market prices, `TOTAL_CHARGES` aggregating sub-fee rows, or `GAIN_LOSS`/`GAIN_TYPE` inside transaction history tables).
    * *The Remedy:* Removed these attributes from the physical base tables. Because derived values can be dynamically calculated in real time using SQL views or mathematical window functions, dropping them ensures an irreducible data model.
2.  **Transitive Redundancy via Foreign-Key Chains** * *The Issue:* Redundant relational paths where an entity holds a reference to an ancestor's primary key despite already being linked to its direct parent. For instance, storing `INVESTOR_ID` and `SECURITY_ID` directly inside a `TRADE` row when that `TRADE` already points to an `ORDER_ID` (which itself explicitly resolves back to the original `INVESTOR_ID` and `SECURITY_ID`). Since `ORDER_ID` is not a superkey in `TRADE` (a single order can generate multiple partial-fill executions), this constitutes a formal BCNF redundancy violation.
    * *The Remedy:* Pruned the redundant tracking paths, forcing the data engine to traverse the natural hierarchy (`TRADE` $\rightarrow$ `ORDER_RECORD` $\rightarrow$ `INVESTOR`), ensuring a single source of truth.

---

## ⚡ Deployment & Installation Guide

To set up and run StockVault locally or in a cloud instance, execute the scripts sequentially using an administrative account in **PostgreSQL**:

### Step 1: Initialize Database & Schema
Open your preferred query environment (such as the `psql` interactive terminal or pgAdmin), load the table definitions script, and run it to construct the database schema shell:
```bash
psql -U your_username -d your_database -f Create-Table-Queries.txt
