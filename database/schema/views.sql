-- ============================================================
-- StockVault — Views
-- Purpose : Reusable, pre-joined views that simplify common
--           query patterns used by the application and analytics.
-- Run     : After final_ddl.sql and seed_data.sql.
-- ============================================================

SET search_path TO trading;


-- ─────────────────────────────────────────────────────────────
-- 1. v_investor_profile
--    Full investor profile with KYC doc count and trading account info.
--    Used by: profile pages, admin dashboards.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_investor_profile AS
SELECT i.investor_id, i.full_name, i.email, i.pan_no, i.aadhar_no,
       i.dob, i.kyc_status, i.is_active, i.investor_type, i.risk_profile, i.cin_no,
       i.created_at,
       ta.ta_id, ta.avail_balance, ta.open_date AS account_open_date,
       COUNT(DISTINCT k.doc_id) AS kyc_doc_count
FROM investor i
LEFT JOIN trading_acc ta ON ta.investor_id = i.investor_id
LEFT JOIN kyc_document k ON k.investor_id = i.investor_id
GROUP BY i.investor_id, i.full_name, i.email, i.pan_no, i.aadhar_no,
         i.dob, i.kyc_status, i.is_active, i.investor_type, i.risk_profile,
         i.cin_no, i.created_at, ta.ta_id, ta.avail_balance, ta.open_date;


-- ─────────────────────────────────────────────────────────────
-- 2. v_portfolio_summary
--    Portfolio view with unrealized P&L per holding.
--    Used by: App Q4 (portfolio), dashboard widgets.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_portfolio_summary AS
SELECT h.holding_id, h.investor_id,
       i.full_name AS investor_name,
       s.security_id, s.ticker, s.company_name, s.security_type, s.sector,
       h.quantity, h.avg_cost_price,
       h.current_value,
       ROUND((h.current_value - (h.quantity * h.avg_cost_price)), 2) AS unrealized_pnl,
       CASE
           WHEN (h.quantity * h.avg_cost_price) = 0 THEN 0
           ELSE ROUND(100.0 * (h.current_value - (h.quantity * h.avg_cost_price))
                      / (h.quantity * h.avg_cost_price), 2)
       END AS pnl_pct,
       h.last_updated
FROM holding h
JOIN investor i ON h.investor_id = i.investor_id
JOIN security s ON h.security_id = s.security_id;


-- ─────────────────────────────────────────────────────────────
-- 3. v_order_with_trade
--    Order + trade details joined. Shows all orders including
--    those without trades (OPEN, CANCELLED).
--    Used by: App Q14 (order history), admin review.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_order_with_trade AS
SELECT o.order_id, o.placed_at, o.side, o.order_type, o.quantity,
       o.limit_price, o.stop_loss_price, o.status,
       o.ta_id, o.security_id, o.broker_id,
       s.ticker, s.company_name,
       t.trade_id, t.trade_ref, t.fill_price, t.filled_qty,
       t.trade_datetime, t.brokerage_fee, t.exchange_charges, t.stt, t.net_amount
FROM order_record o
JOIN security s ON o.security_id = s.security_id
LEFT JOIN trade t ON t.order_id = o.order_id;


-- ─────────────────────────────────────────────────────────────
-- 4. v_broker_performance
--    Broker dashboard: total trades, revenue, avg execution time.
--    Used by: A1, A3, A5, A6, A9, A13.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_broker_performance AS
SELECT b.broker_id, b.full_name, b.email, b.sebi_license_no,
       b.commission_rate, b.is_active,
       COUNT(DISTINCT o.order_id) AS total_orders,
       COUNT(DISTINCT t.trade_id) AS total_trades,
       COALESCE(SUM(t.brokerage_fee), 0) AS total_brokerage,
       COALESCE(SUM(t.exchange_charges + t.stt), 0) AS total_regulatory_charges,
       COALESCE(SUM(t.brokerage_fee + t.exchange_charges + t.stt), 0) AS total_revenue,
       ROUND(AVG(t.net_amount), 2) AS avg_trade_value,
       ROUND(AVG(EXTRACT(EPOCH FROM (t.trade_datetime - o.placed_at)) / 60), 1) AS avg_exec_minutes,
       ROUND(
           COUNT(DISTINCT t.trade_id)::NUMERIC
           / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
       ) AS execution_rate
FROM broker b
LEFT JOIN order_record o ON o.broker_id = b.broker_id
LEFT JOIN trade t ON t.order_id = o.order_id
GROUP BY b.broker_id, b.full_name, b.email, b.sebi_license_no,
         b.commission_rate, b.is_active;


-- ─────────────────────────────────────────────────────────────
-- 5. v_security_details
--    Unified security view that merges EQUITY and MUTUAL_FUND
--    subtype data into one row.
--    Used by: App Q3 (security detail page).
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_security_details AS
SELECT s.security_id, s.ticker, s.company_name, s.exchange,
       s.security_type, s.isin, s.sector, s.is_active,
       e.market_cap, e.pe_ratio, e.eps,
       mf.amc_name, mf.scheme_category, mf.nav, mf.nav_date, mf.expense_ratio
FROM security s
LEFT JOIN equity e ON e.security_id = s.security_id
LEFT JOIN mutual_fund mf ON mf.security_id = s.security_id;


-- ─────────────────────────────────────────────────────────────
-- 6. v_fund_ledger
--    Fund transaction history with investor and bank account info.
--    Used by: reconciliation and audit.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_fund_ledger AS
SELECT ft.txn_id, ft.txn_type, ft.amt, ft.balance_after, ft.txn_date_time,
       ta.ta_id, ta.investor_id,
       i.full_name AS investor_name,
       ba.acc_no, ba.ifsc_code
FROM fund_transaction ft
JOIN trading_acc ta ON ft.ta_id = ta.ta_id
JOIN investor i ON ta.investor_id = i.investor_id
LEFT JOIN bank_acc ba ON ft.bank_acc_id = ba.bank_acc_id;


-- ─────────────────────────────────────────────────────────────
-- 7. v_capital_gains
--    Capital gains with buy/sell trade details and gain type.
--    Used by: tax reporting.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_capital_gains AS
SELECT cg.cg_id,
       cg.buy_trade_id, cg.sell_trade_id,
       cg.buy_price, cg.sell_price, cg.quantity,
       ROUND((cg.sell_price - cg.buy_price) * cg.quantity, 2) AS gain_amount,
       CASE
           WHEN cg.holding_days > 365 THEN 'LTCG'
           ELSE 'STCG'
       END AS gain_type,
       cg.tax_amount, cg.holding_days,
       s.ticker, s.company_name,
       i.full_name AS investor_name
FROM capital_gains_record cg
JOIN trade bt ON cg.buy_trade_id = bt.trade_id
JOIN order_record bo ON bt.order_id = bo.order_id
JOIN security s ON bo.security_id = s.security_id
JOIN trading_acc ta ON bo.ta_id = ta.ta_id
JOIN investor i ON ta.investor_id = i.investor_id;
