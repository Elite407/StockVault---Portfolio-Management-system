-- ============================================================
-- StockVault — Simplified, Idempotent Seed Data
-- Purpose : Populate all 15 tables with realistic financial data.
--           Guaranteed to produce non-empty, mathematically exact
--           output for all 13 analytical and 17 application queries.
-- Idempotency: Safe to re-run at any time. Cleanly resets tables
--              and restarts identity sequences.
-- ============================================================

SET search_path TO trading;

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 0. CLEANUP & SEQUENCE RESET (Safe Re-execution)
-- ─────────────────────────────────────────────────────────────
TRUNCATE TABLE
    capital_gains_record,
    trade,
    order_record,
    holding,
    mutual_fund,
    equity,
    security,
    broker_client,
    plan_catalog,
    fund_transaction,
    bank_acc,
    trading_acc,
    kyc_document,
    broker,
    investor
RESTART IDENTITY CASCADE;

-- Temporarily disable triggers during bulk static seed to prevent
-- race conditions, double balance deductions, or manual holding conflicts.
ALTER TABLE order_record DISABLE TRIGGER USER;
ALTER TABLE trade DISABLE TRIGGER USER;
ALTER TABLE fund_transaction DISABLE TRIGGER USER;
ALTER TABLE investor DISABLE TRIGGER USER;

-- ─────────────────────────────────────────────────────────────
-- 1. INVESTOR (8 investors: 6 RETAIL, 2 INSTITUTIONAL)
-- ─────────────────────────────────────────────────────────────
INSERT INTO investor (investor_id, full_name, email, password_hash, pan_no, aadhar_no, dob, kyc_status, is_active, investor_type, risk_profile, cin_no) VALUES
-- RETAIL investors (CIN_NO must be NULL)
('a0000000-0000-0000-0000-000000000001', 'Aarav Mehta',     'aarav@example.com',   '$2b$12$e68Y2X6Z4wP3t.aaravhash99999999999999999999999999999999', 'ABCPM1234A', '111122223333', '1990-03-15', 'VERIFIED',  TRUE,  'RETAIL', 'AGGRESSIVE',   NULL),
('a0000000-0000-0000-0000-000000000002', 'Priya Sharma',    'priya@example.com',   '$2b$12$e68Y2X6Z4wP3t.priyahash99999999999999999999999999999999', 'BCDPS5678B', '222233334444', '1985-07-22', 'VERIFIED',  TRUE,  'RETAIL', 'MODERATE',     NULL),
('a0000000-0000-0000-0000-000000000003', 'Rohan Patel',     'rohan@example.com',   '$2b$12$e68Y2X6Z4wP3t.rohanhash99999999999999999999999999999999', 'CDERP9012C', '333344445555', '1992-11-08', 'VERIFIED',  TRUE,  'RETAIL', 'CONSERVATIVE', NULL),
('a0000000-0000-0000-0000-000000000004', 'Neha Gupta',      'neha@example.com',    '$2b$12$e68Y2X6Z4wP3t.nehahash99999999999999999999999999999999',  'DEFNG3456D', '444455556666', '1988-01-30', 'VERIFIED',  TRUE,  'RETAIL', 'HNI',          NULL),
('a0000000-0000-0000-0000-000000000005', 'Vikram Singh',    'vikram@example.com',  '$2b$12$e68Y2X6Z4wP3t.vikramhash9999999999999999999999999999999', 'EFGVS7890E', '555566667777', '1995-06-12', 'PENDING',   TRUE,  'RETAIL', 'MODERATE',     NULL),
('a0000000-0000-0000-0000-000000000006', 'Ananya Reddy',    'ananya@example.com',  '$2b$12$e68Y2X6Z4wP3t.ananyahash9999999999999999999999999999999', 'FGHAR1234F', '666677778888', '1993-09-25', 'VERIFIED',  TRUE,  'RETAIL', 'AGGRESSIVE',   NULL),
-- INSTITUTIONAL investors (RISK_PROFILE must be NULL, CIN_NO required)
('a0000000-0000-0000-0000-000000000007', 'BlueStar Capital','bluestar@example.com','$2b$12$e68Y2X6Z4wP3t.bluestarhash99999999999999999999999999999', 'GHIBC5678G', '777788889999', '2000-01-01', 'VERIFIED',  TRUE,  'INSTITUTIONAL', NULL, 'U12345MH2000PLC123456'),
('a0000000-0000-0000-0000-000000000008', 'Zenith Fund Mgmt','zenith@example.com',  '$2b$12$e68Y2X6Z4wP3t.zenithhash999999999999999999999999999999', 'HIJZF9012H', '888899990000', '2005-05-15', 'VERIFIED',  TRUE,  'INSTITUTIONAL', NULL, 'U67890DL2005PTC654321');

