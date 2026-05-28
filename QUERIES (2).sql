-- ===========================================================
-- QUERY 1 : Complete KYC Status Dashboard per Investor
-- ===========================================================
--
-- Problem Statement:
-- Compliance teams require a consolidated dashboard that reports each
-- investor's KYC progress. The query should count the total number of
-- submitted documents and break them down by verification status
-- (VERIFIED, PENDING, REJECTED) so that onboarding bottlenecks
-- can be identified and acted upon swiftly.
--

SELECT
    i.investor_id,
    i.full_name AS investor_name,
    i.kyc_status AS overall_kyc_status,

    COUNT(k.doc_id) AS total_documents,

    COUNT(k.doc_id) FILTER (WHERE k.verification_status = 'VERIFIED') AS verified_docs,
    COUNT(k.doc_id) FILTER (WHERE k.verification_status = 'PENDING')  AS pending_docs,
    COUNT(k.doc_id) FILTER (WHERE k.verification_status = 'REJECTED') AS rejected_docs,

    COALESCE(
        STRING_AGG(k.doc_type::TEXT, ', ' ORDER BY k.doc_type),
        'No Documents'
    ) AS document_types_submitted

FROM trading.investor i
LEFT JOIN trading.kyc_document k 
    ON k.investor_id = i.investor_id

GROUP BY 
    i.investor_id, 
    i.full_name, 
    i.kyc_status

ORDER BY
    CASE i.kyc_status
        WHEN 'REJECTED' THEN 1
        WHEN 'PENDING'  THEN 2
        ELSE 3
    END,
    i.investor_id;

-- ===========================================================
-- QUERY 2 : Total Tax Liability per Investor (STCG & LTCG Summary)
-- ===========================================================
--
-- Problem Statement:
-- For annual tax reporting purposes, the platform must calculate each
-- investor's short-term capital gains (STCG) and long-term capital gains
-- (LTCG) separately, along with the corresponding tax liabilities.
-- The query must derive investor identity by traversing the chain
-- capital_gains_record → trade → order_record → investor.
--

SELECT
    inv.investor_id,
    inv.full_name AS investor_name,

    SUM(cg.gain_loss) FILTER (WHERE cg.gain_type = 'SHORT_TERM') AS total_stcg,
    SUM(cg.tax_amount) FILTER (WHERE cg.gain_type = 'SHORT_TERM') AS stcg_tax,

    SUM(cg.gain_loss) FILTER (WHERE cg.gain_type = 'LONG_TERM') AS total_ltcg,
    SUM(cg.tax_amount) FILTER (WHERE cg.gain_type = 'LONG_TERM') AS ltcg_tax,

    SUM(cg.gain_loss) AS net_gain_loss,
    SUM(cg.tax_amount) AS total_tax_liability

FROM trading.capital_gains_record cg

LEFT JOIN trading.trade t 
    ON t.trade_id = cg.sell_trade_id

LEFT JOIN trading.order_record o 
    ON o.order_id = t.order_id

LEFT JOIN trading.investor inv 
    ON inv.investor_id = o.investor_id

GROUP BY 
    inv.investor_id,
    inv.full_name

ORDER BY 
    total_tax_liability DESC NULLS LAST;

-- ===========================================================
-- QUERY 3 : Latest Closing Price and 11-Day Price Range per Security
-- ===========================================================
--
-- Problem Statement:
-- Traders and analysts require a snapshot of each security's most
-- recent fill price alongside its high and low over recent executions
-- to measure short-term price volatility and momentum. Since a
-- dedicated price-history table is not present, the query uses the
-- trade table to reconstruct this information using window functions.
--

WITH recent_trades AS (
    SELECT
        o.security_id,
        t.fill_price AS fill_price,
        t.trade_datetime
    FROM trading.trade t
    JOIN trading.order_record o 
        ON o.order_id = t.order_id
    WHERE t.trade_datetime >= CURRENT_DATE - INTERVAL '11 days'
),

ranked_trades AS (
    SELECT
        security_id,
        fill_price,
        trade_datetime,
        ROW_NUMBER() OVER (
            PARTITION BY security_id 
            ORDER BY trade_datetime DESC
        ) AS rn
    FROM recent_trades
),

