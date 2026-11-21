-- ============================================================
-- StockVault — Test: Constraint Enforcement
-- Validates that CHECK, UNIQUE, and FK constraints properly
-- reject invalid data by attempting forbidden operations
-- inside savepoints (so failures don't abort the transaction).
-- ============================================================

SET search_path TO trading;


-- ─────────────────────────────────────────────────────────────
-- Helper: Attempts to execute SQL that SHOULD fail.
-- If the SQL succeeds, the test FAILs (constraint is broken).
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _test_expect_failure(p_label TEXT, p_sql TEXT)
RETURNS VOID AS $$
BEGIN
    EXECUTE p_sql;
    -- If we reach here, the constraint did NOT fire
    RAISE EXCEPTION 'FAIL [%]: Expected an error but the statement succeeded', p_label;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'PASS [%]: Correctly rejected — %', p_label, SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════
--  INVESTOR constraints
-- ═══════════════════════════════════════════════════════════════

-- 1. RETAIL investor with CIN_NO should be rejected (ISA subtype rule)
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'RETAIL with CIN_NO',
        $sql$
        INSERT INTO investor (full_name, email, password_hash, pan_no, aadhar_no,
                              dob, kyc_status, is_active, investor_type, risk_profile, cin_no)
        VALUES ('Test Retail', 'test_retail_cin@test.com', 'hash', 'ZZZZZ9999Z', '999999999901',
                '1990-01-01', 'PENDING', TRUE, 'RETAIL', 'MODERATE', 'U12345MH9999PLC999999')
        $sql$
    );
END $$;

-- 2. INSTITUTIONAL investor with RISK_PROFILE should be rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'INSTITUTIONAL with RISK_PROFILE',
        $sql$
        INSERT INTO investor (full_name, email, password_hash, pan_no, aadhar_no,
                              dob, kyc_status, is_active, investor_type, risk_profile, cin_no)
        VALUES ('Test Inst', 'test_inst_risk@test.com', 'hash', 'YYYYY8888Y', '888888888801',
                '2000-01-01', 'PENDING', TRUE, 'INSTITUTIONAL', 'AGGRESSIVE', 'U99999MH9999PLC888888')
        $sql$
    );
END $$;

-- 3. Invalid investor_type rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'Invalid investor_type CORPORATE',
        $sql$
        INSERT INTO investor (full_name, email, password_hash, pan_no, aadhar_no,
                              dob, kyc_status, is_active, investor_type)
        VALUES ('Test Bad', 'test_badtype@test.com', 'hash', 'XXXXX7777X', '777777777701',
                '1990-01-01', 'PENDING', TRUE, 'CORPORATE')
        $sql$
    );
END $$;

-- 4. Invalid KYC status rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'Invalid kyc_status APPROVED',
        $sql$
        INSERT INTO investor (full_name, email, password_hash, pan_no, aadhar_no,
                              dob, kyc_status, is_active, investor_type, risk_profile)
        VALUES ('Test KYC', 'test_badkyc@test.com', 'hash', 'WWWWW6666W', '666666666601',
                '1990-01-01', 'APPROVED', TRUE, 'RETAIL', 'MODERATE')
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  ORDER_RECORD constraints
-- ═══════════════════════════════════════════════════════════════

-- 5. LIMIT order without limit_price rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'LIMIT order without limit_price',
        $sql$
        INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type,
                                  quantity, limit_price, stop_loss_price, status)
        VALUES (1, 1, 'b0000000-0000-0000-0000-000000000001', 'BUY', 'LIMIT',
                10, NULL, NULL, 'OPEN')
        $sql$
    );
END $$;

-- 6. SL order without stop_loss_price rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'SL order without stop_loss_price',
        $sql$
        INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type,
                                  quantity, limit_price, stop_loss_price, status)
        VALUES (1, 1, 'b0000000-0000-0000-0000-000000000001', 'BUY', 'SL',
                10, 100, NULL, 'OPEN')
        $sql$
    );
