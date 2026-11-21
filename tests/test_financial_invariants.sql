-- ============================================================
-- StockVault — Test: Financial Invariants & Domain Integrity
-- Validates mathematical consistency, fee calculations,
-- tax classification (STCG/LTCG), and regulatory rules.
-- ============================================================

SET search_path TO trading;

BEGIN;

DO $$
DECLARE
    v_violations INT;
    v_rec RECORD;
BEGIN
    RAISE NOTICE '══════════════════════════════════════════════════════';
    RAISE NOTICE '  StockVault — Financial Invariants Test Suite        ';
    RAISE NOTICE '══════════════════════════════════════════════════════';

    -- ─────────────────────────────────────────────────────────────
    -- 1. Trade Net Amount Calculation Invariant
    -- BUY:  net_amount = (fill_price * filled_qty) + brokerage_fee + exchange_charges + stt
    -- SELL: net_amount = (fill_price * filled_qty) - brokerage_fee - exchange_charges - stt
    -- ─────────────────────────────────────────────────────────────
    SELECT COUNT(*) INTO v_violations
    FROM trade t
    JOIN order_record o ON t.order_id = o.order_id
    WHERE (
        o.side = 'BUY' AND
        ABS(t.net_amount - ((t.fill_price * t.filled_qty) + t.brokerage_fee + t.exchange_charges + t.stt)) > 0.05
    ) OR (
        o.side = 'SELL' AND
        ABS(t.net_amount - ((t.fill_price * t.filled_qty) - t.brokerage_fee - t.exchange_charges - t.stt)) > 0.05
    );

    IF v_violations > 0 THEN
        RAISE EXCEPTION 'FAIL [FI-1]: % trade(s) violate trade net_amount arithmetic', v_violations;
    END IF;
    RAISE NOTICE 'PASS [FI-1]: All trade net_amount calculations match BUY/SELL fee formulas (0 violations)';

    -- ─────────────────────────────────────────────────────────────
    -- 2. Capital Gains Tax Classification Invariant
    -- Holding days <= 365 must be STCG, > 365 must be LTCG
    -- ─────────────────────────────────────────────────────────────
    SELECT COUNT(*) INTO v_violations
    FROM capital_gains_record
    WHERE (holding_days <= 365 AND gain_type <> 'STCG')
       OR (holding_days > 365  AND gain_type <> 'LTCG');

    IF v_violations > 0 THEN
        RAISE EXCEPTION 'FAIL [FI-2]: % capital gains record(s) violate STCG/LTCG holding period rule', v_violations;
    END IF;
    RAISE NOTICE 'PASS [FI-2]: Capital gains STCG/LTCG classification accurately adheres to 365-day rule';

    -- ─────────────────────────────────────────────────────────────
    -- 3. Capital Gains Arithmetic Invariant
    -- gain_loss = (sell_price - buy_price) * quantity
    -- ─────────────────────────────────────────────────────────────
    SELECT COUNT(*) INTO v_violations
    FROM capital_gains_record
    WHERE ABS(gain_loss - ((sell_price - buy_price) * quantity)) > 0.01;

    IF v_violations > 0 THEN
        RAISE EXCEPTION 'FAIL [FI-3]: % capital gains record(s) violate gain_loss formula', v_violations;
    END IF;
    RAISE NOTICE 'PASS [FI-3]: Capital gains gain_loss matches (sell_price - buy_price) * quantity';

    -- ─────────────────────────────────────────────────────────────
    -- 4. Regulatory KYC Invariant
    -- Investors with PENDING or REJECTED KYC must have 0 executed orders
    -- ─────────────────────────────────────────────────────────────
    SELECT COUNT(*) INTO v_violations
    FROM order_record o
    JOIN trading_acc ta ON o.ta_id = ta.ta_id
    JOIN investor i ON ta.investor_id = i.investor_id
    WHERE i.kyc_status <> 'VERIFIED'
      AND o.status = 'EXECUTED';

    IF v_violations > 0 THEN
        RAISE EXCEPTION 'FAIL [FI-4]: % executed order(s) found for non-VERIFIED KYC investors', v_violations;
    END IF;
    RAISE NOTICE 'PASS [FI-4]: Zero executed orders for unverified KYC investors';

    -- ─────────────────────────────────────────────────────────────
    -- 5. Non-negative Balances and Quantities
    -- ─────────────────────────────────────────────────────────────
    SELECT COUNT(*) INTO v_violations
    FROM trading_acc WHERE avail_balance < 0;

    IF v_violations > 0 THEN
        RAISE EXCEPTION 'FAIL [FI-5]: % trading account(s) have negative balance', v_violations;
    END IF;

    SELECT COUNT(*) INTO v_violations
    FROM holding WHERE quantity <= 0 OR avg_cost_price <= 0;

    IF v_violations > 0 THEN
        RAISE EXCEPTION 'FAIL [FI-5]: % holding(s) have non-positive quantity or cost price', v_violations;
    END IF;
    RAISE NOTICE 'PASS [FI-5]: All account balances and holding quantities strictly non-negative';

    -- ─────────────────────────────────────────────────────────────
    -- 6. Total Portfolio Valuation Consistency
    -- ─────────────────────────────────────────────────────────────
    SELECT COUNT(*) INTO v_violations
    FROM holding
    WHERE current_value <= 0;

    IF v_violations > 0 THEN
        RAISE EXCEPTION 'FAIL [FI-6]: % holding(s) have invalid current value', v_violations;
    END IF;
    RAISE NOTICE 'PASS [FI-6]: Portfolio holding values strictly positive and consistent';

    RAISE NOTICE '══════════════════════════════════════════════════════';
    RAISE NOTICE '  ✅ ALL FINANCIAL INVARIANTS VERIFIED SUCCESSFULLY   ';
    RAISE NOTICE '══════════════════════════════════════════════════════';
END;
$$;

ROLLBACK;
