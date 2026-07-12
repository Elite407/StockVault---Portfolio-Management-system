-- ============================================================
--  StockVault — Interview-Ready Schema (17 entities)
--  Target: PostgreSQL 15.18 (Docker), run via Beekeeper Studio
--  ID strategy: UUID on externally-identifying entities
--               (INVESTOR, BROKER) to prevent ID enumeration;
--               BIGINT IDENTITY elsewhere for join performance.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS trading;
SET search_path TO trading;

-- gen_random_uuid() is native to PostgreSQL 13+, no extension required.

-- -------------------------------------------------------
-- 1. INVESTOR  (ISA supertype)
-- -------------------------------------------------------
CREATE TABLE INVESTOR (
    INVESTOR_ID     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    FULL_NAME       VARCHAR(100) NOT NULL,
    EMAIL           VARCHAR(100) NOT NULL UNIQUE,
    PASSWORD_HASH   VARCHAR(255) NOT NULL,
    PAN_NO          CHAR(10)     NOT NULL UNIQUE,
    AADHAR_NO       CHAR(12)     NOT NULL UNIQUE,
    MOBILE_NO       VARCHAR(15),
    DOB             DATE         NOT NULL CHECK (DOB < CURRENT_DATE),
    KYC_STATUS      VARCHAR(30)  NOT NULL,
    IS_ACTIVE       BOOLEAN      NOT NULL DEFAULT TRUE,
    CREATED_AT      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    INVESTOR_TYPE   VARCHAR(20)  NOT NULL,
    CONSTRAINT chk_kyc_status    CHECK (KYC_STATUS IN ('PENDING','VERIFIED','REJECTED')),
    CONSTRAINT chk_investor_type CHECK (INVESTOR_TYPE IN ('RETAIL','INSTITUTIONAL'))
);
-- AGE intentionally omitted (derived from DOB — compute with AGE(DOB) at query time)

-- -------------------------------------------------------
-- 2. RETAIL_INVESTOR  (ISA subtype)
-- -------------------------------------------------------
CREATE TABLE RETAIL_INVESTOR (
    INVESTOR_ID   UUID PRIMARY KEY REFERENCES INVESTOR(INVESTOR_ID) ON DELETE CASCADE,
    RISK_PROFILE  VARCHAR(30) NOT NULL,
    IS_NRI        BOOLEAN NOT NULL DEFAULT FALSE,
    ANNUAL_INCOME NUMERIC(15,2) CHECK (ANNUAL_INCOME >= 0),
    TAX_ID        VARCHAR(50),
    CONSTRAINT chk_risk_profile CHECK (RISK_PROFILE IN ('CONSERVATIVE','MODERATE','AGGRESSIVE','HNI'))
);

-- -------------------------------------------------------
-- 3. INSTITUTIONAL_INVESTOR  (ISA subtype)
-- -------------------------------------------------------
CREATE TABLE INSTITUTIONAL_INVESTOR (
    INVESTOR_ID       UUID PRIMARY KEY REFERENCES INVESTOR(INVESTOR_ID) ON DELETE CASCADE,
    ORGANIZATION_NAME VARCHAR(150) NOT NULL,
    CIN_NO            VARCHAR(21)  NOT NULL UNIQUE,
    REGISTRATION_NO   VARCHAR(50),
    CATEGORY          VARCHAR(50)
);

-- -------------------------------------------------------
-- 4. KYC_DOCUMENT
-- -------------------------------------------------------
CREATE TABLE KYC_DOCUMENT (
    DOC_ID              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    DOC_NO              VARCHAR(50) NOT NULL UNIQUE,
    DOC_TYPE            VARCHAR(20) NOT NULL,
    DOC_URL             TEXT,
    ISSUE_DATE          DATE,
    EXPIRY_DATE         DATE,
    VERIFICATION_STATUS VARCHAR(20) NOT NULL,
    VERIFIED_BY         VARCHAR(100),
    INVESTOR_ID         UUID NOT NULL REFERENCES INVESTOR(INVESTOR_ID) ON DELETE CASCADE,
    CONSTRAINT chk_doc_type     CHECK (DOC_TYPE IN ('PAN','AADHAR','PASSPORT','DRIVING_LICENSE')),
    CONSTRAINT chk_verif_status CHECK (VERIFICATION_STATUS IN ('PENDING','VERIFIED','REJECTED')),
    CONSTRAINT chk_expiry_after_issue CHECK (EXPIRY_DATE IS NULL OR EXPIRY_DATE > ISSUE_DATE)
);