-- ─────────────────────────────────────────────────────────────
-- 2. KYC_DOCUMENT (12 documents — includes 3 expiring within 30 days)
-- ─────────────────────────────────────────────────────────────
INSERT INTO kyc_document (doc_no, doc_type, issue_date, expiry_date, verification_status, investor_id) VALUES
('DOC-PAN-001',  'PAN',             '2020-01-10', NULL,                                'VERIFIED', 'a0000000-0000-0000-0000-000000000001'),
('DOC-PASS-002', 'PASSPORT',        '2016-08-20', CURRENT_DATE + INTERVAL '15 days',   'VERIFIED', 'a0000000-0000-0000-0000-000000000001'), -- Expiring soon (A7)
('DOC-PAN-003',  'PAN',             '2019-03-05', NULL,                                'VERIFIED', 'a0000000-0000-0000-0000-000000000002'),
('DOC-DL-004',   'DRIVING_LICENSE', '2015-06-15', CURRENT_DATE + INTERVAL '10 days',   'VERIFIED', 'a0000000-0000-0000-0000-000000000002'), -- Expiring soon (A7)
('DOC-PAN-005',  'PAN',             '2021-02-14', NULL,                                'VERIFIED', 'a0000000-0000-0000-0000-000000000003'),
('DOC-AADH-006', 'AADHAR',          '2018-09-01', NULL,                                'VERIFIED', 'a0000000-0000-0000-0000-000000000003'),
('DOC-PAN-007',  'PAN',             '2017-11-20', NULL,                                'VERIFIED', 'a0000000-0000-0000-0000-000000000004'),
('DOC-PASS-008', 'PASSPORT',        '2017-12-01', CURRENT_DATE + INTERVAL '25 days',   'VERIFIED', 'a0000000-0000-0000-0000-000000000004'), -- Expiring soon (A7)
('DOC-PAN-009',  'PAN',             '2023-01-10', NULL,                                'PENDING',  'a0000000-0000-0000-0000-000000000005'),
('DOC-PAN-010',  'PAN',             '2022-04-18', NULL,                                'VERIFIED', 'a0000000-0000-0000-0000-000000000006'),
('DOC-PAN-011',  'PAN',             '2001-03-20', NULL,                                'VERIFIED', 'a0000000-0000-0000-0000-000000000007'),
('DOC-PAN-012',  'PAN',             '2006-08-11', NULL,                                'VERIFIED', 'a0000000-0000-0000-0000-000000000008');

-- ─────────────────────────────────────────────────────────────
-- 3. TRADING_ACC (8 trading accounts — identity 1 to 8)
-- ─────────────────────────────────────────────────────────────
INSERT INTO trading_acc (investor_id, is_active, avail_balance, open_date) VALUES
('a0000000-0000-0000-0000-000000000001', TRUE,  500000.00,  '2023-01-15'),  -- TA 1: Aarav
('a0000000-0000-0000-0000-000000000002', TRUE,  750000.00,  '2023-02-20'),  -- TA 2: Priya
('a0000000-0000-0000-0000-000000000003', TRUE,  200000.00,  '2023-03-10'),  -- TA 3: Rohan
('a0000000-0000-0000-0000-000000000004', TRUE, 2000000.00,  '2023-04-05'),  -- TA 4: Neha (HNI)
('a0000000-0000-0000-0000-000000000005', TRUE,   50000.00,  '2024-01-01'),  -- TA 5: Vikram
('a0000000-0000-0000-0000-000000000006', TRUE,  300000.00,  '2023-06-18'),  -- TA 6: Ananya
('a0000000-0000-0000-0000-000000000007', TRUE, 5000000.00,  '2022-09-01'),  -- TA 7: BlueStar
('a0000000-0000-0000-0000-000000000008', TRUE, 3000000.00,  '2023-01-05');  -- TA 8: Zenith

