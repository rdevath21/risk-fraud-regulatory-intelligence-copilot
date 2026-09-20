# Risk, Fraud & Regulatory Intelligence Copilot

> AI-powered compliance investigation platform built entirely on Snowflake's native AI stack, authored end-to-end with **Cortex Code (CoCo)**.

---

## What This Project Does

A risk analyst opens the Streamlit copilot, sees flagged alerts (structuring, layering, round-tripping), clicks **"Generate Evidence Report"**, and gets a fully cited investigation memo in seconds -- grounded in the institution's actual regulatory documents via RAG. They can also chat with the regulatory corpus in natural language and every interaction is audit-logged.

---

## Architecture

```
+---------------------------------------------------------------------+
|                        CORTEX CODE (CoCo)                           |
|  Orchestrates everything: data gen, pipelines, app, tests, deploy   |
+---------------------------------------------------------------------+
        |               |               |               |
        v               v               v               v
+-------------+  +-------------+  +-------------+  +-------------+
|  SYNTHETIC  |  |     RAG     |  |  DETECTION  |  |  SCHEDULED  |
|    DATA     |  |  PIPELINE   |  |    LAYER    |  | AUTOMATION  |
| 20 customers|  | 18 doc      |  | 4 detection |  | Stream +    |
| 50 txns     |  |   chunks    |  |   views     |  |  2 tasks    |
| 10 alerts   |  | Embeddings  |  | Semantic    |  | Dynamic     |
| 6 fraud     |  |   (768-dim) |  |   View + 4  |  |   table     |
|   patterns  |  | Cortex      |  |   verified  |  | 15-min auto |
|             |  |   Search    |  |   queries   |  |   alerts    |
+------+------+  +------+------+  +------+------+  +------+------+
       |                |                |                |
       +--------+-------+--------+-------+--------+-------+
                |                |                |
                v                v                v
+---------------------------------------------------------------------+
|                    SNOWFLAKE CORTEX AI ENGINE                       |
|                                                                     |
|  CORTEX.COMPLETE     CORTEX.EMBED_TEXT_768    CORTEX SEARCH SERVICE |
|  (llama3.1-70b)      (e5-base-v2)             (hybrid retrieval)   |
|  Evidence reports     Vector embeddings        Semantic + keyword   |
|  Regulatory Q&A       for RAG pipeline         search over docs    |
+---------------------------------------------------------------------+
                |                                      |
                v                                      v
+-----------------------------------+  +-----------------------------------+
|   STREAMLIT-IN-SNOWFLAKE APP      |  |   MCP CONNECTOR (CoCo Plugin)    |
|                                   |  |                                   |
|   Page 1: Risk Dashboard          |  |   Filesystem MCP server           |
|   Page 2: Transaction Investigation|  |   Exports evidence reports        |
|   Page 3: Regulatory Chat (RAG)   |  |   to local reports/ directory     |
|   Page 4: Audit Trail             |  |   for compliance archival         |
+-----------------------------------+  +-----------------------------------+
                |                                      |
                v                                      v
+---------------------------------------------------------------------+
|                     GOVERNANCE LAYER                                |
|                                                                     |
|   RBAC: RISK_ANALYST + RISK_AUDITOR roles                          |
|   PII Masking: name, email, phone, address                         |
|   Object Tags: SNOWFLAKE.CORE.SEMANTIC_CATEGORY                    |
|   Audit Log: every AI interaction recorded                         |
+---------------------------------------------------------------------+
```

---

## Snowflake Features Used

