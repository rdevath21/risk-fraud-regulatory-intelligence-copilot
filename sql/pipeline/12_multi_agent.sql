-- ============================================================
-- Risk, Fraud & Regulatory Intelligence Copilot
-- Step 12: Multi-Agent Orchestration
-- ============================================================
-- Three specialized agents with distinct responsibilities:
--   1. RISK_TRIAGE_AGENT      - Data specialist (queries structured data)
--   2. REGULATORY_COMPLIANCE_AGENT - Docs specialist (searches regulatory corpus)
--   3. RISK_INTELLIGENCE_AGENT - Orchestrator (has both tools, coordinates workflow)
--
-- Orchestration flow for an investigation:
--   Step 1: RISK_TRIAGE_AGENT screens the alert and pulls data context
--   Step 2: REGULATORY_COMPLIANCE_AGENT finds applicable regulations
--   Step 3: RISK_INTELLIGENCE_AGENT synthesizes both into a final report

USE SCHEMA RISK_COPILOT.PUBLIC;

-- Agent 1: Risk Triage (data-only, fast screening)
CREATE OR REPLACE AGENT RISK_TRIAGE_AGENT
FROM SPECIFICATION $$
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "risk_data_analyst"
      description: "Query transaction data, customer profiles, risk scores, and alerts to triage and prioritize risk signals. Use this to identify suspicious patterns, rank alerts by severity, and pull customer transaction histories."
tool_resources:
  risk_data_analyst:
    semantic_view: "RISK_COPILOT.SEMANTIC.SV_RISK_INTELLIGENCE"
$$;

-- Agent 2: Regulatory Compliance (docs-only, policy lookup)
CREATE OR REPLACE AGENT REGULATORY_COMPLIANCE_AGENT
FROM SPECIFICATION $$
tools:
  - tool_spec:
      type: "cortex_search"
      name: "regulatory_knowledge"
      description: "Search the regulatory document corpus for AML/CFT policies, Basel III requirements, SAR filing rules, KYC procedures, and internal risk management policies. Returns specific policy sections and citations."
tool_resources:
  regulatory_knowledge:
    search_service: "RISK_COPILOT.PUBLIC.REGULATORY_SEARCH_SERVICE"
    max_results: 5
    title_column: "DOC_NAME"
    content_column: "CHUNK_TEXT"
$$;

-- Agent 3: Risk Intelligence Orchestrator (both tools, synthesis)
-- Already exists from 09_agent_mcp.sql - has both semantic view + search service

-- Grant access
GRANT USAGE ON AGENT RISK_TRIAGE_AGENT TO ROLE RISK_ANALYST;
GRANT USAGE ON AGENT REGULATORY_COMPLIANCE_AGENT TO ROLE RISK_ANALYST;
GRANT USAGE ON AGENT RISK_TRIAGE_AGENT TO ROLE RISK_AUDITOR;
GRANT USAGE ON AGENT REGULATORY_COMPLIANCE_AGENT TO ROLE RISK_AUDITOR;
