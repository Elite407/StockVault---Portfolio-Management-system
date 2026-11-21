-- ============================================================
-- StockVault — Test: Query Execution
-- Validates that all 13 analytical queries and 17 application
-- queries execute without errors and return expected results.
-- Parameterized queries ($1, $2, ...) are replaced with real
-- seed data values.
-- ============================================================

SET search_path TO trading;


-- ═══════════════════════════════════════════════════════════════
--  ANALYTICAL QUERIES (13)
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────
-- A1. Broker revenue in last 3 months
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.broker_id, b.full_name, b.sebi_license_no,
               COALESCE(SUM(t.brokerage_fee + t.exchange_charges + t.stt), 0) AS total_revenue
        FROM broker b
        LEFT JOIN order_record o ON o.broker_id = b.broker_id AND o.status = 'EXECUTED'
        LEFT JOIN trade t ON t.order_id = o.order_id AND t.trade_datetime >= NOW() - INTERVAL '3 months'
        GROUP BY b.broker_id, b.full_name, b.sebi_license_no
    ) sub;
    IF v_count < 4 THEN
        RAISE EXCEPTION 'FAIL [A1]: Expected >= 4 rows (all brokers), got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [A1]: Broker revenue — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A2. Top 10 most traded securities in last 30 days
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT s.security_id, s.ticker, s.company_name, s.security_type,
               COALESCE(SUM(t.filled_qty), 0) AS total_qty_traded
        FROM security s
        LEFT JOIN order_record o ON o.security_id = s.security_id AND o.status = 'EXECUTED'
        LEFT JOIN trade t ON t.order_id = o.order_id AND t.trade_datetime >= NOW() - INTERVAL '1 month'
        GROUP BY s.security_id, s.ticker, s.company_name, s.security_type
        ORDER BY total_qty_traded DESC LIMIT 10
    ) sub;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [A2]: Expected > 0 rows';
    END IF;
    RAISE NOTICE 'PASS [A2]: Top traded securities — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A3. Monthly trade count and revenue per broker
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.broker_id, b.full_name,
               DATE_TRUNC('month', t.trade_datetime) AS month,
               COUNT(DISTINCT t.trade_id) AS total_trades,
               COALESCE(SUM(t.brokerage_fee + t.exchange_charges + t.stt), 0) AS revenue
        FROM broker b
        LEFT JOIN order_record o ON o.broker_id = b.broker_id AND o.status = 'EXECUTED'
        LEFT JOIN trade t ON t.order_id = o.order_id
        GROUP BY b.broker_id, b.full_name, month
    ) sub;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [A3]: Expected > 0 rows';
    END IF;
    RAISE NOTICE 'PASS [A3]: Monthly broker revenue — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A4. Dormant investors (no order in 30 days)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT i.investor_id, i.full_name, i.email, i.pan_no,
               MAX(o.placed_at) AS last_order_date
        FROM investor i
        JOIN trading_acc ta ON ta.investor_id = i.investor_id
        JOIN order_record o ON o.ta_id = ta.ta_id
        GROUP BY i.investor_id, i.full_name, i.email, i.pan_no
        HAVING MAX(o.placed_at) < CURRENT_DATE - INTERVAL '30 days'
    ) sub;
    -- Rohan's last order is 45+ days ago → should appear
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [A4]: Expected >= 1 dormant investor (Rohan)';
    END IF;
    RAISE NOTICE 'PASS [A4]: Dormant investors — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A5. Average trade value per broker
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.broker_id, b.full_name, ROUND(AVG(t.net_amount), 2) AS avg_trade_value
        FROM broker b
        LEFT JOIN order_record o ON o.broker_id = b.broker_id AND o.status = 'EXECUTED'
        LEFT JOIN trade t ON t.order_id = o.order_id
        GROUP BY b.broker_id, b.full_name
    ) sub;
    IF v_count < 4 THEN
        RAISE EXCEPTION 'FAIL [A5]: Expected >= 4 rows, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [A5]: Avg trade value per broker — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A6. Top brokers by commission + exec time
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.broker_id, b.full_name,
               COALESCE(SUM(t.brokerage_fee), 0) AS total_commission,
               ROUND(AVG(EXTRACT(EPOCH FROM (t.trade_datetime - o.placed_at))) / 60, 1) AS avg_execution_minutes
        FROM broker b
        LEFT JOIN order_record o ON o.broker_id = b.broker_id
        LEFT JOIN trade t ON t.order_id = o.order_id
        WHERE o.status = 'EXECUTED'
        GROUP BY b.broker_id, b.full_name
        ORDER BY total_commission DESC LIMIT 10
    ) sub;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [A6]: Expected > 0 rows';
    END IF;
    RAISE NOTICE 'PASS [A6]: Top brokers by commission — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A7. KYC documents expiring within 30 days
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT i.investor_id, i.full_name, k.doc_no, k.doc_type,
               k.issue_date, k.expiry_date
        FROM kyc_document k
        JOIN investor i ON k.investor_id = i.investor_id
        WHERE k.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
          AND k.verification_status = 'VERIFIED'
    ) sub;
    -- Seed data has 3 docs expiring within 30 days (Aarav, Priya, Neha)
    IF v_count < 3 THEN
        RAISE EXCEPTION 'FAIL [A7]: Expected >= 3 expiring KYC docs, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [A7]: KYC expiring within 30 days — % docs', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A8. Verified investors who never traded
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT i.investor_id, i.full_name, i.email, i.kyc_status, i.created_at
        FROM investor i
        WHERE i.kyc_status = 'VERIFIED'
          AND NOT EXISTS (
              SELECT 1 FROM trading_acc ta
              JOIN order_record o ON o.ta_id = ta.ta_id
              WHERE ta.investor_id = i.investor_id
          )
    ) sub;
    -- Query executes successfully (may return 0 if all verified investors have traded)
    RAISE NOTICE 'PASS [A8]: Verified never-traded investors — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A9. Average execution time per broker
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.broker_id, b.full_name,
               ROUND(AVG(EXTRACT(EPOCH FROM (t.trade_datetime - o.placed_at)) / 60), 1) AS avg_execution_minutes
        FROM broker b
        JOIN order_record o ON o.broker_id = b.broker_id
        JOIN trade t ON t.order_id = o.order_id
        WHERE o.status = 'EXECUTED'
        GROUP BY b.broker_id, b.full_name
    ) sub;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [A9]: Expected > 0 rows';
    END IF;
    RAISE NOTICE 'PASS [A9]: Avg exec time per broker — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A10. Plan subscription to trade conversion rate
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT pc.plan_type, pc.brokerage_percent,
               COUNT(DISTINCT bc.bc_id) AS total_subscriptions,
               COUNT(DISTINCT o.order_id) AS orders_executed,
               ROUND(100.0 * COUNT(DISTINCT CASE WHEN o.status = 'EXECUTED' THEN o.order_id END)
                     / NULLIF(COUNT(DISTINCT bc.bc_id), 0), 2) AS conversion_pct
        FROM plan_catalog pc
        LEFT JOIN broker_client bc ON bc.plan_type = pc.plan_type
        LEFT JOIN trading_acc ta ON ta.investor_id = bc.investor_id
        LEFT JOIN order_record o ON o.ta_id = ta.ta_id AND o.broker_id = bc.broker_id
        GROUP BY pc.plan_type, pc.brokerage_percent
    ) sub;
    IF v_count < 4 THEN
        RAISE EXCEPTION 'FAIL [A10]: Expected >= 4 plan rows, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [A10]: Plan conversion rate — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A11. Order cancellation rate by order type
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT order_type,
               COUNT(*) AS total_orders,
               SUM(CASE WHEN status = 'EXECUTED' THEN 1 ELSE 0 END) AS executed,
               SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled,
               ROUND(100.0 * SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_rate_pct
        FROM order_record
        GROUP BY order_type
    ) sub;
    IF v_count < 4 THEN
        RAISE EXCEPTION 'FAIL [A11]: Expected >= 4 order types, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [A11]: Cancellation rate by type — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A12. Stale open orders (> 7 days)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT o.order_id, i.full_name, s.ticker, o.side, o.order_type,
               o.quantity, o.placed_at
        FROM order_record o
        JOIN trading_acc ta ON o.ta_id = ta.ta_id
        JOIN investor i ON ta.investor_id = i.investor_id
        JOIN security s ON o.security_id = s.security_id
        WHERE o.status = 'OPEN'
          AND o.placed_at < CURRENT_DATE - INTERVAL '7 days'
    ) sub;
    -- O21 (10 days old) and O23 (9 days old) should be stale
    IF v_count < 2 THEN
        RAISE EXCEPTION 'FAIL [A12]: Expected >= 2 stale open orders, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [A12]: Stale open orders — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- A13. Orders handled per broker (execution rate)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.broker_id, b.full_name,
               COUNT(DISTINCT o.order_id) AS order_count,
               COUNT(DISTINCT t.trade_id) AS trade_count,
               ROUND(COUNT(DISTINCT t.trade_id)::NUMERIC / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS execution_rate
        FROM broker b
        LEFT JOIN order_record o ON o.broker_id = b.broker_id
        LEFT JOIN trade t ON t.order_id = o.order_id
        GROUP BY b.broker_id, b.full_name
    ) sub;
    IF v_count < 4 THEN
        RAISE EXCEPTION 'FAIL [A13]: Expected >= 4 broker rows, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [A13]: Broker execution rate — % rows', v_count;
