-- ============================================================
-- Risk, Fraud & Regulatory Intelligence Copilot
-- Step 9: Cortex Agent + MCP Server (Multi-Surface)
-- ============================================================

USE SCHEMA RISK_COPILOT.PUBLIC;

-- Cortex Agent: wraps semantic view (structured data) + search service (regulatory docs)
CREATE OR REPLACE AGENT RISK_INTELLIGENCE_AGENT
FROM SPECIFICATION $$
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "risk_analyst"
      description: "Query structured risk data including customers, transactions, alerts, and risk scores"
  - tool_spec:
      type: "cortex_search"
      name: "regulatory_search"
      description: "Search AML/CFT policies, Basel III regulations, and internal risk procedures"
tool_resources:
  risk_analyst:
    semantic_view: "RISK_COPILOT.PUBLIC.SV_RISK_INTELLIGENCE"
  regulatory_search:
    search_service: "RISK_COPILOT.PUBLIC.REGULATORY_SEARCH_SERVICE"
    max_results: 3
    title_column: "DOC_NAME"
    content_column: "CHUNK_TEXT"
$$;

-- MCP Server: exposes the agent to external MCP clients (Claude, ChatGPT, Cursor, Slack)
CREATE OR REPLACE MCP SERVER RISK_COPILOT_MCP_SERVER
  FROM SPECIFICATION $$
  tools:
    - title: "Risk Intelligence Agent"
      name: "risk_intelligence_agent"
      type: "CORTEX_AGENT_RUN"
      identifier: "RISK_COPILOT.PUBLIC.RISK_INTELLIGENCE_AGENT"
      description: "AI-powered risk, fraud, and regulatory intelligence agent. Ask about customer risk scores, suspicious transactions, open alerts, AML policies, Basel III requirements, and investigation procedures."
  $$;

-- Grant access to roles
GRANT USAGE ON AGENT RISK_INTELLIGENCE_AGENT TO ROLE RISK_ANALYST;
GRANT USAGE ON AGENT RISK_INTELLIGENCE_AGENT TO ROLE RISK_AUDITOR;
GRANT USAGE ON MCP SERVER RISK_COPILOT_MCP_SERVER TO ROLE RISK_ANALYST;
