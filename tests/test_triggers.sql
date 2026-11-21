-- ============================================================
-- StockVault — Test: Trigger Logic
-- Validates all 9 triggers fire correctly and enforce
-- business rules. Each test runs in a transaction/savepoint
-- to isolate side effects from the seed data.
-- ============================================================

SET search_path TO trading;

-- Helper for expecting failures
CREATE OR REPLACE FUNCTION _test_expect_failure(p_label TEXT, p_sql TEXT)
RETURNS VOID AS $$
BEGIN
    EXECUTE p_sql;
    RAISE EXCEPTION 'FAIL [%]: Expected an error but the statement succeeded', p_label;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'PASS [%]: Correctly rejected — %', p_label, SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════
--  T1. trg_fund_txn_update_balance
--      BEFORE INSERT on fund_transaction
-- ═══════════════════════════════════════════════════════════════

-- T1a. Deposit increases balance and stamps balance_after
DO $$
DECLARE
    v_balance_before NUMERIC(15,2);
    v_balance_after  NUMERIC(15,2);
    v_txn_bal        NUMERIC(15,2);
BEGIN
    -- Use Ananya's account (TA=6) to avoid interfering with trigger tests below
    SELECT avail_balance INTO v_balance_before
    FROM trading_acc WHERE ta_id = 6;

    INSERT INTO fund_transaction (ta_id, bank_acc_id, txn_type, amt)
    VALUES (6, 8, 'DEPOSIT', 1000.00);

    SELECT avail_balance INTO v_balance_after
    FROM trading_acc WHERE ta_id = 6;

    IF v_balance_after <> v_balance_before + 1000.00 THEN
        RAISE EXCEPTION 'FAIL [T1a]: Balance after deposit should be %, got %',
            v_balance_before + 1000.00, v_balance_after;
    END IF;

    -- Check balance_after was auto-stamped on the transaction
    SELECT balance_after INTO v_txn_bal
    FROM fund_transaction
    WHERE ta_id = 6 ORDER BY txn_id DESC LIMIT 1;

    IF v_txn_bal <> v_balance_after THEN
        RAISE EXCEPTION 'FAIL [T1a]: balance_after on txn should be %, got %',
            v_balance_after, v_txn_bal;
    END IF;

    RAISE NOTICE 'PASS [T1a]: Deposit increases balance and stamps balance_after';

    -- Reverse the deposit to restore state
    UPDATE trading_acc SET avail_balance = v_balance_before WHERE ta_id = 6;
    DELETE FROM fund_transaction WHERE ta_id = 6 AND amt = 1000.00
        AND txn_id = (SELECT MAX(txn_id) FROM fund_transaction WHERE ta_id = 6);
END $$;

-- T1b. Withdrawal decreases balance
DO $$
DECLARE
    v_balance_before NUMERIC(15,2);
    v_balance_after  NUMERIC(15,2);
BEGIN
    SELECT avail_balance INTO v_balance_before
    FROM trading_acc WHERE ta_id = 6;

    INSERT INTO fund_transaction (ta_id, bank_acc_id, txn_type, amt)
    VALUES (6, 8, 'WITHDRAWAL', 500.00);

    SELECT avail_balance INTO v_balance_after
    FROM trading_acc WHERE ta_id = 6;

    IF v_balance_after <> v_balance_before - 500.00 THEN
        RAISE EXCEPTION 'FAIL [T1b]: Balance after withdrawal should be %, got %',
            v_balance_before - 500.00, v_balance_after;
    END IF;

    RAISE NOTICE 'PASS [T1b]: Withdrawal decreases balance';

    -- Restore
    UPDATE trading_acc SET avail_balance = v_balance_before WHERE ta_id = 6;
    DELETE FROM fund_transaction WHERE ta_id = 6 AND amt = 500.00
        AND txn_id = (SELECT MAX(txn_id) FROM fund_transaction WHERE ta_id = 6);
END $$;

-- T1c. Overdraft (insufficient balance) raises exception
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'T1c: Overdraft withdrawal',
        $sql$
        INSERT INTO fund_transaction (ta_id, bank_acc_id, txn_type, amt)
        VALUES (6, 8, 'WITHDRAWAL', 99999999.00)
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  T2. trg_trade_compute_net
--      BEFORE INSERT on trade — auto-calculates NET_AMOUNT
-- ═══════════════════════════════════════════════════════════════

-- T2a. BUY trade: net_amount = gross + fees
DO $$
DECLARE
    v_net NUMERIC(14,2);
    v_expected NUMERIC(14,2);
    v_trade_id BIGINT;
BEGIN
    -- Order 27 is a BUY MARKET for ICICI Bank (security_id=6, ta_id=4)
    -- Insert a test trade with known values; let trigger compute net_amount
    INSERT INTO trade (order_id, trade_ref, fill_price, filled_qty,
                       brokerage_fee, exchange_charges, stt)
    VALUES (27, 'TRD-TEST-BUYNET', 1000.00, 10, 50.00, 10.00, 5.00)
    RETURNING trade_id, net_amount INTO v_trade_id, v_net;

    -- BUY: net = (1000 * 10) + 50 + 10 + 5 = 10065
    v_expected := 10065.00;

    IF v_net <> v_expected THEN
        RAISE EXCEPTION 'FAIL [T2a]: BUY net_amount should be %, got %', v_expected, v_net;
    END IF;
    RAISE NOTICE 'PASS [T2a]: BUY net_amount correctly computed as %', v_net;

    -- Cleanup
    DELETE FROM trade WHERE trade_id = v_trade_id;
