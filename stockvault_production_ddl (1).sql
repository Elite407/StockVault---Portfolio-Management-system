-- ============================================================
--  StockVault — Production DDL (PostgreSQL 15, BCNF, 19 tables)
--  All PK/FK/UNIQUE/CHECK constraints explicitly named.
--  ON UPDATE CASCADE only on natural-key FKs (IFSC_CODE, PLAN_TYPE);
--  ON UPDATE NO ACTION on all surrogate-key FKs (UUID / BIGINT IDENTITY).
-- ============================================================

CREATE SCHEMA IF NOT EXISTS trading;
SET search_path TO trading;

-- gen_random_uuid() is native to PostgreSQL 13+, no extension required.

-- -------------------------------------------------------
-- 1. INVESTOR  (ISA supertype)
-- -------------------------------------------------------
CREATE TABLE INVESTOR (
    INVESTOR_ID     UUID NOT NULL DEFAULT gen_random_uuid(),
    FULL_NAME       VARCHAR(100) NOT NULL,
    EMAIL           VARCHAR(100) NOT NULL,
    PASSWORD_HASH   VARCHAR(255) NOT NULL,
    PAN_NO          CHAR(10)     NOT NULL,
    AADHAR_NO       CHAR(12)     NOT NULL,
    MOBILE_NO       VARCHAR(15),
    DOB             DATE         NOT NULL,
    KYC_STATUS      VARCHAR(30)  NOT NULL,
    IS_ACTIVE       BOOLEAN      NOT NULL DEFAULT TRUE,
    CREATED_AT      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    INVESTOR_TYPE   VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_investor PRIMARY KEY (INVESTOR_ID),
    CONSTRAINT uq_investor_email UNIQUE (EMAIL),
    CONSTRAINT uq_investor_pan_no UNIQUE (PAN_NO),
    CONSTRAINT uq_investor_aadhar_no UNIQUE (AADHAR_NO),
    CONSTRAINT chk_investor_dob CHECK (DOB < CURRENT_DATE),
    CONSTRAINT chk_investor_kyc_status CHECK (KYC_STATUS IN ('PENDING','VERIFIED','REJECTED')),
    CONSTRAINT chk_investor_type CHECK (INVESTOR_TYPE IN ('RETAIL','INSTITUTIONAL'))
);
-- AGE omitted (derived from DOB)