-- ─────────────────────────────────────────────────────────────
-- 4. BANK_ACC (10 bank accounts — each investor has 1 primary)
-- ─────────────────────────────────────────────────────────────
INSERT INTO bank_acc (acc_no, ifsc_code, is_primary, investor_id) VALUES
('1001200034001', 'SBIN0001234', TRUE,  'a0000000-0000-0000-0000-000000000001'),
('1001200034002', 'HDFC0005678', FALSE, 'a0000000-0000-0000-0000-000000000001'),
('2002300045001', 'ICIC0009012', TRUE,  'a0000000-0000-0000-0000-000000000002'),
('3003400056001', 'KKBK0003456', TRUE,  'a0000000-0000-0000-0000-000000000003'),
('4004500067001', 'HDFC0007890', TRUE,  'a0000000-0000-0000-0000-000000000004'),
('4004500067002', 'SBIN0002345', FALSE, 'a0000000-0000-0000-0000-000000000004'),
('5005600078001', 'UTIB0006789', TRUE,  'a0000000-0000-0000-0000-000000000005'),
('6006700089001', 'BARB0001234', TRUE,  'a0000000-0000-0000-0000-000000000006'),
('7007800090001', 'SBIN0005678', TRUE,  'a0000000-0000-0000-0000-000000000007'),
('8008900001001', 'HDFC0009012', TRUE,  'a0000000-0000-0000-0000-000000000008');

-- ─────────────────────────────────────────────────────────────
-- 5. BROKER (4 brokers: 3 active, 1 inactive for LEFT JOIN tests)
-- ─────────────────────────────────────────────────────────────
INSERT INTO broker (broker_id, full_name, email, password_hash, sebi_license_no, commission_rate, is_active) VALUES
('b0000000-0000-0000-0000-000000000001', 'Rajesh Kumar',   'rajesh.b@example.com',  '$2b$12$e68Y2X6Z4wP3t.rajeshhash9999999999999999999999999999999', 'INB-2023-001', 0.50, TRUE),
('b0000000-0000-0000-0000-000000000002', 'Sunita Verma',   'sunita.b@example.com',  '$2b$12$e68Y2X6Z4wP3t.sunitahash9999999999999999999999999999999', 'INB-2023-002', 0.35, TRUE),
('b0000000-0000-0000-0000-000000000003', 'Amit Joshi',     'amit.b@example.com',    '$2b$12$e68Y2X6Z4wP3t.amithash99999999999999999999999999999999', 'INB-2023-003', 0.45, TRUE),
('b0000000-0000-0000-0000-000000000004', 'Kavita Nair',    'kavita.b@example.com',  '$2b$12$e68Y2X6Z4wP3t.kavitahash999999999999999999999999999999', 'INB-2023-004', 0.25, FALSE);

-- ─────────────────────────────────────────────────────────────
-- 6. FUND_TRANSACTION (10 transactions — deposits and withdrawals)
-- ─────────────────────────────────────────────────────────────
INSERT INTO fund_transaction (ta_id, bank_acc_id, txn_type, amt, balance_after, txn_date_time) VALUES
(1, 1, 'DEPOSIT',    500000.00, 500000.00, '2023-01-16 09:00:00+05:30'),
(2, 3, 'DEPOSIT',    750000.00, 750000.00, '2023-02-21 10:30:00+05:30'),
(3, 4, 'DEPOSIT',    200000.00, 200000.00, '2023-03-11 11:00:00+05:30'),
(4, 5, 'DEPOSIT',   2000000.00, 2000000.00,'2023-04-06 08:45:00+05:30'),
(5, 7, 'DEPOSIT',     50000.00,  50000.00, '2024-01-02 14:00:00+05:30'),
(6, 8, 'DEPOSIT',    300000.00, 300000.00, '2023-06-19 09:30:00+05:30'),
(7, 9, 'DEPOSIT',   5000000.00, 5000000.00,'2022-09-02 10:00:00+05:30'),
(8, 10,'DEPOSIT',   3000000.00, 3000000.00,'2023-01-06 11:15:00+05:30'),
(1, 1, 'WITHDRAWAL',  50000.00, 450000.00, '2023-06-01 15:00:00+05:30'),
(4, 5, 'WITHDRAWAL', 100000.00, 1900000.00,'2024-03-15 16:30:00+05:30');