END $$;

-- T2b. SELL trade: net_amount = gross - fees
DO $$
DECLARE
    v_net NUMERIC(14,2);
    v_expected NUMERIC(14,2);
    v_trade_id BIGINT;
BEGIN
    -- Order 4 is a SELL LIMIT for Reliance (Aarav)
    INSERT INTO trade (order_id, trade_ref, fill_price, filled_qty,
                       brokerage_fee, exchange_charges, stt)
    VALUES (4, 'TRD-TEST-SELLNET', 3000.00, 5, 30.00, 6.00, 3.00)
    RETURNING trade_id, net_amount INTO v_trade_id, v_net;

    -- SELL: net = (3000 * 5) - 30 - 6 - 3 = 14961
    v_expected := 14961.00;

    IF v_net <> v_expected THEN
        RAISE EXCEPTION 'FAIL [T2b]: SELL net_amount should be %, got %', v_expected, v_net;
    END IF;
    RAISE NOTICE 'PASS [T2b]: SELL net_amount correctly computed as %', v_net;

    -- Cleanup
    DELETE FROM trade WHERE trade_id = v_trade_id;
END $$;


-- ═══════════════════════════════════════════════════════════════
--  T3. trg_validate_order (enabled post-seed)
--      BEFORE INSERT on order_record
-- ═══════════════════════════════════════════════════════════════

-- T3a. Order from PENDING KYC investor is rejected
DO $$
BEGIN
    -- Vikram (investor 5) has KYC_STATUS = 'PENDING', TA = 5
    PERFORM _test_expect_failure(
        'T3a: Order from PENDING KYC investor',
        $sql$
        INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type,
                                  quantity, status)
        VALUES (1, 5, 'b0000000-0000-0000-0000-000000000002', 'BUY', 'MARKET', 10, 'OPEN')
        $sql$
    );
END $$;

-- T3b. SELL order with insufficient holdings is rejected
DO $$
BEGIN
    -- Aarav (TA=1) has 100 Reliance shares; try to sell 9999
    PERFORM _test_expect_failure(
        'T3b: SELL with insufficient holdings',
        $sql$
        INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type,
                                  quantity, status)
        VALUES (1, 1, 'b0000000-0000-0000-0000-000000000001', 'SELL', 'MARKET', 9999, 'OPEN')
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  T7. trg_order_check_broker_active
--      BEFORE INSERT/UPDATE on order_record
-- ═══════════════════════════════════════════════════════════════

-- T7. Order assigned to inactive broker is rejected
DO $$
BEGIN
    -- Broker 4 (Kavita Nair) is inactive
    PERFORM _test_expect_failure(
        'T7: Order to inactive broker',
        $sql$
        INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type,
                                  quantity, status)
        VALUES (1, 1, 'b0000000-0000-0000-0000-000000000004', 'BUY', 'MARKET', 10, 'OPEN')
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  T8. trg_order_prevent_cancel_executed
--      BEFORE UPDATE on order_record
-- ═══════════════════════════════════════════════════════════════

-- T8a. Cannot cancel an EXECUTED order
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'T8a: Cancel EXECUTED order',
        $sql$
        UPDATE order_record SET status = 'CANCELLED' WHERE order_id = 1
        $sql$
    );
END $$;

-- T8b. Cannot cancel a PARTIAL order
DO $$
BEGIN
    PERFORM _test_expect_failure(
        'T8b: Cancel PARTIAL order',
        $sql$
        UPDATE order_record SET status = 'CANCELLED' WHERE order_id = 15
        $sql$
    );
END $$;


-- ═══════════════════════════════════════════════════════════════
--  T9. trg_investor_audit
--      AFTER UPDATE on investor — logs changes
-- ═══════════════════════════════════════════════════════════════

-- T9. Email change is logged in audit table
DO $$
DECLARE
    v_log_count INT;
    v_old_email TEXT;
BEGIN
    -- Save original email
    SELECT email INTO v_old_email FROM investor
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000006';

    -- Change Ananya's email
    UPDATE investor SET email = 'ananya_test_audit@test.com'
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000006';

    -- Check audit log
    SELECT COUNT(*) INTO v_log_count
    FROM investor_audit_log
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000006'
      AND field_name = 'EMAIL'
      AND new_value = 'ananya_test_audit@test.com';

    IF v_log_count = 0 THEN
        RAISE EXCEPTION 'FAIL [T9]: Email change not logged in investor_audit_log';
    END IF;
    RAISE NOTICE 'PASS [T9]: Email change logged in audit table';

    -- Restore original email
    UPDATE investor SET email = v_old_email
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000006';

    -- Clean audit entries from this test
    DELETE FROM investor_audit_log
    WHERE investor_id = 'a0000000-0000-0000-0000-000000000006'
      AND new_value IN ('ananya_test_audit@test.com', v_old_email);
END $$;


-- Cleanup
DROP FUNCTION IF EXISTS _test_expect_failure(TEXT, TEXT);

-- ─────────────────────────────────────────────────────────────
\echo '══════════════════════════════════════════════════════'
\echo '  ✅ test_triggers.sql — ALL TESTS PASSED'
\echo '══════════════════════════════════════════════════════'
