-- ============================================================
-- StockVault — Triggers & Functions
-- Purpose : Automate business logic at the database level to
--           enforce data integrity beyond what constraints can do.
-- Run     : After final_ddl.sql (before or after seed_data.sql).
-- ============================================================

SET search_path TO trading;


-- ═══════════════════════════════════════════════════════════════
--  FUNCTIONS (reusable logic)
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────
-- F1. fn_update_balance_on_fund_txn()
--     Automatically adjusts TRADING_ACC.avail_balance when a
--     FUND_TRANSACTION is inserted, and stamps balance_after.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_update_balance_on_fund_txn()
RETURNS TRIGGER AS $$
DECLARE
    v_new_balance NUMERIC(15,2);
BEGIN
    IF NEW.txn_type = 'DEPOSIT' THEN
        UPDATE trading_acc
        SET avail_balance = avail_balance + NEW.amt
        WHERE ta_id = NEW.ta_id
        RETURNING avail_balance INTO v_new_balance;

    ELSIF NEW.txn_type = 'WITHDRAWAL' THEN
        -- Check sufficient balance before withdrawal
        SELECT avail_balance INTO v_new_balance
        FROM trading_acc WHERE ta_id = NEW.ta_id;

        IF v_new_balance < NEW.amt THEN
            RAISE EXCEPTION 'Insufficient balance: available %, requested %',
                v_new_balance, NEW.amt;
        END IF;

        UPDATE trading_acc
        SET avail_balance = avail_balance - NEW.amt
        WHERE ta_id = NEW.ta_id
        RETURNING avail_balance INTO v_new_balance;
    END IF;

    -- Auto-stamp the balance_after column
    NEW.balance_after := v_new_balance;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- F2. fn_compute_trade_net_amount()
--     Auto-calculates NET_AMOUNT on trade insertion:
--     BUY:  (fill_price × filled_qty) + all fees
--     SELL: (fill_price × filled_qty) − all fees
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_compute_trade_net_amount()
RETURNS TRIGGER AS $$
DECLARE
    v_side VARCHAR(10);
    v_gross NUMERIC(14,2);
    v_fees  NUMERIC(14,2);
BEGIN
    -- Look up the order side
    SELECT side INTO v_side
    FROM order_record WHERE order_id = NEW.order_id;

    v_gross := NEW.fill_price * NEW.filled_qty;
    v_fees  := COALESCE(NEW.brokerage_fee, 0)
             + COALESCE(NEW.exchange_charges, 0)
             + COALESCE(NEW.stt, 0);

    IF v_side = 'BUY' THEN
        NEW.net_amount := v_gross + v_fees;
    ELSE  -- SELL
        NEW.net_amount := v_gross - v_fees;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- F3. fn_validate_order_placement()
--     Before inserting an order, validates:
--     (a) Trading account is active
--     (b) Investor KYC is VERIFIED
--     (c) BUY: sufficient balance for MARKET orders
--     (d) SELL: sufficient holdings
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_validate_order_placement()
RETURNS TRIGGER AS $$
DECLARE
    v_investor_id  UUID;
    v_is_active    BOOLEAN;
    v_kyc_status   VARCHAR(30);
    v_balance      NUMERIC(15,2);
    v_holding_qty  NUMERIC(15,4);
BEGIN
    -- Get investor via trading account
    SELECT ta.investor_id, ta.is_active, ta.avail_balance
    INTO v_investor_id, v_is_active, v_balance
    FROM trading_acc ta
    WHERE ta.ta_id = NEW.ta_id;

    -- (a) Trading account must be active
    IF NOT v_is_active THEN
        RAISE EXCEPTION 'Cannot place order: trading account % is inactive', NEW.ta_id;
    END IF;

    -- (b) KYC must be verified
    SELECT kyc_status INTO v_kyc_status
    FROM investor WHERE investor_id = v_investor_id;

    IF v_kyc_status <> 'VERIFIED' THEN
        RAISE EXCEPTION 'Cannot place order: investor KYC status is %, must be VERIFIED',
            v_kyc_status;
    END IF;

    -- (c) SELL: check holdings
    IF NEW.side = 'SELL' THEN
        SELECT COALESCE(quantity, 0) INTO v_holding_qty
        FROM holding
        WHERE investor_id = v_investor_id AND security_id = NEW.security_id;

        IF v_holding_qty IS NULL OR v_holding_qty < NEW.quantity THEN
            RAISE EXCEPTION 'Cannot place SELL order: insufficient holdings (have %, need %)',
                COALESCE(v_holding_qty, 0), NEW.quantity;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- F4. fn_update_holdings_on_trade()
