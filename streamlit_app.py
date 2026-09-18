import streamlit as st
import pandas as pd
import json
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Risk & Fraud Intelligence Copilot", page_icon="", layout="wide")

session = get_active_session()

# ── Helper functions ──

def run_query(sql):
    return session.sql(sql).to_pandas()

def search_regulatory_docs(query, limit=3):
    import _snowflake
    result = _snowflake.send_snow_api_request(
        "POST",
        f"/api/v2/databases/RISK_COPILOT/schemas/PUBLIC/cortex-search-services/REGULATORY_SEARCH_SERVICE:query",
        {},
        {},
        json.dumps({"query": query, "columns": ["CHUNK_TEXT", "DOC_NAME"], "limit": limit}),
        {},
        30000,
    )
    if result["status"] == 200:
        body = json.loads(result["content"])
        return body.get("results", [])
    return []

def call_llm(prompt, model="mistral-large2"):
    escaped = prompt.replace("'", "''")
    result = run_query(f"SELECT SNOWFLAKE.CORTEX.COMPLETE('{model}', '{escaped}') AS RESPONSE")
    return result["RESPONSE"].iloc[0] if len(result) > 0 else "Error generating response."

def log_audit(action_type, alert_id, user_query, rag_context, llm_response):
    q = user_query.replace("'", "''")[:2000]
    r = rag_context.replace("'", "''")[:8000]
    l = llm_response.replace("'", "''")[:16000]
    a = (alert_id or "").replace("'", "''")
    session.sql(f"""
        INSERT INTO RISK_COPILOT.PUBLIC.COPILOT_AUDIT_LOG (ACTION_TYPE, ALERT_ID, USER_QUERY, RAG_CONTEXT, LLM_RESPONSE)
        VALUES ('{action_type}', '{a}', '{q}', '{r}', '{l}')
    """).collect()

# ── Sidebar ──

st.sidebar.title("Risk Copilot")
st.sidebar.markdown("AI-powered fraud detection and regulatory intelligence")
page = st.sidebar.radio("Navigation", ["Dashboard", "Investigation", "Regulatory Chat", "Audit Trail"])

# ══════════════════════════════════════════════════════════════
# PAGE 1: RISK DASHBOARD
# ══════════════════════════════════════════════════════════════
if page == "Dashboard":
    st.title("Risk & Fraud Dashboard")

    # KPI row
    alerts_df = run_query("SELECT * FROM RISK_COPILOT.PUBLIC.ALERTS")
    col1, col2, col3, col4 = st.columns(4)
    open_count = len(alerts_df[alerts_df["STATUS"].isin(["OPEN", "INVESTIGATING"])])
    critical_count = len(alerts_df[(alerts_df["SEVERITY"] == "CRITICAL") & (alerts_df["STATUS"] != "CLOSED")])
    high_count = len(alerts_df[(alerts_df["SEVERITY"] == "HIGH") & (alerts_df["STATUS"] != "CLOSED")])
    closed_count = len(alerts_df[alerts_df["STATUS"] == "CLOSED"])

    col1.metric("Open Alerts", open_count)
    col2.metric("Critical", critical_count)
    col3.metric("High Severity", high_count)
    col4.metric("Resolved", closed_count)

    st.markdown("---")

    # Filters
    fcol1, fcol2 = st.columns(2)
    with fcol1:
        severity_filter = st.multiselect("Filter by Severity", ["CRITICAL", "HIGH", "MEDIUM", "LOW"], default=["CRITICAL", "HIGH", "MEDIUM"])
    with fcol2:
        status_filter = st.multiselect("Filter by Status", ["OPEN", "INVESTIGATING", "CLOSED"], default=["OPEN", "INVESTIGATING"])

    filtered = alerts_df[alerts_df["SEVERITY"].isin(severity_filter) & alerts_df["STATUS"].isin(status_filter)]

    # Color-coded alert table
    st.subheader(f"Alerts ({len(filtered)})")
    if len(filtered) > 0:
        display_df = filtered[["ALERT_ID", "CUSTOMER_ID", "ALERT_TYPE", "SEVERITY", "STATUS", "ASSIGNED_TO", "CREATED_AT"]].copy()
        st.dataframe(
            display_df.style.apply(
                lambda row: [
                    "background-color: #ffcccc" if row["SEVERITY"] == "CRITICAL"
                    else "background-color: #ffe0b2" if row["SEVERITY"] == "HIGH"
                    else "background-color: #fff9c4" if row["SEVERITY"] == "MEDIUM"
                    else ""
                ] * len(row), axis=1
            ),
            use_container_width=True,
            hide_index=True,
        )
    else:
        st.info("No alerts match the current filters.")

    # Risk score distribution
    st.subheader("Risk Score Distribution")
    risk_df = run_query("SELECT CUSTOMER_ID, COMPOSITE_SCORE, RISK_CATEGORY FROM RISK_COPILOT.PUBLIC.RISK_SCORES ORDER BY COMPOSITE_SCORE DESC")
    st.bar_chart(risk_df.set_index("CUSTOMER_ID")["COMPOSITE_SCORE"])

    # Alerts by type
    st.subheader("Alerts by Type")
    type_counts = alerts_df.groupby("ALERT_TYPE").size().reset_index(name="COUNT")
    st.bar_chart(type_counts.set_index("ALERT_TYPE"))


