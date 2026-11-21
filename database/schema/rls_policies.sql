-- RLS Policies for StockVault
SET search_path TO trading;

-- Helper function to safely get the current user ID
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_user_id', true), '')::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- Enable RLS on all tables
ALTER TABLE INVESTOR ENABLE ROW LEVEL SECURITY;
ALTER TABLE KYC_DOCUMENT ENABLE ROW LEVEL SECURITY;
ALTER TABLE TRADING_ACC ENABLE ROW LEVEL SECURITY;
ALTER TABLE BANK_ACC ENABLE ROW LEVEL SECURITY;
ALTER TABLE BROKER ENABLE ROW LEVEL SECURITY;
ALTER TABLE FUND_TRANSACTION ENABLE ROW LEVEL SECURITY;
ALTER TABLE PLAN_CATALOG ENABLE ROW LEVEL SECURITY;
ALTER TABLE BROKER_CLIENT ENABLE ROW LEVEL SECURITY;
ALTER TABLE SECURITY ENABLE ROW LEVEL SECURITY;
ALTER TABLE EQUITY ENABLE ROW LEVEL SECURITY;
ALTER TABLE MUTUAL_FUND ENABLE ROW LEVEL SECURITY;
ALTER TABLE HOLDING ENABLE ROW LEVEL SECURITY;
ALTER TABLE ORDER_RECORD ENABLE ROW LEVEL SECURITY;
ALTER TABLE TRADE ENABLE ROW LEVEL SECURITY;
ALTER TABLE CAPITAL_GAINS_RECORD ENABLE ROW LEVEL SECURITY;

-------------------------------------------------------------------------------
-- 1. Public Tables (Readable by all authenticated users)
-------------------------------------------------------------------------------
-- Assuming any authenticated user can read securities and plans.
CREATE POLICY p_security_select ON SECURITY FOR SELECT USING (true);
CREATE POLICY p_equity_select ON EQUITY FOR SELECT USING (true);
CREATE POLICY p_mutual_fund_select ON MUTUAL_FUND FOR SELECT USING (true);
CREATE POLICY p_plan_catalog_select ON PLAN_CATALOG FOR SELECT USING (true);

-------------------------------------------------------------------------------
-- 2. INVESTOR Policies
-------------------------------------------------------------------------------
-- INVESTOR table
CREATE POLICY p_investor_select ON INVESTOR FOR SELECT 
    USING (INVESTOR_ID = get_current_user_id());
CREATE POLICY p_investor_update ON INVESTOR FOR UPDATE 
    USING (INVESTOR_ID = get_current_user_id());

-- KYC_DOCUMENT
CREATE POLICY p_kyc_document_select ON KYC_DOCUMENT FOR SELECT 
    USING (INVESTOR_ID = get_current_user_id());

-- TRADING_ACC
CREATE POLICY p_trading_acc_select ON TRADING_ACC FOR SELECT 
    USING (INVESTOR_ID = get_current_user_id());

-- BANK_ACC
CREATE POLICY p_bank_acc_select ON BANK_ACC FOR SELECT 
    USING (INVESTOR_ID = get_current_user_id());

-- HOLDING
CREATE POLICY p_holding_select ON HOLDING FOR SELECT 
    USING (INVESTOR_ID = get_current_user_id());

-- FUND_TRANSACTION
CREATE POLICY p_fund_txn_select ON FUND_TRANSACTION FOR SELECT 
    USING (TA_ID IN (
        SELECT TA_ID FROM TRADING_ACC 
        WHERE INVESTOR_ID = get_current_user_id()
    ));

-- BROKER_CLIENT
CREATE POLICY p_broker_client_investor_select ON BROKER_CLIENT FOR SELECT 
    USING (INVESTOR_ID = get_current_user_id());
CREATE POLICY p_broker_client_investor_update ON BROKER_CLIENT FOR UPDATE 
    USING (INVESTOR_ID = get_current_user_id());

-- ORDER_RECORD
CREATE POLICY p_order_record_investor_select ON ORDER_RECORD FOR SELECT 
    USING (TA_ID IN (
        SELECT TA_ID FROM TRADING_ACC 
        WHERE INVESTOR_ID = get_current_user_id()
    ));

-- TRADE
CREATE POLICY p_trade_investor_select ON TRADE FOR SELECT 
    USING (ORDER_ID IN (
        SELECT ORDER_ID FROM ORDER_RECORD 
        WHERE TA_ID IN (
            SELECT TA_ID FROM TRADING_ACC 
            WHERE INVESTOR_ID = get_current_user_id()
        )
    ));

-- CAPITAL_GAINS_RECORD
CREATE POLICY p_cg_record_investor_select ON CAPITAL_GAINS_RECORD FOR SELECT 
    USING (BUY_TRADE_ID IN (
        SELECT TRADE_ID FROM TRADE 
        WHERE ORDER_ID IN (
            SELECT ORDER_ID FROM ORDER_RECORD 
            WHERE TA_ID IN (
                SELECT TA_ID FROM TRADING_ACC 
                WHERE INVESTOR_ID = get_current_user_id()
            )
        )
    ));

-------------------------------------------------------------------------------
-- 3. BROKER Policies
-------------------------------------------------------------------------------
-- BROKER table
CREATE POLICY p_broker_select ON BROKER FOR SELECT 
    USING (BROKER_ID = get_current_user_id());
CREATE POLICY p_broker_update ON BROKER FOR UPDATE 
    USING (BROKER_ID = get_current_user_id());

-- BROKER_CLIENT (Brokers can see their clients)
CREATE POLICY p_broker_client_broker_select ON BROKER_CLIENT FOR SELECT 
    USING (BROKER_ID = get_current_user_id());

-- ORDER_RECORD (Brokers can see orders placed through them)
CREATE POLICY p_order_record_broker_select ON ORDER_RECORD FOR SELECT 
    USING (BROKER_ID = get_current_user_id());

-- TRADE (Brokers can see trades from their orders)
CREATE POLICY p_trade_broker_select ON TRADE FOR SELECT 
    USING (ORDER_ID IN (
        SELECT ORDER_ID FROM ORDER_RECORD 
        WHERE BROKER_ID = get_current_user_id()
    ));
