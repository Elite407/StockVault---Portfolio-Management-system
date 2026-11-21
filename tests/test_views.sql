-- ============================================================
-- StockVault — Test: View Correctness
-- Validates all 7 views exist, return rows, and produce
-- correct computed columns.
-- ============================================================

SET search_path TO trading;


-- ─────────────────────────────────────────────────────────────
-- 1. All 7 views exist
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_views TEXT[] := ARRAY[
        'v_investor_profile',
        'v_portfolio_summary',
        'v_order_with_trade',
        'v_broker_performance',
        'v_security_details',
        'v_fund_ledger',
        'v_capital_gains'
    ];
    v_view TEXT;
    v_exists BOOLEAN;
BEGIN
    FOREACH v_view IN ARRAY v_views LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.views
            WHERE table_schema = 'trading' AND table_name = v_view
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE EXCEPTION 'FAIL: View "%" does not exist', v_view;
        END IF;
        RAISE NOTICE 'PASS: View "%" exists', v_view;
    END LOOP;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 2. v_investor_profile returns rows with expected data
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
    v_doc_count BIGINT;
    v_balance NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_count FROM v_investor_profile;
    IF v_count < 8 THEN
        RAISE EXCEPTION 'FAIL: v_investor_profile returned % rows, expected >= 8', v_count;
    END IF;

    -- Aarav has 2 KYC docs
    SELECT kyc_doc_count INTO v_doc_count
    FROM v_investor_profile
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000001'
    LIMIT 1;

    IF v_doc_count <> 2 THEN
        RAISE EXCEPTION 'FAIL: Aarav should have 2 KYC docs, got %', v_doc_count;
    END IF;

    -- Aarav has a trading account with balance
    SELECT avail_balance INTO v_balance
    FROM v_investor_profile
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000001'
    LIMIT 1;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'FAIL: Aarav avail_balance should not be NULL';
    END IF;

    RAISE NOTICE 'PASS: v_investor_profile returns correct data';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 3. v_portfolio_summary computes unrealized P&L
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
    v_pnl NUMERIC;
    v_pct NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_count FROM v_portfolio_summary;
    IF v_count < 14 THEN
        RAISE EXCEPTION 'FAIL: v_portfolio_summary returned % rows, expected >= 14', v_count;
    END IF;

    -- Check that unrealized_pnl is computed (not NULL)
    SELECT unrealized_pnl, pnl_pct INTO v_pnl, v_pct
    FROM v_portfolio_summary
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000001'
      AND ticker = 'RELIANCE'
    LIMIT 1;

    IF v_pnl IS NULL THEN
        RAISE EXCEPTION 'FAIL: unrealized_pnl for Aarav/RELIANCE should not be NULL';
    END IF;
    IF v_pct IS NULL THEN
        RAISE EXCEPTION 'FAIL: pnl_pct for Aarav/RELIANCE should not be NULL';
    END IF;

    RAISE NOTICE 'PASS: v_portfolio_summary computes unrealized_pnl (%) and pnl_pct (%)', v_pnl, v_pct;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 4. v_order_with_trade includes unfilled orders (LEFT JOIN)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_total INT;
    v_nulltrade INT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM v_order_with_trade;

    -- Some orders should have NULL trade_id (OPEN, CANCELLED orders without trades)
    SELECT COUNT(*) INTO v_nulltrade
    FROM v_order_with_trade
    WHERE trade_id IS NULL;

    IF v_nulltrade = 0 THEN
        RAISE EXCEPTION 'FAIL: v_order_with_trade should include orders without trades (NULL trade_id)';
    END IF;

    RAISE NOTICE 'PASS: v_order_with_trade has % total rows, % without trades', v_total, v_nulltrade;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 5. v_broker_performance aggregates correctly
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
    v_revenue NUMERIC;
    v_rate NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_count FROM v_broker_performance;
    IF v_count < 4 THEN
        RAISE EXCEPTION 'FAIL: v_broker_performance returned % rows, expected >= 4 (all brokers)', v_count;
    END IF;

    -- Rajesh (broker 1) should have revenue > 0
    SELECT total_revenue, execution_rate INTO v_revenue, v_rate
    FROM v_broker_performance
    WHERE broker_id = 'b0000000-0000-0000-0000-000000000001';

    IF v_revenue <= 0 THEN
        RAISE EXCEPTION 'FAIL: Rajesh total_revenue should be > 0, got %', v_revenue;
    END IF;

    RAISE NOTICE 'PASS: v_broker_performance — Rajesh revenue=%, exec_rate=%', v_revenue, v_rate;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 6. v_security_details merges ISA subtypes correctly
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_mkt_cap NUMERIC;
    v_nav NUMERIC;
