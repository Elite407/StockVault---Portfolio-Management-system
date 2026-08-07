-- ============================================================
-- StockVault — Analytical Queries
-- Purpose: Business intelligence, compliance monitoring, and
--          operational analytics for the trading platform.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. Broker revenue in last 3 months
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Management needs to rank brokers by their total fee
--          revenue to evaluate performance and allocate leads.
-- WHY THIS QUERY: A LEFT JOIN from BROKER ensures zero-revenue
--                 brokers still appear (important for attrition
--                 risk), and COALESCE prevents NULL aggregation.
-- SOLUTION: Join BROKER → ORDER_RECORD (EXECUTED only) → TRADE,
--           filter trades to the last 3 months, sum all fee
--           components, and order descending by revenue.
-- ─────────────────────────────────────────────────────────────
SELECT b.broker_id, b.full_name, b.sebi_license_no,
       COALESCE(SUM(t.brokerage_fee + t.exchange_charges + t.stt), 0) AS total_revenue
FROM broker b
LEFT JOIN order_record o ON o.broker_id = b.broker_id
    AND o.status = 'EXECUTED'
LEFT JOIN trade t ON t.order_id = o.order_id
    AND t.trade_datetime >= NOW() - INTERVAL '3 months'
GROUP BY b.broker_id, b.full_name, b.sebi_license_no
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────────────────────
-- 2. Top 10 most traded securities in last 30 days
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Identify which securities are seeing the highest
--          trading volume to inform liquidity and marketing.
-- WHY THIS QUERY: LEFT JOIN from SECURITY ensures even inactive
--                 or newly listed securities appear with 0 volume,
--                 avoiding silent exclusion bias.
-- SOLUTION: Aggregate filled_qty from TRADE via ORDER_RECORD,
--           restrict to the last 30 days, group by security,
--           and take the top 10 by total quantity traded.
-- ─────────────────────────────────────────────────────────────
SELECT s.security_id, s.ticker, s.company_name, s.security_type,
       COALESCE(SUM(t.filled_qty), 0) AS total_qty_traded
FROM security s
LEFT JOIN order_record o ON o.security_id = s.security_id
    AND o.status = 'EXECUTED'
LEFT JOIN trade t ON t.order_id = o.order_id
    AND t.trade_datetime >= NOW() - INTERVAL '1 month'
GROUP BY s.security_id, s.ticker, s.company_name, s.security_type
ORDER BY total_qty_traded DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- 3. Monthly trade count and revenue per broker
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Finance needs a month-over-month revenue breakdown
--          per broker for commission reconciliation.
-- WHY THIS QUERY: DATE_TRUNC collapses timestamps to month
--                 boundaries, making time-series aggregation
--                 clean and index-friendly in PostgreSQL.
-- SOLUTION: Truncate trade_datetime to month, count distinct
--           trades, sum all revenue components, and group by
--           broker + month for trend analysis.
-- ─────────────────────────────────────────────────────────────
SELECT b.broker_id, b.full_name,
       DATE_TRUNC('month', t.trade_datetime) AS month,
       COUNT(DISTINCT t.trade_id) AS total_trades,
       COALESCE(SUM(t.brokerage_fee + t.exchange_charges + t.stt), 0) AS revenue
FROM broker b
LEFT JOIN order_record o ON o.broker_id = b.broker_id
    AND o.status = 'EXECUTED'
LEFT JOIN trade t ON t.order_id = o.order_id
GROUP BY b.broker_id, b.full_name, month
ORDER BY revenue DESC;


-- ─────────────────────────────────────────────────────────────
-- 4. Investors who haven't placed an order in last 30 days
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Detect dormant investors for re-engagement campaigns
--          and churn-risk flagging.
-- WHY THIS QUERY: HAVING filters on an aggregate (MAX placed_at)
--                 after grouping, which is more efficient than
--                 a subquery for this pattern.
-- SOLUTION: Join INVESTOR → TRADING_ACC → ORDER_RECORD, group
--           by investor, and keep only those whose most recent
--           order is older than 30 days.
-- ─────────────────────────────────────────────────────────────
SELECT i.investor_id, i.full_name, i.email, i.pan_no,
       MAX(o.placed_at) AS last_order_date
FROM investor i
JOIN trading_acc ta ON ta.investor_id = i.investor_id
JOIN order_record o ON o.ta_id = ta.ta_id
GROUP BY i.investor_id, i.full_name, i.email, i.pan_no
HAVING MAX(o.placed_at) < CURRENT_DATE - INTERVAL '30 days';