-- -------------------------------------------------------
-- 5. TRADING_ACC
-- -------------------------------------------------------
CREATE TABLE TRADING_ACC (
    TA_ID         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    INVESTOR_ID   UUID NOT NULL REFERENCES INVESTOR(INVESTOR_ID) ON DELETE RESTRICT,
    IS_ACTIVE     BOOLEAN NOT NULL DEFAULT TRUE,
    AVAIL_BALANCE NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (AVAIL_BALANCE >= 0),
    OPEN_DATE     DATE NOT NULL DEFAULT CURRENT_DATE
);

-- -------------------------------------------------------
-- 6. BANK_ACC
-- -------------------------------------------------------
CREATE TABLE BANK_ACC (
    BANK_ACC_ID BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ACC_NO      VARCHAR(20) NOT NULL UNIQUE,
    BANK_NAME   VARCHAR(100) NOT NULL,
    BRANCH_NAME VARCHAR(100),
    IFSC_CODE   CHAR(11) NOT NULL,
    IS_PRIMARY  BOOLEAN NOT NULL DEFAULT FALSE,
    INVESTOR_ID UUID NOT NULL REFERENCES INVESTOR(INVESTOR_ID) ON DELETE RESTRICT
);
-- NOTE: IFSC_CODE -> BANK_NAME, BRANCH_NAME is a transitive dependency,
-- deliberately left in at this stage; resolved in the BCNF decomposition pass.

CREATE UNIQUE INDEX one_primary_bank_acc_per_investor
    ON BANK_ACC (INVESTOR_ID) WHERE IS_PRIMARY = TRUE;

-- -------------------------------------------------------
-- 7. BROKER  (USER auth fields merged in)
-- -------------------------------------------------------
CREATE TABLE BROKER (
    BROKER_ID       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    FULL_NAME       VARCHAR(150) NOT NULL,
    EMAIL           VARCHAR(100) NOT NULL UNIQUE,
    PASSWORD_HASH   VARCHAR(255) NOT NULL,
    SEBI_LICENSE_NO VARCHAR(50)  NOT NULL UNIQUE,
    COMMISSION_RATE NUMERIC(5,2) CHECK (COMMISSION_RATE BETWEEN 0 AND 100),
    IS_ACTIVE       BOOLEAN NOT NULL DEFAULT TRUE
);

-- -------------------------------------------------------
-- 8. FUND_TRANSACTION  (associative entity: TRADING_ACC <-> BANK_ACC)
-- -------------------------------------------------------
CREATE TABLE FUND_TRANSACTION (
    TXN_ID           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TA_ID            BIGINT NOT NULL REFERENCES TRADING_ACC(TA_ID) ON DELETE RESTRICT,
    BANK_ACC_ID      BIGINT REFERENCES BANK_ACC(BANK_ACC_ID) ON DELETE RESTRICT,
    TXN_TYPE         VARCHAR(20) NOT NULL,
    AMT              NUMERIC(15,2) NOT NULL CHECK (AMT > 0),
    BALANCE_AFTER    NUMERIC(15,2),
    TXN_DATE_TIME    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    REFERENCE_NUMBER VARCHAR(50) UNIQUE,
    CONSTRAINT chk_txn_type CHECK (TXN_TYPE IN ('DEPOSIT','WITHDRAWAL'))
);

-- -------------------------------------------------------
-- 9. BROKER_CLIENT  (associative entity: INVESTOR <-> BROKER, M:N)
--     CLIENT_PLAN attributes merged in per interview-scope redesign
-- -------------------------------------------------------
CREATE TABLE BROKER_CLIENT (
    BC_ID             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    INVESTOR_ID       UUID NOT NULL REFERENCES INVESTOR(INVESTOR_ID) ON DELETE CASCADE,
    BROKER_ID         UUID NOT NULL REFERENCES BROKER(BROKER_ID) ON DELETE CASCADE,
    POA_GRANTED       BOOLEAN NOT NULL DEFAULT FALSE,
    IS_ACTIVE         BOOLEAN NOT NULL DEFAULT TRUE,
    LINK_DATE         DATE NOT NULL DEFAULT CURRENT_DATE,
    PLAN_TYPE         VARCHAR(50),
    BROKERAGE_PERCENT NUMERIC(8,4) CHECK (BROKERAGE_PERCENT >= 0),
    PLAN_START_DATE   DATE,
    PLAN_END_DATE     DATE,
    UNIQUE (INVESTOR_ID, BROKER_ID),
    CONSTRAINT chk_plan_dates CHECK (PLAN_END_DATE IS NULL OR PLAN_END_DATE > PLAN_START_DATE)
);

