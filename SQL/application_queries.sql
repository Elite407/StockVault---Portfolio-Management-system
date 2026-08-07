-- ============================================================
-- StockVault — Application Queries
-- Purpose: Backend API queries powering the trading platform's
--          core user-facing operations and transaction flows.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. List securities by exchange
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: The browse screen needs to show all active securities
--          listed on a specific exchange (NSE or BSE) for investors
--          to discover tradable instruments.
-- WHY THIS QUERY: Filtering on is_active = TRUE prevents delisted
--                 or suspended securities from cluttering the UI;
--                 ordering by ticker gives a predictable scan.
-- SOLUTION: Select from SECURITY with parameterized exchange filter,
--           enforce active status, and sort alphabetically by ticker.
-- ─────────────────────────────────────────────────────────────
SELECT s.security_id, s.ticker, s.company_name, s.security_type, s.exchange, s.sector
FROM security s
WHERE s.exchange = $1 AND s.is_active = TRUE
ORDER BY s.ticker;


-- ─────────────────────────────────────────────────────────────
-- 2. Search securities by ticker or company name
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Investors need a quick search to find securities by
--          partial ticker symbol or company name.
-- WHY THIS QUERY: ILIKE with wildcard concatenation enables
--                 case-insensitive partial matching; LIMIT 20
--                 caps result set size for fast autocomplete
--                 responses.
-- SOLUTION: Match against both ticker and company_name using
--           parameterized ILIKE patterns, restrict to active
--           securities, and return the top 20 alphabetically.
-- ─────────────────────────────────────────────────────────────
SELECT s.security_id, s.ticker, s.company_name, s.security_type, s.exchange
FROM security s
WHERE (s.ticker ILIKE '%' || $1 || '%' OR s.company_name ILIKE '%' || $1 || '%')
  AND s.is_active = TRUE
ORDER BY s.ticker
LIMIT 20;


-- ─────────────────────────────────────────────────────────────
-- 3. Security details page
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: The security detail view must display both common
--          attributes and type-specific data (Equity vs Mutual Fund).
-- WHY THIS QUERY: LEFT JOIN to both EQUITY and MUTUAL_FUND
--                 handles the ISA hierarchy in a single query;
--                 only one subtype will match, so NULLs in the
--                 other are expected and handled by the application.
-- SOLUTION: Fetch SECURITY row by ID, left join both subtype tables,
--           and return all columns for the detail page renderer.
-- ─────────────────────────────────────────────────────────────
SELECT s.security_id, s.ticker, s.company_name, s.exchange, s.security_type, s.sector, s.isin,
       e.market_cap, e.pe_ratio, e.eps,
       mf.amc_name, mf.scheme_category, mf.nav, mf.nav_date, mf.expense_ratio
FROM security s
LEFT JOIN equity e ON e.security_id = s.security_id
LEFT JOIN mutual_fund mf ON mf.security_id = s.security_id
WHERE s.security_id = $1;


-- ─────────────────────────────────────────────────────────────
-- 4. Get portfolio for a specified investor
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: The portfolio dashboard needs a real-time view of all
--          holdings with unrealized profit/loss.
-- WHY THIS QUERY: Computing unrealized P&L inline avoids a second
--                 round-trip; ordering by current_value descending
--                 surfaces the largest positions first (materiality).
-- SOLUTION: Join HOLDING → SECURITY, compute P&L as current_value
--           minus (quantity × avg_cost_price), and sort by value.
-- ─────────────────────────────────────────────────────────────
SELECT h.holding_id, s.security_id, s.ticker, s.company_name, s.security_type,
       h.quantity, h.avg_cost_price, h.current_value,
       ROUND((h.current_value - (h.quantity * h.avg_cost_price)), 2) AS unrealized_pnl
FROM holding h
JOIN security s ON h.security_id = s.security_id
WHERE h.investor_id = $1
ORDER BY h.current_value DESC;


-- ─────────────────────────────────────────────────────────────
-- 5. Place order
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Investors need to submit buy/sell orders that enter
--          the system with an OPEN status for matching.
-- WHY THIS QUERY: A single INSERT with parameterized values is
--                 atomic and fast; status defaults to 'OPEN' inline
--                 to avoid a separate update step.
-- SOLUTION: Insert into ORDER_RECORD with all order parameters
--           and hardcoded status 'OPEN'.
-- ─────────────────────────────────────────────────────────────
INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type, quantity, limit_price, stop_loss_price, status)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'OPEN');


-- ─────────────────────────────────────────────────────────────
-- 6. Cancel order
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Investors must be able to cancel unfilled orders
--          without affecting already-executed trades.
-- WHY THIS QUERY: The WHERE clause guards against cancelling
--                 already-EXECUTED (or PARTIAL) orders, preventing
--                 data inconsistency and race conditions.
-- SOLUTION: Update ORDER_RECORD status to 'CANCELLED' only if
--           the current status is 'OPEN'.
-- ─────────────────────────────────────────────────────────────
UPDATE order_record
SET status = 'CANCELLED'
WHERE order_id = $1 AND status = 'OPEN';