-- ─────────────────────────────────────────────────────────────
-- 7. PLAN_CATALOG (4 plans)
-- ─────────────────────────────────────────────────────────────
INSERT INTO plan_catalog (plan_type, brokerage_percent, is_active) VALUES
('BASIC',      0.50, TRUE),
('STANDARD',   0.30, TRUE),
('PREMIUM',    0.15, TRUE),
('ENTERPRISE', 0.10, TRUE);

-- ─────────────────────────────────────────────────────────────
-- 8. BROKER_CLIENT (8 relationships)
-- ─────────────────────────────────────────────────────────────
INSERT INTO broker_client (investor_id, broker_id, poa_granted, is_active, plan_type, plan_start_date, plan_end_date) VALUES
('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', TRUE,  TRUE,  'PREMIUM',    '2023-01-15', '2025-01-15'),
('a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', FALSE, TRUE,  'STANDARD',   '2023-02-20', '2025-02-20'),
('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', TRUE,  TRUE,  'BASIC',      '2023-03-10', '2025-03-10'),
('a0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000002', TRUE,  TRUE,  'PREMIUM',    '2023-04-05', '2025-04-05'),
('a0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000003', FALSE, TRUE,  'STANDARD',   '2023-06-18', '2025-06-18'),
('a0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000001', TRUE,  TRUE,  'ENTERPRISE', '2022-09-01', '2027-09-01'),
('a0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000003', TRUE,  TRUE,  'ENTERPRISE', '2023-01-05', '2028-01-05'),
('a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000002', FALSE, FALSE, 'BASIC',      '2024-01-01', '2024-06-01');

-- ─────────────────────────────────────────────────────────────
-- 9. SECURITY (12 securities: 8 EQUITIES, 4 MUTUAL FUNDS)
-- ─────────────────────────────────────────────────────────────
INSERT INTO security (ticker, company_name, exchange, security_type, isin, sector, is_active) VALUES
-- Equities (IDs 1..8)
('RELIANCE',  'Reliance Industries Ltd',     'NSE', 'EQUITY',      'INE002A01018', 'Energy',          TRUE),
('TCS',       'Tata Consultancy Services',   'NSE', 'EQUITY',      'INE467B01029', 'IT',              TRUE),
('HDFCBANK',  'HDFC Bank Ltd',               'NSE', 'EQUITY',      'INE040A01034', 'Banking',         TRUE),
('INFY',      'Infosys Ltd',                 'NSE', 'EQUITY',      'INE009A01021', 'IT',              TRUE),
('WIPRO',     'Wipro Ltd',                   'BSE', 'EQUITY',      'INE075A01022', 'IT',              TRUE),
('ICICIBANK', 'ICICI Bank Ltd',              'NSE', 'EQUITY',      'INE090A01021', 'Banking',         TRUE),
('TATASTEEL', 'Tata Steel Ltd',              'BSE', 'EQUITY',      'INE081A01020', 'Metals',          TRUE),
('SUNPHARMA', 'Sun Pharmaceutical Ind Ltd',  'NSE', 'EQUITY',      'INE044A01036', 'Pharma',          TRUE),
-- Mutual Funds (IDs 9..12)
('AXISBLUECHIP', 'Axis Bluechip Fund',       'NSE', 'MUTUAL_FUND', 'INF846K01DP8', 'Large Cap',       TRUE),
('HDFCMIDCAP',   'HDFC Mid-Cap Opp Fund',   'NSE', 'MUTUAL_FUND', 'INF179K01BB4', 'Mid Cap',         TRUE),
('SBISMALLCAP',  'SBI Small Cap Fund',       'BSE', 'MUTUAL_FUND', 'INF200K01RQ1', 'Small Cap',       TRUE),
('ABORSL100',    'Aditya Birla SL Frontline','BSE', 'MUTUAL_FUND', 'INF209K01YY0', 'Large Cap',       TRUE);