-- -------------------------------------------------------
-- 10. SECURITY  (ISA supertype)
-- -------------------------------------------------------
CREATE TABLE SECURITY (
    SECURITY_ID   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    TICKER        VARCHAR(20) NOT NULL UNIQUE,
    COMPANY_NAME  VARCHAR(200) NOT NULL,
    EXCHANGE      VARCHAR(20) NOT NULL,
    SECTOR        VARCHAR(80),
    SECURITY_TYPE VARCHAR(20) NOT NULL,
    FACE_VALUE    NUMERIC(10,2) CHECK (FACE_VALUE > 0),
    ISIN          CHAR(12) NOT NULL UNIQUE,
    IS_ACTIVE     BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_exchange      CHECK (EXCHANGE IN ('NSE','BSE')),
    CONSTRAINT chk_security_type CHECK (SECURITY_TYPE IN ('EQUITY','MUTUAL_FUND'))
);

-- -------------------------------------------------------
-- 11. EQUITY  (ISA subtype)
-- -------------------------------------------------------
CREATE TABLE EQUITY (
    SECURITY_ID        BIGINT PRIMARY KEY REFERENCES SECURITY(SECURITY_ID) ON DELETE CASCADE,
    MARKET_CAP         NUMERIC(22,2) CHECK (MARKET_CAP >= 0),
    PE_RATIO           NUMERIC(10,2),
    EPS                NUMERIC(10,2),   -- can legitimately be negative (loss-making company)
    SHARES_OUTSTANDING BIGINT CHECK (SHARES_OUTSTANDING > 0)
);

-- -------------------------------------------------------
-- 12. MUTUAL_FUND  (ISA subtype)
-- -------------------------------------------------------
CREATE TABLE MUTUAL_FUND (
    SECURITY_ID     BIGINT PRIMARY KEY REFERENCES SECURITY(SECURITY_ID) ON DELETE CASCADE,
    AMC_NAME        VARCHAR(150),
    SCHEME_CATEGORY VARCHAR(50),
    NAV             NUMERIC(12,4) CHECK (NAV > 0),
    NAV_DATE        DATE,
    EXPENSE_RATIO   NUMERIC(6,4) CHECK (EXPENSE_RATIO >= 0)
);

-- -------------------------------------------------------
-- 13. PORTFOLIO
-- -------------------------------------------------------
CREATE TABLE PORTFOLIO (
    PORTFOLIO_ID   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PORTFOLIO_NAME VARCHAR(100) NOT NULL,
    CREATED_AT     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    INVESTOR_ID    UUID NOT NULL REFERENCES INVESTOR(INVESTOR_ID) ON DELETE RESTRICT
);

-- -------------------------------------------------------
-- 14. HOLDING  (associative entity: PORTFOLIO <-> SECURITY, M:N)
-- -------------------------------------------------------
CREATE TABLE HOLDING (
    HOLDING_ID     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PORTFOLIO_ID   BIGINT NOT NULL REFERENCES PORTFOLIO(PORTFOLIO_ID) ON DELETE RESTRICT,
    SECURITY_ID    BIGINT NOT NULL REFERENCES SECURITY(SECURITY_ID) ON DELETE RESTRICT,
    QUANTITY       NUMERIC(15,4) NOT NULL CHECK (QUANTITY >= 0),
    AVG_COST_PRICE NUMERIC(15,4) NOT NULL CHECK (AVG_COST_PRICE > 0),
    CURRENT_VALUE  NUMERIC(15,2),
    LAST_UPDATED   TIMESTAMPTZ,
    UNIQUE (PORTFOLIO_ID, SECURITY_ID)
);
-- UNREALISED_PNL intentionally omitted (derived: CURRENT_VALUE - AVG_COST_PRICE * QUANTITY)

