<div align="center">

  <img src="docs/screenshots/dashboard_overview.png" alt="StockVault DBMS Explorer Dashboard" width="100%" style="border-radius: 12px; box-shadow: 0 20px 40px rgba(0,0,0,0.4);" />

  <br/><br/>

  # 🛡️ StockVault — Portfolio Management & Brokerage DBMS
  ### Production-Grade PostgreSQL 15+ Core • BCNF Normalized • Full-Stack DBMS Explorer

  <p align="center">
    A comprehensive FinTech relational database platform modeling the end-to-end data architecture of an enterprise stock trading ecosystem. Normalized to <strong>Boyce-Codd Normal Form (BCNF)</strong>, powered by <strong>9 PL/pgSQL business triggers</strong>, <strong>7 analytical views</strong>, <strong>16 performance indexes</strong>, and an interactive <strong>full-stack DBMS Explorer web application</strong>.
  </p>

  <p align="center">
    <a href="https://github.com/Elite407/StockVault---Portfolio-Management-system/actions/workflows/ci.yml">
      <img src="https://img.shields.io/badge/CI-Automated_Tests_Passing-10B981?style=for-the-badge&logo=githubactions&logoColor=white" alt="CI Status" />
    </a>
    <img src="https://img.shields.io/badge/PostgreSQL-15%2B-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
    <img src="https://img.shields.io/badge/Schema-15_Tables_(BCNF)-8B5CF6?style=for-the-badge&logo=databricks&logoColor=white" alt="BCNF Schema" />
    <img src="https://img.shields.io/badge/Node.js-v20%2B-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js" />
    <img src="https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge" alt="License" />
  </p>

</div>

---

## 📑 Table of Contents