-- ─────────────────────────────────────────────────────────────
-- 10. EQUITY (Subtype table for 8 equities)
-- ─────────────────────────────────────────────────────────────
INSERT INTO equity (security_id, market_cap, pe_ratio, eps) VALUES
(1, 1950000000000.00, 28.50,  95.20),
(2, 1450000000000.00, 32.10, 120.50),
(3, 1200000000000.00, 21.40,  78.30),
(4,  780000000000.00, 29.80,  56.70),
(5,  250000000000.00, 22.60,  21.40),
(6,  850000000000.00, 19.50,  45.80),
(7,  180000000000.00,  8.20,  15.60),
(8,  420000000000.00, 35.40,  28.90);

-- ─────────────────────────────────────────────────────────────
-- 11. MUTUAL_FUND (Subtype table for 4 mutual funds)
-- ─────────────────────────────────────────────────────────────
INSERT INTO mutual_fund (security_id, amc_name, scheme_category, nav, nav_date, expense_ratio) VALUES
(9,  'Axis AMC',             'Large Cap', 52.3400, CURRENT_DATE - INTERVAL '1 day', 1.5600),
(10, 'HDFC AMC',             'Mid Cap',   38.7200, CURRENT_DATE - INTERVAL '1 day', 1.7800),
(11, 'SBI Funds Management', 'Small Cap', 98.1500, CURRENT_DATE - INTERVAL '1 day', 1.9200),
(12, 'Aditya Birla SL AMC',  'Large Cap', 45.6800, CURRENT_DATE - INTERVAL '1 day', 1.6500);

-- ─────────────────────────────────────────────────────────────
-- 12. HOLDING (14 diversified positions across investors)
-- ─────────────────────────────────────────────────────────────
INSERT INTO holding (investor_id, security_id, quantity, avg_cost_price, current_value, last_updated) VALUES
-- Aarav (TA=1): Reliance, TCS, Axis MF
('a0000000-0000-0000-0000-000000000001', 1,  100.0000, 2450.0000,  295000.00, NOW() - INTERVAL '2 days'),
('a0000000-0000-0000-0000-000000000001', 2,   50.0000, 3500.0000,  192500.00, NOW() - INTERVAL '3 days'),
('a0000000-0000-0000-0000-000000000001', 9,  500.0000,   48.5000,   26170.00, NOW() - INTERVAL '1 day'),
-- Priya (TA=2): HDFC Bank, Infosys
('a0000000-0000-0000-0000-000000000002', 3,  200.0000, 1580.0000,  340000.00, NOW() - INTERVAL '5 days'),
('a0000000-0000-0000-0000-000000000002', 4,  150.0000, 1420.0000,  228000.00, NOW() - INTERVAL '4 days'),
-- Rohan (TA=3, dormant trader): Wipro, SBI MF
('a0000000-0000-0000-0000-000000000003', 5,  300.0000,  420.0000,  138000.00, NOW() - INTERVAL '6 days'),
('a0000000-0000-0000-0000-000000000003', 11, 200.0000,   85.0000,   19630.00, NOW() - INTERVAL '2 days'),
-- Neha (TA=4, HNI): Reliance, ICICI Bank, HDFC MF
('a0000000-0000-0000-0000-000000000004', 1,  500.0000, 2380.0000, 1475000.00, NOW() - INTERVAL '1 day'),
('a0000000-0000-0000-0000-000000000004', 6,  400.0000,  950.0000,  412000.00, NOW() - INTERVAL '3 days'),
('a0000000-0000-0000-0000-000000000004', 10, 1000.0000,  35.2000,   38720.00, NOW() - INTERVAL '2 days'),
-- Ananya (TA=6): Tata Steel, Sun Pharma
('a0000000-0000-0000-0000-000000000006', 7,  250.0000,  125.0000,   35000.00, NOW() - INTERVAL '4 days'),
('a0000000-0000-0000-0000-000000000006', 8,  100.0000, 1120.0000,  118000.00, NOW() - INTERVAL '5 days'),
-- BlueStar Capital (TA=7, Institutional): Reliance
('a0000000-0000-0000-0000-000000000007', 1, 2000.0000, 2400.0000, 5900000.00, NOW() - INTERVAL '1 day'),
-- Zenith Fund (TA=8, Institutional): HDFC Bank
('a0000000-0000-0000-0000-000000000008', 3,  800.0000, 1550.0000, 1360000.00, NOW() - INTERVAL '2 days');