| Category | Feature | How It's Used |
|----------|---------|---------------|
| **AI** | `CORTEX.COMPLETE` (llama3.1-70b) | Generates investigation evidence reports and answers regulatory questions |
| **AI** | `CORTEX.EMBED_TEXT_768` (e5-base-v2) | Creates 768-dim vector embeddings for regulatory document chunks |
| **AI** | Cortex Search Service | Hybrid semantic + keyword retrieval over the regulatory corpus |
| **Data Pipeline** | Dynamic Table | `DT_CUSTOMER_RISK_SUMMARY` auto-refreshes every 1 minute |
| **Data Pipeline** | Stream | `TRANSACTIONS_STREAM` captures new transactions via CDC |
| **Data Pipeline** | Scheduled Tasks | Alert detection every 15 min + daily risk score refresh |
| **Semantic** | Semantic View | 4 entities, 13 dimensions, 5 metrics, 4 verified queries |
| **App** | Streamlit in Snowflake | 4-page copilot UI deployed natively |
| **Governance** | Dynamic Data Masking | PII columns masked for non-analyst roles |
| **Governance** | Object Tagging | Semantic category tags on sensitive columns |
| **Governance** | RBAC | Two scoped roles with least-privilege grants |
| **External** | MCP Plugin | Filesystem connector for evidence report export |

---

## The Four App Pages

### 1. Risk Dashboard
KPI cards showing open alerts, critical count, high severity, and resolved. Filterable alert table and charts for risk score distribution and alert types.

### 2. Transaction Investigation
Select any alert to see the full transaction timeline, customer profile, and risk scores. Click **"Generate Evidence Report"** to produce an AI-generated memo that:
- Pulls transaction context from Snowflake tables
- Retrieves regulatory citations from the Cortex Search RAG pipeline
- Generates a structured report with executive summary, regulatory basis, and recommended actions

### 3. Regulatory Chat
Ask natural language questions grounded in the regulatory document corpus:
- *"What are the SAR filing thresholds?"*
- *"What does Basel III say about LCR requirements?"*
- *"What enhanced due diligence is required for PEPs?"*

Every answer includes expandable source citations from the retrieved documents.

### 4. Audit Trail
Complete log of all AI interactions -- query, RAG context, LLM response, timestamp, and user. Filterable and exportable for compliance documentation.

---

## Fraud Patterns in Synthetic Data

| # | Pattern | Customer | Description |
|---|---------|----------|-------------|
| 1 | **Structuring** | CUST-002 | 5 cash deposits under $10k ($48.5k total) then $45k wire to Cayman Islands |
| 2 | **Rapid Transfers** | CUST-003 | $740k+ wired to 5 countries in 30 hours |
| 3 | **Round-Tripping** | CUST-013/020 | Circular $500k flows between Panama and Belize shell company |
| 4 | **Dormant Reactivation** | CUST-015 | Inactive 3+ years, suddenly moves $160k internationally |
| 5 | **Velocity Spike** | CUST-007 | 8 wires to 8 African countries in 3.5 hours |
| 6 | **Layering** | CUST-009 | Decreasing transfers through 5 jurisdictions over 5 days |

---

## Data Pipeline & Automation

```
New Transaction inserted
        |
        v
[TRANSACTIONS_STREAM] -----> [TASK_AUTO_ALERT_DETECTION]
   (CDC capture)               Runs every 15 min
                               Auto-generates STRUCTURING alerts
                               when stream has data

[DT_CUSTOMER_RISK_SUMMARY] -- Dynamic table, 1-min target lag
                               Auto-joins customers + transactions +
                               risk scores + alerts

[TASK_DAILY_RISK_REFRESH] ---- Runs at 6AM UTC daily
                               Recalculates all risk scores using
                               behavioral + jurisdictional + network factors
```

---

## Regulatory Document Corpus (RAG)

Three synthetic policy documents, chunked into 18 segments with vector embeddings:

| Document | Chunks | Key Topics |
|----------|--------|------------|
| **AML/CFT Policy** | 8 | CTR thresholds ($10k), SAR filing (30-day), structuring definition, PEP screening, monitoring rules (TM-001 to TM-005), investigation SLAs |
| **Basel III Liquidity** | 5 | LCR formula (>= 100%), HQLA levels, cash outflow assumptions, stress scenarios, NSFR |
| **Internal Risk Policy** | 5 | Risk appetite, three lines of defense, escalation matrix, evidence standards, AI copilot guidelines |

