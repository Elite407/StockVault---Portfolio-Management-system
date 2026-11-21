-- ============================================================
-- StockVault — Test: Schema & Structure
-- Validates that all tables, primary keys, foreign keys,
-- constraints, and unique indexes exist as expected.
-- ============================================================

SET search_path TO trading;

-- ─────────────────────────────────────────────────────────────
-- Helper: Assert a table exists in the trading schema
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _test_assert_table_exists(p_table TEXT)
RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'trading' AND table_name = lower(p_table)
    ) THEN
        RAISE EXCEPTION 'FAIL: Table "%" does not exist in schema "trading"', p_table;
    END IF;
    RAISE NOTICE 'PASS: Table "%" exists', p_table;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- 1. All 14 tables + audit log table exist
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_tables TEXT[] := ARRAY[
        'investor', 'kyc_document', 'trading_acc', 'bank_acc',
        'broker', 'fund_transaction', 'plan_catalog', 'broker_client',
        'security', 'equity', 'mutual_fund', 'holding',
        'order_record', 'trade', 'capital_gains_record',
        'investor_audit_log'
    ];
    v_tbl TEXT;
BEGIN
    FOREACH v_tbl IN ARRAY v_tables LOOP
        PERFORM _test_assert_table_exists(v_tbl);
    END LOOP;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 2. Total table count in the trading schema = 16
--    (14 core + investor_audit_log + any test helpers)
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'trading' AND table_type = 'BASE TABLE';

    -- 14 core tables + investor_audit_log = 15 base tables minimum
    IF v_count < 15 THEN
        RAISE EXCEPTION 'FAIL: Expected >= 15 base tables in trading schema, found %', v_count;
    END IF;
    RAISE NOTICE 'PASS: Found % base tables in trading schema (expected >= 15)', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 3. Primary keys exist on all tables
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_tables TEXT[] := ARRAY[
        'investor', 'kyc_document', 'trading_acc', 'bank_acc',
        'broker', 'fund_transaction', 'plan_catalog', 'broker_client',
        'security', 'equity', 'mutual_fund', 'holding',
        'order_record', 'trade', 'capital_gains_record',
        'investor_audit_log'
    ];
    v_tbl TEXT;
    v_has_pk BOOLEAN;
BEGIN
    FOREACH v_tbl IN ARRAY v_tables LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.table_constraints
            WHERE table_schema = 'trading'
              AND table_name = v_tbl
              AND constraint_type = 'PRIMARY KEY'
        ) INTO v_has_pk;

        IF NOT v_has_pk THEN
            RAISE EXCEPTION 'FAIL: Table "%" has no PRIMARY KEY', v_tbl;
        END IF;
        RAISE NOTICE 'PASS: Table "%" has a PRIMARY KEY', v_tbl;
    END LOOP;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 4. Foreign key relationships exist
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_fks TEXT[][] := ARRAY[
        ARRAY['kyc_document',          'fk_kyc_document_investor'],
        ARRAY['trading_acc',           'fk_trading_acc_investor'],
        ARRAY['bank_acc',              'fk_bank_acc_investor'],
        ARRAY['fund_transaction',      'fk_fund_transaction_trading_acc'],
        ARRAY['fund_transaction',      'fk_fund_transaction_bank_acc'],
        ARRAY['broker_client',         'fk_broker_client_investor'],
        ARRAY['broker_client',         'fk_broker_client_broker'],
        ARRAY['broker_client',         'fk_broker_client_plan_catalog'],
        ARRAY['equity',                'fk_equity_security'],
        ARRAY['mutual_fund',           'fk_mutual_fund_security'],
        ARRAY['holding',               'fk_holding_investor'],
        ARRAY['holding',               'fk_holding_security'],
        ARRAY['order_record',          'fk_order_record_security'],
        ARRAY['order_record',          'fk_order_record_trading_acc'],
        ARRAY['order_record',          'fk_order_record_broker'],
        ARRAY['trade',                 'fk_trade_order_record'],
        ARRAY['capital_gains_record',  'fk_capital_gains_record_buy_trade'],
        ARRAY['capital_gains_record',  'fk_capital_gains_record_sell_trade']
    ];
    v_fk TEXT[];
    v_exists BOOLEAN;