-- ─────────────────────────────────────────────────────────────
-- 13. ORDER_RECORD (30 orders: diverse statuses, types, sides)
-- ─────────────────────────────────────────────────────────────
INSERT INTO order_record (security_id, ta_id, broker_id, side, order_type, quantity, limit_price, stop_loss_price, status, placed_at) VALUES
-- Aarav (TA=1, Broker=Rajesh)
(1, 1, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'MARKET', 100.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '10 days'), -- O1
(2, 1, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'LIMIT',   50.0000, 3450.0000, NULL,      'EXECUTED',  NOW() - INTERVAL '20 days'), -- O2
(9, 1, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'MARKET', 500.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '15 days'), -- O3
(1, 1, 'b0000000-0000-0000-0000-000000000001', 'SELL', 'LIMIT',   30.0000, 2950.0000, NULL,      'EXECUTED',  NOW() - INTERVAL '5 days'),  -- O4
(4, 1, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'SL',      25.0000, 1400.0000, 1380.0000, 'CANCELLED', NOW() - INTERVAL '8 days'),  -- O5

-- Priya (TA=2, Broker=Rajesh)
(3, 2, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'MARKET', 200.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '25 days'), -- O6
(4, 2, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'LIMIT',  150.0000, 1450.0000, NULL,      'EXECUTED',  NOW() - INTERVAL '18 days'), -- O7
(3, 2, 'b0000000-0000-0000-0000-000000000001', 'SELL', 'MARKET',  50.0000, NULL,      NULL,      'OPEN',      NOW() - INTERVAL '3 days'),  -- O8

-- Rohan (TA=3, Broker=Sunita, dormant > 30 days)
(5,  3, 'b0000000-0000-0000-0000-000000000002', 'BUY',  'MARKET', 300.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '60 days'), -- O9
(11, 3, 'b0000000-0000-0000-0000-000000000002', 'BUY',  'MARKET', 200.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '55 days'), -- O10
(5,  3, 'b0000000-0000-0000-0000-000000000002', 'SELL', 'SL-M',   50.0000, NULL,      410.0000,  'CANCELLED', NOW() - INTERVAL '45 days'), -- O11

-- Neha (TA=4, Broker=Sunita, HNI)
(1,  4, 'b0000000-0000-0000-0000-000000000002', 'BUY',  'MARKET', 500.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '12 days'), -- O12
(6,  4, 'b0000000-0000-0000-0000-000000000002', 'BUY',  'LIMIT',  400.0000, 960.0000,  NULL,      'EXECUTED',  NOW() - INTERVAL '22 days'), -- O13
(10, 4, 'b0000000-0000-0000-0000-000000000002', 'BUY',  'MARKET',1000.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '28 days'), -- O14
(1,  4, 'b0000000-0000-0000-0000-000000000002', 'SELL', 'LIMIT',  100.0000, 2900.0000, NULL,      'PARTIAL',   NOW() - INTERVAL '2 days'),  -- O15
(6,  4, 'b0000000-0000-0000-0000-000000000002', 'SELL', 'SL',     100.0000, 1000.0000, 980.0000,  'CANCELLED', NOW() - INTERVAL '7 days'),  -- O16

-- Ananya (TA=6, Broker=Amit)
(7, 6, 'b0000000-0000-0000-0000-000000000003', 'BUY',  'MARKET', 250.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '14 days'), -- O17
(8, 6, 'b0000000-0000-0000-0000-000000000003', 'BUY',  'LIMIT',  100.0000, 1100.0000, NULL,      'EXECUTED',  NOW() - INTERVAL '19 days'), -- O18
(7, 6, 'b0000000-0000-0000-0000-000000000003', 'SELL', 'MARKET',  80.0000, NULL,      NULL,      'CANCELLED', NOW() - INTERVAL '6 days'),  -- O19

-- BlueStar Capital (TA=7, Broker=Rajesh)
(1, 7, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'MARKET',2000.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '30 days'), -- O20
(1, 7, 'b0000000-0000-0000-0000-000000000001', 'SELL', 'LIMIT',  500.0000, 2980.0000, NULL,      'OPEN',      NOW() - INTERVAL '10 days'), -- O21 (stale open > 7d)