price_range AS (
    SELECT
        security_id,
        MAX(fill_price) AS high_price,
        MIN(fill_price) AS low_price,
        COUNT(*)        AS trade_count
    FROM recent_trades
    GROUP BY security_id
)

SELECT
    s.security_id,
    s.ticker,
    s.company_name,
    s.sector,

    rt.fill_price     AS latest_fill_price,
    rt.trade_datetime AS latest_trade_time,

    pr.high_price     AS period_high,
    pr.low_price      AS period_low,

    (pr.high_price - pr.low_price) AS price_range,
    pr.trade_count  AS total_executions,

    ROUND(
        (pr.high_price - pr.low_price) / NULLIF(pr.low_price, 0) * 100,
        2
    ) AS volatility_pct

FROM ranked_trades rt
JOIN price_range pr 
    ON pr.security_id = rt.security_id

JOIN trading.security s 
    ON s.security_id = rt.security_id

WHERE rt.rn = 1

ORDER BY volatility_pct DESC NULLS LAST;

-- ===========================================================
-- QUERY 4 : Brokerage Plan Comparison for Cost Saving
-- ===========================================================
--
-- Problem Statement:
-- Each investor subscribed to a brokerage plan. This query evaluates
-- what the investor actually paid in brokerage versus what they would
-- have paid under an alternative plan type (FLAT_FEE vs PERCENTAGE)
-- offered by the same broker. The difference quantifies potential
-- savings, helping the platform make personalised plan recommendations.
--

WITH investor_trades AS (
    SELECT
        o.investor_id,
        cp.plan_id,
        p.plan_type,
        p.brokerage_percent,
        p.min_brokerage,
        SUM(t.brokerage_fee)                                AS actual_brokerage_paid,
        SUM(t.fill_price * t.filled_qty)                    AS total_trade_value,
        COUNT(t.trade_id)                                   AS num_trades
    FROM trading.trade        t
    JOIN trading.order_record o  ON o.order_id   = t.order_id
    JOIN trading.client_plan  cp ON cp.investor_id = o.investor_id AND cp.is_active = TRUE
    JOIN trading.plan         p  ON p.plan_id     = cp.plan_id
    GROUP BY o.investor_id, cp.plan_id, p.plan_type, p.brokerage_percent, p.min_brokerage
),
alternative_cost AS (
    SELECT
        it.*,
        -- Simulated cost under PERCENTAGE model
        GREATEST(
            it.total_trade_value * it.brokerage_percent / 100,
            it.min_brokerage * it.num_trades
        ) AS simulated_pct_cost,
        -- Simulated cost under FLAT_FEE model (₹20 per trade as benchmark)
        20.00 * it.num_trades AS simulated_flat_cost
    FROM investor_trades it
)
SELECT
    i.investor_id,
    i.full_name                         AS investor_name,
    ac.plan_type                        AS current_plan_type,
    ROUND(ac.actual_brokerage_paid, 2)  AS actual_brokerage_paid,
    ROUND(ac.simulated_pct_cost,    2)  AS cost_under_percentage_plan,
    ROUND(ac.simulated_flat_cost,   2)  AS cost_under_flat_plan,
    ROUND(ac.actual_brokerage_paid - LEAST(ac.simulated_pct_cost, ac.simulated_flat_cost), 2)
                                        AS potential_saving,
    CASE
        WHEN ac.simulated_flat_cost < ac.simulated_pct_cost THEN 'Switch to FLAT_FEE'
        ELSE 'Switch to PERCENTAGE'
    END                                 AS recommendation
FROM alternative_cost ac
JOIN trading.investor i ON i.investor_id = ac.investor_id
ORDER BY potential_saving DESC NULLS LAST;

-- ===========================================================
-- QUERY 4 : Brokerage Plan Comparison for Cost Saving
-- ===========================================================
--
-- Problem Statement:
-- Each investor subscribed to a brokerage plan. This query evaluates
-- what the investor actually paid in brokerage versus what they would
-- have paid under an alternative plan type (FLAT_FEE vs PERCENTAGE)
-- offered by the same broker. The difference quantifies potential
-- savings, helping the platform make personalised plan recommendations.
--

