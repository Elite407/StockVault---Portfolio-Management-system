-- test_rls.sql
-- This script tests the Row Level Security (RLS) policies.
-- Note: RLS is bypassed by superusers, so we create a temporary non-superuser role to test it.

\set ON_ERROR_STOP on

BEGIN;

CREATE ROLE test_rls_user NOSUPERUSER NOLOGIN;
GRANT USAGE ON SCHEMA trading TO test_rls_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA trading TO test_rls_user;

SET search_path TO trading;

DO $$
DECLARE
    inv1_id UUID;
    inv2_id UUID;
    brk1_id UUID;
    sec_id BIGINT;
    count_val INT;
BEGIN
    RAISE NOTICE '--- Starting RLS Tests ---';

    -- 1. Setup Mock Data (done as superuser to bypass RLS for setup)
    INSERT INTO INVESTOR (FULL_NAME, EMAIL, PASSWORD_HASH, PAN_NO, AADHAR_NO, DOB, KYC_STATUS, INVESTOR_TYPE)
    VALUES ('RLS Investor 1', 'rls1@test.com', 'hash', 'RLSPAN0001', 'RLSAAD000001', '1990-01-01', 'VERIFIED', 'RETAIL')
    RETURNING INVESTOR_ID INTO inv1_id;

    INSERT INTO INVESTOR (FULL_NAME, EMAIL, PASSWORD_HASH, PAN_NO, AADHAR_NO, DOB, KYC_STATUS, INVESTOR_TYPE)
    VALUES ('RLS Investor 2', 'rls2@test.com', 'hash', 'RLSPAN0002', 'RLSAAD000002', '1992-01-01', 'VERIFIED', 'RETAIL')
    RETURNING INVESTOR_ID INTO inv2_id;

    INSERT INTO BROKER (FULL_NAME, EMAIL, PASSWORD_HASH, SEBI_LICENSE_NO, COMMISSION_RATE)
    VALUES ('RLS Broker 1', 'brk1@test.com', 'hash', 'SEBIRLS001', 0.5)
    RETURNING BROKER_ID INTO brk1_id;
    
    INSERT INTO SECURITY (TICKER, COMPANY_NAME, EXCHANGE, SECURITY_TYPE, ISIN)
    VALUES ('RLSTEST', 'RLS Test Corp', 'NSE', 'EQUITY', 'INE0RLS00001')
    RETURNING SECURITY_ID INTO sec_id;

    -- 2. Switch to non-superuser role
    SET LOCAL ROLE test_rls_user;

    -- 3. Test Investor 1 Context
    PERFORM set_config('app.current_user_id', inv1_id::text, true);
    
    -- Should see only own record
    SELECT count(*) INTO count_val FROM INVESTOR;
    IF count_val <> 1 THEN
        RAISE EXCEPTION 'Investor 1 saw % investor records instead of 1', count_val;
    END IF;
    
    -- Should NOT see Investor 2
    SELECT count(*) INTO count_val FROM INVESTOR WHERE INVESTOR_ID = inv2_id;
    IF count_val > 0 THEN
        RAISE EXCEPTION 'Investor 1 saw Investor 2 record!';
    END IF;

    -- Should see public SECURITY data
    SELECT count(*) INTO count_val FROM SECURITY WHERE TICKER = 'RLSTEST';
    IF count_val = 0 THEN
        RAISE EXCEPTION 'Investor 1 could not see public SECURITY data';
    END IF;

    -- 4. Test Broker 1 Context
    PERFORM set_config('app.current_user_id', brk1_id::text, true);

    -- Should see only own broker record
    SELECT count(*) INTO count_val FROM BROKER;
    IF count_val <> 1 THEN
        RAISE EXCEPTION 'Broker 1 saw % broker records instead of 1', count_val;
    END IF;

    RAISE NOTICE '--- All RLS Tests Passed ---';
END;
$$;

ROLLBACK;