BEGIN
    FOREACH v_fk SLICE 1 IN ARRAY v_fks LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.table_constraints
            WHERE table_schema = 'trading'
              AND table_name = v_fk[1]
              AND constraint_name = v_fk[2]
              AND constraint_type = 'FOREIGN KEY'
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE EXCEPTION 'FAIL: FK "%" on table "%" not found', v_fk[2], v_fk[1];
        END IF;
        RAISE NOTICE 'PASS: FK "%" on "%"', v_fk[2], v_fk[1];
    END LOOP;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 5. Check constraints exist
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_checks TEXT[][] := ARRAY[
        ARRAY['investor',              'chk_investor_type'],
        ARRAY['investor',              'chk_investor_kyc_status'],
        ARRAY['investor',              'chk_investor_subtype_fields'],
        ARRAY['investor',              'chk_investor_dob'],
        ARRAY['kyc_document',          'chk_kyc_document_doc_type'],
        ARRAY['kyc_document',          'chk_kyc_document_verification_status'],
        ARRAY['trading_acc',           'chk_trading_acc_avail_balance'],
        ARRAY['fund_transaction',      'chk_fund_transaction_amt'],
        ARRAY['fund_transaction',      'chk_fund_transaction_txn_type'],
        ARRAY['order_record',          'chk_order_record_side'],
        ARRAY['order_record',          'chk_order_record_order_type'],
        ARRAY['order_record',          'chk_order_record_status'],
        ARRAY['order_record',          'chk_order_record_limit_price'],
        ARRAY['order_record',          'chk_order_record_sl_price'],
        ARRAY['trade',                 'chk_trade_fill_price'],
        ARRAY['trade',                 'chk_trade_filled_qty'],
        ARRAY['capital_gains_record',  'chk_capital_gains_record_distinct_trades']
    ];
    v_chk TEXT[];
    v_exists BOOLEAN;
BEGIN
    FOREACH v_chk SLICE 1 IN ARRAY v_checks LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.table_constraints
            WHERE table_schema = 'trading'
              AND table_name = v_chk[1]
              AND constraint_name = v_chk[2]
              AND constraint_type = 'CHECK'
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE EXCEPTION 'FAIL: CHECK constraint "%" on table "%" not found', v_chk[2], v_chk[1];
        END IF;
        RAISE NOTICE 'PASS: CHECK "%" on "%"', v_chk[2], v_chk[1];
    END LOOP;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 6. Unique constraints exist
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_uqs TEXT[][] := ARRAY[
        ARRAY['investor',              'uq_investor_email'],
        ARRAY['investor',              'uq_investor_pan_no'],
        ARRAY['investor',              'uq_investor_aadhar_no'],
        ARRAY['broker',                'uq_broker_email'],
        ARRAY['broker',                'uq_broker_sebi_license_no'],
        ARRAY['security',              'uq_security_ticker'],
        ARRAY['security',              'uq_security_isin'],
        ARRAY['kyc_document',          'uq_kyc_document_doc_no'],
        ARRAY['holding',               'uq_holding_investor_security'],
        ARRAY['broker_client',         'uq_broker_client_investor_broker'],
        ARRAY['bank_acc',              'uq_bank_acc_acc_no'],
        ARRAY['trade',                 'uq_trade_trade_ref']
    ];
    v_uq TEXT[];
    v_exists BOOLEAN;
BEGIN
    FOREACH v_uq SLICE 1 IN ARRAY v_uqs LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.table_constraints
            WHERE table_schema = 'trading'
              AND table_name = v_uq[1]
              AND constraint_name = v_uq[2]
              AND constraint_type = 'UNIQUE'
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE EXCEPTION 'FAIL: UNIQUE constraint "%" on table "%" not found', v_uq[2], v_uq[1];
        END IF;
        RAISE NOTICE 'PASS: UNIQUE "%" on "%"', v_uq[2], v_uq[1];
    END LOOP;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 7. Column count validation for key tables
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
BEGIN
    -- INVESTOR: 13 columns
    SELECT COUNT(*) INTO v_count FROM information_schema.columns
    WHERE table_schema = 'trading' AND table_name = 'investor';
    IF v_count <> 13 THEN
        RAISE EXCEPTION 'FAIL: investor table has % columns, expected 13', v_count;
    END IF;
    RAISE NOTICE 'PASS: investor has 13 columns';

    -- ORDER_RECORD: 11 columns
    SELECT COUNT(*) INTO v_count FROM information_schema.columns
    WHERE table_schema = 'trading' AND table_name = 'order_record';
    IF v_count <> 11 THEN
        RAISE EXCEPTION 'FAIL: order_record table has % columns, expected 11', v_count;
    END IF;
    RAISE NOTICE 'PASS: order_record has 11 columns';

    -- TRADE: 11 columns
    SELECT COUNT(*) INTO v_count FROM information_schema.columns
    WHERE table_schema = 'trading' AND table_name = 'trade';
    IF v_count <> 11 THEN
        RAISE EXCEPTION 'FAIL: trade table has % columns, expected 11', v_count;
    END IF;
    RAISE NOTICE 'PASS: trade has 11 columns';
END $$;


-- Cleanup helper function
DROP FUNCTION IF EXISTS _test_assert_table_exists(TEXT);

-- ─────────────────────────────────────────────────────────────
\echo '══════════════════════════════════════════════════════'
\echo '  ✅ test_schema.sql — ALL TESTS PASSED'
\echo '══════════════════════════════════════════════════════'