# ══════════════════════════════════════════════════════════════
# PAGE 2: TRANSACTION INVESTIGATION
# ══════════════════════════════════════════════════════════════
elif page == "Investigation":
    st.title("Transaction Investigation")

    # Select alert or customer
    tab_alert, tab_customer = st.tabs(["Investigate Alert", "Investigate Customer"])

    with tab_alert:
        alerts_df = run_query("SELECT ALERT_ID, CUSTOMER_ID, ALERT_TYPE, SEVERITY, DESCRIPTION FROM RISK_COPILOT.PUBLIC.ALERTS WHERE STATUS != 'CLOSED' ORDER BY SEVERITY DESC")
        if len(alerts_df) > 0:
            alert_options = alerts_df.apply(lambda r: f"{r['ALERT_ID']} | {r['ALERT_TYPE']} | {r['SEVERITY']} | {r['CUSTOMER_ID']}", axis=1).tolist()
            selected_alert = st.selectbox("Select Alert", alert_options)
            alert_id = selected_alert.split(" | ")[0]
            alert_row = alerts_df[alerts_df["ALERT_ID"] == alert_id].iloc[0]

            st.warning(f"**{alert_row['ALERT_TYPE']}** — {alert_row['SEVERITY']}")
            st.write(alert_row["DESCRIPTION"])

            # Transaction timeline
            cust_id = alert_row["CUSTOMER_ID"]
            txns = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.TRANSACTIONS WHERE CUSTOMER_ID = '{cust_id}' ORDER BY TXN_DATE DESC")
            st.subheader(f"Transactions for {cust_id}")
            st.dataframe(txns, use_container_width=True, hide_index=True)

            # Customer profile
            cust = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.CUSTOMERS WHERE CUSTOMER_ID = '{cust_id}'")
            risk = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.RISK_SCORES WHERE CUSTOMER_ID = '{cust_id}'")
            c1, c2 = st.columns(2)
            with c1:
                st.subheader("Customer Profile")
                if len(cust) > 0:
                    for col_name in ["FULL_NAME", "COUNTRY", "ACCOUNT_TYPE", "KYC_STATUS", "PEP_FLAG", "RISK_TIER"]:
                        st.write(f"**{col_name}:** {cust[col_name].iloc[0]}")
            with c2:
                st.subheader("Risk Scores")
                if len(risk) > 0:
                    for col_name in ["BEHAVIORAL_RISK", "JURISDICTIONAL_RISK", "NETWORK_RISK", "COMPOSITE_SCORE", "RISK_CATEGORY"]:
                        st.write(f"**{col_name}:** {risk[col_name].iloc[0]}")

            # Evidence generation button
            st.markdown("---")
            if st.button("Generate Evidence Report", type="primary"):
                with st.spinner("Generating AI-powered evidence report..."):
                    # Gather context
                    alert_desc = alert_row["DESCRIPTION"]
                    txn_summary = txns.head(10).to_string(index=False)
                    cust_summary = cust.to_string(index=False) if len(cust) > 0 else "N/A"
                    risk_summary = risk.to_string(index=False) if len(risk) > 0 else "N/A"

                    # RAG: search for relevant regulatory context
                    search_query = f"{alert_row['ALERT_TYPE']} {alert_desc[:200]}"
                    rag_results = search_regulatory_docs(search_query, limit=3)
                    rag_context = "\n\n".join([r.get("CHUNK_TEXT", "") for r in rag_results])

                    prompt = f"""You are a senior AML compliance investigator. Generate a structured investigation evidence report for the following alert.

ALERT DETAILS:
- Alert ID: {alert_id}
- Type: {alert_row['ALERT_TYPE']}
- Severity: {alert_row['SEVERITY']}
- Description: {alert_desc}

CUSTOMER PROFILE:
{cust_summary}

RISK SCORES:
{risk_summary}

RECENT TRANSACTIONS:
{txn_summary}

APPLICABLE REGULATORY FRAMEWORK:
{rag_context}

Generate the report with these sections:
1. EXECUTIVE SUMMARY (2-3 sentences)
2. SUSPICIOUS ACTIVITY ANALYSIS (detail the pattern and why it is suspicious)
3. REGULATORY BASIS (cite specific policy sections from the regulatory framework above)
4. RISK ASSESSMENT (overall risk level with justification)
5. RECOMMENDED ACTIONS (specific next steps: SAR filing, account restriction, enhanced monitoring, etc.)
6. EVIDENCE CITATIONS (list specific transaction IDs and amounts supporting the findings)

Be specific, cite transaction IDs and amounts, and reference the applicable regulatory sections."""

                    response = call_llm(prompt)
                    log_audit("EVIDENCE_GENERATION", alert_id, search_query, rag_context[:4000], response[:8000])

                    st.subheader("Evidence Report")
                    st.markdown(response)
                    st.download_button("Download Report", response, file_name=f"evidence_{alert_id}.txt", mime="text/plain")

    with tab_customer:
        customers = run_query("SELECT CUSTOMER_ID, FULL_NAME, COUNTRY, RISK_TIER FROM RISK_COPILOT.PUBLIC.CUSTOMERS ORDER BY CUSTOMER_ID")
        cust_options = customers.apply(lambda r: f"{r['CUSTOMER_ID']} | {r['FULL_NAME']} | {r['RISK_TIER']}", axis=1).tolist()
        selected_cust = st.selectbox("Select Customer", cust_options)
        cust_id = selected_cust.split(" | ")[0]

        txns = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.TRANSACTIONS WHERE CUSTOMER_ID = '{cust_id}' ORDER BY TXN_DATE DESC")
        st.subheader(f"Transaction History ({len(txns)} transactions)")
        if len(txns) > 0:
            st.dataframe(txns, use_container_width=True, hide_index=True)

            # Transaction volume chart
            txns["TXN_DAY"] = pd.to_datetime(txns["TXN_DATE"]).dt.date
            daily = txns.groupby("TXN_DAY")["AMOUNT"].sum().reset_index()
            st.line_chart(daily.set_index("TXN_DAY"))
        else:
            st.info("No transactions found for this customer.")


