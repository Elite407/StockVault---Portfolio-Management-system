-- ============================================================
-- StockVault — Performance Indexes
-- Purpose : Speed up the analytical and application queries.
--           Run after final_ddl.sql (which already creates PKs,
--           UNIQUEs, and the partial unique index on BANK_ACC).
-- ============================================================

SET search_path TO trading;

-- ─────────────────────────────────────────────────────────────
-- INVESTOR
-- ─────────────────────────────────────────────────────────────
-- A4, A8: filter by kyc_status
CREATE INDEX idx_investor_kyc_status ON investor (kyc_status);

-- A4: join investor → trading_acc frequently
CREATE INDEX idx_investor_type ON investor (investor_type);


-- ─────────────────────────────────────────────────────────────
-- KYC_DOCUMENT
-- ─────────────────────────────────────────────────────────────
-- A7: KYC docs expiring within 30 days (range scan on expiry_date)
CREATE INDEX idx_kyc_document_expiry ON kyc_document (expiry_date)
    WHERE verification_status = 'VERIFIED';

-- App Q7: list KYC docs by investor
CREATE INDEX idx_kyc_document_investor ON kyc_document (investor_id);


-- ─────────────────────────────────────────────────────────────
-- TRADING_ACC
-- ─────────────────────────────────────────────────────────────
-- Frequent FK lookups from order_record, fund_transaction
CREATE INDEX idx_trading_acc_investor ON trading_acc (investor_id);


-- ─────────────────────────────────────────────────────────────
-- BANK_ACC
-- ─────────────────────────────────────────────────────────────
-- App Q8, Q15: filter by investor_id
CREATE INDEX idx_bank_acc_investor ON bank_acc (investor_id);


-- ─────────────────────────────────────────────────────────────
-- BROKER_CLIENT
-- ─────────────────────────────────────────────────────────────
-- App Q16: active broker relationships for an investor
CREATE INDEX idx_broker_client_investor ON broker_client (investor_id)
    WHERE is_active = TRUE;

-- A10: join on plan_type
CREATE INDEX idx_broker_client_plan ON broker_client (plan_type);


-- ─────────────────────────────────────────────────────────────
-- ORDER_RECORD  (heaviest query target)
-- ─────────────────────────────────────────────────────────────
-- A1, A3, A5, A6, A9, A13: join on broker_id + filter by status
CREATE INDEX idx_order_record_broker_status ON order_record (broker_id, status);

-- A2: join on security_id + filter by status
CREATE INDEX idx_order_record_security_status ON order_record (security_id, status);

-- A4, App Q14: filter by ta_id + order by placed_at
CREATE INDEX idx_order_record_ta_placed ON order_record (ta_id, placed_at DESC);

-- A12: stale open orders (partial index — only OPEN status)
CREATE INDEX idx_order_record_open_placed ON order_record (placed_at)
    WHERE status = 'OPEN';

-- A11: group by order_type
CREATE INDEX idx_order_record_type ON order_record (order_type);


-- ─────────────────────────────────────────────────────────────
-- TRADE
-- ─────────────────────────────────────────────────────────────
-- A1, A2: filter by trade_datetime (range scan for last 30 days / 3 months)
CREATE INDEX idx_trade_datetime ON trade (trade_datetime);

-- Most queries join trade → order_record via order_id (FK already indexed by PK,
-- but order_id on trade side needs an index for the reverse join)
CREATE INDEX idx_trade_order ON trade (order_id);


-- ─────────────────────────────────────────────────────────────
-- HOLDING
-- ─────────────────────────────────────────────────────────────
-- App Q4: portfolio lookup by investor
CREATE INDEX idx_holding_investor ON holding (investor_id);


-- ─────────────────────────────────────────────────────────────
-- FUND_TRANSACTION
-- ─────────────────────────────────────────────────────────────
-- Audit queries: filter by ta_id + date range
CREATE INDEX idx_fund_txn_ta_date ON fund_transaction (ta_id, txn_date_time DESC);


-- ─────────────────────────────────────────────────────────────
-- SECURITY
-- ─────────────────────────────────────────────────────────────
-- App Q1: filter by exchange + is_active
CREATE INDEX idx_security_exchange_active ON security (exchange)
    WHERE is_active = TRUE;

-- App Q2: search by ticker or company_name (trigram would be better,
-- but a simple btree on ticker still helps prefix matches)
CREATE INDEX idx_security_ticker ON security (ticker);