---

## MCP Connector

The `mcp/plugin.json` file configures a CoCo Desktop plugin that connects to the local filesystem via the Model Context Protocol:

```
CoCo Desktop
    |
    |-- Generates evidence report in Snowflake (Cortex Complete + RAG)
    |
    v
[MCP Filesystem Server] --> reports/evidence_ALT-001.txt
                            (structured investigation memo
                             exported for compliance archival)
```

**What it enables:** CoCo can write AI-generated investigation reports directly to the filesystem, turning read-only analysis into cross-tool action. The `reports/` directory contains a sample output.

**Install:** Copy `mcp/plugin.json` to `~/.snowflake/cortex/plugins/risk-copilot-mcp/.cortex-plugin/plugin.json` and restart CoCo Desktop.

---

## Validation Results

All 8 tests pass (run `sql/tests/08_validation_tests.sql`):

| # | Test | Validates | Result |
|---|------|-----------|--------|
| 1 | Structuring Detection | V_STRUCTURING_ALERTS catches CUST-002 | PASS |
| 2 | Dormant Reactivation | V_DORMANT_REACTIVATION catches CUST-015 | PASS |
| 3 | High-Risk Jurisdiction | V_HIGH_RISK_JURISDICTIONS catches CUST-003 | PASS |
| 4 | Dynamic Table | DT_CUSTOMER_RISK_SUMMARY has all 20 customers | PASS |
| 5 | RAG Embeddings | All 18 chunks have vector embeddings | PASS |
| 6 | LLM Response | CORTEX.COMPLETE generates coherent output | PASS |
| 7 | Semantic View | Verified query returns open alerts | PASS |
| 8 | Masking Policy | PII masked for non-analyst roles | PASS |

---

## Project Structure

```
risk-fraud-regulatory-intelligence-copilot/
|
|-- app/                               # Streamlit application
|   |-- streamlit_app.py               #   4-page copilot UI (dashboard, investigation, chat, audit)
|   |-- snowflake.yml                  #   SiS deployment manifest
|
|-- sql/
|   |-- data/                          # Data layer
|   |   |-- 01_setup_data.sql          #   Database, 4 tables, 20 customers, 50 transactions, 10 alerts
|   |   |-- 02_regulatory_docs.sql     #   18 regulatory document chunks for RAG corpus
|   |
|   |-- pipeline/                      # Intelligence layer
|   |   |-- 03_rag_pipeline.sql        #   Vector embeddings + Cortex Search Service
|   |   |-- 04_risk_detection.sql      #   4 detection views + audit log table
|   |   |-- 06_pipeline_automation.sql #   Stream, dynamic table, 2 scheduled tasks
|   |   |-- 07_semantic_view.sql       #   Semantic view with verified queries
|   |
|   |-- governance/                    # Governance layer
|   |   |-- 05_governance.sql          #   RBAC roles, PII tags, masking policies
|   |
|   |-- tests/                         # Validation
|       |-- 08_validation_tests.sql    #   8 automated correctness tests
|
|-- mcp/                               # MCP connector
|   |-- plugin.json                    #   CoCo Desktop plugin for filesystem export
|
|-- reports/                           # Evidence output (MCP target)
|   |-- evidence_ALT-001.txt           #   Sample AI-generated investigation report
|
|-- .gitignore
|-- README.md
```

---

## Setup Instructions

### Prerequisites
- Snowflake account with Cortex AI features enabled
- ACCOUNTADMIN role (or equivalent)
- Warehouse named `COMPUTE_WH` (or edit the scripts)

### Deploy

```bash
git clone https://github.com/rdevath21/risk-fraud-regulatory-intelligence-copilot.git
cd risk-fraud-regulatory-intelligence-copilot
```

Run SQL scripts in order in Snowsight or any SQL client:

```
sql/data/01_setup_data.sql          # Creates database, tables, synthetic data
sql/data/02_regulatory_docs.sql     # Creates regulatory chunks (run inserts from 01)
sql/pipeline/03_rag_pipeline.sql    # Generates embeddings, creates search service
sql/pipeline/04_risk_detection.sql  # Creates detection views and audit log
sql/pipeline/06_pipeline_automation.sql  # Creates stream, dynamic table, tasks
sql/pipeline/07_semantic_view.sql   # Creates semantic view
sql/governance/05_governance.sql    # Creates roles, tags, masking policies
sql/tests/08_validation_tests.sql   # Runs all validation tests
```

Deploy the Streamlit app:

```sql
CREATE OR REPLACE STAGE RISK_COPILOT.PUBLIC.STREAMLIT_STAGE;

PUT 'file:///path/to/app/streamlit_app.py'
    @RISK_COPILOT.PUBLIC.STREAMLIT_STAGE
    AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

CREATE OR REPLACE STREAMLIT RISK_COPILOT.PUBLIC.RISK_FRAUD_COPILOT
  ROOT_LOCATION = '@RISK_COPILOT.PUBLIC.STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH;
```

Open: **Snowsight > Projects > Streamlit > RISK_FRAUD_COPILOT**

---

## CoCo Capabilities Demonstrated

| Hackathon Criterion | What We Did |
|---------------------|-------------|
| Synthetic data generation | 20 customers, 50 transactions, 6 fraud patterns, referentially consistent |
| Data pipeline creation | Stream + dynamic table + 2 scheduled tasks for incremental flows |
| Semantic model authoring | Semantic view with entities, relationships, metrics, verified queries |
| Streamlit app generation | 4-page SiS app with RAG chat and AI evidence generation |
| Document processing | Regulatory corpus parsed, chunked, embedded, indexed in Cortex Search |
| MCP connectors | Filesystem plugin for cross-tool evidence report export |
| Automations | 15-min alert detection + daily risk refresh, both running unattended |
| Testing & validation | 8 automated tests covering every layer of the solution |
| Guardrails & fallback | PII masking, RBAC, audit logging, RAG-grounded answers with citations |

---

## Snowflake Objects Created

| Object | Type | Purpose |
|--------|------|---------|
| `CUSTOMERS` | Table | 20 customer profiles |
| `TRANSACTIONS` | Table | 50 transactions with fraud patterns |
| `RISK_SCORES` | Table | Composite risk scores |
| `ALERTS` | Table | 10 alerts across 7 types |
| `REGULATORY_CHUNKS` | Table + VECTOR | 18 doc chunks with embeddings |
| `COPILOT_AUDIT_LOG` | Table | AI interaction audit trail |
| `DT_CUSTOMER_RISK_SUMMARY` | Dynamic Table | Real-time risk aggregation |
| `TRANSACTIONS_STREAM` | Stream | CDC on transactions |
| `TASK_AUTO_ALERT_DETECTION` | Task | 15-min structuring detection |
| `TASK_DAILY_RISK_REFRESH` | Task | Daily risk recalculation |
| `REGULATORY_SEARCH_SERVICE` | Cortex Search | Hybrid document retrieval |
| `SV_RISK_INTELLIGENCE` | Semantic View | Ontology + verified queries |
| `V_STRUCTURING_ALERTS` | View | Structuring detection |
| `V_VELOCITY_ANOMALIES` | View | Velocity spike detection |
| `V_HIGH_RISK_JURISDICTIONS` | View | High-risk jurisdiction monitoring |
| `V_DORMANT_REACTIVATION` | View | Dormant account detection |
| `PII_MASK` | Masking Policy | Protects customer PII |
| `RISK_ANALYST` | Role | Investigation access |
| `RISK_AUDITOR` | Role | Read-only audit access |
| `RISK_FRAUD_COPILOT` | Streamlit App | 4-page copilot UI |

---

## License

MIT