-- -------------------------------------------------------
-- 15. ORDER_RECORD
-- -------------------------------------------------------
CREATE TABLE ORDER_RECORD (
    ORDER_ID         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    INVESTOR_ID      UUID NOT NULL REFERENCES INVESTOR(INVESTOR_ID) ON DELETE RESTRICT,
    SECURITY_ID      BIGINT NOT NULL REFERENCES SECURITY(SECURITY_ID) ON DELETE RESTRICT,
    TA_ID            BIGINT NOT NULL REFERENCES TRADING_ACC(TA_ID) ON DELETE RESTRICT,
    PLACED_BY_BROKER UUID REFERENCES BROKER(BROKER_ID) ON DELETE SET NULL,
    SIDE             VARCHAR(10) NOT NULL,
    ORDER_TYPE       VARCHAR(20) NOT NULL,
    PRODUCT_TYPE     VARCHAR(20) NOT NULL,
    QUANTITY         NUMERIC(15,4) NOT NULL CHECK (QUANTITY > 0),
    LIMIT_PRICE      NUMERIC(15,4),
    STOP_LOSS_PRICE  NUMERIC(15,4),
    STATUS           VARCHAR(20) NOT NULL,
    PLACED_AT        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UPDATED_AT       TIMESTAMPTZ,
    CONSTRAINT chk_side         CHECK (SIDE IN ('BUY','SELL')),
    CONSTRAINT chk_order_type   CHECK (ORDER_TYPE IN ('MARKET','LIMIT','SL','SL-M')),
    CONSTRAINT chk_product_type CHECK (PRODUCT_TYPE IN ('CNC','MIS','NRML')),
    CONSTRAINT chk_status       CHECK (STATUS IN ('OPEN','EXECUTED','CANCELLED','PARTIAL')),
    CONSTRAINT chk_limit_price  CHECK (ORDER_TYPE NOT IN ('LIMIT','SL') OR LIMIT_PRICE IS NOT NULL),
    CONSTRAINT chk_sl_price     CHECK (ORDER_TYPE NOT IN ('SL','SL-M') OR STOP_LOSS_PRICE IS NOT NULL)
);

-- -------------------------------------------------------
-- 16. TRADE
-- -------------------------------------------------------
CREATE TABLE TRADE (
    TRADE_ID         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ORDER_ID         BIGINT NOT NULL REFERENCES ORDER_RECORD(ORDER_ID) ON DELETE RESTRICT,
    TRADE_REF        VARCHAR(20) UNIQUE,
    FILL_PRICE       NUMERIC(12,2) NOT NULL CHECK (FILL_PRICE > 0),
    FILLED_QTY       INT NOT NULL CHECK (FILLED_QTY > 0),
    TRADE_DATETIME   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    SETTLEMENT_DATE  DATE,
    BROKERAGE_FEE    NUMERIC(10,2) DEFAULT 0 CHECK (BROKERAGE_FEE >= 0),
    EXCHANGE_CHARGES NUMERIC(10,2) DEFAULT 0 CHECK (EXCHANGE_CHARGES >= 0),
    STT              NUMERIC(10,2) DEFAULT 0 CHECK (STT >= 0),
    NET_AMOUNT       NUMERIC(14,2)
);
-- TOTAL_CHARGES intentionally omitted (derived: BROKERAGE_FEE + EXCHANGE_CHARGES + STT)
-- No direct FK to INVESTOR/SECURITY here by design — reachable via ORDER_ID -> ORDER_RECORD

-- -------------------------------------------------------
-- 17. CAPITAL_GAINS_RECORD
-- -------------------------------------------------------
CREATE TABLE CAPITAL_GAINS_RECORD (
    CG_ID          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    BUY_TRADE_ID   BIGINT NOT NULL REFERENCES TRADE(TRADE_ID) ON DELETE RESTRICT,
    SELL_TRADE_ID  BIGINT NOT NULL REFERENCES TRADE(TRADE_ID) ON DELETE RESTRICT,
    BUY_PRICE      NUMERIC(15,4) NOT NULL CHECK (BUY_PRICE > 0),
    SELL_PRICE     NUMERIC(15,4) NOT NULL CHECK (SELL_PRICE > 0),
    QUANTITY       NUMERIC(15,4) NOT NULL CHECK (QUANTITY > 0),
    GAIN_TYPE      VARCHAR(20) NOT NULL,
    TAX_AMOUNT     NUMERIC(15,2) CHECK (TAX_AMOUNT >= 0),
    HOLDING_DAYS   INT CHECK (HOLDING_DAYS >= 0),
    FINANCIAL_YEAR VARCHAR(10),
    CONSTRAINT chk_gain_type CHECK (GAIN_TYPE IN ('SHORT_TERM','LONG_TERM')),
    CONSTRAINT chk_distinct_trades CHECK (BUY_TRADE_ID <> SELL_TRADE_ID)
);
-- GAIN_LOSS intentionally omitted (derived: (SELL_PRICE - BUY_PRICE) * QUANTITY)

-- ============================================================
-- End of StockVault interview-ready schema (17 entities)
-- ============================================================