-- -------------------------------------------------------
-- 2. RETAIL_INVESTOR  (ISA subtype)
-- -------------------------------------------------------
CREATE TABLE RETAIL_INVESTOR (
    INVESTOR_ID   UUID NOT NULL,
    RISK_PROFILE  VARCHAR(30) NOT NULL,
    IS_NRI        BOOLEAN NOT NULL DEFAULT FALSE,
    ANNUAL_INCOME NUMERIC(15,2),
    TAX_ID        VARCHAR(50),
    CONSTRAINT pk_retail_investor PRIMARY KEY (INVESTOR_ID),
    CONSTRAINT fk_retail_investor_investor FOREIGN KEY (INVESTOR_ID)
        REFERENCES INVESTOR (INVESTOR_ID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT chk_retail_investor_risk_profile
        CHECK (RISK_PROFILE IN ('CONSERVATIVE','MODERATE','AGGRESSIVE','HNI')),
    CONSTRAINT chk_retail_investor_annual_income CHECK (ANNUAL_INCOME >= 0)
);

-- -------------------------------------------------------
-- 3. INSTITUTIONAL_INVESTOR  (ISA subtype)
-- -------------------------------------------------------
CREATE TABLE INSTITUTIONAL_INVESTOR (
    INVESTOR_ID       UUID NOT NULL,
    ORGANIZATION_NAME VARCHAR(150) NOT NULL,
    CIN_NO            VARCHAR(21)  NOT NULL,
    REGISTRATION_NO   VARCHAR(50),
    CATEGORY          VARCHAR(50),
    CONSTRAINT pk_institutional_investor PRIMARY KEY (INVESTOR_ID),
    CONSTRAINT fk_institutional_investor_investor FOREIGN KEY (INVESTOR_ID)
        REFERENCES INVESTOR (INVESTOR_ID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT uq_institutional_investor_cin_no UNIQUE (CIN_NO)
);

-- -------------------------------------------------------
-- 4. KYC_DOCUMENT
-- -------------------------------------------------------
CREATE TABLE KYC_DOCUMENT (
    DOC_ID              BIGINT GENERATED ALWAYS AS IDENTITY,
    DOC_NO              VARCHAR(50) NOT NULL,
    DOC_TYPE            VARCHAR(20) NOT NULL,
    DOC_URL             TEXT,
    ISSUE_DATE          DATE,
    EXPIRY_DATE         DATE,
    VERIFICATION_STATUS VARCHAR(20) NOT NULL,
    VERIFIED_BY         VARCHAR(100),
    INVESTOR_ID         UUID NOT NULL,
    CONSTRAINT pk_kyc_document PRIMARY KEY (DOC_ID),
    CONSTRAINT fk_kyc_document_investor FOREIGN KEY (INVESTOR_ID)
        REFERENCES INVESTOR (INVESTOR_ID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT uq_kyc_document_doc_no UNIQUE (DOC_NO),
    CONSTRAINT chk_kyc_document_doc_type
        CHECK (DOC_TYPE IN ('PAN','AADHAR','PASSPORT','DRIVING_LICENSE')),
    CONSTRAINT chk_kyc_document_verification_status
        CHECK (VERIFICATION_STATUS IN ('PENDING','VERIFIED','REJECTED')),
    CONSTRAINT chk_kyc_document_expiry_after_issue
        CHECK (EXPIRY_DATE IS NULL OR EXPIRY_DATE > ISSUE_DATE)
);

-- -------------------------------------------------------
-- 5. TRADING_ACC
-- -------------------------------------------------------
CREATE TABLE TRADING_ACC (
    TA_ID         BIGINT GENERATED ALWAYS AS IDENTITY,
    INVESTOR_ID   UUID NOT NULL,
    IS_ACTIVE     BOOLEAN NOT NULL DEFAULT TRUE,
    AVAIL_BALANCE NUMERIC(15,2) NOT NULL DEFAULT 0,
    OPEN_DATE     DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_trading_acc PRIMARY KEY (TA_ID),
    CONSTRAINT fk_trading_acc_investor FOREIGN KEY (INVESTOR_ID)
        REFERENCES INVESTOR (INVESTOR_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT chk_trading_acc_avail_balance CHECK (AVAIL_BALANCE >= 0)
);

-- -------------------------------------------------------
-- 6. BANK_BRANCH   (resolves BCNF violation in BANK_ACC)
-- -------------------------------------------------------
CREATE TABLE BANK_BRANCH (
    IFSC_CODE   CHAR(11) NOT NULL,
    BANK_NAME   VARCHAR(100) NOT NULL,
    BRANCH_NAME VARCHAR(100),
    CONSTRAINT pk_bank_branch PRIMARY KEY (IFSC_CODE)
);

-- -------------------------------------------------------
-- 7. BANK_ACC
-- -------------------------------------------------------
CREATE TABLE BANK_ACC (
    BANK_ACC_ID BIGINT GENERATED ALWAYS AS IDENTITY,
    ACC_NO      VARCHAR(20) NOT NULL,
    IFSC_CODE   CHAR(11) NOT NULL,
    IS_PRIMARY  BOOLEAN NOT NULL DEFAULT FALSE,
    INVESTOR_ID UUID NOT NULL,
    CONSTRAINT pk_bank_acc PRIMARY KEY (BANK_ACC_ID),
    CONSTRAINT fk_bank_acc_bank_branch FOREIGN KEY (IFSC_CODE)
        REFERENCES BANK_BRANCH (IFSC_CODE) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_bank_acc_investor FOREIGN KEY (INVESTOR_ID)
        REFERENCES INVESTOR (INVESTOR_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT uq_bank_acc_acc_no UNIQUE (ACC_NO)
);

CREATE UNIQUE INDEX uq_bank_acc_one_primary_per_investor
    ON BANK_ACC (INVESTOR_ID) WHERE IS_PRIMARY = TRUE;

-- -------------------------------------------------------
-- 8. BROKER  (USER auth fields merged in)
-- -------------------------------------------------------
CREATE TABLE BROKER (
    BROKER_ID       UUID NOT NULL DEFAULT gen_random_uuid(),
    FULL_NAME       VARCHAR(150) NOT NULL,
    EMAIL           VARCHAR(100) NOT NULL,
    PASSWORD_HASH   VARCHAR(255) NOT NULL,
    SEBI_LICENSE_NO VARCHAR(50)  NOT NULL,
    COMMISSION_RATE NUMERIC(5,2),
    IS_ACTIVE       BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_broker PRIMARY KEY (BROKER_ID),
    CONSTRAINT uq_broker_email UNIQUE (EMAIL),
    CONSTRAINT uq_broker_sebi_license_no UNIQUE (SEBI_LICENSE_NO),
    CONSTRAINT chk_broker_commission_rate CHECK (COMMISSION_RATE BETWEEN 0 AND 100)
);

-- -------------------------------------------------------
-- 9. FUND_TRANSACTION  (associative: TRADING_ACC <-> BANK_ACC)
-- -------------------------------------------------------
CREATE TABLE FUND_TRANSACTION (
    TXN_ID           BIGINT GENERATED ALWAYS AS IDENTITY,
    TA_ID            BIGINT NOT NULL,
    BANK_ACC_ID      BIGINT,
    TXN_TYPE         VARCHAR(20) NOT NULL,
    AMT              NUMERIC(15,2) NOT NULL,
    BALANCE_AFTER    NUMERIC(15,2),
    TXN_DATE_TIME    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    REFERENCE_NUMBER VARCHAR(50),
    CONSTRAINT pk_fund_transaction PRIMARY KEY (TXN_ID),
    CONSTRAINT fk_fund_transaction_trading_acc FOREIGN KEY (TA_ID)
        REFERENCES TRADING_ACC (TA_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT fk_fund_transaction_bank_acc FOREIGN KEY (BANK_ACC_ID)
        REFERENCES BANK_ACC (BANK_ACC_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT uq_fund_transaction_reference_number UNIQUE (REFERENCE_NUMBER),
    CONSTRAINT chk_fund_transaction_amt CHECK (AMT > 0),
    CONSTRAINT chk_fund_transaction_txn_type CHECK (TXN_TYPE IN ('DEPOSIT','WITHDRAWAL'))
);

-- -------------------------------------------------------
-- 10. PLAN_CATALOG   (resolves BCNF violation in BROKER_CLIENT)
-- -------------------------------------------------------
CREATE TABLE PLAN_CATALOG (
    PLAN_TYPE         VARCHAR(50) NOT NULL,
    BROKERAGE_PERCENT NUMERIC(8,4) NOT NULL,
    CONSTRAINT pk_plan_catalog PRIMARY KEY (PLAN_TYPE),
    CONSTRAINT chk_plan_catalog_brokerage_percent CHECK (BROKERAGE_PERCENT >= 0)
);

-- -------------------------------------------------------
-- 11. BROKER_CLIENT  (associative: INVESTOR <-> BROKER, M:N)
-- -------------------------------------------------------
CREATE TABLE BROKER_CLIENT (
    BC_ID             BIGINT GENERATED ALWAYS AS IDENTITY,
    INVESTOR_ID       UUID NOT NULL,
    BROKER_ID         UUID NOT NULL,
    POA_GRANTED       BOOLEAN NOT NULL DEFAULT FALSE,
    IS_ACTIVE         BOOLEAN NOT NULL DEFAULT TRUE,
    LINK_DATE         DATE NOT NULL DEFAULT CURRENT_DATE,
    PLAN_TYPE         VARCHAR(50),
    PLAN_START_DATE   DATE,
    PLAN_END_DATE     DATE,
    CONSTRAINT pk_broker_client PRIMARY KEY (BC_ID),
    CONSTRAINT fk_broker_client_investor FOREIGN KEY (INVESTOR_ID)
        REFERENCES INVESTOR (INVESTOR_ID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_broker_client_broker FOREIGN KEY (BROKER_ID)
        REFERENCES BROKER (BROKER_ID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_broker_client_plan_catalog FOREIGN KEY (PLAN_TYPE)
        REFERENCES PLAN_CATALOG (PLAN_TYPE) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT uq_broker_client_investor_broker UNIQUE (INVESTOR_ID, BROKER_ID),
    CONSTRAINT chk_broker_client_plan_dates
        CHECK (PLAN_END_DATE IS NULL OR PLAN_END_DATE > PLAN_START_DATE)
);

-- -------------------------------------------------------
-- 12. SECURITY  (ISA supertype)
-- -------------------------------------------------------
CREATE TABLE SECURITY (
    SECURITY_ID   BIGINT GENERATED ALWAYS AS IDENTITY,
    TICKER        VARCHAR(20) NOT NULL,
    COMPANY_NAME  VARCHAR(200) NOT NULL,
    EXCHANGE      VARCHAR(20) NOT NULL,
    SECTOR        VARCHAR(80),
    SECURITY_TYPE VARCHAR(20) NOT NULL,
    FACE_VALUE    NUMERIC(10,2),
    ISIN          CHAR(12) NOT NULL,
    IS_ACTIVE     BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_security PRIMARY KEY (SECURITY_ID),
    CONSTRAINT uq_security_ticker UNIQUE (TICKER),
    CONSTRAINT uq_security_isin UNIQUE (ISIN),
    CONSTRAINT chk_security_exchange CHECK (EXCHANGE IN ('NSE','BSE')),
    CONSTRAINT chk_security_type CHECK (SECURITY_TYPE IN ('EQUITY','MUTUAL_FUND')),
    CONSTRAINT chk_security_face_value CHECK (FACE_VALUE > 0)
);

-- -------------------------------------------------------
-- 13. EQUITY  (ISA subtype)
-- -------------------------------------------------------
CREATE TABLE EQUITY (
    SECURITY_ID        BIGINT NOT NULL,
    MARKET_CAP         NUMERIC(22,2),
    PE_RATIO           NUMERIC(10,2),
    EPS                NUMERIC(10,2),
    SHARES_OUTSTANDING BIGINT,
    CONSTRAINT pk_equity PRIMARY KEY (SECURITY_ID),
    CONSTRAINT fk_equity_security FOREIGN KEY (SECURITY_ID)
        REFERENCES SECURITY (SECURITY_ID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT chk_equity_market_cap CHECK (MARKET_CAP >= 0),
    CONSTRAINT chk_equity_shares_outstanding CHECK (SHARES_OUTSTANDING > 0)
    -- EPS has no lower-bound check: loss-making companies legitimately report negative EPS
);

-- -------------------------------------------------------
-- 14. MUTUAL_FUND  (ISA subtype)
-- -------------------------------------------------------
CREATE TABLE MUTUAL_FUND (
    SECURITY_ID     BIGINT NOT NULL,
    AMC_NAME        VARCHAR(150),
    SCHEME_CATEGORY VARCHAR(50),
    NAV             NUMERIC(12,4),
    NAV_DATE        DATE,
    EXPENSE_RATIO   NUMERIC(6,4),
    CONSTRAINT pk_mutual_fund PRIMARY KEY (SECURITY_ID),
    CONSTRAINT fk_mutual_fund_security FOREIGN KEY (SECURITY_ID)
        REFERENCES SECURITY (SECURITY_ID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT chk_mutual_fund_nav CHECK (NAV > 0),
    CONSTRAINT chk_mutual_fund_expense_ratio CHECK (EXPENSE_RATIO >= 0)
);

-- -------------------------------------------------------
-- 15. PORTFOLIO
-- -------------------------------------------------------
CREATE TABLE PORTFOLIO (
    PORTFOLIO_ID   BIGINT GENERATED ALWAYS AS IDENTITY,
    PORTFOLIO_NAME VARCHAR(100) NOT NULL,
    CREATED_AT     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    INVESTOR_ID    UUID NOT NULL,
    CONSTRAINT pk_portfolio PRIMARY KEY (PORTFOLIO_ID),
    CONSTRAINT fk_portfolio_investor FOREIGN KEY (INVESTOR_ID)
        REFERENCES INVESTOR (INVESTOR_ID) ON DELETE RESTRICT ON UPDATE NO ACTION
);

-- -------------------------------------------------------
-- 16. HOLDING  (associative: PORTFOLIO <-> SECURITY, M:N)
-- -------------------------------------------------------
CREATE TABLE HOLDING (
    HOLDING_ID     BIGINT GENERATED ALWAYS AS IDENTITY,
    PORTFOLIO_ID   BIGINT NOT NULL,
    SECURITY_ID    BIGINT NOT NULL,
    QUANTITY       NUMERIC(15,4) NOT NULL,
    AVG_COST_PRICE NUMERIC(15,4) NOT NULL,
    CURRENT_VALUE  NUMERIC(15,2),
    LAST_UPDATED   TIMESTAMPTZ,
    CONSTRAINT pk_holding PRIMARY KEY (HOLDING_ID),
    CONSTRAINT fk_holding_portfolio FOREIGN KEY (PORTFOLIO_ID)
        REFERENCES PORTFOLIO (PORTFOLIO_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT fk_holding_security FOREIGN KEY (SECURITY_ID)
        REFERENCES SECURITY (SECURITY_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT uq_holding_portfolio_security UNIQUE (PORTFOLIO_ID, SECURITY_ID),
    CONSTRAINT chk_holding_quantity CHECK (QUANTITY >= 0),
    CONSTRAINT chk_holding_avg_cost_price CHECK (AVG_COST_PRICE > 0)
);
-- UNREALISED_PNL omitted (derived: CURRENT_VALUE - AVG_COST_PRICE * QUANTITY)

-- -------------------------------------------------------
-- 17. ORDER_RECORD
-- -------------------------------------------------------
CREATE TABLE ORDER_RECORD (
    ORDER_ID         BIGINT GENERATED ALWAYS AS IDENTITY,
    SECURITY_ID      BIGINT NOT NULL,
    TA_ID            BIGINT NOT NULL,
    PLACED_BY_BROKER UUID,
    SIDE             VARCHAR(10) NOT NULL,
    ORDER_TYPE       VARCHAR(20) NOT NULL,
    PRODUCT_TYPE     VARCHAR(20) NOT NULL,
    QUANTITY         NUMERIC(15,4) NOT NULL,
    LIMIT_PRICE      NUMERIC(15,4),
    STOP_LOSS_PRICE  NUMERIC(15,4),
    STATUS           VARCHAR(20) NOT NULL,
    PLACED_AT        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UPDATED_AT       TIMESTAMPTZ,
    CONSTRAINT pk_order_record PRIMARY KEY (ORDER_ID),
    CONSTRAINT fk_order_record_security FOREIGN KEY (SECURITY_ID)
        REFERENCES SECURITY (SECURITY_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT fk_order_record_trading_acc FOREIGN KEY (TA_ID)
        REFERENCES TRADING_ACC (TA_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT fk_order_record_broker FOREIGN KEY (PLACED_BY_BROKER)
        REFERENCES BROKER (BROKER_ID) ON DELETE SET NULL ON UPDATE NO ACTION,
    CONSTRAINT chk_order_record_quantity CHECK (QUANTITY > 0),
    CONSTRAINT chk_order_record_side CHECK (SIDE IN ('BUY','SELL')),
    CONSTRAINT chk_order_record_order_type CHECK (ORDER_TYPE IN ('MARKET','LIMIT','SL','SL-M')),
    CONSTRAINT chk_order_record_product_type CHECK (PRODUCT_TYPE IN ('CNC','MIS','NRML')),
    CONSTRAINT chk_order_record_status CHECK (STATUS IN ('OPEN','EXECUTED','CANCELLED','PARTIAL')),
    CONSTRAINT chk_order_record_limit_price
        CHECK (ORDER_TYPE NOT IN ('LIMIT','SL') OR LIMIT_PRICE IS NOT NULL),
    CONSTRAINT chk_order_record_sl_price
        CHECK (ORDER_TYPE NOT IN ('SL','SL-M') OR STOP_LOSS_PRICE IS NOT NULL)
);
-- INVESTOR_ID omitted (transitive: ORDER_RECORD.TA_ID -> TRADING_ACC.INVESTOR_ID)

-- -------------------------------------------------------
-- 18. TRADE
-- -------------------------------------------------------
CREATE TABLE TRADE (
    TRADE_ID         BIGINT GENERATED ALWAYS AS IDENTITY,
    ORDER_ID         BIGINT NOT NULL,
    TRADE_REF        VARCHAR(20),
    FILL_PRICE       NUMERIC(12,2) NOT NULL,
    FILLED_QTY       INT NOT NULL,
    TRADE_DATETIME   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    SETTLEMENT_DATE  DATE,
    BROKERAGE_FEE    NUMERIC(10,2) DEFAULT 0,
    EXCHANGE_CHARGES NUMERIC(10,2) DEFAULT 0,
    STT              NUMERIC(10,2) DEFAULT 0,
    NET_AMOUNT       NUMERIC(14,2),
    CONSTRAINT pk_trade PRIMARY KEY (TRADE_ID),
    CONSTRAINT fk_trade_order_record FOREIGN KEY (ORDER_ID)
        REFERENCES ORDER_RECORD (ORDER_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT uq_trade_trade_ref UNIQUE (TRADE_REF),
    CONSTRAINT chk_trade_fill_price CHECK (FILL_PRICE > 0),
    CONSTRAINT chk_trade_filled_qty CHECK (FILLED_QTY > 0),
    CONSTRAINT chk_trade_brokerage_fee CHECK (BROKERAGE_FEE >= 0),
    CONSTRAINT chk_trade_exchange_charges CHECK (EXCHANGE_CHARGES >= 0),
    CONSTRAINT chk_trade_stt CHECK (STT >= 0)
);
-- TOTAL_CHARGES omitted (derived: BROKERAGE_FEE + EXCHANGE_CHARGES + STT)
-- No direct FK to INVESTOR/SECURITY by design — reachable via ORDER_ID -> ORDER_RECORD

-- -------------------------------------------------------
-- 19. CAPITAL_GAINS_RECORD
-- -------------------------------------------------------
CREATE TABLE CAPITAL_GAINS_RECORD (
    CG_ID          BIGINT GENERATED ALWAYS AS IDENTITY,
    BUY_TRADE_ID   BIGINT NOT NULL,
    SELL_TRADE_ID  BIGINT NOT NULL,
    BUY_PRICE      NUMERIC(15,4) NOT NULL,
    SELL_PRICE     NUMERIC(15,4) NOT NULL,
    QUANTITY       NUMERIC(15,4) NOT NULL,
    TAX_AMOUNT     NUMERIC(15,2),
    HOLDING_DAYS   INT,
    FINANCIAL_YEAR VARCHAR(10),
    CONSTRAINT pk_capital_gains_record PRIMARY KEY (CG_ID),
    CONSTRAINT fk_capital_gains_record_buy_trade FOREIGN KEY (BUY_TRADE_ID)
        REFERENCES TRADE (TRADE_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT fk_capital_gains_record_sell_trade FOREIGN KEY (SELL_TRADE_ID)
        REFERENCES TRADE (TRADE_ID) ON DELETE RESTRICT ON UPDATE NO ACTION,
    CONSTRAINT chk_capital_gains_record_buy_price CHECK (BUY_PRICE > 0),
    CONSTRAINT chk_capital_gains_record_sell_price CHECK (SELL_PRICE > 0),
    CONSTRAINT chk_capital_gains_record_quantity CHECK (QUANTITY > 0),
    CONSTRAINT chk_capital_gains_record_tax_amount CHECK (TAX_AMOUNT >= 0),
    CONSTRAINT chk_capital_gains_record_holding_days CHECK (HOLDING_DAYS >= 0),
    CONSTRAINT chk_capital_gains_record_distinct_trades CHECK (BUY_TRADE_ID <> SELL_TRADE_ID)
);
-- GAIN_LOSS omitted (derived: (SELL_PRICE - BUY_PRICE) * QUANTITY)
-- GAIN_TYPE omitted (derived: CASE WHEN HOLDING_DAYS < 365 THEN 'SHORT_TERM' ELSE 'LONG_TERM' END)

-- ============================================================
-- End of StockVault production DDL (BCNF, 19 tables)
-- ============================================================