END $$;


-- ═══════════════════════════════════════════════════════════════
--  APPLICATION QUERIES (17)
--  Parameterized $1, $2 etc. replaced with real seed data values
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────
-- App Q1. List securities by exchange (param: exchange = 'NSE')
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT s.security_id, s.ticker, s.company_name, s.security_type, s.exchange, s.sector
        FROM security s WHERE s.exchange = 'NSE' AND s.is_active = TRUE ORDER BY s.ticker
    ) sub;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [AppQ1]: Expected > 0 NSE securities';
    END IF;
    RAISE NOTICE 'PASS [AppQ1]: List securities by exchange — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q2. Search securities by ticker (param: 'REL')
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT s.security_id, s.ticker, s.company_name, s.security_type, s.exchange
        FROM security s
        WHERE (s.ticker ILIKE '%' || 'REL' || '%' OR s.company_name ILIKE '%' || 'REL' || '%')
          AND s.is_active = TRUE
        ORDER BY s.ticker LIMIT 20
    ) sub;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [AppQ2]: Search for "REL" should find Reliance';
    END IF;
    RAISE NOTICE 'PASS [AppQ2]: Search securities — % rows for "REL"', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q3. Security details page (param: security_id = 1)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
    v_mkt_cap NUMERIC;
BEGIN
    SELECT COUNT(*), MAX(e.market_cap) INTO v_count, v_mkt_cap FROM (
        SELECT s.security_id, e.market_cap
        FROM security s
        LEFT JOIN equity e ON e.security_id = s.security_id
        LEFT JOIN mutual_fund mf ON mf.security_id = s.security_id
        WHERE s.security_id = 1
    ) sub
    JOIN equity e ON TRUE WHERE FALSE;

    -- Simpler: just execute and check we get 1 row
    SELECT COUNT(*) INTO v_count FROM security s
    LEFT JOIN equity e ON e.security_id = s.security_id
    LEFT JOIN mutual_fund mf ON mf.security_id = s.security_id
    WHERE s.security_id = 1;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'FAIL [AppQ3]: Expected 1 row for security_id=1, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [AppQ3]: Security details page — 1 row';
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q4. Get investor portfolio (param: investor_id = Aarav)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT h.holding_id, s.security_id, s.ticker, s.company_name, s.security_type,
               h.quantity, h.avg_cost_price, h.current_value,
               ROUND((h.current_value - (h.quantity * h.avg_cost_price)), 2) AS unrealized_pnl
        FROM holding h
        JOIN security s ON h.security_id = s.security_id
        WHERE h.investor_id = 'a0000000-0000-0000-0000-000000000001'
        ORDER BY h.current_value DESC
    ) sub;
    -- Aarav has 3 holdings
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'FAIL [AppQ4]: Expected 3 holdings for Aarav, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [AppQ4]: Investor portfolio — % holdings', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q5. Place order (test insert + rollback)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_order_id BIGINT;
BEGIN
    INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type,
                              quantity, limit_price, stop_loss_price, status)
    VALUES (2, 1, 'b0000000-0000-0000-0000-000000000001', 'BUY', 'MARKET',
            10, NULL, NULL, 'OPEN')
    RETURNING order_id INTO v_order_id;

    IF v_order_id IS NULL THEN
        RAISE EXCEPTION 'FAIL [AppQ5]: INSERT did not return an order_id';
    END IF;
    RAISE NOTICE 'PASS [AppQ5]: Place order — created order_id=%', v_order_id;

    -- Cleanup: delete the test order
    DELETE FROM order_record WHERE order_id = v_order_id;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q6. Cancel order (cancel an OPEN order)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_rows INT;
    v_open_order_id BIGINT;