-- ─────────────────────────────────────────────────────────────
-- 5. Average trade value per broker
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Benchmark brokers by the average monetary size of
--          trades they execute (indicates client quality).
-- WHY THIS QUERY: AVG on net_amount directly measures trade
--                 size; LEFT JOIN preserves brokers with no
--                 trades so the report is complete.
-- SOLUTION: Compute the mean of net_amount per broker across
--           all executed trades, rounded to 2 decimals.
-- ─────────────────────────────────────────────────────────────
SELECT b.broker_id, b.full_name,
       ROUND(AVG(t.net_amount), 2) AS avg_trade_value
FROM broker b
LEFT JOIN order_record o ON o.broker_id = b.broker_id
    AND o.status = 'EXECUTED'
LEFT JOIN trade t ON t.order_id = o.order_id
GROUP BY b.broker_id, b.full_name
ORDER BY avg_trade_value DESC;


-- ─────────────────────────────────────────────────────────────
-- 6. Top 10 brokers by commission and avg execution time
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Identify high-earning brokers while monitoring
--          whether high commission correlates with slow
--          execution (SLA risk).
-- WHY THIS QUERY: EXTRACT(EPOCH FROM ...) converts interval
--                 to seconds for precise arithmetic; dividing
--                 by 60 gives minutes, a business-meaningful
--                 unit for operations dashboards.
-- SOLUTION: Sum brokerage_fee for total commission, compute
--           the average time delta between order placement
--           and trade execution, and rank by commission.
-- ─────────────────────────────────────────────────────────────
SELECT b.broker_id, b.full_name,
       COALESCE(SUM(t.brokerage_fee), 0) AS total_commission,
       ROUND(AVG(EXTRACT(EPOCH FROM (t.trade_datetime - o.placed_at))) / 60, 1) AS avg_execution_minutes
FROM broker b
LEFT JOIN order_record o ON o.broker_id = b.broker_id
LEFT JOIN trade t ON t.order_id = o.order_id
WHERE o.status = 'EXECUTED'
GROUP BY b.broker_id, b.full_name
ORDER BY total_commission DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- 7. KYC documents expiring within 30 days
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Compliance team needs advance notice of expiring
--          KYC documents to prevent trading lockouts.
-- WHY THIS QUERY: The BETWEEN range on CURRENT_DATE is
--                 sargable (index-friendly) and exactly matches
--                 the 30-day compliance window.
-- SOLUTION: Filter KYC_DOCUMENT where expiry falls within the
--           next 30 days and status is VERIFIED, then join
--           INVESTOR to get contact details for outreach.
-- ─────────────────────────────────────────────────────────────
SELECT i.investor_id, i.full_name, k.doc_no, k.doc_type,
       k.issue_date, k.expiry_date
FROM kyc_document k
JOIN investor i ON k.investor_id = i.investor_id
WHERE k.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
  AND k.verification_status = 'VERIFIED'
ORDER BY k.expiry_date;


-- ─────────────────────────────────────────────────────────────
-- 8. Investors who completed KYC but never placed an order
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Measure onboarding funnel leakage — how many
--          verified investors never became active traders.
-- WHY THIS QUERY: NOT EXISTS with a correlated subquery is
--                 semantically precise ("no matching row")
--                 and often outperforms LEFT JOIN + IS NULL
--                 when the anti-join set is large.
-- SOLUTION: Select verified investors where no trading account
--           linked to them has any associated order record.
-- ─────────────────────────────────────────────────────────────
SELECT i.investor_id, i.full_name, i.email, i.kyc_status, i.created_at
FROM investor i
WHERE i.kyc_status = 'VERIFIED'
  AND NOT EXISTS (
      SELECT 1 FROM trading_acc ta
      JOIN order_record o ON o.ta_id = ta.ta_id
      WHERE ta.investor_id = i.investor_id
  )
ORDER BY i.created_at;


-- ─────────────────────────────────────────────────────────────
-- 9. Average execution time per broker
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Operations needs to monitor execution latency per
--          broker to enforce SLA thresholds.
-- WHY THIS QUERY: INNER JOIN is used here (not LEFT) because
--                 only brokers with actual executed trades
--                 have meaningful latency data to report.
-- SOLUTION: Compute the average minutes between order
--           placement and trade execution per broker.
-- ─────────────────────────────────────────────────────────────
SELECT b.broker_id, b.full_name,
       ROUND(AVG(EXTRACT(EPOCH FROM (t.trade_datetime - o.placed_at)) / 60), 1) AS avg_execution_minutes
