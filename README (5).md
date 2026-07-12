# StockVault

**StockVault** is a PostgreSQL-based database system designed to model
the core data layer of a stock trading and investment platform. The
project focuses on relational database design, normalization, integrity
constraints, ISA hierarchies, and real-world relationships between
investors, brokers, securities, portfolios, orders, and trades.

## Project Overview

StockVault models a simplified stock brokerage ecosystem where:

-   Retail and institutional investors can maintain trading and bank
    accounts.
-   Investors can complete KYC verification.
-   Investors can be associated with multiple brokers.
-   Equity and mutual fund securities are represented using an ISA
    hierarchy.
-   Portfolios maintain investor holdings.
-   Investors can place market, limit, stop-loss, and stop-loss market
    orders.
-   Executed orders generate trade records.
-   Deposits and withdrawals are tracked through fund transactions.
-   Capital gains records store realised profit or loss information.

The database is designed for **PostgreSQL 15** and the production schema
is normalized to **Boyce-Codd Normal Form (BCNF)**.

## Database Design

The production database contains **19 relational tables**.

  -----------------------------------------------------------------------
  Category                            Tables
  ----------------------------------- -----------------------------------
  Investor Management                 `INVESTOR`, `RETAIL_INVESTOR`,
                                      `INSTITUTIONAL_INVESTOR`

  KYC                                 `KYC_DOCUMENT`

  Accounts and Funds                  `TRADING_ACC`, `BANK_BRANCH`,
                                      `BANK_ACC`, `FUND_TRANSACTION`

  Broker Management                   `BROKER`, `PLAN_CATALOG`,
                                      `BROKER_CLIENT`

  Securities                          `SECURITY`, `EQUITY`, `MUTUAL_FUND`

  Portfolio Management                `PORTFOLIO`, `HOLDING`

  Trading                             `ORDER_RECORD`, `TRADE`

  Tax and Gains                       `CAPITAL_GAINS_RECORD`
  -----------------------------------------------------------------------

## Key Database Concepts Implemented

### 1. ISA Hierarchies

StockVault uses supertype-subtype relationships to model specialized
entities.

**Investor hierarchy**

``` text
INVESTOR
├── RETAIL_INVESTOR
└── INSTITUTIONAL_INVESTOR
```

**Security hierarchy**

``` text
SECURITY
├── EQUITY
└── MUTUAL_FUND
```

The subtype tables use the primary key of their supertype as both a
**primary key and foreign key**.

### 2. Many-to-Many Relationships

Many-to-many relationships are resolved using associative entities.

-   `BROKER_CLIENT` resolves the relationship between `INVESTOR` and
    `BROKER`.
-   `HOLDING` resolves the relationship between `PORTFOLIO` and
    `SECURITY`.
-   `FUND_TRANSACTION` connects trading accounts with bank accounts for
    deposits and withdrawals.

### 3. BCNF Normalization

The production schema resolves important functional dependencies.

#### Bank branch decomposition

Instead of storing bank and branch details repeatedly in `BANK_ACC`:

``` text
IFSC_CODE -> BANK_NAME, BRANCH_NAME
```

the dependency is separated into:

``` text
BANK_BRANCH(IFSC_CODE, BANK_NAME, BRANCH_NAME)
BANK_ACC(BANK_ACC_ID, ACC_NO, IFSC_CODE, ...)
```

#### Brokerage plan decomposition

The dependency:

``` text
PLAN_TYPE -> BROKERAGE_PERCENT
```

is moved to the `PLAN_CATALOG` relation.

This reduces redundancy and prevents update anomalies.

## Integrity Constraints

The schema uses extensive database-level constraints to maintain data
consistency.

### Primary and Foreign Keys

All entities have explicitly defined primary keys. Relationships are
enforced through foreign keys with appropriate `ON DELETE` and
`ON UPDATE` actions.

### Unique Constraints

Examples include:

-   Investor email
-   PAN number
-   Aadhaar number
-   Broker email
-   SEBI license number
-   Bank account number
-   Security ticker
-   ISIN
-   Trade reference
-   Transaction reference number

### Check Constraints

Business rules are enforced directly in the database.

Examples:

``` sql
CHECK (KYC_STATUS IN ('PENDING', 'VERIFIED', 'REJECTED'))
CHECK (SIDE IN ('BUY', 'SELL'))
CHECK (ORDER_TYPE IN ('MARKET', 'LIMIT', 'SL', 'SL-M'))
CHECK (PRODUCT_TYPE IN ('CNC', 'MIS', 'NRML'))
CHECK (STATUS IN ('OPEN', 'EXECUTED', 'CANCELLED', 'PARTIAL'))
CHECK (AMT > 0)
CHECK (QUANTITY > 0)
```

Conditional constraints also ensure that limit and stop-loss prices are
present for the corresponding order types.

### Partial Unique Index

Only one bank account can be marked as the primary account for an
investor.

``` sql
CREATE UNIQUE INDEX uq_bank_acc_one_primary_per_investor
ON BANK_ACC (INVESTOR_ID)
WHERE IS_PRIMARY = TRUE;
```

## Core Entity Relationships