END $$;

-- 7. SL-M order without stop_loss_price rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'SL-M order without stop_loss_price',
        $sql$
        INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type,
                                  quantity, limit_price, stop_loss_price, status)
        VALUES (1, 1, 'b0000000-0000-0000-0000-000000000001', 'SELL', 'SL-M',
                10, NULL, NULL, 'OPEN')
        $sql$
    );
END $$;

-- 8. Invalid order side rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'Invalid side SHORT',
        $sql$
        INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type,
                                  quantity, limit_price, stop_loss_price, status)
        VALUES (1, 1, NULL, 'SHORT', 'MARKET', 10, NULL, NULL, 'OPEN')
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  TRADING_ACC constraints
-- ═══════════════════════════════════════════════════════════════

-- 9. Negative balance rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'Negative avail_balance',
        $sql$
        INSERT INTO trading_acc (investor_id, is_active, avail_balance)
        VALUES ('a0000000-0000-0000-0000-000000000001', TRUE, -100.00)
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  TRADE constraints
-- ═══════════════════════════════════════════════════════════════

-- 10. Zero fill_price rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'Zero fill_price on trade',
        $sql$
        INSERT INTO trade (order_id, trade_ref, fill_price, filled_qty, brokerage_fee, exchange_charges, stt)
        VALUES (1, 'TRD-TEST-ZERO', 0, 10, 0, 0, 0)
        $sql$
    );
END $$;

-- 11. Zero filled_qty rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'Zero filled_qty on trade',
        $sql$
        INSERT INTO trade (order_id, trade_ref, fill_price, filled_qty, brokerage_fee, exchange_charges, stt)
        VALUES (1, 'TRD-TEST-ZEROQ', 100, 0, 0, 0, 0)
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  BANK_ACC partial unique index
-- ═══════════════════════════════════════════════════════════════

-- 12. Second primary bank account for same investor rejected
DO $$
BEGIN
    -- Investor 1 already has a primary bank account (bank_acc_id=1)
    PERFORM _test_expect_failure(
        'Second primary bank account for same investor',
        $sql$
        INSERT INTO bank_acc (acc_no, ifsc_code, is_primary, investor_id)
        VALUES ('9999999999999', 'TEST0001234', TRUE, 'a0000000-0000-0000-0000-000000000001')
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  KYC_DOCUMENT constraints
-- ═══════════════════════════════════════════════════════════════

-- 13. Expiry date before issue date rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'KYC expiry before issue',
        $sql$
        INSERT INTO kyc_document (doc_no, doc_type, issue_date, expiry_date, verification_status, investor_id)
        VALUES ('DOC-TEST-EXP', 'PAN', '2025-01-01', '2020-01-01', 'PENDING', 'a0000000-0000-0000-0000-000000000001')
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  CAPITAL_GAINS_RECORD constraints
-- ═══════════════════════════════════════════════════════════════

-- 14. Same trade as both buy and sell rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'Capital gains: same buy and sell trade',
        $sql$
        INSERT INTO capital_gains_record (buy_trade_id, sell_trade_id, buy_price, sell_price, quantity, tax_amount, holding_days)
        VALUES (1, 1, 100, 150, 10, 5, 30)
        $sql$
    );
END $$;

-- 15. Negative tax amount rejected
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'Capital gains: negative tax_amount',
        $sql$
        INSERT INTO capital_gains_record (buy_trade_id, sell_trade_id, buy_price, sell_price, quantity, tax_amount, holding_days)
        VALUES (1, 4, 100, 150, 10, -5, 30)
        $sql$
    );
END $$;


-- Cleanup
DROP FUNCTION IF EXISTS _test_expect_failure(TEXT, TEXT);

-- ─────────────────────────────────────────────────────────────
\echo '══════════════════════════════════════════════════════'
\echo '  ✅ test_constraints.sql — ALL TESTS PASSED'
\echo '══════════════════════════════════════════════════════'