WITH investor_trades AS (
    SELECT
        o.investor_id,
        cp.plan_id,
        p.plan_type,
        p.brokerage_percent,
        p.min_brokerage,

        -- Derived brokerage (actual paid)
        SUM(
            GREATEST(
                (t.fill_price * t.filled_qty) * p.brokerage_percent / 100,
                p.min_brokerage
            )
        ) AS actual_brokerage_paid,

        SUM(t.fill_price * t.filled_qty) AS total_trade_value,
        COUNT(t.trade_id) AS num_trades

    FROM trading.trade t

    JOIN trading.order_record o 
        ON o.order_id = t.order_id

    JOIN trading.client_plan cp 
        ON cp.investor_id = o.investor_id 
        AND cp.is_active = TRUE

    JOIN trading.brokerage_plan p 
        ON p.plan_id = cp.plan_id

    GROUP BY 
        o.investor_id, 
        cp.plan_id, 
        p.plan_type, 
        p.brokerage_percent, 
        p.min_brokerage
),

alternative_cost AS (
    SELECT
        it.*,

        -- Simulated percentage model
        GREATEST(
            it.total_trade_value * it.brokerage_percent / 100,
            it.min_brokerage * it.num_trades
        ) AS simulated_pct_cost,

        -- Flat ₹20 per trade
        (20 * it.num_trades) AS simulated_flat_cost

    FROM investor_trades it
)

SELECT
    i.investor_id,
    i.full_name AS investor_name,

    ac.plan_type AS current_plan_type,

    ROUND(ac.actual_brokerage_paid, 2) AS actual_brokerage_paid,
    ROUND(ac.simulated_pct_cost, 2) AS cost_under_percentage_plan,
    ROUND(ac.simulated_flat_cost, 2) AS cost_under_flat_plan,

    ROUND(
        ac.actual_brokerage_paid - 
        LEAST(ac.simulated_pct_cost, ac.simulated_flat_cost),
        2
    ) AS potential_saving,

    CASE
        WHEN ac.simulated_flat_cost < ac.simulated_pct_cost 
            THEN 'Switch to FLAT_FEE'
        ELSE 
            'Switch to PERCENTAGE'
    END AS recommendation

FROM alternative_cost ac

JOIN trading.investor i 
    ON i.investor_id = ac.investor_id

ORDER BY potential_saving DESC NULLS LAST;

-- ===========================================================
-- QUERY 5 : Mutual Fund NAV Drift vs Average Buy Price
-- ===========================================================
--
-- Problem Statement:
-- Portfolio managers need to detect underperforming mutual fund
-- positions by comparing each investor's weighted average purchase
-- price (avg_cost_price) against the fund's current NAV. A negative
-- drift indicates a loss-making or stagnant holding that may warrant
-- redemption or review.
--

SELECT
    i.investor_id,
    i.full_name AS investor_name,

    s.ticker,
    s.company_name AS fund_name,

    mf.amc_name,
    mf.scheme_category,

    h.quantity AS units_held,
    h.avg_cost_price AS avg_buy_nav,

    mf.nav AS current_nav,
    mf.nav_date AS nav_as_of,

    ROUND(mf.nav - h.avg_cost_price, 4) AS nav_drift,

    ROUND(
        (mf.nav - h.avg_cost_price) / NULLIF(h.avg_cost_price, 0) * 100,
        2
    ) AS drift_pct,

    ROUND(h.quantity * mf.nav, 2) AS current_value,
    ROUND(h.quantity * h.avg_cost_price, 2) AS invested_value,

    CASE
        WHEN mf.nav > h.avg_cost_price THEN 'Profit'
        WHEN mf.nav < h.avg_cost_price THEN 'Loss'
        ELSE 'No Change'
    END AS position_status

FROM trading.holding h

JOIN trading.portfolio p 
    ON p.portfolio_id = h.portfolio_id

JOIN trading.investor i 
    ON i.investor_id = p.investor_id

JOIN trading.security s 
    ON s.security_id = h.security_id
    AND s.security_type = 'MUTUAL_FUND'   -- IMPORTANT FILTER

