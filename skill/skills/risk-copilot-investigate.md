---
name: risk-copilot-investigate
description: Investigate a customer or alert using the Risk Copilot. Generates AI-powered evidence reports with regulatory citations.
user_invocable: true
---

# Risk Copilot Investigate

Investigate a specific alert or customer using the deployed Risk Copilot infrastructure.

## When to Use

- A compliance analyst needs to investigate a flagged alert
- Generate an evidence report for SAR filing
- Check a customer's risk profile and transaction history
- Look up regulatory requirements for a specific scenario

## Prerequisites

- Risk Copilot must be deployed (run `/risk-copilot-deploy` first)
- `RISK_COPILOT.PUBLIC` database and all objects must exist

## Steps

### Step 1: Identify the Investigation Target

Ask the user what they want to investigate:
- **A specific alert** (e.g., ALT-001, ALT-007)
- **A specific customer** (e.g., CUST-002, CUST-003)
- **A type of fraud pattern** (e.g., structuring, layering)

### Step 2: Gather Context

For an **alert investigation**, run:

```sql
-- Get alert details
SELECT * FROM RISK_COPILOT.PUBLIC.ALERTS WHERE ALERT_ID = '<ALERT_ID>';

-- Get customer profile
SELECT * FROM RISK_COPILOT.PUBLIC.CUSTOMERS WHERE CUSTOMER_ID = (
  SELECT CUSTOMER_ID FROM RISK_COPILOT.PUBLIC.ALERTS WHERE ALERT_ID = '<ALERT_ID>'
);

-- Get risk scores
SELECT * FROM RISK_COPILOT.PUBLIC.RISK_SCORES WHERE CUSTOMER_ID = (
  SELECT CUSTOMER_ID FROM RISK_COPILOT.PUBLIC.ALERTS WHERE ALERT_ID = '<ALERT_ID>'
);

-- Get related transactions
SELECT * FROM RISK_COPILOT.PUBLIC.TRANSACTIONS WHERE CUSTOMER_ID = (
  SELECT CUSTOMER_ID FROM RISK_COPILOT.PUBLIC.ALERTS WHERE ALERT_ID = '<ALERT_ID>'
) ORDER BY TXN_DATE DESC;
```

### Step 3: Search Regulatory Context

Use the Cortex Search Service to find relevant regulatory passages:

```sql
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'RISK_COPILOT.PUBLIC.REGULATORY_SEARCH_SERVICE',
    '{
      "query": "<ALERT_TYPE> <BRIEF_DESCRIPTION>",
      "columns": ["CHUNK_TEXT", "DOC_NAME"],
      "limit": 3
    }'
  )
)['results'] AS regulatory_context;
```

### Step 4: Generate Evidence Report

Combine the transaction context and regulatory citations into a prompt for `CORTEX.COMPLETE`:

```sql
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b', 
  'You are a senior AML compliance investigator. Generate a structured investigation evidence report.

  ALERT: <alert_details>
  CUSTOMER: <customer_profile>
  RISK SCORES: <risk_scores>
  TRANSACTIONS: <transaction_summary>
  REGULATORY CONTEXT: <rag_results>

  Generate sections: Executive Summary, Suspicious Activity Analysis, Regulatory Basis, Risk Assessment, Recommended Actions, Evidence Citations.'
) AS EVIDENCE_REPORT;
```

### Step 5: Log the Investigation

```sql
INSERT INTO RISK_COPILOT.PUBLIC.COPILOT_AUDIT_LOG 
  (ACTION_TYPE, ALERT_ID, USER_QUERY, RAG_CONTEXT, LLM_RESPONSE)
VALUES ('EVIDENCE_GENERATION', '<ALERT_ID>', '<search_query>', '<rag_context>', '<report>');
```

### Step 6: Present Results

Display the evidence report to the user with:
- Executive summary
- Transaction timeline with suspicious patterns highlighted
- Regulatory citations from the RAG corpus
- Recommended next steps (SAR filing, account restriction, enhanced monitoring)

## Example Questions This Skill Handles

- "Investigate alert ALT-001 for structuring"
- "Generate an evidence report for CUST-003"
- "What regulatory rules apply to the layering pattern in ALT-007?"
- "Show me the risk profile for CUST-020 (shell company)"
- "What are the SAR filing requirements for this case?"
