---
name: risk-copilot-orchestrate
description: Multi-agent orchestration workflow. Coordinates 3 specialized agents (Triage, Compliance, Intelligence) to investigate an alert end-to-end with clear handoffs.
user_invocable: true
---

# Risk Copilot Multi-Agent Orchestration

Orchestrate a full investigation using 3 specialized Cortex Agents, each with a distinct role and clear handoff points.

## Agent Architecture

```
User Question (e.g., "Investigate alert ALT-003 for round-tripping")
         |
         v
  ┌─────────────────────────────────┐
  │  STEP 1: RISK_TRIAGE_AGENT     │
  │  Role: Data Specialist          │
  │  Tool: cortex_analyst (SQL)     │
  │  Task: Screen alert, pull       │
  │    customer profile, transaction│
  │    history, risk scores         │
  │  Output: Triage Summary         │
  └──────────────┬──────────────────┘
                 │ handoff: triage context
                 v
  ┌─────────────────────────────────┐
  │  STEP 2: REGULATORY_COMPLIANCE  │
  │  _AGENT                         │
  │  Role: Policy Specialist        │
  │  Tool: cortex_search (RAG)      │
  │  Task: Find applicable regs,    │
  │    filing requirements, SLAs    │
  │  Output: Regulatory Citations   │
  └──────────────┬──────────────────┘
                 │ handoff: triage + regulatory context
                 v
  ┌─────────────────────────────────┐
  │  STEP 3: RISK_INTELLIGENCE      │
  │  _AGENT                          │
  │  Role: Orchestrator / Synthesizer│
  │  Tools: Both SQL + Search       │
  │  Task: Synthesize triage data + │
  │    regulatory context into final│
  │    evidence report              │
  │  Output: Investigation Report   │
  └──────────────┬──────────────────┘
                 │
                 v
         Audit Log Entry Created
         Evidence Report Delivered
```

## When to Use

- Full investigation of a flagged alert
- Generating a complete evidence package for SAR filing
- Compliance review requiring both data analysis and regulatory grounding
- Any workflow where you need data context + regulatory context + synthesis

## Steps

### Step 1: Identify the Target

Ask the user what to investigate:
- A specific alert ID (e.g., ALT-001, ALT-003, ALT-007)
- A customer ID (e.g., CUST-003, CUST-020)
- A fraud pattern type (e.g., structuring, layering, round-tripping)

### Step 2: Agent 1 — Risk Triage (Data Screening)

Call the **RISK_TRIAGE_AGENT** to screen the alert and gather data context.

Ask it questions like:
- "Show me the details for alert {ALERT_ID} including customer name and severity"
- "Pull the transaction history for customer {CUSTOMER_ID} sorted by date"
- "What is the composite risk score and risk category for {CUSTOMER_ID}?"
- "How many open alerts does this customer have?"

Collect the triage output: alert details, customer profile, transaction list, risk scores.

**Handoff**: Pass the triage summary to the next agent.

### Step 3: Agent 2 — Regulatory Compliance (Policy Lookup)

Call the **REGULATORY_COMPLIANCE_AGENT** to find applicable regulations.

Based on the alert type from Step 2, ask:
- For STRUCTURING: "What are the CTR filing thresholds and structuring detection rules?"
- For LAYERING: "What defines layering under AML regulations and what are the investigation requirements?"
- For ROUND_TRIPPING: "What are the rules around circular fund flows and shell company transactions?"
- For DORMANT_REACTIVATION: "What enhanced due diligence is required for reactivated dormant accounts?"
- For PEP alerts: "What enhanced monitoring is required for politically exposed persons?"
- General: "What are the SAR filing timelines and investigation SLAs for {SEVERITY} alerts?"

Collect: Regulatory citations, policy sections, filing requirements, SLA timelines.

**Handoff**: Combine triage data + regulatory citations for the final agent.

### Step 4: Agent 3 — Risk Intelligence (Synthesis)

Call the **RISK_INTELLIGENCE_AGENT** (the orchestrator with both tools) to produce the final report.

Provide it with the combined context:
"Based on the following triage data and regulatory context, generate a structured investigation evidence report:

TRIAGE DATA:
{triage_summary_from_step_2}

REGULATORY CONTEXT:
{regulatory_citations_from_step_3}

Generate sections: Executive Summary, Suspicious Activity Analysis, Regulatory Basis, Risk Assessment, Recommended Actions, Evidence Citations."

### Step 5: Log and Deliver

After receiving the final report:

```sql
INSERT INTO RISK_COPILOT.PUBLIC.COPILOT_AUDIT_LOG
  (ACTION_TYPE, ALERT_ID, USER_QUERY, RAG_CONTEXT, LLM_RESPONSE)
VALUES ('MULTI_AGENT_INVESTIGATION', '{alert_id}', '{original_question}', '{regulatory_context}', '{final_report}');
```

Present the report to the user with:
1. The triage summary (from Agent 1)
2. The regulatory citations (from Agent 2)
3. The synthesized evidence report (from Agent 3)
4. The audit log confirmation

## Example Run

User: "Investigate alert ALT-007 for layering"

**Agent 1 (Triage)** responds:
- ALT-007: LAYERING, CRITICAL, OPEN, assigned to analyst_jones
- Customer: CUST-009 Viktor Petrov, Ukraine, HIGH risk tier
- 5 wire transfers $160k-$180k across Georgia, Malta, UK, US, Switzerland
- Composite risk score: 0.84 (CRITICAL)

**Agent 2 (Compliance)** responds:
- AML/CFT Policy Section 3.2: Layering defined as rapid movement through multiple jurisdictions
- Internal Risk Policy: CRITICAL alerts require 24-hour SLA, SAR filing within 48 hours
- Basel III: Enhanced monitoring for cross-border transaction chains

**Agent 3 (Intelligence)** synthesizes into:
- Executive Summary: Classic layering pattern with decreasing amounts across 5 jurisdictions
- Regulatory Basis: Cites AML/CFT 3.2, Internal Policy SLA requirements
- Recommended Actions: Immediate SAR filing, account restriction, enhanced monitoring

## Why This Is Multi-Agent Orchestration

1. **Specialization**: Each agent has a single tool and a focused role
2. **Clear handoffs**: Output of Agent 1 feeds Agent 2's context, both feed Agent 3
3. **Shared context**: The orchestrating skill maintains state across all 3 agents
4. **Distinct capabilities**: Triage does SQL, Compliance does RAG, Intelligence does both
5. **Composable**: Each agent works independently but produces better results when orchestrated