JOIN trading.mutual_fund mf 
    ON mf.security_id = s.security_id

ORDER BY drift_pct ASC NULLS LAST;

-- ===========================================================
-- QUERY 6 : Sector-Wise Holding Concentration per Investor
-- ===========================================================
--
-- Problem Statement:
-- Over-concentration of an investor's portfolio in a single sector
-- increases systemic risk. This query calculates what percentage of
-- each investor's total equity holding value lies within each sector,
-- and applies PERCENT_RANK() to rank sectors by concentration,
-- enabling risk alerts for advisors.
--

WITH base AS (
    SELECT
        p.investor_id,
        s.sector,
        SUM(
            CASE 
                WHEN s.security_type = 'EQUITY' 
                    THEN h.quantity * e.eps * e.pe_ratio
                WHEN s.security_type = 'MUTUAL_FUND'
                    THEN h.quantity * mf.nav
                ELSE 0
            END
        ) AS sector_value
    FROM trading.holding h
    JOIN trading.portfolio p 
        ON p.portfolio_id = h.portfolio_id
    JOIN trading.security s 
        ON s.security_id = h.security_id
    LEFT JOIN trading.equity e 
        ON e.security_id = s.security_id
    LEFT JOIN trading.mutual_fund mf 
        ON mf.security_id = s.security_id
    WHERE s.sector IS NOT NULL
    GROUP BY p.investor_id, s.sector
),

total AS (
    SELECT
        investor_id,
        SUM(sector_value) AS total_portfolio_value
    FROM base
    GROUP BY investor_id
)

SELECT
    i.investor_id,
    i.full_name AS investor_name,

    b.sector,
    ROUND(b.sector_value::numeric, 2) AS sector_value,
    ROUND(t.total_portfolio_value::numeric, 2) AS total_portfolio_value,

    ROUND(
        (b.sector_value / NULLIF(t.total_portfolio_value, 0) * 100)::numeric,
        2
    ) AS concentration_pct,

    ROUND(
        (PERCENT_RANK() OVER (
            PARTITION BY b.investor_id
            ORDER BY b.sector_value DESC
        ) * 100)::numeric,
        2
    ) AS percent_rank_within_investor,

    CASE
        WHEN (b.sector_value / NULLIF(t.total_portfolio_value, 0) * 100) > 50
            THEN 'HIGH RISK — Over-concentrated'
        WHEN (b.sector_value / NULLIF(t.total_portfolio_value, 0) * 100) > 30
            THEN 'MODERATE — Review Advised'
        ELSE 'NORMAL'
    END AS concentration_flag

FROM base b
JOIN total t 
    ON t.investor_id = b.investor_id
JOIN trading.investor i 
    ON i.investor_id = b.investor_id

ORDER BY 
    i.investor_id,
    concentration_pct DESC;

-- ===========================================================
-- QUERY 7 : Mutual Fund NAV Tracking (Current Value vs Invested Value)
-- ===========================================================
--
-- Problem Statement:
-- Investors and fund managers need to track the real-time valuation of
-- all mutual fund holdings by applying the latest NAV to the number of
-- units held, and compare this against the total amount originally
-- invested. This enables computation of absolute and percentage profit
-- or loss at the holding level.
--

SELECT
    i.investor_id,
    i.full_name AS investor_name,

    p.portfolio_name,

    s.ticker AS fund_ticker,
    s.company_name AS fund_name,

    mf.amc_name,
    mf.scheme_category,

    mf.nav AS current_nav,
    mf.nav_date,

    h.quantity AS units_held,

    ROUND((h.quantity * h.avg_cost_price)::numeric, 2) AS invested_value,

    ROUND((h.quantity * mf.nav)::numeric, 2) AS current_value,

    ROUND(
        (h.quantity * (mf.nav - h.avg_cost_price))::numeric,
        2
    ) AS absolute_pnl,

    ROUND(
        ((mf.nav - h.avg_cost_price) / NULLIF(h.avg_cost_price, 0) * 100)::numeric,
        2
    ) AS return_pct,

    h.last_updated

FROM trading.holding h