BEGIN
    -- Equity (Reliance, security_id=1): should have market_cap, NULL nav
    SELECT market_cap, nav INTO v_mkt_cap, v_nav
    FROM v_security_details WHERE security_id = 1;

    IF v_mkt_cap IS NULL THEN
        RAISE EXCEPTION 'FAIL: Reliance (equity) should have market_cap';
    END IF;
    IF v_nav IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: Reliance (equity) should have NULL nav';
    END IF;
    RAISE NOTICE 'PASS: Equity (Reliance) has market_cap=%, nav=NULL', v_mkt_cap;

    -- Mutual Fund (Axis Bluechip, security_id=9): should have nav, NULL market_cap
    SELECT market_cap, nav INTO v_mkt_cap, v_nav
    FROM v_security_details WHERE security_id = 9;

    IF v_nav IS NULL THEN
        RAISE EXCEPTION 'FAIL: Axis Bluechip (MF) should have nav';
    END IF;
    IF v_mkt_cap IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL: Axis Bluechip (MF) should have NULL market_cap';
    END IF;
    RAISE NOTICE 'PASS: MF (Axis Bluechip) has nav=%, market_cap=NULL', v_nav;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 7. v_fund_ledger returns transaction data with investor name
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
    v_name TEXT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM v_fund_ledger;
    IF v_count < 10 THEN
        RAISE EXCEPTION 'FAIL: v_fund_ledger returned % rows, expected >= 10', v_count;
    END IF;

    -- Check investor name is populated
    SELECT investor_name INTO v_name FROM v_fund_ledger LIMIT 1;
    IF v_name IS NULL THEN
        RAISE EXCEPTION 'FAIL: v_fund_ledger investor_name should not be NULL';
    END IF;

    RAISE NOTICE 'PASS: v_fund_ledger has % rows with investor names', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 8. v_capital_gains computes gain_amount and classifies STCG/LTCG
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
    v_gain NUMERIC;
    v_type TEXT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM v_capital_gains;
    IF v_count < 1 THEN
        RAISE EXCEPTION 'FAIL: v_capital_gains returned % rows, expected >= 1', v_count;
    END IF;

    -- The seed data has a CG record with holding_days = 5 → STCG
    SELECT gain_amount, gain_type INTO v_gain, v_type
    FROM v_capital_gains LIMIT 1;

    IF v_gain IS NULL THEN
        RAISE EXCEPTION 'FAIL: gain_amount should not be NULL';
    END IF;
    IF v_type NOT IN ('STCG', 'LTCG') THEN
        RAISE EXCEPTION 'FAIL: gain_type should be STCG or LTCG, got %', v_type;
    END IF;

    -- 5 days < 365 → must be STCG
    IF v_type <> 'STCG' THEN
        RAISE EXCEPTION 'FAIL: holding_days=5 should classify as STCG, got %', v_type;
    END IF;

    RAISE NOTICE 'PASS: v_capital_gains — gain_amount=%, gain_type=%', v_gain, v_type;
END $$;


-- ─────────────────────────────────────────────────────────────
\echo '══════════════════════════════════════════════════════'
\echo '  ✅ test_views.sql — ALL TESTS PASSED'
\echo '══════════════════════════════════════════════════════'
