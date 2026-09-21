---
name: risk-copilot-deploy
description: Deploy the complete Risk, Fraud & Regulatory Intelligence Copilot to a Snowflake account. Creates all objects end-to-end.
user_invocable: true
---

# Risk Copilot Deploy

Deploy a complete Risk, Fraud & Regulatory Intelligence Copilot to any Snowflake account.

## What This Skill Creates

1. **Database & Synthetic Data** - `RISK_COPILOT.PUBLIC` with 4 tables: CUSTOMERS (20), TRANSACTIONS (50 with 6 fraud patterns), RISK_SCORES, ALERTS (10)
2. **Regulatory RAG Pipeline** - 18 document chunks from AML/CFT, Basel III, and internal risk policies, embedded with `EMBED_TEXT_768`, indexed in a Cortex Search Service
3. **Detection Views** - 4 views: structuring, velocity anomalies, high-risk jurisdictions, dormant reactivation
4. **Data Pipeline** - Stream on transactions + dynamic table + 2 scheduled tasks (15-min alert detection, daily risk refresh)
5. **Semantic View** - 4 entities, 13 dimensions, 5 metrics, 4 verified queries
6. **Cortex Agent** - Wraps semantic view + search service, works across Snowsight, CoCo, MCP
7. **MCP Server** - Exposes agent to Claude, ChatGPT, Cursor, Slack
8. **Streamlit App** - 4-page copilot: dashboard, investigation with AI evidence generation, regulatory chat, audit trail
9. **Governance** - RBAC roles, PII tags, masking policies, audit log

## Prerequisites

- Snowflake account with Cortex AI features enabled
- ACCOUNTADMIN role (or equivalent)
- A warehouse (default: `COMPUTE_WH`)

## Steps

### Step 1: Confirm Configuration

Ask the user:
- **Warehouse name**: Default `COMPUTE_WH`
- **Database name**: Default `RISK_COPILOT`

### Step 2: Run SQL Scripts

Execute the following SQL scripts in order from the project repository. Each script is self-contained and idempotent (uses CREATE OR REPLACE).

```
sql/data/01_setup_data.sql          -- Database, tables, synthetic data
sql/data/02_regulatory_docs.sql     -- Regulatory document chunks
sql/pipeline/03_rag_pipeline.sql    -- Embeddings + Cortex Search Service
sql/pipeline/04_risk_detection.sql  -- Detection views + audit log
sql/pipeline/06_pipeline_automation.sql -- Stream, dynamic table, tasks
sql/pipeline/07_semantic_view.sql   -- Semantic view + verified queries
sql/pipeline/09_agent_mcp.sql       -- Cortex Agent + MCP Server
sql/governance/05_governance.sql    -- RBAC, tags, masking policies
```

### Step 3: Deploy Streamlit App

```sql
CREATE OR REPLACE STAGE <DATABASE>.PUBLIC.STREAMLIT_STAGE;
PUT 'file:///path/to/app/streamlit_app.py' @<DATABASE>.PUBLIC.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
CREATE OR REPLACE STREAMLIT <DATABASE>.PUBLIC.RISK_FRAUD_COPILOT
  ROOT_LOCATION = '@<DATABASE>.PUBLIC.STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = <WAREHOUSE>;
```

### Step 4: Run Validation Tests

```sql
-- Execute sql/tests/08_validation_tests.sql
-- All 8 tests should return PASS
```

### Step 5: Verify All Surfaces

1. **Streamlit**: Open Snowsight > Projects > Streamlit > RISK_FRAUD_COPILOT
2. **Agent**: Open Snowsight > AI & ML > Cortex Agents > RISK_INTELLIGENCE_AGENT
3. **MCP**: Connect any MCP client to `https://<account>/api/v2/databases/RISK_COPILOT/schemas/PUBLIC/mcp-servers/RISK_COPILOT_MCP_SERVER`

## Output

After deployment, the user has:
- A working 4-page Streamlit copilot
- A Cortex Agent accessible from 5 surfaces
- An MCP server for external tool integration
- Automated alert detection running every 15 minutes
- Daily risk score refresh at 6AM UTC
- Full governance with RBAC and PII masking