JOIN trading.portfolio p 
    ON p.portfolio_id = h.portfolio_id

JOIN trading.investor i 
    ON i.investor_id = p.investor_id

JOIN trading.security s 
    ON s.security_id = h.security_id
    AND s.security_type = 'MUTUAL_FUND'   -- IMPORTANT

JOIN trading.mutual_fund mf 
    ON mf.security_id = s.security_id

WHERE h.quantity > 0

ORDER BY return_pct DESC NULLS LAST;

-- ===========================================================
-- QUERY 8 : Holding Period Analysis per Security per Investor
-- ===========================================================
--
-- Problem Statement:
-- To assist tax planning, the system must calculate the holding period
-- (in days) for each security position by computing the difference
-- between the weighted earliest buy date and today's date. Holdings are
-- then classified as Short-Term (< 365 days) or Long-Term (>= 365 days)
-- under Indian capital gains tax rules.
--

SELECT
    i.investor_id,
    i.full_name AS investor_name,

    p.portfolio_name,

    s.ticker,
    s.company_name,
    s.sector,
    s.security_type,

    h.quantity,
    h.avg_cost_price,

    -- Derived current price per unit
    CASE
        WHEN s.security_type = 'EQUITY'
            THEN (e.eps * e.pe_ratio)
        WHEN s.security_type = 'MUTUAL_FUND'
            THEN mf.nav
        ELSE NULL
    END AS current_price_per_unit,

    ROUND((h.quantity * h.avg_cost_price)::numeric, 2) AS total_cost_basis,

    ROUND((
        h.quantity *
        CASE
            WHEN s.security_type = 'EQUITY'
                THEN (e.eps * e.pe_ratio)
            WHEN s.security_type = 'MUTUAL_FUND'
                THEN mf.nav
            ELSE 0
        END
    )::numeric, 2) AS current_market_value,

    ROUND((
        h.quantity *
        (
            CASE
                WHEN s.security_type = 'EQUITY'
                    THEN (e.eps * e.pe_ratio)
                WHEN s.security_type = 'MUTUAL_FUND'
                    THEN mf.nav
                ELSE 0
            END
            - h.avg_cost_price
        )
    )::numeric, 2) AS unrealized_pnl,

    ROUND((
        (
            CASE
                WHEN s.security_type = 'EQUITY'
                    THEN (e.eps * e.pe_ratio)
                WHEN s.security_type = 'MUTUAL_FUND'
                    THEN mf.nav
                ELSE 0
            END
            - h.avg_cost_price
        ) / NULLIF(h.avg_cost_price, 0) * 100
    )::numeric, 2) AS return_pct,

    RANK() OVER (
        PARTITION BY p.portfolio_id
        ORDER BY (
            h.quantity *
            (
                CASE
                    WHEN s.security_type = 'EQUITY'
                        THEN (e.eps * e.pe_ratio)
                    WHEN s.security_type = 'MUTUAL_FUND'
                        THEN mf.nav
                    ELSE 0
                END
                - h.avg_cost_price
            )
        ) DESC
    ) AS rank_by_pnl

FROM trading.holding h

JOIN trading.portfolio p 
    ON p.portfolio_id = h.portfolio_id

JOIN trading.investor i 
    ON i.investor_id = p.investor_id

JOIN trading.security s 
    ON s.security_id = h.security_id

LEFT JOIN trading.equity e 
    ON e.security_id = s.security_id

LEFT JOIN trading.mutual_fund mf 
    ON mf.security_id = s.security_id

WHERE h.quantity > 0

ORDER BY 
    i.investor_id,
    return_pct DESC NULLS LAST;

-- ===========================================================
-- QUERY 10 : Portfolio P&L Ranked by Unrealized Gain / Loss
-- ===========================================================
--
-- Problem Statement:
-- The platform dashboard requires a ranked summary of all portfolios
-- showing total invested value, current market value, unrealized P&L,
-- and P&L percentage. Portfolios are ranked using RANK() on unrealized
-- gain, allowing relationship managers to quickly identify clients who
-- may need attention or be highlighted as success stories.
--

