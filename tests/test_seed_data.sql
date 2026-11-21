-- ============================================================
-- StockVault — Test: Seed Data Integrity
-- Validates that all seed data was loaded correctly with
-- exact row counts, data distributions, and FK integrity.
-- ============================================================

SET search_path TO trading;


-- ─────────────────────────────────────────────────────────────
-- Helper: Assert exact row count for a table
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _test_assert_count(p_table TEXT, p_expected INT)
RETURNS VOID AS $$
DECLARE
    v_actual INT;
BEGIN
    EXECUTE format('SELECT COUNT(*) FROM %I', p_table) INTO v_actual;
    IF v_actual <> p_expected THEN
        RAISE EXCEPTION 'FAIL: Table "%" has % rows, expected %', p_table, v_actual, p_expected;
    END IF;
    RAISE NOTICE 'PASS: Table "%" has % rows', p_table, p_expected;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- 1. Exact row counts per table
-- ─────────────────────────────────────────────────────────────
DO $$
BEGIN
    PERFORM _test_assert_count('investor',              8);
    PERFORM _test_assert_count('kyc_document',          12);
    PERFORM _test_assert_count('trading_acc',           8);
    PERFORM _test_assert_count('bank_acc',              10);
    PERFORM _test_assert_count('broker',                4);
    PERFORM _test_assert_count('fund_transaction',      10);
    PERFORM _test_assert_count('plan_catalog',          4);
    PERFORM _test_assert_count('broker_client',         8);
    PERFORM _test_assert_count('security',              12);
    PERFORM _test_assert_count('equity',                8);
    PERFORM _test_assert_count('mutual_fund',           4);
    PERFORM _test_assert_count('holding',               14);
    PERFORM _test_assert_count('order_record',          30);
    PERFORM _test_assert_count('trade',                 20);
    PERFORM _test_assert_count('capital_gains_record',  1);
END $$;


-- ─────────────────────────────────────────────────────────────
-- 2. Investor type distribution (6 RETAIL, 2 INSTITUTIONAL)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_retail INT;
    v_inst INT;
BEGIN
    SELECT COUNT(*) INTO v_retail FROM investor WHERE investor_type = 'RETAIL';
    SELECT COUNT(*) INTO v_inst   FROM investor WHERE investor_type = 'INSTITUTIONAL';

    IF v_retail <> 6 THEN
        RAISE EXCEPTION 'FAIL: Expected 6 RETAIL investors, found %', v_retail;
    END IF;
    IF v_inst <> 2 THEN
        RAISE EXCEPTION 'FAIL: Expected 2 INSTITUTIONAL investors, found %', v_inst;
    END IF;
    RAISE NOTICE 'PASS: Investor distribution — 6 RETAIL, 2 INSTITUTIONAL';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 3. All 4 order statuses are present
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_statuses TEXT[];
    v_expected TEXT[] := ARRAY['OPEN', 'EXECUTED', 'CANCELLED', 'PARTIAL'];
    v_st TEXT;
BEGIN
    SELECT ARRAY_AGG(DISTINCT status) INTO v_statuses FROM order_record;

    FOREACH v_st IN ARRAY v_expected LOOP
        IF NOT v_st = ANY(v_statuses) THEN
            RAISE EXCEPTION 'FAIL: Order status "%" not found in seed data', v_st;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS: All 4 order statuses present (OPEN, EXECUTED, CANCELLED, PARTIAL)';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 4. All 4 order types are present
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_types TEXT[];
    v_expected TEXT[] := ARRAY['MARKET', 'LIMIT', 'SL', 'SL-M'];
    v_tp TEXT;
BEGIN
    SELECT ARRAY_AGG(DISTINCT order_type) INTO v_types FROM order_record;

    FOREACH v_tp IN ARRAY v_expected LOOP
        IF NOT v_tp = ANY(v_types) THEN
            RAISE EXCEPTION 'FAIL: Order type "%" not found in seed data', v_tp;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS: All 4 order types present (MARKET, LIMIT, SL, SL-M)';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 5. Security type split (8 EQUITY, 4 MUTUAL_FUND)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_eq INT;
    v_mf INT;