- [Live Proof of Work & Showcase](#-live-proof-of-work--showcase)
- [System Architecture & Value Proposition](#-system-architecture--value-proposition)
- [Entity-Relationship Diagram (15 Tables)](#️-entity-relationship-diagram-15-tables)
- [BCNF Normalization & Mathematical Integrity](#-bcnf-normalization--mathematical-integrity)
- [Business Automation Engine (9 Triggers)](#-business-automation-engine-9-triggers)
- [Pre-Built Views (7 Analytical Views)](#-pre-built-views-7-analytical-views)
- [Production Queries Catalogue (30 Queries)](#-production-queries-catalogue-30-queries)
- [Multi-Tier Automated Test Suite](#-multi-tier-automated-test-suite)
- [Quickstart & Local Setup](#️-quickstart--local-setup)
- [Project Directory Layout](#-project-directory-layout)
- [Author & Credits](#-author--credits)

---

## 📸 Live Proof of Work & Showcase

StockVault includes a full-stack DBMS Explorer and SQL Workbench that runs locally or in the cloud, giving developers, database administrators, and evaluators a live visual window into the database:

### 1️⃣ Analytics Dashboard & Real-Time Mark-to-Market KPI Grid
<p align="center">
  <img src="docs/screenshots/dashboard_overview.png" alt="Analytics Dashboard" width="95%" style="border-radius: 8px;" />
</p>

- **Dynamic Stats Grid**: Real-time aggregation of Total Assets Under Management (**AUM: ₹1.19 Cr**), Daily Trading Turnover (**₹1.72 Cr**), Active Verified Investors, and SEBI-licensed Brokers.
- **Risk Profile Allocation**: Doughnut chart rendering investor distribution across `CONSERVATIVE`, `MODERATE`, `AGGRESSIVE`, `HNI`, and `INSTITUTIONAL` tiers.
- **Securities Exposure**: Top-grossing blue-chip equities (`RELIANCE`, `HDFCBANK`, `ICICIBANK`, `INFY`, `TCS`).
- **Live Order Book Ticker**: Executed fills with automatic trigger-driven holdings reconciliation and statutory fee breakdowns.

---

### 2️⃣ Interactive SQL Workbench & Sandbox Playground
<p align="center">
  <img src="docs/screenshots/sql_playground.png" alt="SQL Playground" width="95%" style="border-radius: 8px;" />
</p>

- **Query Execution Engine**: Runs live queries directly against the PostgreSQL `trading` schema.
- **Strict Read-Only Guard**: Syntax filter allowing only `SELECT` and `WITH` statements, rejecting mutative DDL/DML statements (`DROP`, `DELETE`, `INSERT`, `UPDATE`, `ALTER`, `TRUNCATE`) with `403 Forbidden`.
- **Execution Analytics**: Microsecond-precision execution timer, returned row counters, and one-click **CSV Data Export**.

---

### 3️⃣ Interactive Relational Schema Explorer
<p align="center">
  <img src="docs/screenshots/schema_explorer.png" alt="Schema Explorer" width="95%" style="border-radius: 8px;" />
</p>

- **3-Panel Inspector**: Browse all 15 tables with live column data types, nullability, unique keys, and check constraints.
- **ISA Subtype Visualizer**: Clear visual indications of supertype–subtype hierarchies for `INVESTOR (Retail/Institutional)` and `SECURITY (Equity/Mutual Fund)`.
- **BCNF Proof Card**: Direct mathematical justification for why each table is free of update, insertion, and deletion anomalies.

---

### 4️⃣ Comprehensive Query Presets Catalogue (30 Queries)
<p align="center">
  <img src="docs/screenshots/query_presets.png" alt="Query Presets" width="95%" style="border-radius: 8px;" />
</p>

- Categorized query library containing **13 Analytical queries** (dormant accounts, broker turnover, KYC expirations, cancellation ratios) and **17 Application queries** (order placement guards, holdings sync, capital gains tax logs).
- **One-Click Execution**: Loads queries directly into the SQL Playground.

---

### 5️⃣ System Proofs & Verification Matrix
<p align="center">
  <img src="docs/screenshots/test_proofs.png" alt="System Proofs" width="95%" style="border-radius: 8px;" />
</p>

- Automated test harness validating schema structure, constraints, triggers, views, indexes, RLS multi-tenant security, and financial invariants.

---

## 🎯 System Architecture & Value Proposition

StockVault is built to model the exact operational reality of an Indian FinTech brokerage (such as Zerodha or Groww):

| Domain Requirement | Architectural Solution |
|---|---|
| **Investor Hierarchy** | Supertype–Subtype ISA hierarchy separating **Retail** investors (Risk Profile, DOB) from **Institutional** funds (CIN, Corporate registration) with zero redundant columns. |
| **Balance Conservation** | Automated PL/pgSQL triggers guarantee that deposits credit balances immediately, withdrawals reject overdrafts, and BUY trades deduct cash atomically. |
| **Statutory Fee Breakdown** | Order fills automatically calculate **Brokerage Fee**, **STT** (Securities Transaction Tax), and **Exchange Turnover Charges** per SEBI guidelines. |
| **Capital Gains Accounting** | Trade ledger automatically computes realized gain/loss and accurately classifies taxation into **STCG** (&le; 365 days) vs **LTCG** (> 365 days). |
| **Multi-Tenant Security** | PostgreSQL **Row Level Security (RLS)** restricts investors to viewing only their own balances, holdings, and trades while allowing public reads on securities. |

---

## 🗃️ Entity-Relationship Diagram (15 Tables)

Below is the normalized relational diagram modeling all 15 entities in the `trading` schema:

```mermaid
erDiagram
    INVESTOR ||--o{ KYC_DOCUMENT : "verifies"
    INVESTOR ||--o{ TRADING_ACC : "owns"
    INVESTOR ||--o{ BANK_ACC : "links"
    INVESTOR ||--o{ BROKER_CLIENT : "subscribes"
    INVESTOR ||--o{ HOLDING : "holds"

    BROKER ||--o{ BROKER_CLIENT : "services"
    PLAN_CATALOG ||--o{ BROKER_CLIENT : "governs"

    TRADING_ACC ||--o{ FUND_TRANSACTION : "logs"
    TRADING_ACC ||--o{ ORDER_RECORD : "places"
    BROKER ||--o{ ORDER_RECORD : "routes"

    SECURITY ||--o{ EQUITY : "isa"
    SECURITY ||--o{ MUTUAL_FUND : "isa"
    SECURITY ||--o{ ORDER_RECORD : "targeted_by"
    SECURITY ||--o{ HOLDING : "tracked_in"

    ORDER_RECORD ||--o| TRADE : "fills"
    TRADE ||--o{ CAPITAL_GAINS_RECORD : "buy_leg"
    TRADE ||--o{ CAPITAL_GAINS_RECORD : "sell_leg"
```

---

## 📐 BCNF Normalization & Mathematical Integrity

Every relation in StockVault satisfies **Boyce-Codd Normal Form (BCNF)**:

$$\forall X \rightarrow Y \implies X \text{ is a superkey of relation } R$$

### Key Normalization Highlights
1. **No Redundant Functional Dependencies**:
   - `BANK_ACC` stores only `(BANK_ACC_ID, ACC_NO, IFSC_CODE, IS_PRIMARY, INVESTOR_ID)`. Bank name and branch details are derived from IFSC to eliminate transitivities.
2. **Elimination of Temporal Redundancy**:
   - `AGE` is intentionally omitted from `INVESTOR` and computed on-the-fly (`EXTRACT(YEAR FROM AGE(DOB))`) to prevent update anomalies.
3. **Derived Metrics Isolation**:
   - Portfolio `UNREALIZED_PNL` and Trade `NET_AMOUNT` are computed via deterministic expressions and triggers, preserving pure relational form.
4. **Subtype Mutual Exclusivity**:
   - Conditional check constraints enforce that `RETAIL` investors cannot have a `CIN_NO`, and `INSTITUTIONAL` funds cannot have a retail `RISK_PROFILE`.

---

## ⚡ Business Automation Engine (9 Triggers)

StockVault deploys 9 PL/pgSQL triggers to enforce business invariants directly in the database engine:

| # | Trigger Name | Table | Event | Functionality |
|---|---|---|---|---|
| **T1** | `trg_fund_txn_update_balance` | `FUND_TRANSACTION` | BEFORE INSERT | Auto-increments balance on `DEPOSIT`, verifies funds & deducts on `WITHDRAWAL`, stamps `balance_after`. |
| **T2** | `trg_trade_compute_net` | `TRADE` | BEFORE INSERT | Computes statutory charges and derives exact `net_amount` based on `BUY` vs `SELL` direction. |
| **T3** | `trg_validate_order` | `ORDER_RECORD` | BEFORE INSERT | Guards against order placement if cash balance is insufficient (BUY) or shares are inadequate (SELL). |
| **T4** | `trg_trade_update_holdings` | `TRADE` | AFTER INSERT | Reconciles holding positions: computes weighted average cost price on BUY; decrements quantity on SELL. |
| **T5** | `trg_trade_update_order_status` | `TRADE` | AFTER INSERT | Automatically flips order status from `OPEN` to `EXECUTED` upon fill execution. |
| **T6** | `trg_trade_adjust_balance` | `TRADE` | AFTER INSERT | Debits cash balance for BUY trades; credits proceeds for SELL trades atomically. |
| **T7** | `trg_order_check_broker_active` | `ORDER_RECORD` | BEFORE INSERT | Rejects order routing through inactive or suspended broker licenses. |
| **T8** | `trg_order_prevent_cancel_executed`| `ORDER_RECORD` | BEFORE UPDATE | Prevents illegal state transition: executed or filled trades can never be cancelled. |
| **T9** | `trg_investor_audit` | `INVESTOR` | AFTER UPDATE/DEL | Writes changes into `investor_audit_log` recording old vs new values, user, and timestamp. |

---

## 📊 Pre-Built Views (7 Analytical Views)

StockVault provides 7 optimized views abstracting complex multi-table joins:

1. **`v_investor_profile`**: Full 360° view of investors including computed current age, active trading accounts, and primary bank details.
2. **`v_portfolio_summary`**: Mark-to-market portfolio breakdown with invested capital, current valuation, unrealized P&L, and percentage return.
3. **`v_order_with_trade`**: Combined order lifecycle audit linking orders to trade references, filled prices, and execution latency.
4. **`v_broker_performance`**: Broker KPI metrics: total clients, trade count, turnover, cumulative brokerage revenue, and average execution latency.
5. **`v_security_details`**: Consolidated view uniting base `SECURITY` with specialized `EQUITY` (P/E, EPS, Market Cap) and `MUTUAL_FUND` (NAV, Expense Ratio) data.
6. **`v_fund_ledger`**: Complete financial transaction ledger tracking investor cash deposits, withdrawals, and historical running balance stamps.
7. **`v_capital_gains`**: Tax reporting view computing realized gains, holding periods, and short-term (STCG) vs long-term (LTCG) tax brackets.

---

## 🔍 Production Queries Catalogue (30 Queries)

The database includes 30 pre-built, production-tested SQL queries:

<details>
<summary><strong>📈 13 Analytical Queries (Click to Expand)</strong></summary>

- **A1**: Broker Revenue & Turnover Leaderboard (Rank brokers by trading volume and commissions).
- **A2**: Top Traded Securities in Last 30 Days (Liquidity and turnover analysis).
- **A3**: Monthly Broker Revenue Trends (Time-series revenue generation).
- **A4**: Dormant Account Detection (Identifies verified investors with zero orders in 30+ days).
- **A5**: Average Trade Ticket Size per Broker.
- **A6**: Broker Execution Latency vs Commission Rates.
- **A7**: Regulatory KYC Expiration Alert (Flags documents expiring within 30 days).
- **A8**: High-Net-Worth Individual (HNI) Portfolio Asset Allocation.
- **A9**: Broker Order Fill Speed Benchmarks.
- **A10**: Subscription Plan to Trade Conversion Rates.
- **A11**: Order Cancellation Rates Segmented by Order Type (MARKET, LIMIT, SL).
- **A12**: Stale Open Orders (> 7 Days Pending Execution).
- **A13**: Daily Exchange Turnover Breakdown by Market Sector.

</details>

<details>
<summary><strong>💼 17 Application Queries (Click to Expand)</strong></summary>

- **App1**: Filter Active Securities by Exchange (NSE / BSE).
- **App2**: Search Securities by Ticker or Company Name Prefix.
- **App3**: Retrieve Equity Valuation Ratios (P/E, EPS, Market Cap).
- **App4**: Real-Time Portfolio Holdings with Unrealized P&L.
- **App5**: Order Placement Pre-Validation Check.
- **App6**: Safe Order Cancellation with Status Guard.
- **App7**: KYC Document Verification Status Lookup.
- **App8**: Fetch Primary Settlement Bank Account.
- **App9**: Holding Balance Validation for SELL Orders.
- **App10**: Record Trade Execution & Synchronize Holdings.
- **App11**: Upsert Portfolio Holding Position.
- **App12**: Create Audited Fund Transaction.
- **App13**: Adjust Cash Balance After Fund Deposit.
- **App14**: Paginated Order History with Trade Records.
- **App15**: List Investor Linked Bank Accounts.
- **App16**: Query Active Broker Client Subscriptions.
- **App17**: Broker Commission Accrual Summary.

</details>

---

## 🧪 Multi-Tier Automated Test Suite

StockVault includes a complete automated testing harness:

| Test Target | Runner Command | Assertions / Coverage |
|---|---|---|
| **SQL Schema & Constraints** | `npm run test:db` / `./tests/run_tests.sh` | 15 tables, column types, foreign keys, and CHECK constraint rejections. |
| **Trigger Execution** | `tests/test_triggers.sql` | Verifies all 9 triggers fire accurately and reject invalid state transitions. |
| **Row Level Security** | `tests/test_rls.sql` | Tests non-superuser role isolation: tenant A cannot view tenant B's trades. |
| **Financial Invariants** | `tests/test_financial_invariants.sql` | Mathematical consistency: trade fee arithmetic, STCG/LTCG 365-day rule. |
| **Backend REST API** | `npm test` | 9 automated integration tests covering health, schema explorer, and read-only query sandbox. |
| **Continuous Integration** | GitHub Actions (`ci.yml`) | Spins up PostgreSQL 15 on Ubuntu, runs full SQL suite + API tests on push/PR. |

---

## 🛠️ Quickstart & Local Setup

### Prerequisites
- **PostgreSQL 15+** installed and running
- **Node.js 20+** installed
- `psql` command-line utility or modern database client (DBeaver / pgAdmin)

### 1. Clone the Repository
```bash
git clone https://github.com/Elite407/StockVault---Portfolio-Management-system.git
cd StockVault---Portfolio-Management-system
```

### 2. Configure Environment
```bash
cp backend/.env.example backend/.env
# Edit backend/.env if your PostgreSQL username/password differ from default:
# DATABASE_URL=postgresql://postgres:postgres@localhost:5432/stockvault
```

### 3. Build Database Schema & Load Seed Data
```bash
# 1. Create database
psql -U postgres -c "CREATE DATABASE stockvault;"

# 2. Run DDL, indexes, views, triggers, and RLS policies
psql -U postgres -d stockvault -f database/schema/final_ddl.sql
psql -U postgres -d stockvault -f database/schema/indexes.sql
psql -U postgres -d stockvault -f database/schema/views.sql
psql -U postgres -d stockvault -f database/schema/triggers_functions.sql
psql -U postgres -d stockvault -f database/schema/rls_policies.sql

# 3. Load idempotent seed data (or run `npm run db:seed`)
psql -U postgres -d stockvault -f database/schema/seed_data.sql
```

### 4. Run the Test Suites
```bash
# Run backend API integration tests
npm test

# Run database schema & logic test suite (Linux/macOS)
./tests/run_tests.sh

# Or run cross-platform test runner (Windows/macOS/Linux)
npm run test:db
```

### 5. Launch Interactive DBMS Explorer Dashboard
```bash
npm start
# Open http://localhost:3000 in your browser
```

---

## 📁 Project Directory Layout

```
StockVault/
├── .github/
│   └── workflows/
│       └── ci.yml                     ← GitHub Actions Automated Test Pipeline
├── backend/
│   ├── public/
│   │   └── index.html                 ← Interactive DBMS Explorer Web UI
│   ├── test/
│   │   └── api.test.js                ← Backend API Integration Test Suite
│   ├── db.js                          ← PostgreSQL Connection Pool Configuration
│   ├── seed.js                        ← Node.js Seed Runner Utility
│   ├── server.js                      ← Express API Server with SQL Sandbox Guard
│   └── package.json                   ← Backend Dependencies & Scripts
├── database/
│   └── schema/
│       ├── final_ddl.sql              ← 15 Tables DDL (BCNF Normalized)
│       ├── indexes.sql                ← 16 Performance & Partial Indexes
│       ├── views.sql                  ← 7 Reusable Analytical Views
│       ├── triggers_functions.sql     ← 9 Business Triggers & Functions
│       ├── rls_policies.sql           ← Multi-Tenant Row Level Security Policies
│       └── seed_data.sql              ← Idempotent Realistic Sample Financial Data
├── SQL/
│   ├── analytic_queries.sql           ← 13 Analytical SQL Queries (A1 - A13)
│   └── application_queries.sql        ← 17 Application SQL Queries (App1 - App17)
├── tests/
│   ├── runner.js                      ← Cross-Platform Node.js Test Runner
│   ├── run_tests.sh                   ← Bash Automated SQL Test Runner
│   ├── test_schema.sql                ← Schema Structure Verification
│   ├── test_constraints.sql           ← Constraint Enforcement Tests
│   ├── test_triggers.sql              ← 9 Business Logic Trigger Tests
│   ├── test_views.sql                 ← 7 Views Result Verification
│   ├── test_indexes.sql               ← Index Strategy Verification
│   ├── test_seed_data.sql             ← Row Count & Foreign Key Checks
│   ├── test_rls.sql                   ← Row Level Security Isolation Tests
│   ├── test_financial_invariants.sql  ← Tax & Fee Calculation Consistency Tests
│   └── test_queries.sql               ← Execution Tests for All 30 Queries
├── docs/
│   ├── screenshots/                   ← High-Resolution Proof of Work Screenshots
│   ├── architecture/                  ← Technical Design Decisions & Reports
│   ├── specs/                         ← Domain Requirements & Comparisons
│   └── PERFORMANCE.md                 ← Index Strategy & EXPLAIN ANALYZE Plans
├── package.json                       ← Root Package Scripts (`npm start`, `npm test`)
├── .gitignore                         ← Clean Repository Ignore Configuration
└── README.md                          ← You Are Here
```

---

## 👨‍💻 Author & Credits

**Pranamya Sanghvi**  
B.Tech — Information and Communication Technology (ICT)  
**Dhirubhai Ambani Institute of Information and Communication Technology (DA-IICT)**, Gandhinagar  

*License: [MIT](LICENSE)*