WITH holding_values AS (
    SELECT
        h.portfolio_id,

        -- invested value
        (h.quantity * h.avg_cost_price) AS invested_value,

        -- current value (derived)
        (
            h.quantity *
            CASE
                WHEN s.security_type = 'EQUITY'
                    THEN (e.eps * e.pe_ratio)
                WHEN s.security_type = 'MUTUAL_FUND'
                    THEN mf.nav
                ELSE 0
            END
        ) AS current_value

    FROM trading.holding h

    JOIN trading.security s 
        ON s.security_id = h.security_id

    LEFT JOIN trading.equity e 
        ON e.security_id = s.security_id

    LEFT JOIN trading.mutual_fund mf 
        ON mf.security_id = s.security_id
)

SELECT
    p.portfolio_id,
    p.portfolio_name,

    i.investor_id,
    i.full_name AS investor_name,

    COUNT(*) AS num_holdings,

    ROUND(SUM(hv.invested_value)::numeric, 2) AS total_invested,

    ROUND(SUM(hv.current_value)::numeric, 2) AS total_current_value,

    ROUND((SUM(hv.current_value - hv.invested_value))::numeric, 2)
        AS total_unrealized_pnl,

    ROUND(
        (
            SUM(hv.current_value - hv.invested_value) /
            NULLIF(SUM(hv.invested_value), 0) * 100
        )::numeric,
        2
    ) AS pnl_pct,

    RANK() OVER (
        ORDER BY SUM(hv.current_value - hv.invested_value) DESC NULLS LAST
    ) AS rank_by_gain,

    RANK() OVER (
        ORDER BY (
            SUM(hv.current_value - hv.invested_value) /
            NULLIF(SUM(hv.invested_value), 0)
        ) DESC NULLS LAST
    ) AS rank_by_return_pct

FROM trading.portfolio p

JOIN trading.investor i 
    ON i.investor_id = p.investor_id

LEFT JOIN holding_values hv 
    ON hv.portfolio_id = p.portfolio_id

GROUP BY 
    p.portfolio_id, 
    p.portfolio_name, 
    i.investor_id, 
    i.full_name

ORDER BY total_unrealized_pnl DESC NULLS LAST;

-- ===========================================================
-- QUERY 11 : Momentum Signals — Stocks Near 52-Week High
-- ===========================================================
--
-- Problem Statement:
-- A momentum strategy requires identifying securities whose most recent
-- traded price is within 5% of their 52-week high fill price. Such
-- stocks may indicate breakout potential. The query uses trade history
-- to approximate the 52-week high and evaluates each security's
-- proximity to this level.
--

WITH yearly_range AS (
    SELECT
        o.security_id,
        MAX(t.fill_price) AS high_52w,
        MIN(t.price) AS low_52w,
        COUNT(t.trade_id) AS trade_count_52w
    FROM trading.trade t
    JOIN trading.order_record o 
        ON o.order_id = t.order_id
    WHERE t.trade_datetime >= CURRENT_DATE - INTERVAL '52 weeks'
    GROUP BY o.security_id
),

latest_price AS (
    SELECT DISTINCT ON (o.security_id)
        o.security_id,
        t.price AS last_price,
        t.trade_datetime
    FROM trading.trade t
    JOIN trading.order_record o 
        ON o.order_id = t.order_id
    ORDER BY 
        o.security_id, 
        t.trade_datetime DESC
)

SELECT
    s.security_id,
    s.ticker,
    s.company_name,
    s.sector,

    lp.last_price,

    yr.high_52w,
    yr.low_52w,

    (yr.high_52w - yr.low_52w) AS range_52w,

    ROUND(
        (lp.last_price / NULLIF(yr.high_52w, 0) * 100)::numeric,
        2
    ) AS pct_of_52w_high,

    ROUND(
        ((lp.last_price - yr.high_52w) / NULLIF(yr.high_52w, 0) * 100)::numeric,
        2
    ) AS gap_from_high_pct,

    CASE
        WHEN lp.last_price >= yr.high_52w * 0.95
            THEN 'NEAR 52W HIGH — Momentum Signal'
        WHEN lp.last_price <= yr.low_52w * 1.05
            THEN 'NEAR 52W LOW — Possible Reversal'
        ELSE 'NEUTRAL'
    END AS momentum_signal,

    yr.trade_count_52w

