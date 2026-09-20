# Risk, Fraud & Regulatory Intelligence Copilot

An AI-powered compliance investigation platform built entirely on Snowflake's native AI and data engine. Combines structured transaction monitoring with unstructured regulatory document intelligence via Retrieval-Augmented Generation (RAG), surfaced through a Streamlit-in-Snowflake interface.

**Built end-to-end with Cortex Code (CoCo)** -- every line of SQL, Python, and config was authored, tested, deployed, and pushed to GitHub through CoCo Desktop.

## Architecture

```
 [ Structured Data ]              [ Unstructured Data ]
 (Transactions/Accounts)        (AML Policies / Basel Docs)
          |                               |
          v                               v
  Snowflake Tables              Cortex Search Service (RAG)
  + Dynamic Tables              (REGULATORY_CHUNKS + Embeddings
  + Streams + Tasks               via EMBED_TEXT_768 / e5-base-v2)
          |                               |
          +---------------+---------------+
                          |
                          v
            Snowflake Cortex LLM Router
            (CORTEX.COMPLETE - llama3.1-70b)
            + Semantic View + Verified Queries
            + Data Governance (RBAC, Masking)
                          |
                          v
            Streamlit-in-Snowflake Copilot UI
            (4-page app: Dashboard > Investigation
             > Regulatory Chat > Audit Trail)
```

## Snowflake Features Used

| Feature | Purpose |
|---------|---------|
| **Cortex Search Service** | Hybrid semantic + keyword retrieval over regulatory document corpus |
| **CORTEX.EMBED_TEXT_768** | Vector embeddings (e5-base-v2) for RAG pipeline |
| **CORTEX.COMPLETE** | LLM-powered evidence generation and regulatory Q&A (llama3.1-70b) |
| **Semantic View** | Ontology with entities, relationships, dimensions, metrics, and verified queries |
| **Dynamic Tables** | Real-time customer risk summary with 1-minute target lag |
| **Streams** | CDC on TRANSACTIONS table for incremental alert detection |
| **Tasks (Scheduled)** | Automated structuring detection (15-min) and daily risk score refresh |
| **Streamlit in Snowflake** | Native copilot UI with 4 pages |
| **Dynamic Data Masking** | PII protection (name, email, phone, address) via masking policies |
| **Object Tagging** | SNOWFLAKE.CORE.SEMANTIC_CATEGORY tags on sensitive columns |
| **RBAC** | RISK_ANALYST and RISK_AUDITOR roles with scoped privileges |

## What It Does

### 1. Risk Dashboard
- KPI metric cards: open alerts, critical/high severity counts, resolved alerts
- Filterable alert table by severity and status
- Risk score distribution chart and alert type breakdown

### 2. Transaction Investigation
- Drill into any open alert to see full transaction timeline
- Customer profile and composite risk scores (behavioral, jurisdictional, network)
- **One-click AI Evidence Report** generation:
  - Gathers transaction context for the alert
  - Retrieves relevant regulatory excerpts via RAG (Cortex Search Service)
  - Calls Cortex LLM to generate a structured investigation memo with regulatory citations

### 3. Regulatory Copilot Chat
- Natural language Q&A grounded in the regulatory document corpus
- Questions like: "What are the SAR filing thresholds?" or "What does Basel III say about LCR?"
- Answers cite specific document sections with expandable source references

### 4. Audit Trail
- Complete log of all AI-assisted actions (evidence generation, chat queries)
- Stores: user query, RAG context retrieved, LLM response, timestamp, user
- Filterable and exportable as CSV for compliance documentation

## Fraud Patterns Detected

| Pattern | Description | Detection |
|---------|-------------|-----------|
| **Structuring** | Multiple sub-$10k cash deposits across branches | V_STRUCTURING_ALERTS view + automated task |
| **Rapid International Transfers** | $740k+ wired to 5 countries in 30 hours | Alert-based |
| **Round-Tripping** | Circular fund flows between Panama and Belize shell company | Alert-based |
| **Dormant Reactivation** | Account inactive 3+ years suddenly moves $160k | V_DORMANT_REACTIVATION view |
| **Velocity Spike** | 8 wire transfers to 8 countries in 3.5 hours | V_VELOCITY_ANOMALIES view |
| **Layering** | Sequential decreasing transfers through 5 jurisdictions | Alert-based |

## Data Pipeline & Automation

| Component | Type | Schedule | Description |
|-----------|------|----------|-------------|
| `TRANSACTIONS_STREAM` | Stream | Real-time CDC | Captures new transactions as they arrive |
| `DT_CUSTOMER_RISK_SUMMARY` | Dynamic Table | 1-min lag | Auto-refreshing customer risk aggregation |
| `TASK_AUTO_ALERT_DETECTION` | Task | Every 15 min | Auto-generates structuring alerts from stream |
| `TASK_DAILY_RISK_REFRESH` | Task | Daily 6AM UTC | Recalculates all customer risk scores |

## Semantic Model

`SV_RISK_INTELLIGENCE` semantic view with:
- **4 entities**: customers, transactions, alerts, risk_scores
- **3 relationships**: transaction-to-customer, alert-to-customer, score-to-customer
- **13 dimensions**: country, risk tier, KYC status, PEP flag, transaction type, severity, etc.
- **5 metrics**: total volume, avg amount, transaction count, alert count, avg risk score
- **4 verified queries**: open alerts, critical customers, structuring detection, high-risk wires

## Validation & Testing

All 8 automated tests pass (see `sql/tests/08_validation_tests.sql`):