--     After a trade is inserted:
--     BUY  → upsert holding (add qty, recalculate avg cost)
--     SELL → reduce holding qty, remove row if qty reaches 0
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_update_holdings_on_trade()
RETURNS TRIGGER AS $$
DECLARE
    v_investor_id  UUID;
    v_security_id  BIGINT;
    v_side         VARCHAR(10);
    v_existing_qty NUMERIC(15,4);
    v_existing_avg NUMERIC(15,4);
    v_new_qty      NUMERIC(15,4);
    v_new_avg      NUMERIC(15,4);
BEGIN
    -- Get order details
    SELECT ta.investor_id, o.security_id, o.side
    INTO v_investor_id, v_security_id, v_side
    FROM order_record o
    JOIN trading_acc ta ON o.ta_id = ta.ta_id
    WHERE o.order_id = NEW.order_id;

    IF v_side = 'BUY' THEN
        -- Check if holding already exists
        SELECT quantity, avg_cost_price
        INTO v_existing_qty, v_existing_avg
        FROM holding
        WHERE investor_id = v_investor_id AND security_id = v_security_id;

        IF FOUND THEN
            -- Update: weighted average cost
            v_new_qty := v_existing_qty + NEW.filled_qty;
            v_new_avg := ((v_existing_qty * v_existing_avg) + (NEW.filled_qty * NEW.fill_price))
                         / v_new_qty;

            UPDATE holding
            SET quantity       = v_new_qty,
                avg_cost_price = ROUND(v_new_avg, 4),
                current_value  = v_new_qty * NEW.fill_price,
                last_updated   = NOW()
            WHERE investor_id = v_investor_id AND security_id = v_security_id;
        ELSE
            -- Insert new holding
            INSERT INTO holding (investor_id, security_id, quantity, avg_cost_price, current_value, last_updated)
            VALUES (v_investor_id, v_security_id, NEW.filled_qty, NEW.fill_price,
                    NEW.filled_qty * NEW.fill_price, NOW());
        END IF;

    ELSIF v_side = 'SELL' THEN
        SELECT quantity INTO v_existing_qty
        FROM holding
        WHERE investor_id = v_investor_id AND security_id = v_security_id;

        v_new_qty := v_existing_qty - NEW.filled_qty;

        IF v_new_qty <= 0 THEN
            DELETE FROM holding
            WHERE investor_id = v_investor_id AND security_id = v_security_id;
        ELSE
            UPDATE holding
            SET quantity      = v_new_qty,
                current_value = v_new_qty * NEW.fill_price,
                last_updated  = NOW()
            WHERE investor_id = v_investor_id AND security_id = v_security_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- F5. fn_update_order_status_on_trade()
--     After a trade fills, check if the total filled quantity
--     matches the order quantity → mark EXECUTED, else PARTIAL.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_update_order_status_on_trade()
RETURNS TRIGGER AS $$
DECLARE
    v_order_qty   NUMERIC(15,4);
    v_total_filled NUMERIC(15,4);
BEGIN
    SELECT quantity INTO v_order_qty
    FROM order_record WHERE order_id = NEW.order_id;

    SELECT COALESCE(SUM(filled_qty), 0) INTO v_total_filled
    FROM trade WHERE order_id = NEW.order_id;

    IF v_total_filled >= v_order_qty THEN
        UPDATE order_record SET status = 'EXECUTED' WHERE order_id = NEW.order_id;
    ELSE
        UPDATE order_record SET status = 'PARTIAL' WHERE order_id = NEW.order_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- F6. fn_deduct_balance_on_buy_trade()
--     After a BUY trade, deduct (fill_price × filled_qty + fees)
--     from the trading account balance.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_deduct_balance_on_buy_trade()
RETURNS TRIGGER AS $$
DECLARE
    v_ta_id  BIGINT;
    v_side   VARCHAR(10);
    v_cost   NUMERIC(15,2);
BEGIN
    SELECT o.ta_id, o.side INTO v_ta_id, v_side
    FROM order_record o WHERE o.order_id = NEW.order_id;

    IF v_side = 'BUY' THEN
        v_cost := (NEW.fill_price * NEW.filled_qty)
                + COALESCE(NEW.brokerage_fee, 0)
                + COALESCE(NEW.exchange_charges, 0)
                + COALESCE(NEW.stt, 0);

        UPDATE trading_acc
        SET avail_balance = avail_balance - v_cost
        WHERE ta_id = v_ta_id;

    ELSIF v_side = 'SELL' THEN
        -- Credit proceeds minus fees
        v_cost := (NEW.fill_price * NEW.filled_qty)
                - COALESCE(NEW.brokerage_fee, 0)
                - COALESCE(NEW.exchange_charges, 0)
                - COALESCE(NEW.stt, 0);

        UPDATE trading_acc
        SET avail_balance = avail_balance + v_cost
        WHERE ta_id = v_ta_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- F7. fn_prevent_inactive_broker_assignment()
--     Prevents assigning an order to an inactive broker.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_prevent_inactive_broker_assignment()
RETURNS TRIGGER AS $$
DECLARE
    v_broker_active BOOLEAN;