FROM latest_price lp

JOIN yearly_range yr 
    ON yr.security_id = lp.security_id

JOIN trading.security s 
    ON s.security_id = lp.security_id

WHERE s.security_type = 'EQUITY'

ORDER BY pct_of_52w_high DESC NULLS LAST;


-- ===========================================================
-- QUERY 12 : Full Investor 360° Snapshot
-- ===========================================================
--
-- Problem Statement:
-- Relationship managers and compliance officers need a single
-- consolidated view of each investor covering their profile data,
-- KYC status, total portfolio value, available trading account
-- balance, and number of trades executed to date. This 360-degree
-- snapshot supports proactive client engagement and risk assessment.
--

WITH portfolio_summary AS (
    SELECT
        p.investor_id,
        COUNT(DISTINCT p.portfolio_id)           AS num_portfolios,
        COUNT(h.holding_id)                      AS total_holdings,
        ROUND(SUM(h.current_value), 2)           AS total_portfolio_value,
        ROUND(SUM(h.unrealized_pnl), 2)          AS total_unrealized_pnl
    FROM trading.portfolio p
    LEFT JOIN trading.holding h ON h.portfolio_id = p.portfolio_id
    WHERE p.is_active = TRUE
    GROUP BY p.investor_id
),
trade_summary AS (
    SELECT
        o.investor_id,
        COUNT(t.trade_id)                        AS total_trades,
        MAX(t.trade_datetime)                    AS last_trade_date,
        ROUND(SUM(t.net_amount), 2)              AS total_trade_volume
    FROM trading.trade        t
    JOIN trading.order_record o ON o.order_id = t.order_id
    GROUP BY o.investor_id
),
kyc_summary AS (
    SELECT
        investor_id,
        COUNT(*) FILTER (WHERE verification_status = 'VERIFIED') AS verified_docs,
        COUNT(*)                                                  AS total_docs
    FROM trading.kyc_document
    GROUP BY investor_id
)
SELECT
    i.investor_id,
    i.full_name,
    i.investor_type,
    i.kyc_status,
    i.age,
    i.mobile_no,
    ks.verified_docs || '/' || ks.total_docs    AS kyc_progress,
    ps.num_portfolios,
    ps.total_holdings,
    COALESCE(ps.total_portfolio_value, 0)        AS total_portfolio_value,
    COALESCE(ps.total_unrealized_pnl, 0)         AS total_unrealized_pnl,
    COALESCE(ta.avl_balance, 0)                  AS cash_balance,
    COALESCE(ts.total_trades, 0)                 AS total_trades,
    ts.last_trade_date,
    COALESCE(ts.total_trade_volume, 0)           AS total_trade_volume
FROM trading.investor          i
LEFT JOIN portfolio_summary    ps ON ps.investor_id = i.investor_id
LEFT JOIN trade_summary        ts ON ts.investor_id = i.investor_id
LEFT JOIN kyc_summary          ks ON ks.investor_id = i.investor_id
LEFT JOIN trading.trading_account ta ON ta.investor_id = i.investor_id
                                     AND ta.is_active  = TRUE
ORDER BY total_portfolio_value DESC NULLS LAST;


-- ===========================================================
-- QUERY 13 : Find Current Active Plan per Investor
-- ===========================================================
--
-- Problem Statement:
-- To apply correct brokerage charges during order placement, the
-- system must determine the currently active subscription plan for each
-- investor. An active plan is defined as one where is_active is TRUE and
-- today's date falls within the plan's start_date and end_date range
-- (or end_date is NULL, indicating an open-ended subscription).
--

SELECT
    i.investor_id,
    i.full_name                                         AS investor_name,
    cp.client_plan_id,
    p.plan_name,
    p.plan_type,
    CASE
        WHEN p.plan_type = 'FLAT_FEE'
            THEN '₹' || p.min_brokerage || ' per trade'
        ELSE p.brokerage_percent || '% (min ₹' || p.min_brokerage || ')'
    END                                                 AS brokerage_structure,
    cp.start_date                                       AS plan_start_date,
    COALESCE(cp.end_date::TEXT, 'Open-ended')           AS plan_end_date,
    b.full_name                                         AS broker_name,
    b.sebi_lic_no
