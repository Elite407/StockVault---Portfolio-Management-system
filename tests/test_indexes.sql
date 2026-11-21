-- ============================================================
-- StockVault — Test: Index Existence
-- Validates all 16 performance indexes + the DDL-created
-- partial unique index exist in pg_indexes.
-- ============================================================

SET search_path TO trading;


-- ─────────────────────────────────────────────────────────────
-- 1. All named indexes exist
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_indexes TEXT[] := ARRAY[
        -- DDL partial unique index
        'uq_bank_acc_one_primary_per_investor',
        -- Performance indexes from indexes.sql
        'idx_investor_kyc_status',
        'idx_investor_type',
        'idx_kyc_document_expiry',
        'idx_kyc_document_investor',
        'idx_trading_acc_investor',
        'idx_bank_acc_investor',
        'idx_broker_client_investor',
        'idx_broker_client_plan',
        'idx_order_record_broker_status',
        'idx_order_record_security_status',
        'idx_order_record_ta_placed',
        'idx_order_record_open_placed',
        'idx_order_record_type',
        'idx_trade_datetime',
        'idx_trade_order',
        'idx_holding_investor',
        'idx_fund_txn_ta_date',
        'idx_security_exchange_active',
        'idx_security_ticker'
    ];
    v_idx TEXT;
    v_exists BOOLEAN;
BEGIN
    FOREACH v_idx IN ARRAY v_indexes LOOP
        SELECT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE schemaname = 'trading' AND indexname = v_idx
        ) INTO v_exists;

        IF NOT v_exists THEN
            RAISE EXCEPTION 'FAIL: Index "%" not found in trading schema', v_idx;
        END IF;
        RAISE NOTICE 'PASS: Index "%" exists', v_idx;
    END LOOP;
END $$;


-- ─────────────────────────────────────────────────────────────
-- 2. Partial indexes have correct WHERE predicates
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_indexdef TEXT;
BEGIN
    -- uq_bank_acc_one_primary_per_investor: WHERE is_primary = TRUE
    SELECT indexdef INTO v_indexdef
    FROM pg_indexes
    WHERE schemaname = 'trading' AND indexname = 'uq_bank_acc_one_primary_per_investor';

    IF v_indexdef NOT ILIKE '%WHERE%is_primary%true%' THEN
        RAISE EXCEPTION 'FAIL: Partial index uq_bank_acc_one_primary_per_investor missing WHERE is_primary = TRUE. Def: %', v_indexdef;
    END IF;
    RAISE NOTICE 'PASS: uq_bank_acc_one_primary_per_investor has correct WHERE predicate';

    -- idx_kyc_document_expiry: WHERE verification_status = 'VERIFIED'
    SELECT indexdef INTO v_indexdef
    FROM pg_indexes
    WHERE schemaname = 'trading' AND indexname = 'idx_kyc_document_expiry';

    IF v_indexdef NOT ILIKE '%WHERE%verification_status%VERIFIED%' THEN
        RAISE EXCEPTION 'FAIL: Partial index idx_kyc_document_expiry missing WHERE verification_status predicate. Def: %', v_indexdef;
    END IF;
    RAISE NOTICE 'PASS: idx_kyc_document_expiry has correct WHERE predicate';

    -- idx_broker_client_investor: WHERE is_active = TRUE
    SELECT indexdef INTO v_indexdef
    FROM pg_indexes
    WHERE schemaname = 'trading' AND indexname = 'idx_broker_client_investor';

    IF v_indexdef NOT ILIKE '%WHERE%is_active%true%' THEN
        RAISE EXCEPTION 'FAIL: Partial index idx_broker_client_investor missing WHERE is_active = TRUE. Def: %', v_indexdef;
    END IF;
    RAISE NOTICE 'PASS: idx_broker_client_investor has correct WHERE predicate';

    -- idx_order_record_open_placed: WHERE status = 'OPEN'
    SELECT indexdef INTO v_indexdef
    FROM pg_indexes
    WHERE schemaname = 'trading' AND indexname = 'idx_order_record_open_placed';

    IF v_indexdef NOT ILIKE '%WHERE%status%OPEN%' THEN
        RAISE EXCEPTION 'FAIL: Partial index idx_order_record_open_placed missing WHERE status = OPEN. Def: %', v_indexdef;
    END IF;
    RAISE NOTICE 'PASS: idx_order_record_open_placed has correct WHERE predicate';

    -- idx_security_exchange_active: WHERE is_active = TRUE
    SELECT indexdef INTO v_indexdef
    FROM pg_indexes
    WHERE schemaname = 'trading' AND indexname = 'idx_security_exchange_active';

    IF v_indexdef NOT ILIKE '%WHERE%is_active%true%' THEN
        RAISE EXCEPTION 'FAIL: Partial index idx_security_exchange_active missing WHERE is_active = TRUE. Def: %', v_indexdef;
    END IF;
    RAISE NOTICE 'PASS: idx_security_exchange_active has correct WHERE predicate';
END $$;


-- ─────────────────────────────────────────────────────────────
-- 3. Total index count sanity check
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM pg_indexes WHERE schemaname = 'trading';

    -- 20 custom + PK/UNIQUE auto-indexes = should be well above 20
    IF v_count < 20 THEN
        RAISE EXCEPTION 'FAIL: Expected >= 20 indexes in trading schema, found %', v_count;
    END IF;
    RAISE NOTICE 'PASS: Total index count = % (expected >= 20)', v_count;
END $$;


-- ─────────────────────────────────────────────────────────────
\echo '══════════════════════════════════════════════════════'
\echo '  ✅ test_indexes.sql — ALL TESTS PASSED'
\echo '══════════════════════════════════════════════════════'