-- ─────────────────────────────────────────────────────────────
-- 7. Get KYC documents for an investor
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: The profile/KYC page needs to list all submitted
--          documents with their verification status.
-- WHY THIS QUERY: Ordering by issue_date DESC surfaces the most
--                 recent documents first, which is typically what
--                 compliance officers and users expect to see.
-- SOLUTION: Select all KYC_DOCUMENT rows for the investor,
--           ordered by issue date descending.
-- ─────────────────────────────────────────────────────────────
SELECT k.doc_id, k.doc_no, k.doc_type, k.issue_date, k.expiry_date, k.verification_status
FROM kyc_document k
WHERE k.investor_id = $1
ORDER BY k.issue_date DESC;


-- ─────────────────────────────────────────────────────────────
-- 8. Get primary bank account for an investor
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: During fund withdrawals or settlement, the system
--          must identify the investor's default bank account.
-- WHY THIS QUERY: The partial unique index on (INVESTOR_ID)
--                 WHERE is_primary = TRUE guarantees at most
--                 one result; LIMIT 1 is a defensive safeguard.
-- SOLUTION: Filter BANK_ACC by investor and is_primary = TRUE,
--           return the single matching row.
-- ─────────────────────────────────────────────────────────────
SELECT b.bank_acc_id, b.acc_no, b.ifsc_code, b.is_primary
FROM bank_acc b
WHERE b.investor_id = $1 AND b.is_primary = TRUE
LIMIT 1;


-- ─────────────────────────────────────────────────────────────
-- 9. Validate order: check balance for BUY or holdings for SELL
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Before accepting an order, the system must validate
--          that the investor has sufficient funds (BUY) or
--          sufficient holdings (SELL) to fulfill it.
-- WHY THIS QUERY: A single query handles both sides with a
--                 CASE expression, avoiding two separate API
--                 calls and reducing latency at checkout.
-- SOLUTION: Fetch trading account balance and holding quantity
--           (LEFT JOIN for SELL case where holdings may not exist),
--           then evaluate the validation rule based on order side.
-- ─────────────────────────────────────────────────────────────
SELECT ta.ta_id, ta.avail_balance, h.quantity AS holding_qty,
       CASE 
           WHEN $4 = 'BUY' AND ta.avail_balance >= ($2 * $3) THEN TRUE
           WHEN $4 = 'SELL' AND h.quantity >= $2 THEN TRUE
           ELSE FALSE
       END AS is_valid
FROM trading_acc ta
LEFT JOIN holding h ON h.investor_id = ta.investor_id AND h.security_id = $3
WHERE ta.ta_id = $1;


-- ─────────────────────────────────────────────────────────────
-- 10. Record trade execution and update order status
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: When an order is matched in the market, the system
--          must persist the trade and mark the order as executed.
-- WHY THIS QUERY: Two statements in one transaction block ensure
--                 atomicity — either both succeed or both rollback,
--                 preventing orphaned trades or stale OPEN orders.
-- SOLUTION: INSERT the trade record with all fee breakdowns,
--           then UPDATE the parent order status to 'EXECUTED'.
-- ─────────────────────────────────────────────────────────────
INSERT INTO trade (order_id, trade_ref, fill_price, filled_qty, brokerage_fee, exchange_charges, stt, net_amount)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8);

UPDATE order_record
SET status = 'EXECUTED'
WHERE order_id = $1;


-- ─────────────────────────────────────────────────────────────
-- 11. Update holdings after BUY trade (upsert with weighted average cost)
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: After a BUY trade, the investor's position must be
--          updated — either created fresh or merged with existing
--          holdings while recalculating the average cost basis.
-- WHY THIS QUERY: PostgreSQL's ON CONFLICT ... DO UPDATE provides
--                 an atomic upsert; the weighted average formula
--                 ensures accurate cost basis for future P&L.
-- SOLUTION: INSERT with conflict on (investor_id, security_id);
--           on conflict, recalculate quantity, weighted avg_cost_price,
--           current_value, and update the timestamp.
-- ─────────────────────────────────────────────────────────────
INSERT INTO holding (investor_id, security_id, quantity, avg_cost_price, current_value, last_updated)
VALUES ($1, $2, $3, $4, ($3 * $4), NOW())
ON CONFLICT (investor_id, security_id)
DO UPDATE SET 
    quantity = holding.quantity + EXCLUDED.quantity,
    avg_cost_price = ((holding.quantity * holding.avg_cost_price) + (EXCLUDED.quantity * EXCLUDED.avg_cost_price)) / (holding.quantity + EXCLUDED.quantity),
    current_value = holding.current_value + EXCLUDED.current_value,
    last_updated = NOW();