FROM trading.client_plan  cp
JOIN trading.investor     i ON i.investor_id = cp.investor_id
JOIN trading.plan         p ON p.plan_id     = cp.plan_id
JOIN trading.broker       b ON b.broker_id   = p.broker_id
WHERE cp.is_active = TRUE
  AND cp.start_date <= CURRENT_DATE
  AND (cp.end_date IS NULL OR cp.end_date >= CURRENT_DATE)
ORDER BY i.investor_id;


-- ===========================================================
-- QUERY 14 : Trades Executed in the Previous Calendar Month
-- ===========================================================
--
-- Problem Statement:
-- Monthly trade reconciliation requires fetching all executed trades
-- for each investor within the previous calendar month. The query
-- uses date arithmetic to dynamically compute the prior month's date
-- range, ensuring accurate filtering without hard-coded dates.
--

SELECT
    t.trade_id,
    t.trade_datetime,
    i.investor_id,
    i.full_name                                     AS investor_name,
    s.ticker,
    s.company_name,
    s.exchange,
    o.side                                          AS trade_direction,
    o.order_type,
    t.filled_qty                                    AS quantity,
    t.fill_price,
    ROUND(t.fill_price * t.filled_qty, 2)           AS gross_trade_value,
    t.brokerage_fee,
    t.stt,
    t.total_charges,
    t.net_amount,
    t.settlement_date
FROM trading.trade        t
JOIN trading.order_record o  ON o.order_id   = t.order_id
JOIN trading.investor     i  ON i.investor_id = o.investor_id
JOIN trading.security     s  ON s.security_id = o.security_id
WHERE t.trade_datetime >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
  AND t.trade_datetime <  DATE_TRUNC('month', CURRENT_DATE)
ORDER BY i.investor_id, t.trade_datetime;


-- ===========================================================
-- QUERY 15 : Portfolios with Equity Concentration > 80%
-- ===========================================================
--
-- Problem Statement:
-- Regulatory guidelines and internal risk policies require flagging
-- portfolios where more than 80% of total current market value is
-- invested in EQUITY securities. High equity concentration indicates
-- insufficient diversification, and such portfolios should be surfaced
-- for mandatory advisor review or automated rebalancing alerts.
--

WITH portfolio_total AS (
    SELECT
        h.portfolio_id,
        SUM(h.current_value)                         AS total_value
    FROM trading.holding h
    GROUP BY h.portfolio_id
),
equity_value AS (
    SELECT
        h.portfolio_id,
        SUM(h.current_value)                         AS equity_value,
        COUNT(h.holding_id)                          AS equity_positions
    FROM trading.holding   h
    JOIN trading.security  s ON s.security_id = h.security_id
    WHERE s.security_type = 'EQUITY'
    GROUP BY h.portfolio_id
)
SELECT
    p.portfolio_id,
    p.portfolio_name,
    i.investor_id,
    i.full_name                                     AS investor_name,
    i.investor_type,
    ROUND(pt.total_value, 2)                        AS total_portfolio_value,
    ROUND(ev.equity_value, 2)                       AS equity_value,
    ROUND(pt.total_value - ev.equity_value, 2)      AS non_equity_value,
    ROUND(ev.equity_value / pt.total_value * 100, 2)
                                                    AS equity_concentration_pct,
    ev.equity_positions                             AS num_equity_positions,
    'HIGH RISK — Equity > 80%'                      AS risk_flag
FROM equity_value      ev
JOIN portfolio_total   pt ON pt.portfolio_id = ev.portfolio_id
JOIN trading.portfolio p  ON p.portfolio_id  = ev.portfolio_id
JOIN trading.investor  i  ON i.investor_id   = p.investor_id
WHERE ev.equity_value / NULLIF(pt.total_value, 0) > 0.80
  AND p.is_active = TRUE
ORDER BY equity_concentration_pct DESC;

-- ===========================================================
-- END OF QUERY FILE
-- ===========================================================