BEGIN
    SELECT COUNT(*) INTO v_eq FROM security WHERE security_type = 'EQUITY';
    SELECT COUNT(*) INTO v_mf FROM security WHERE security_type = 'MUTUAL_FUND';

    IF v_eq <> 8 THEN
        RAISE EXCEPTION 'FAIL: Expected 8 EQUITY securities, found %', v_eq;
    END IF;
    IF v_mf <> 4 THEN
        RAISE EXCEPTION 'FAIL: Expected 4 MUTUAL_FUND securities, found %', v_mf;
    END IF;
    RAISE NOTICE 'PASS: Security split — 8 EQUITY, 4 MUTUAL_FUND';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 6. FK integrity: every trade references a valid order
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_orphans INT;
BEGIN
    SELECT COUNT(*) INTO v_orphans
    FROM trade t
    LEFT JOIN order_record o ON t.order_id = o.order_id
    WHERE o.order_id IS NULL;

    IF v_orphans > 0 THEN
        RAISE EXCEPTION 'FAIL: % trades reference non-existent orders', v_orphans;
    END IF;
    RAISE NOTICE 'PASS: All trades reference valid orders (0 orphans)';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 7. FK integrity: every holding references valid investor + security
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_orphan_inv INT;
    v_orphan_sec INT;
BEGIN
    SELECT COUNT(*) INTO v_orphan_inv
    FROM holding h
    LEFT JOIN investor i ON h.investor_id = i.investor_id
    WHERE i.investor_id IS NULL;

    SELECT COUNT(*) INTO v_orphan_sec
    FROM holding h
    LEFT JOIN security s ON h.security_id = s.security_id
    WHERE s.security_id IS NULL;

    IF v_orphan_inv > 0 THEN
        RAISE EXCEPTION 'FAIL: % holdings reference non-existent investors', v_orphan_inv;
    END IF;
    IF v_orphan_sec > 0 THEN
        RAISE EXCEPTION 'FAIL: % holdings reference non-existent securities', v_orphan_sec;
    END IF;
    RAISE NOTICE 'PASS: All holdings reference valid investors and securities';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 8. ISA integrity: equity rows match EQUITY securities
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_mismatch INT;
BEGIN
    SELECT COUNT(*) INTO v_mismatch
    FROM equity e
    JOIN security s ON e.security_id = s.security_id
    WHERE s.security_type <> 'EQUITY';

    IF v_mismatch > 0 THEN
        RAISE EXCEPTION 'FAIL: % equity rows reference non-EQUITY securities', v_mismatch;
    END IF;
    RAISE NOTICE 'PASS: All equity rows reference EQUITY-type securities';

    SELECT COUNT(*) INTO v_mismatch
    FROM mutual_fund mf
    JOIN security s ON mf.security_id = s.security_id
    WHERE s.security_type <> 'MUTUAL_FUND';

    IF v_mismatch > 0 THEN
        RAISE EXCEPTION 'FAIL: % mutual_fund rows reference non-MUTUAL_FUND securities', v_mismatch;
    END IF;
    RAISE NOTICE 'PASS: All mutual_fund rows reference MUTUAL_FUND-type securities';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 9. At least one investor with PENDING KYC (Vikram)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_pending INT;
BEGIN
    SELECT COUNT(*) INTO v_pending FROM investor WHERE kyc_status = 'PENDING';
    IF v_pending = 0 THEN
        RAISE EXCEPTION 'FAIL: Expected at least 1 investor with PENDING KYC';
    END IF;
    RAISE NOTICE 'PASS: Found % investor(s) with PENDING KYC', v_pending;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 10. At least one inactive broker (Kavita)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_inactive INT;
BEGIN
    SELECT COUNT(*) INTO v_inactive FROM broker WHERE is_active = FALSE;
    IF v_inactive = 0 THEN
        RAISE EXCEPTION 'FAIL: Expected at least 1 inactive broker';
    END IF;
    RAISE NOTICE 'PASS: Found % inactive broker(s)', v_inactive;
END $$;


-- Cleanup
DROP FUNCTION IF EXISTS _test_assert_count(TEXT, INT);

-- ─────────────────────────────────────────────────────────────
\echo '══════════════════════════════════════════════════════'
\echo '  ✅ test_seed_data.sql — ALL TESTS PASSED'
\echo '══════════════════════════════════════════════════════'