# ══════════════════════════════════════════════════════════════
# PAGE 3: REGULATORY COPILOT CHAT
# ══════════════════════════════════════════════════════════════
elif page == "Regulatory Chat":
    st.title("Regulatory Intelligence Copilot")
    st.caption("Ask questions about AML/CFT policies, Basel III regulations, and internal risk management procedures. Answers are grounded in the regulatory document corpus via RAG.")

    if "chat_history" not in st.session_state:
        st.session_state.chat_history = []

    # Display chat history
    for msg in st.session_state.chat_history:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])
            if msg.get("sources"):
                with st.expander("Sources"):
                    for s in msg["sources"]:
                        st.caption(f"**{s['doc']}**: {s['text'][:200]}...")

    # Chat input
    user_input = st.chat_input("Ask about regulations, policies, or compliance requirements...")
    if user_input:
        st.session_state.chat_history.append({"role": "user", "content": user_input})
        with st.chat_message("user"):
            st.markdown(user_input)

        with st.chat_message("assistant"):
            with st.spinner("Searching regulatory corpus and generating answer..."):
                # RAG retrieval
                rag_results = search_regulatory_docs(user_input, limit=4)
                rag_context = "\n\n---\n\n".join([f"[{r.get('DOC_NAME', 'Unknown')}]: {r.get('CHUNK_TEXT', '')}" for r in rag_results])
                sources = [{"doc": r.get("DOC_NAME", "Unknown"), "text": r.get("CHUNK_TEXT", "")} for r in rag_results]

                prompt = f"""You are a regulatory compliance expert assistant. Answer the user's question using ONLY the regulatory document excerpts provided below. If the answer is not found in the provided context, say so clearly.

REGULATORY CONTEXT:
{rag_context}

USER QUESTION: {user_input}

Provide a clear, structured answer. Cite the specific document name and section when referencing policies. If multiple documents are relevant, synthesize the information."""

                response = call_llm(prompt)
                log_audit("REGULATORY_CHAT", None, user_input, rag_context[:4000], response[:8000])

                st.markdown(response)
                if sources:
                    with st.expander("Sources"):
                        for s in sources:
                            st.caption(f"**{s['doc']}**: {s['text'][:200]}...")

                st.session_state.chat_history.append({"role": "assistant", "content": response, "sources": sources})

    # Suggested questions
    if not st.session_state.chat_history:
        st.markdown("**Suggested questions:**")
        suggestions = [
            "What are the SAR filing thresholds and timelines?",
            "What defines structuring under AML regulations?",
            "What are the Basel III LCR requirements?",
            "What enhanced due diligence is required for PEPs?",
            "What are the investigation SLAs for CRITICAL alerts?",
            "What are the high-risk jurisdictions for wire transfers?",
        ]
        cols = st.columns(2)
        for i, q in enumerate(suggestions):
            with cols[i % 2]:
                if st.button(q, key=f"suggestion_{i}"):
                    st.session_state.chat_history.append({"role": "user", "content": q})
                    st.rerun()