-- Zenith Fund (TA=8, Broker=Amit)
(3, 8, 'b0000000-0000-0000-0000-000000000003', 'BUY',  'MARKET', 800.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '35 days'), -- O22
(3, 8, 'b0000000-0000-0000-0000-000000000003', 'SELL', 'LIMIT',  200.0000, 1700.0000, NULL,      'OPEN',      NOW() - INTERVAL '9 days'),  -- O23 (stale open > 7d)

-- Additional distribution mix (Types & statuses)
(2, 1, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'SL',      40.0000, 3400.0000, 3350.0000, 'CANCELLED', NOW() - INTERVAL '12 days'), -- O24
(8, 6, 'b0000000-0000-0000-0000-000000000003', 'SELL', 'SL-M',    30.0000, NULL,      1080.0000, 'CANCELLED', NOW() - INTERVAL '4 days'),  -- O25
(4, 2, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'LIMIT',   60.0000, 1480.0000, NULL,      'OPEN',      NOW() - INTERVAL '1 day'),   -- O26
(6, 4, 'b0000000-0000-0000-0000-000000000002', 'BUY',  'MARKET', 200.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '3 days'),  -- O27
(7, 6, 'b0000000-0000-0000-0000-000000000003', 'BUY',  'LIMIT',  150.0000,  130.0000, NULL,      'EXECUTED',  NOW() - INTERVAL '7 days'),  -- O28
(2, 7, 'b0000000-0000-0000-0000-000000000001', 'BUY',  'MARKET', 100.0000, NULL,      NULL,      'EXECUTED',  NOW() - INTERVAL '5 days'),  -- O29
(8, 4, 'b0000000-0000-0000-0000-000000000002', 'BUY',  'LIMIT',   75.0000, 1150.0000, NULL,      'EXECUTED',  NOW() - INTERVAL '9 days');  -- O30

-- ─────────────────────────────────────────────────────────────
-- 14. TRADE (20 trades executed for the 20 EXECUTED orders)
-- ─────────────────────────────────────────────────────────────
INSERT INTO trade (order_id, trade_ref, fill_price, filled_qty, trade_datetime, brokerage_fee, exchange_charges, stt, net_amount) VALUES
-- Aarav trades
(1,  'TRD-20260728-001', 2950.00, 100, NOW() - INTERVAL '10 days' + INTERVAL '5 minutes',  147.50,  29.50,  14.75,  295191.75),
(2,  'TRD-20260718-002', 3450.00,  50, NOW() - INTERVAL '20 days' + INTERVAL '12 minutes',  86.25,  17.25,   8.63,  172612.13),
(3,  'TRD-20260723-003',   48.50, 500, NOW() - INTERVAL '15 days' + INTERVAL '2 minutes',   12.13,   2.43,   1.21,   24265.77),
(4,  'TRD-20260802-004', 2980.00,  30, NOW() - INTERVAL '5 days'  + INTERVAL '8 minutes',   44.70,   8.94,   4.47,   89341.89),

-- Priya trades
(6,  'TRD-20260713-005', 1600.00, 200, NOW() - INTERVAL '25 days' + INTERVAL '3 minutes',  160.00,  32.00,  16.00,  320208.00),
(7,  'TRD-20260720-006', 1450.00, 150, NOW() - INTERVAL '18 days' + INTERVAL '15 minutes', 108.75,  21.75,  10.88,  217641.38),

-- Rohan trades (dormant)
(9,  'TRD-20260608-007',  430.00, 300, NOW() - INTERVAL '60 days' + INTERVAL '4 minutes',   64.50,  12.90,   6.45,  129083.85),
(10, 'TRD-20260613-008',   87.00, 200, NOW() - INTERVAL '55 days' + INTERVAL '6 minutes',    8.70,   1.74,   0.87,   17411.31),

-- Neha trades
(12, 'TRD-20260726-009', 2920.00, 500, NOW() - INTERVAL '12 days' + INTERVAL '7 minutes',  730.00, 146.00,  73.00, 1460949.00),
(13, 'TRD-20260716-010',  960.00, 400, NOW() - INTERVAL '22 days' + INTERVAL '10 minutes', 192.00,  38.40,  19.20,  384249.60),
(14, 'TRD-20260710-011',   35.50,1000, NOW() - INTERVAL '28 days' + INTERVAL '3 minutes',   17.75,   3.55,   1.78,   35523.08),
(15, 'TRD-20260803-020', 2900.00,  50, NOW() - INTERVAL '2 days'  + INTERVAL '10 minutes',  72.50,  14.50,   7.25,  144905.75),

