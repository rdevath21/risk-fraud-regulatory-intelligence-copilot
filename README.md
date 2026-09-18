# Risk, Fraud & Regulatory Intelligence Copilot

An AI-powered compliance investigation platform built entirely on Snowflake's native AI and data engine. Combines structured transaction monitoring with unstructured regulatory document intelligence via Retrieval-Augmented Generation (RAG), surfaced through a Streamlit-in-Snowflake interface.

## Architecture

```
 [ Structured Data ]              [ Unstructured Data ]
 (Transactions/Accounts)        (AML Policies / Basel Docs)
          │                               │
          ▼                               ▼
  Snowflake Tables              Cortex Search Service (RAG)
  (CUSTOMERS, TRANSACTIONS,     (REGULATORY_CHUNKS + Embeddings
   RISK_SCORES, ALERTS)          via EMBED_TEXT_768 / e5-base-v2)
          │                               │
          └──────────────┬────────────────┘
                         │
                         ▼
           Snowflake Cortex LLM Router
           (CORTEX.COMPLETE - mistral-large2)
           + Data Governance (RBAC, Masking)
                         │
                         ▼
           Streamlit-in-Snowflake Copilot UI
           (4-page app: Dashboard → Investigation
            → Regulatory Chat → Audit Trail)
```

## Snowflake Features Used

| Feature | Purpose |
|---------|---------|
| **Cortex Search Service** | Hybrid semantic + keyword retrieval over regulatory document corpus |
| **CORTEX.EMBED_TEXT_768** | Vector embeddings (e5-base-v2) for RAG pipeline |
| **CORTEX.COMPLETE** | LLM-powered evidence generation and regulatory Q&A (mistral-large2) |
| **Streamlit in Snowflake** | Native copilot UI with 4 pages |
| **Dynamic Data Masking** | PII protection (name, email, phone, address) via masking policies |
| **Object Tagging** | SNOWFLAKE.CORE.SEMANTIC_CATEGORY tags on sensitive columns |
| **RBAC** | RISK_ANALYST and RISK_AUDITOR roles with scoped privileges |
| **Cortex Search Service** | Hybrid (semantic + keyword) search for regulatory document retrieval |

## What It Does

### 1. Risk Dashboard
- KPI metric cards: open alerts, critical/high severity counts, resolved alerts
- Color-coded alert table filterable by severity and status
- Risk score distribution chart and alert type breakdown

### 2. Transaction Investigation
- Drill into any open alert to see full transaction timeline
- Customer profile and composite risk scores (behavioral, jurisdictional, network)
- **One-click AI Evidence Report** generation:
  - Gathers transaction context for the alert
  - Retrieves relevant regulatory excerpts via RAG (Cortex Search Service)
  - Calls Cortex LLM to generate a structured investigation memo with regulatory citations
  - Downloadable as a text file

### 3. Regulatory Copilot Chat
- Natural language Q&A grounded in the regulatory document corpus
- Questions like: "What are the SAR filing thresholds?" or "What does Basel III say about LCR?"
- Answers cite specific document sections with expandable source references
- Persistent chat history within session

### 4. Audit Trail
- Complete log of all AI-assisted actions (evidence generation, chat queries)
- Stores: user query, RAG context retrieved, LLM response, timestamp, user
- Filterable and exportable as CSV for compliance documentation

## Fraud Patterns Detected

The synthetic dataset includes six embedded fraud/AML patterns:

| Pattern | Description | Detection |
|---------|-------------|-----------|
| **Structuring** | Multiple sub-$10k cash deposits across branches | V_STRUCTURING_ALERTS view |
| **Rapid International Transfers** | $740k+ wired to 5 countries in 30 hours | Alert-based |
| **Round-Tripping** | Circular fund flows between Panama and Belize shell company | Alert-based |
| **Dormant Reactivation** | Account inactive 3+ years suddenly moves $160k | V_DORMANT_REACTIVATION view |
| **Velocity Spike** | 8 wire transfers to 8 countries in 3.5 hours | V_VELOCITY_ANOMALIES view |
| **Layering** | Sequential decreasing transfers through 5 jurisdictions | Alert-based |

## Regulatory Document Corpus

Three synthetic regulatory documents (18 chunks) indexed for RAG:

1. **AML/CFT Policy** (8 chunks) — CTR thresholds, SAR filing criteria, structuring definitions, PEP screening, transaction monitoring rules, investigation SLAs
2. **Basel III Liquidity Guidelines** (5 chunks) — LCR requirements, HQLA definitions, cash outflow assumptions, stress scenario parameters, NSFR
3. **Internal Risk Policy** (5 chunks) — Risk appetite, three lines of defense, escalation matrix, evidence documentation standards, AI copilot usage guidelines

## Setup Instructions

### Prerequisites
- Snowflake account with Cortex AI features enabled
- ACCOUNTADMIN role (or equivalent for creating databases, roles, and policies)
- A warehouse named `COMPUTE_WH` (or modify the scripts to use your warehouse)

### Step-by-Step Deployment

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/risk-fraud-regulatory-intelligence-copilot.git
cd risk-fraud-regulatory-intelligence-copilot
```

Run the SQL scripts in order via Snowsight or any Snowflake SQL client:

```sql
-- 2. Create database, tables, and synthetic data
-- Run: 01_setup_data.sql

-- 3. Create regulatory document chunks
-- Run: 02_regulatory_docs.sql
-- (The chunks are inserted inline in 01_setup_data.sql companion)

-- 4. Build RAG pipeline (embeddings + Cortex Search Service)
-- Run: 03_rag_pipeline.sql

-- 5. Create risk detection views and audit log
-- Run: 04_risk_detection.sql

-- 6. Apply governance (roles, tags, masking policies)
-- Run: 05_governance.sql
```

Deploy the Streamlit app:

```sql
-- 7. Create stage and upload app
CREATE OR REPLACE STAGE RISK_COPILOT.PUBLIC.STREAMLIT_STAGE;
PUT 'file:///path/to/streamlit_app.py' @RISK_COPILOT.PUBLIC.STREAMLIT_STAGE
    AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 8. Create the Streamlit app
CREATE OR REPLACE STREAMLIT RISK_COPILOT.PUBLIC.RISK_FRAUD_COPILOT
  ROOT_LOCATION = '@RISK_COPILOT.PUBLIC.STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH;
```

Then open in Snowsight: **Projects > Streamlit > RISK_FRAUD_COPILOT**

## Project Structure

```
├── 01_setup_data.sql          # Database, tables, synthetic transaction/customer data
├── 02_regulatory_docs.sql     # Stage creation and document chunk metadata
├── 03_rag_pipeline.sql        # Vector embeddings + Cortex Search Service
├── 04_risk_detection.sql      # Detection views (structuring, velocity, dormant, jurisdiction)
├── 05_governance.sql          # RBAC roles, PII tags, masking policies
├── streamlit_app.py           # Complete Streamlit-in-Snowflake application (4 pages)
├── snowflake.yml              # Deployment manifest
└── README.md
```

## Snowflake Objects Created

| Object | Type | Description |
|--------|------|-------------|
| `RISK_COPILOT.PUBLIC.CUSTOMERS` | Table | 20 customer profiles with risk tiers and KYC status |
| `RISK_COPILOT.PUBLIC.TRANSACTIONS` | Table | 50 transactions with embedded fraud patterns |
| `RISK_COPILOT.PUBLIC.RISK_SCORES` | Table | Composite risk scores per customer |
| `RISK_COPILOT.PUBLIC.ALERTS` | Table | 10 alerts across 7 types |
| `RISK_COPILOT.PUBLIC.REGULATORY_CHUNKS` | Table | 18 document chunks with vector embeddings |
| `RISK_COPILOT.PUBLIC.COPILOT_AUDIT_LOG` | Table | AI interaction audit trail |
| `RISK_COPILOT.PUBLIC.REGULATORY_SEARCH_SERVICE` | Cortex Search | Hybrid retrieval service |
| `RISK_COPILOT.PUBLIC.V_STRUCTURING_ALERTS` | View | Structuring detection |
| `RISK_COPILOT.PUBLIC.V_VELOCITY_ANOMALIES` | View | Velocity spike detection |
| `RISK_COPILOT.PUBLIC.V_HIGH_RISK_JURISDICTIONS` | View | High-risk jurisdiction monitoring |
| `RISK_COPILOT.PUBLIC.V_DORMANT_REACTIVATION` | View | Dormant account reactivation detection |
| `RISK_COPILOT.PUBLIC.RISK_FRAUD_COPILOT` | Streamlit | 4-page copilot UI |
| `RISK_COPILOT.PUBLIC.PII_MASK` | Masking Policy | Protects customer PII |
| `RISK_ANALYST` | Role | Investigation and copilot access |
| `RISK_AUDITOR` | Role | Read-only audit access |

## License

MIT