| Test | What It Validates | Result |
|------|-------------------|--------|
| Structuring Detection | V_STRUCTURING_ALERTS catches CUST-002 | PASS |
| Dormant Reactivation | V_DORMANT_REACTIVATION catches CUST-015 | PASS |
| High-Risk Jurisdiction | V_HIGH_RISK_JURISDICTIONS catches CUST-003 | PASS |
| Dynamic Table | DT_CUSTOMER_RISK_SUMMARY has all 20 customers | PASS |
| RAG Embeddings | All 18 chunks have vector embeddings | PASS |
| LLM Response | CORTEX.COMPLETE generates coherent output | PASS |
| Semantic View VQ | Verified query returns open alerts | PASS |
| Masking Policy | PII columns masked for non-analyst roles | PASS |

## Setup Instructions

### Prerequisites
- Snowflake account with Cortex AI features enabled
- ACCOUNTADMIN role (or equivalent)
- A warehouse named `COMPUTE_WH` (or modify scripts)

### Step-by-Step Deployment

```bash
git clone https://github.com/rdevath21/risk-fraud-regulatory-intelligence-copilot.git
cd risk-fraud-regulatory-intelligence-copilot
```

Run SQL scripts in order via Snowsight:

```sql
-- 1. Database, tables, synthetic data
-- Run: sql/data/01_setup_data.sql
-- Run: sql/data/02_regulatory_docs.sql

-- 2. RAG pipeline + detection views
-- Run: sql/pipeline/03_rag_pipeline.sql
-- Run: sql/pipeline/04_risk_detection.sql

-- 3. Data pipeline automation
-- Run: sql/pipeline/06_pipeline_automation.sql

-- 4. Semantic view
-- Run: sql/pipeline/07_semantic_view.sql

-- 5. Governance
-- Run: sql/governance/05_governance.sql

-- 6. Validation
-- Run: sql/tests/08_validation_tests.sql
```

Deploy the Streamlit app:

```sql
CREATE OR REPLACE STAGE RISK_COPILOT.PUBLIC.STREAMLIT_STAGE;
PUT 'file:///path/to/app/streamlit_app.py' @RISK_COPILOT.PUBLIC.STREAMLIT_STAGE
    AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

CREATE OR REPLACE STREAMLIT RISK_COPILOT.PUBLIC.RISK_FRAUD_COPILOT
  ROOT_LOCATION = '@RISK_COPILOT.PUBLIC.STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH;
```

Open in Snowsight: **Projects > Streamlit > RISK_FRAUD_COPILOT**

## Project Structure

```
risk-fraud-regulatory-intelligence-copilot/
|
|-- app/
|   |-- streamlit_app.py          # 4-page Streamlit-in-Snowflake copilot UI
|   |-- snowflake.yml             # SiS deployment manifest
|
|-- sql/
|   |-- data/
|   |   |-- 01_setup_data.sql     # Database, tables, synthetic transaction/customer data
|   |   |-- 02_regulatory_docs.sql # Regulatory document chunks for RAG
|   |
|   |-- pipeline/
|   |   |-- 03_rag_pipeline.sql    # Vector embeddings + Cortex Search Service
|   |   |-- 04_risk_detection.sql  # Detection views + audit log table
|   |   |-- 06_pipeline_automation.sql # Stream, dynamic table, scheduled tasks
|   |   |-- 07_semantic_view.sql   # Semantic view with verified queries
|   |
|   |-- governance/
|   |   |-- 05_governance.sql      # RBAC roles, PII tags, masking policies
|   |
|   |-- tests/
|       |-- 08_validation_tests.sql # 8 automated validation tests
|
|-- .gitignore
|-- README.md
```

## CoCo (Cortex Code) Capabilities Demonstrated

| Capability | How It Was Used |
|------------|----------------|
| **Synthetic data generation** | Generated 20 customers, 50 transactions with 6 fraud patterns, risk scores, and alerts |
| **Data pipeline creation** | Built stream + dynamic table + 2 scheduled tasks for incremental processing |
| **Semantic model authoring** | Created semantic view with entities, relationships, metrics, and verified queries |
| **Streamlit app generation** | Scaffolded and deployed 4-page SiS app with RAG chat and evidence generation |
| **Document processing** | Created regulatory document corpus, chunked it, generated embeddings, built search service |
| **Automations** | Scheduled tasks: 15-min alert detection + daily risk refresh, both running unattended |
| **Testing & validation** | 8 automated tests covering detection views, RAG, LLM, dynamic table, semantic view |
| **Guardrails** | PII masking, RBAC roles, audit logging, RAG-grounded answers with source citations |

## Snowflake Objects Created

| Object | Type |
|--------|------|
| `CUSTOMERS`, `TRANSACTIONS`, `RISK_SCORES`, `ALERTS` | Tables |
| `REGULATORY_CHUNKS` | Table (with VECTOR column) |
| `COPILOT_AUDIT_LOG` | Table |
| `DT_CUSTOMER_RISK_SUMMARY` | Dynamic Table |
| `TRANSACTIONS_STREAM` | Stream |
| `TASK_AUTO_ALERT_DETECTION` | Task (15-min) |
| `TASK_DAILY_RISK_REFRESH` | Task (daily) |
| `REGULATORY_SEARCH_SERVICE` | Cortex Search Service |
| `SV_RISK_INTELLIGENCE` | Semantic View |
| `V_STRUCTURING_ALERTS`, `V_VELOCITY_ANOMALIES`, `V_HIGH_RISK_JURISDICTIONS`, `V_DORMANT_REACTIVATION` | Views |
| `PII_MASK` | Masking Policy |
| `RISK_ANALYST`, `RISK_AUDITOR` | Roles |
| `RISK_FRAUD_COPILOT` | Streamlit App |

## License

MIT
