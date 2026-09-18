-- ============================================================
-- Risk, Fraud & Regulatory Intelligence Copilot
-- Step 3: RAG Pipeline - Embeddings & Cortex Search Service
-- ============================================================

USE SCHEMA RISK_COPILOT.PUBLIC;

-- Add vector column for embeddings
ALTER TABLE REGULATORY_CHUNKS 
ADD COLUMN CHUNK_EMBEDDING VECTOR(FLOAT, 768);

-- Generate embeddings using Snowflake Cortex
UPDATE REGULATORY_CHUNKS
SET CHUNK_EMBEDDING = SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', CHUNK_TEXT);

-- Create Cortex Search Service for hybrid (semantic + keyword) retrieval
CREATE OR REPLACE CORTEX SEARCH SERVICE REGULATORY_SEARCH_SERVICE
  ON CHUNK_TEXT
  ATTRIBUTES DOC_NAME, DOC_TYPE
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT CHUNK_TEXT, DOC_NAME, DOC_TYPE, CHUNK_ID
    FROM REGULATORY_CHUNKS
  );
