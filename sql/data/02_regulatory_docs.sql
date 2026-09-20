-- ============================================================
-- Risk, Fraud & Regulatory Intelligence Copilot
-- Step 2: Synthetic Regulatory Documents & Chunks
-- ============================================================

USE SCHEMA RISK_COPILOT.PUBLIC;

CREATE OR REPLACE STAGE REGULATORY_DOCS;

CREATE OR REPLACE TABLE REGULATORY_CHUNKS (
    CHUNK_ID INT,
    DOC_NAME VARCHAR(100),
    DOC_TYPE VARCHAR(50),
    CHUNK_INDEX INT,
    CHUNK_TEXT VARCHAR(4000)
);

-- See 01_setup_data.sql companion or run the full INSERT statements
-- 18 chunks across 3 documents:
--   AML_CFT_POLICY (8 chunks): CTR, SAR, CDD/EDD, PEP, jurisdictions, monitoring rules, escalation
--   BASEL_III_LIQUIDITY (5 chunks): LCR, HQLA, cash outflows, stress scenarios, NSFR
--   INTERNAL_RISK_POLICY (5 chunks): risk appetite, 3 lines of defense, SLAs, evidence standards, AI copilot guidelines