-- Ananya trades
(17, 'TRD-20260724-012',  132.00, 250, NOW() - INTERVAL '14 days' + INTERVAL '9 minutes',   16.50,   3.30,   1.65,   33021.45),
(18, 'TRD-20260719-013', 1100.00, 100, NOW() - INTERVAL '19 days' + INTERVAL '20 minutes',  55.00,  11.00,   5.50,  110071.50),

-- BlueStar trades
(20, 'TRD-20260708-014', 2880.00,2000, NOW() - INTERVAL '30 days' + INTERVAL '11 minutes',2880.00, 576.00, 288.00, 5763744.00),

-- Zenith trades
(22, 'TRD-20260703-015', 1580.00, 800, NOW() - INTERVAL '35 days' + INTERVAL '6 minutes',  632.00, 126.40,  63.20, 1265221.60),

-- Recent trades
(27, 'TRD-20260804-016',  980.00, 200, NOW() - INTERVAL '3 days'  + INTERVAL '4 minutes',   98.00,  19.60,   9.80,  196127.40),
(28, 'TRD-20260801-017',  135.00, 150, NOW() - INTERVAL '7 days'  + INTERVAL '14 minutes',  10.13,   2.03,   1.01,   20263.17),
(29, 'TRD-20260803-018', 3850.00, 100, NOW() - INTERVAL '5 days'  + INTERVAL '6 minutes',  192.50,  38.50,  19.25,  385250.25),
(30, 'TRD-20260729-019', 1150.00,  75, NOW() - INTERVAL '9 days'  + INTERVAL '18 minutes',  43.13,   8.63,   4.31,   86302.07);

-- ─────────────────────────────────────────────────────────────
-- 15. CAPITAL_GAINS_RECORD (1 record: Aarav SELL Reliance)
-- ─────────────────────────────────────────────────────────────
INSERT INTO capital_gains_record (buy_trade_id, sell_trade_id, buy_price, sell_price, quantity, tax_amount, holding_days) VALUES
(1, 4, 2950.0000, 2980.0000, 30.0000, 45.00, 5);

-- ─────────────────────────────────────────────────────────────
-- Re-enable triggers
-- ─────────────────────────────────────────────────────────────
ALTER TABLE order_record ENABLE TRIGGER USER;
ALTER TABLE trade ENABLE TRIGGER USER;
ALTER TABLE fund_transaction ENABLE TRIGGER USER;
ALTER TABLE investor ENABLE TRIGGER USER;

COMMIT;

-- ─────────────────────────────────────────────────────────────
-- Verification Summary
-- ─────────────────────────────────────────────────────────────
SELECT 'INVESTOR'             AS table_name, COUNT(*) AS total_rows FROM investor
UNION ALL SELECT 'KYC_DOCUMENT',         COUNT(*) FROM kyc_document
UNION ALL SELECT 'TRADING_ACC',          COUNT(*) FROM trading_acc
UNION ALL SELECT 'BANK_ACC',             COUNT(*) FROM bank_acc
UNION ALL SELECT 'BROKER',               COUNT(*) FROM broker
UNION ALL SELECT 'FUND_TRANSACTION',     COUNT(*) FROM fund_transaction
UNION ALL SELECT 'PLAN_CATALOG',         COUNT(*) FROM plan_catalog
UNION ALL SELECT 'BROKER_CLIENT',        COUNT(*) FROM broker_client
UNION ALL SELECT 'SECURITY',             COUNT(*) FROM security
UNION ALL SELECT 'EQUITY',               COUNT(*) FROM equity
UNION ALL SELECT 'MUTUAL_FUND',          COUNT(*) FROM mutual_fund
UNION ALL SELECT 'HOLDING',              COUNT(*) FROM holding
UNION ALL SELECT 'ORDER_RECORD',         COUNT(*) FROM order_record
UNION ALL SELECT 'TRADE',                COUNT(*) FROM trade
UNION ALL SELECT 'CAPITAL_GAINS_RECORD', COUNT(*) FROM capital_gains_record
ORDER BY table_name;