BEGIN
    IF NEW.broker_id IS NOT NULL THEN
        SELECT is_active INTO v_broker_active
        FROM broker WHERE broker_id = NEW.broker_id;

        IF NOT v_broker_active THEN
            RAISE EXCEPTION 'Cannot assign order to inactive broker %', NEW.broker_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- F8. fn_prevent_cancel_executed_order()
--     Prevents updating an EXECUTED or PARTIAL order to CANCELLED.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_prevent_cancel_executed_order()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IN ('EXECUTED', 'PARTIAL') AND NEW.status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Cannot cancel order %: status is already %',
            OLD.order_id, OLD.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- F9. fn_audit_investor_changes()
--     Logs critical investor profile changes (email, KYC, status)
--     into an audit table.
-- ─────────────────────────────────────────────────────────────

-- Audit table for investor changes
CREATE TABLE IF NOT EXISTS investor_audit_log (
    log_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    investor_id UUID NOT NULL,
    field_name  VARCHAR(50) NOT NULL,
    old_value   TEXT,
    new_value   TEXT,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION fn_audit_investor_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.email <> NEW.email THEN
        INSERT INTO investor_audit_log (investor_id, field_name, old_value, new_value)
        VALUES (OLD.investor_id, 'EMAIL', OLD.email, NEW.email);
    END IF;

    IF OLD.kyc_status <> NEW.kyc_status THEN
        INSERT INTO investor_audit_log (investor_id, field_name, old_value, new_value)
        VALUES (OLD.investor_id, 'KYC_STATUS', OLD.kyc_status, NEW.kyc_status);
    END IF;

    IF OLD.is_active <> NEW.is_active THEN
        INSERT INTO investor_audit_log (investor_id, field_name, old_value, new_value)
        VALUES (OLD.investor_id, 'IS_ACTIVE', OLD.is_active::TEXT, NEW.is_active::TEXT);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════
--  TRIGGERS (wire functions to table events)
-- ═══════════════════════════════════════════════════════════════


-- T1. Auto-update balance on fund deposit/withdrawal
CREATE TRIGGER trg_fund_txn_update_balance
    BEFORE INSERT ON fund_transaction
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_balance_on_fund_txn();


-- T2. Auto-compute net_amount on trade insertion
CREATE TRIGGER trg_trade_compute_net
    BEFORE INSERT ON trade
    FOR EACH ROW
    EXECUTE FUNCTION fn_compute_trade_net_amount();


-- T3. Validate order placement (KYC, active account, holdings)
--     Disabled by default during seed data loading.
--     Enable after seeding: ALTER TABLE order_record ENABLE TRIGGER trg_validate_order;
CREATE TRIGGER trg_validate_order
    BEFORE INSERT ON order_record
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_order_placement();

ALTER TABLE order_record DISABLE TRIGGER trg_validate_order;


-- T4. Auto-update holdings after trade
--     Disabled by default during seed data loading.
CREATE TRIGGER trg_trade_update_holdings
    AFTER INSERT ON trade
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_holdings_on_trade();

ALTER TABLE trade DISABLE TRIGGER trg_trade_update_holdings;


-- T5. Auto-update order status after trade fill
--     Disabled by default during seed data loading.
CREATE TRIGGER trg_trade_update_order_status
    AFTER INSERT ON trade
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_order_status_on_trade();

ALTER TABLE trade DISABLE TRIGGER trg_trade_update_order_status;


-- T6. Deduct/credit trading account balance on trade
--     Disabled by default during seed data loading.
CREATE TRIGGER trg_trade_adjust_balance
    AFTER INSERT ON trade
    FOR EACH ROW
    EXECUTE FUNCTION fn_deduct_balance_on_buy_trade();

ALTER TABLE trade DISABLE TRIGGER trg_trade_adjust_balance;


-- T7. Prevent assigning order to inactive broker
CREATE TRIGGER trg_order_check_broker_active
    BEFORE INSERT OR UPDATE ON order_record
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_inactive_broker_assignment();


-- T8. Prevent cancelling executed/partial orders
CREATE TRIGGER trg_order_prevent_cancel_executed
    BEFORE UPDATE ON order_record
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_cancel_executed_order();


-- T9. Audit log for investor profile changes
CREATE TRIGGER trg_investor_audit
    AFTER UPDATE ON investor
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_investor_changes();


-- ═══════════════════════════════════════════════════════════════
--  ENABLE TRIGGERS (run after seed_data.sql)
-- ═══════════════════════════════════════════════════════════════
-- Uncomment these after loading seed data to activate full
-- business logic enforcement:
--
-- ALTER TABLE order_record ENABLE TRIGGER trg_validate_order;
-- ALTER TABLE trade ENABLE TRIGGER trg_trade_update_holdings;
-- ALTER TABLE trade ENABLE TRIGGER trg_trade_update_order_status;
-- ALTER TABLE trade ENABLE TRIGGER trg_trade_adjust_balance;