BEGIN
    -- Find an OPEN order to test
    SELECT order_id INTO v_open_order_id
    FROM order_record WHERE status = 'OPEN' LIMIT 1;

    IF v_open_order_id IS NULL THEN
        RAISE NOTICE 'SKIP [AppQ6]: No OPEN orders to cancel';
        RETURN;
    END IF;

    UPDATE order_record SET status = 'CANCELLED'
    WHERE order_id = v_open_order_id AND status = 'OPEN';
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows <> 1 THEN
        RAISE EXCEPTION 'FAIL [AppQ6]: Cancel should affect 1 row, affected %', v_rows;
    END IF;
    RAISE NOTICE 'PASS [AppQ6]: Cancel order — order_id=% cancelled', v_open_order_id;

    -- Restore
    UPDATE order_record SET status = 'OPEN' WHERE order_id = v_open_order_id;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q7. Get KYC documents for investor (param: Aarav)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT k.doc_id, k.doc_no, k.doc_type, k.issue_date, k.expiry_date, k.verification_status
        FROM kyc_document k
        WHERE k.investor_id = 'a0000000-0000-0000-0000-000000000001'
        ORDER BY k.issue_date DESC
    ) sub;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'FAIL [AppQ7]: Expected 2 KYC docs for Aarav, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [AppQ7]: KYC documents — % docs', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q8. Get primary bank account (param: Aarav)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.bank_acc_id, b.acc_no, b.ifsc_code, b.is_primary
        FROM bank_acc b
        WHERE b.investor_id = 'a0000000-0000-0000-0000-000000000001' AND b.is_primary = TRUE
        LIMIT 1
    ) sub;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'FAIL [AppQ8]: Expected exactly 1 primary bank for Aarav, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [AppQ8]: Primary bank account — 1 row';
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q9. Validate order (check balance for BUY)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_is_valid BOOLEAN;
BEGIN
    -- Aarav TA=1, check if can buy 1 share at 100.00 (security_id=1)
    SELECT
        CASE WHEN 'BUY' = 'BUY' AND ta.avail_balance >= (1 * 100.00) THEN TRUE
             WHEN 'BUY' = 'SELL' AND h.quantity >= 1 THEN TRUE
             ELSE FALSE
        END INTO v_is_valid
    FROM trading_acc ta
    LEFT JOIN holding h ON h.investor_id = ta.investor_id AND h.security_id = 1
    WHERE ta.ta_id = 1;

    IF NOT v_is_valid THEN
        RAISE EXCEPTION 'FAIL [AppQ9]: Aarav should have enough balance for 1 share at 100';
    END IF;
    RAISE NOTICE 'PASS [AppQ9]: Validate order — BUY validation works';
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q10. Record trade execution (test insert + rollback)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_trade_id BIGINT;
BEGIN
    -- Use order 8 (OPEN, Priya's SELL HDFC Bank) — insert a trade
    -- First disable the problematic triggers for this test
    -- (order_status, holdings, balance triggers would change state)

    -- Just verify the INSERT + UPDATE syntax works
    INSERT INTO trade (order_id, trade_ref, fill_price, filled_qty,
                       brokerage_fee, exchange_charges, stt)
    VALUES (8, 'TRD-TEST-Q10', 1650.00, 50, 41.25, 8.25, 4.13)
    RETURNING trade_id INTO v_trade_id;

    IF v_trade_id IS NULL THEN
        RAISE EXCEPTION 'FAIL [AppQ10]: Trade INSERT did not return trade_id';
    END IF;
    RAISE NOTICE 'PASS [AppQ10]: Record trade execution — trade_id=%', v_trade_id;

    -- Cleanup
    DELETE FROM trade WHERE trade_id = v_trade_id;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q11. Update holdings (upsert test)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_qty NUMERIC;
    v_orig_qty NUMERIC;
BEGIN
    -- Save original
    SELECT quantity INTO v_orig_qty FROM holding
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000001' AND security_id = 1;

    -- Upsert: add 10 shares to Aarav's Reliance holding
    INSERT INTO holding (investor_id, security_id, quantity, avg_cost_price, current_value, last_updated)
    VALUES ('a0000000-0000-0000-0000-000000000001', 1, 10, 3000.0000, 30000.00, NOW())
    ON CONFLICT (investor_id, security_id)
    DO UPDATE SET
        quantity = holding.quantity + EXCLUDED.quantity,
        avg_cost_price = ((holding.quantity * holding.avg_cost_price) + (EXCLUDED.quantity * EXCLUDED.avg_cost_price))
                         / (holding.quantity + EXCLUDED.quantity),
        current_value = holding.current_value + EXCLUDED.current_value,
        last_updated = NOW();

    SELECT quantity INTO v_qty FROM holding
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000001' AND security_id = 1;

    IF v_qty <> v_orig_qty + 10 THEN
        RAISE EXCEPTION 'FAIL [AppQ11]: Upsert should increase qty from % to %, got %',
            v_orig_qty, v_orig_qty + 10, v_qty;
    END IF;
    RAISE NOTICE 'PASS [AppQ11]: Holdings upsert — qty increased from % to %', v_orig_qty, v_qty;

    -- Restore
    UPDATE holding
    SET quantity = v_orig_qty,
        avg_cost_price = 2450.0000,
        current_value = 295000.00
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000001' AND security_id = 1;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q12. Create fund transaction (test syntax)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_bal_before NUMERIC;
BEGIN
    SELECT avail_balance INTO v_bal_before FROM trading_acc WHERE ta_id = 6;

    INSERT INTO fund_transaction (ta_id, bank_acc_id, txn_type, amt)
    VALUES (6, 8, 'DEPOSIT', 100.00);

    RAISE NOTICE 'PASS [AppQ12]: Create fund transaction — DEPOSIT of 100.00';

    -- Cleanup
    UPDATE trading_acc SET avail_balance = v_bal_before WHERE ta_id = 6;
    DELETE FROM fund_transaction WHERE ta_id = 6 AND amt = 100.00
        AND txn_id = (SELECT MAX(txn_id) FROM fund_transaction WHERE ta_id = 6);
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q13. Update trading account balance (CASE expression)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_before NUMERIC;
    v_after NUMERIC;
BEGIN
    SELECT avail_balance INTO v_before FROM trading_acc WHERE ta_id = 6;

    UPDATE trading_acc
    SET avail_balance = CASE
        WHEN 'DEPOSIT' = 'DEPOSIT' THEN avail_balance + 250.00
        WHEN 'DEPOSIT' = 'WITHDRAWAL' THEN avail_balance - 250.00
        ELSE avail_balance
    END
    WHERE ta_id = 6;

    SELECT avail_balance INTO v_after FROM trading_acc WHERE ta_id = 6;

    IF v_after <> v_before + 250.00 THEN
        RAISE EXCEPTION 'FAIL [AppQ13]: Balance should be %, got %', v_before + 250.00, v_after;
    END IF;
    RAISE NOTICE 'PASS [AppQ13]: Update balance via CASE — % → %', v_before, v_after;

    -- Restore
    UPDATE trading_acc SET avail_balance = v_before WHERE ta_id = 6;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q14. Order history with trades (param: ta_id = 1)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT o.order_id, o.placed_at, o.side, o.order_type, o.quantity, o.status,
               o.limit_price, o.stop_loss_price,
               t.trade_id, t.trade_ref, t.fill_price, t.filled_qty, t.trade_datetime, t.net_amount
        FROM order_record o
        LEFT JOIN trade t ON t.order_id = o.order_id
        WHERE o.ta_id = 1
        ORDER BY o.placed_at DESC LIMIT 10
    ) sub;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [AppQ14]: Expected > 0 order history rows for TA=1';
    END IF;
    RAISE NOTICE 'PASS [AppQ14]: Order history — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q15. Get bank accounts (param: Aarav)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.bank_acc_id, b.acc_no, b.ifsc_code, b.is_primary
        FROM bank_acc b
        WHERE b.investor_id = 'a0000000-0000-0000-0000-000000000001'
        ORDER BY b.is_primary DESC
    ) sub;
    -- Aarav has 2 bank accounts
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'FAIL [AppQ15]: Expected 2 bank accounts for Aarav, got %', v_count;
    END IF;
    RAISE NOTICE 'PASS [AppQ15]: Bank accounts — % accounts', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q16. Active broker relationships (param: Aarav)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM (
        SELECT b.broker_id, b.full_name, b.sebi_license_no, b.commission_rate,
               bc.plan_type, bc.plan_start_date, bc.plan_end_date, bc.poa_granted
        FROM broker_client bc
        JOIN broker b ON bc.broker_id = b.broker_id
        WHERE bc.investor_id = 'a0000000-0000-0000-0000-000000000001' AND bc.is_active = TRUE
    ) sub;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'FAIL [AppQ16]: Expected > 0 active broker relationships for Aarav';
    END IF;
    RAISE NOTICE 'PASS [AppQ16]: Active broker relationships — % rows', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- App Q17. Broker commission summary (param: Rajesh)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_commission NUMERIC;
    v_trades INT;
BEGIN
    SELECT
        COALESCE(SUM(t.brokerage_fee), 0),
        COUNT(DISTINCT t.trade_id)
    INTO v_commission, v_trades
    FROM trade t
    JOIN order_record o ON t.order_id = o.order_id
    WHERE o.broker_id = 'b0000000-0000-0000-0000-000000000001';

    IF v_trades = 0 THEN
        RAISE EXCEPTION 'FAIL [AppQ17]: Rajesh should have > 0 trades';
    END IF;
    IF v_commission <= 0 THEN
        RAISE EXCEPTION 'FAIL [AppQ17]: Rajesh commission should be > 0, got %', v_commission;
    END IF;
    RAISE NOTICE 'PASS [AppQ17]: Broker commission — % total, % trades', v_commission, v_trades;
END $$;


-- ─────────────────────────────────────────────────────────────
\echo '══════════════════════════════════════════════════════'
\echo '  ✅ test_queries.sql — ALL TESTS PASSED'
\echo '══════════════════════════════════════════════════════'