``` text
INVESTOR
│
├── RETAIL_INVESTOR / INSTITUTIONAL_INVESTOR
├── KYC_DOCUMENT
├── TRADING_ACC
├── BANK_ACC
├── PORTFOLIO
├── ORDER_RECORD
└── BROKER_CLIENT ───── BROKER

BANK_BRANCH ───── BANK_ACC

TRADING_ACC ───── FUND_TRANSACTION ───── BANK_ACC

PORTFOLIO ───── HOLDING ───── SECURITY
                               │
                               ├── EQUITY
                               └── MUTUAL_FUND

ORDER_RECORD ───── TRADE ───── CAPITAL_GAINS_RECORD

PLAN_CATALOG ───── BROKER_CLIENT
```

## Order Management

The `ORDER_RECORD` table supports multiple trading order types.

  Order Type   Description
  ------------ ---------------------------------------
  `MARKET`     Execute at the available market price
  `LIMIT`      Execute at a specified limit price
  `SL`         Stop-loss limit order
  `SL-M`       Stop-loss market order

Supported transaction sides:

``` text
BUY
SELL
```

Supported product types:

``` text
CNC
MIS
NRML
```

Order states include:

``` text
OPEN
EXECUTED
CANCELLED
PARTIAL
```

## Project Files

``` text
StockVault/
├── stockvault_production_ddl.sql
├── stockvault_normalized_schema.sql
├── stockvault_interview_schema.sql
├── stockvault_seed_data.sql
└── README.md
```

### `stockvault_production_ddl.sql`

Production-ready PostgreSQL DDL containing the BCNF schema, explicitly
named primary keys, foreign keys, unique constraints, and check
constraints.

### `stockvault_normalized_schema.sql`

Normalized version of the StockVault relational schema. It demonstrates
the final decomposition of functional dependencies into relations such
as `BANK_BRANCH` and `PLAN_CATALOG`.

### `stockvault_interview_schema.sql`

A simplified 17-table schema intended for explaining the database design
during interviews. Some dependencies are deliberately retained to make
the design evolution and BCNF decomposition easier to discuss.

### `stockvault_seed_data.sql`

Sample data for all 19 production tables. The seed data can be used to
test relationships, constraints, joins, and SQL queries.

## Getting Started

### Prerequisites

-   PostgreSQL 15 or later
-   `psql` command-line client or a PostgreSQL GUI such as pgAdmin

### 1. Create the database

``` sql
CREATE DATABASE stockvault;
```

### 2. Connect to the database

Using `psql`:

``` bash
psql -U postgres -d stockvault
```

### 3. Create the schema and tables

``` bash
psql -U postgres -d stockvault -f stockvault_production_ddl.sql
```

The production DDL creates and uses the `trading` schema.

### 4. Insert sample data

``` bash
psql -U postgres -d stockvault -f stockvault_seed_data.sql
```

### 5. Verify the tables

``` sql
SET search_path TO trading;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'trading'
ORDER BY table_name;
```

## Example Queries

### View investor portfolios

``` sql
SELECT
    i.full_name,
    p.portfolio_name
FROM investor i
JOIN portfolio p
    ON i.investor_id = p.investor_id;
```

### View portfolio holdings

``` sql
SELECT
    p.portfolio_name,
    s.ticker,
    s.company_name,
    h.quantity,
    h.avg_cost_price,
    h.current_value
FROM holding h
JOIN portfolio p
    ON h.portfolio_id = p.portfolio_id
JOIN security s
    ON h.security_id = s.security_id;
```

### View executed trades

``` sql
SELECT
    o.order_id,
    i.full_name,
    s.ticker,
    o.side,
    t.fill_price,
    t.fill_quantity,
    t.executed_at
FROM order_record o
JOIN investor i
    ON o.investor_id = i.investor_id
JOIN security s
    ON o.security_id = s.security_id
JOIN trade t
    ON o.order_id = t.order_id
WHERE o.status = 'EXECUTED';
```

### View investor-broker relationships

``` sql
SELECT
    i.full_name AS investor,
    b.full_name AS broker,
    bc.plan_type,
    bc.poa_granted
FROM broker_client bc
JOIN investor i
    ON bc.investor_id = i.investor_id
JOIN broker b
    ON bc.broker_id = b.broker_id;
```

## Design Highlights

-   PostgreSQL 15 compatible schema
-   BCNF-normalized relational design
-   19 production tables
-   ISA supertype-subtype modeling
-   Associative entities for many-to-many relationships
-   UUID and identity-based surrogate keys
-   Explicit referential integrity rules
-   Business rules enforced using `CHECK` constraints
-   Partial unique index for primary bank accounts
-   Support for equity and mutual fund securities
-   Portfolio and holding management
-   Order and trade lifecycle modeling
-   Capital gains tracking
-   Realistic sample data for testing

## Future Enhancements

Potential extensions to StockVault include:

-   Database triggers for automatic holding updates after trades
-   Stored procedures for order execution
-   Automatic trading balance updates
-   Audit logging
-   Role-based database access control
-   Market price history tables
-   Dividend and corporate action tracking
-   Tax calculation procedures
-   REST API integration
-   Backend and dashboard integration

## Tech Stack

-   **Database:** PostgreSQL 15
-   **Language:** SQL
-   **Database Design:** Relational Model, BCNF
-   **Concepts:** Normalization, ISA Hierarchy, Associative Entities,
    Referential Integrity, Functional Dependencies

## Author

**Pranamya Sanghvi**

B.Tech --- Information and Communication Technology\
Dhirubhai Ambani University, Gandhinagar