# ══════════════════════════════════════════════════════════════
# PAGE 4: AUDIT TRAIL
# ══════════════════════════════════════════════════════════════
elif page == "Audit Trail":
    st.title("Copilot Audit Trail")
    st.caption("Complete log of all AI-assisted actions for compliance and explainability.")

    audit_df = run_query("SELECT * FROM RISK_COPILOT.PUBLIC.COPILOT_AUDIT_LOG ORDER BY CREATED_AT DESC LIMIT 100")

    if len(audit_df) > 0:
        # Summary metrics
        c1, c2, c3 = st.columns(3)
        c1.metric("Total Actions", len(audit_df))
        c2.metric("Evidence Reports", len(audit_df[audit_df["ACTION_TYPE"] == "EVIDENCE_GENERATION"]))
        c3.metric("Chat Queries", len(audit_df[audit_df["ACTION_TYPE"] == "REGULATORY_CHAT"]))

        # Filter
        action_filter = st.multiselect("Filter by Action", audit_df["ACTION_TYPE"].unique().tolist(), default=audit_df["ACTION_TYPE"].unique().tolist())
        filtered_audit = audit_df[audit_df["ACTION_TYPE"].isin(action_filter)]

        st.dataframe(
            filtered_audit[["LOG_ID", "ACTION_TYPE", "ALERT_ID", "USER_QUERY", "CREATED_AT", "CREATED_BY"]],
            use_container_width=True,
            hide_index=True,
        )

        # Detail view
        st.subheader("Detail View")
        if len(filtered_audit) > 0:
            selected_log = st.selectbox("Select log entry", filtered_audit["LOG_ID"].tolist())
            log_row = filtered_audit[filtered_audit["LOG_ID"] == selected_log].iloc[0]

            with st.expander("User Query", expanded=True):
                st.write(log_row["USER_QUERY"])
            with st.expander("RAG Context Retrieved"):
                st.write(log_row["RAG_CONTEXT"])
            with st.expander("LLM Response"):
                st.write(log_row["LLM_RESPONSE"])

        # Export
        st.markdown("---")
        csv = filtered_audit.to_csv(index=False)
        st.download_button("Export Audit Log (CSV)", csv, file_name="copilot_audit_log.csv", mime="text/csv")
    else:
        st.info("No audit entries yet. Use the Investigation or Regulatory Chat pages to generate entries.")