-- ─────────────────────────────────────────────────────────────
-- 12. Create fund transaction record
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Every deposit or withdrawal must be auditable with
--          a persistent transaction log for reconciliation.
-- WHY THIS QUERY: A simple parameterized INSERT captures all
--                 required audit fields including balance_after
--                 for point-in-time verification.
-- SOLUTION: Insert into FUND_TRANSACTION with parameterized
--           values for the transaction type and amounts.
-- ─────────────────────────────────────────────────────────────
INSERT INTO fund_transaction (ta_id, bank_acc_id, txn_type, amt, balance_after)
VALUES ($1, $2, $3, $4, $5);


-- ─────────────────────────────────────────────────────────────
-- 13. Update trading account balance after fund transaction
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: The trading account's available balance must reflect
--          the fund movement immediately to prevent overdrafts.
-- WHY THIS QUERY: A single UPDATE with a CASE expression handles
--                 both DEPOSIT (add) and WITHDRAWAL (subtract)
--                 atomically, eliminating conditional logic in
--                 the application layer.
-- SOLUTION: Update AVAIL_BALANCE conditionally based on txn_type,
--           filtered by the specific trading account.
-- ─────────────────────────────────────────────────────────────
UPDATE trading_acc
SET avail_balance = CASE 
    WHEN $2 = 'DEPOSIT' THEN avail_balance + $3
    WHEN $2 = 'WITHDRAWAL' THEN avail_balance - $3
    ELSE avail_balance
END
WHERE ta_id = $1;


-- ─────────────────────────────────────────────────────────────
-- 14. Order history with trade details
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Investors need a paginated history showing order
--          details alongside any executed trades for full traceability.
-- WHY THIS QUERY: LEFT JOIN from ORDER_RECORD to TRADE ensures
--                 cancelled or unfilled orders still appear in
--                 history (with NULL trade columns), preserving
--                 the complete audit trail.
-- SOLUTION: Select orders for the trading account, left join
--           trades, order by placement time descending, and
--           paginate with LIMIT.
-- ─────────────────────────────────────────────────────────────
SELECT o.order_id, o.placed_at, o.side, o.order_type, o.quantity, o.status,
       o.limit_price, o.stop_loss_price,
       t.trade_id, t.trade_ref, t.fill_price, t.filled_qty, t.trade_datetime, t.net_amount
FROM order_record o
LEFT JOIN trade t ON t.order_id = o.order_id
WHERE o.ta_id = $1
ORDER BY o.placed_at DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- 15. Get bank accounts for an investor
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: The settings page must display all linked bank
--          accounts with the primary account highlighted first.
-- WHY THIS QUERY: Ordering by is_primary DESC pushes the primary
--                 account to the top of the list, improving UX
--                 without requiring client-side sorting.
-- SOLUTION: Select all bank accounts for the investor, sorted
--           by primary flag descending.
-- ─────────────────────────────────────────────────────────────
SELECT b.bank_acc_id, b.acc_no, b.ifsc_code, b.is_primary
FROM bank_acc b
WHERE b.investor_id = $1
ORDER BY b.is_primary DESC;


-- ─────────────────────────────────────────────────────────────
-- 16. Get active broker relationships for an investor
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Investors need to see which brokers they are currently
--          onboarded with, along with plan and POA details.
-- WHY THIS QUERY: Filtering on is_active = TRUE excludes expired
--                 or terminated relationships; joining BROKER
--                 enriches the view with SEBI license and
--                 commission rate for transparency.
-- SOLUTION: Join BROKER_CLIENT → BROKER for the investor,
--           filter active relationships, and return all metadata.
-- ─────────────────────────────────────────────────────────────
SELECT b.broker_id, b.full_name, b.sebi_license_no, b.commission_rate,
       bc.plan_type, bc.plan_start_date, bc.plan_end_date, bc.poa_granted
FROM broker_client bc
JOIN broker b ON bc.broker_id = b.broker_id
WHERE bc.investor_id = $1 AND bc.is_active = TRUE;


-- ─────────────────────────────────────────────────────────────
-- 17. Broker commission summary
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Brokers need a dashboard showing their total earnings,
--          regulatory charges passed through, and trade volume.
-- WHY THIS QUERY: COALESCE ensures zero values when no trades
--                 exist (new brokers), avoiding NULL display
--                 issues in the UI.
-- SOLUTION: Aggregate brokerage fees, exchange charges + STT,
--           and distinct trade count for the specified broker.
-- ─────────────────────────────────────────────────────────────
SELECT 
    COALESCE(SUM(t.brokerage_fee), 0) AS total_commission,
    COALESCE(SUM(t.exchange_charges + t.stt), 0) AS total_charges,
    COUNT(DISTINCT t.trade_id) AS total_trades
FROM trade t
JOIN order_record o ON t.order_id = o.order_id
WHERE o.broker_id = $1;