FROM broker b
JOIN order_record o ON o.broker_id = b.broker_id
JOIN trade t ON t.order_id = o.order_id
WHERE o.status = 'EXECUTED'
GROUP BY b.broker_id, b.full_name
ORDER BY avg_execution_minutes;


-- ─────────────────────────────────────────────────────────────
-- 10. Plan subscription to trade conversion rate
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Product team wants to know which brokerage plans
--          actually drive trading activity vs. passive signups.
-- WHY THIS QUERY: NULLIF in the denominator prevents division
--                 by zero for plans with zero subscriptions;
--                 the CASE inside COUNT(DISTINCT) filters
--                 executed orders accurately at the row level.
-- SOLUTION: Count total plan subscriptions and executed orders
--           per plan, then compute the conversion percentage.
-- ─────────────────────────────────────────────────────────────
SELECT pc.plan_type, pc.brokerage_percent,
       COUNT(DISTINCT bc.bc_id) AS total_subscriptions,
       COUNT(DISTINCT o.order_id) AS orders_executed,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN o.status = 'EXECUTED' THEN o.order_id END) / NULLIF(COUNT(DISTINCT bc.bc_id), 0), 2) AS conversion_pct
FROM plan_catalog pc
LEFT JOIN broker_client bc ON bc.plan_type = pc.plan_type
LEFT JOIN trading_acc ta ON ta.investor_id = bc.investor_id
LEFT JOIN order_record o ON o.ta_id = ta.ta_id AND o.broker_id = bc.broker_id
GROUP BY pc.plan_type, pc.brokerage_percent
ORDER BY conversion_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- 11. Order cancellation rate by order type
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Identify which order types (MARKET, LIMIT, SL, SL-M)
--          suffer the highest cancellation rates.
-- WHY THIS QUERY: Conditional aggregation (SUM CASE WHEN) is
--                 more efficient than multiple subqueries or
--                 self-joins for computing ratios in one pass.
-- SOLUTION: Group by order_type, count total orders, count
--           executed and cancelled separately, then compute
--           the cancellation rate as a percentage.
-- ─────────────────────────────────────────────────────────────
SELECT order_type,
       COUNT(*) AS total_orders,
       SUM(CASE WHEN status = 'EXECUTED' THEN 1 ELSE 0 END) AS executed,
       SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled,
       ROUND(100.0 * SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_rate_pct
FROM order_record
GROUP BY order_type
ORDER BY cancellation_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- 12. Stale open orders pending for more than 7 days
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Find orphaned or forgotten open orders that may
--          need manual intervention or auto-cancellation.
-- WHY THIS QUERY: Filtering on placed_at < CURRENT_DATE - 7
--                 days is a simple, index-friendly range scan
--                 on a high-cardinality timestamp column.
-- SOLUTION: Select OPEN orders older than 7 days, join
--           INVESTOR and SECURITY for context, and sort
--           by age to prioritize the oldest first.
-- ─────────────────────────────────────────────────────────────
SELECT o.order_id, i.full_name, s.ticker, o.side, o.order_type,
       o.quantity, o.placed_at
FROM order_record o
JOIN trading_acc ta ON o.ta_id = ta.ta_id
JOIN investor i ON ta.investor_id = i.investor_id
JOIN security s ON o.security_id = s.security_id
WHERE o.status = 'OPEN'
  AND o.placed_at < CURRENT_DATE - INTERVAL '7 days'
ORDER BY o.placed_at;


-- ─────────────────────────────────────────────────────────────
-- 13. Orders handled per broker
-- ─────────────────────────────────────────────────────────────
-- PROBLEM: Measure broker efficiency by comparing how many
--          orders they receive vs. how many actually execute.
-- WHY THIS QUERY: The ratio COUNT(trades) / COUNT(orders)
--                 gives an execution_rate; ::NUMERIC cast
--                 ensures floating-point division in PostgreSQL.
-- SOLUTION: Count distinct orders and trades per broker,
--           compute the execution rate, and order descending
--           to surface the most efficient brokers.
-- ─────────────────────────────────────────────────────────────
SELECT b.broker_id, b.full_name,
       COUNT(DISTINCT o.order_id) AS order_count,
       COUNT(DISTINCT t.trade_id) AS trade_count,
       ROUND(COUNT(DISTINCT t.trade_id)::NUMERIC / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS execution_rate
FROM broker b
LEFT JOIN order_record o ON o.broker_id = b.broker_id
LEFT JOIN trade t ON t.order_id = o.order_id
GROUP BY b.broker_id, b.full_name
ORDER BY execution_rate DESC;
