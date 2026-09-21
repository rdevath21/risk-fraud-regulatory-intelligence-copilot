import streamlit as st
import pandas as pd
import json
from datetime import datetime
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Risk & Fraud Intelligence Copilot", page_icon="", layout="wide")

session = get_active_session()

# ── Global CSS ──

st.markdown("""
<style>
    /* KPI cards */
    .kpi-card {
        padding: 1.2rem;
        border-radius: 10px;
        text-align: center;
        margin-bottom: 0.5rem;
        border: 1px solid #e0e0e0;
    }
    .kpi-card h2 { margin: 0; font-size: 2rem; }
    .kpi-card p { margin: 0; font-size: 0.85rem; color: #666; }
    .kpi-red { background: linear-gradient(135deg, #fff5f5, #ffe0e0); border-left: 4px solid #e53e3e; }
    .kpi-red h2 { color: #e53e3e; }
    .kpi-orange { background: linear-gradient(135deg, #fffaf0, #feebc8); border-left: 4px solid #dd6b20; }
    .kpi-orange h2 { color: #dd6b20; }
    .kpi-blue { background: linear-gradient(135deg, #ebf8ff, #bee3f8); border-left: 4px solid #3182ce; }
    .kpi-blue h2 { color: #3182ce; }
    .kpi-green { background: linear-gradient(135deg, #f0fff4, #c6f6d5); border-left: 4px solid #38a169; }
    .kpi-green h2 { color: #38a169; }
    .kpi-purple { background: linear-gradient(135deg, #faf5ff, #e9d8fd); border-left: 4px solid #805ad5; }
    .kpi-purple h2 { color: #805ad5; }

    /* Sidebar styling */
    .sidebar-header { text-align: center; padding: 0.5rem 0 1rem 0; }
    .sidebar-header h1 { font-size: 1.4rem; margin: 0; }
    .sidebar-header p { font-size: 0.75rem; color: #888; margin: 0; }
    .sidebar-stat { display: flex; justify-content: space-between; padding: 0.3rem 0; font-size: 0.85rem; border-bottom: 1px solid #eee; }
    .sidebar-stat .label { color: #666; }
    .sidebar-stat .value { font-weight: 600; }

    /* Status badge */
    .badge { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 0.75rem; font-weight: 600; }
    .badge-critical { background: #fed7d7; color: #c53030; }
    .badge-high { background: #feebc8; color: #c05621; }
    .badge-medium { background: #fefcbf; color: #975a16; }
    .badge-low { background: #c6f6d5; color: #276749; }
    .badge-open { background: #bee3f8; color: #2a69ac; }
    .badge-investigating { background: #e9d8fd; color: #6b46c1; }
    .badge-closed { background: #e2e8f0; color: #4a5568; }

    /* Chat bubbles */
    .chat-user {
        background: #ebf8ff; border: 1px solid #bee3f8; border-radius: 12px;
        padding: 0.8rem 1rem; margin: 0.5rem 0; margin-left: 15%;
    }
    .chat-user .sender { font-weight: 600; color: #2b6cb0; font-size: 0.8rem; margin-bottom: 0.3rem; }
    .chat-assistant {
        background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 12px;
        padding: 0.8rem 1rem; margin: 0.5rem 0; margin-right: 5%;
    }
    .chat-assistant .sender { font-weight: 600; color: #2d3748; font-size: 0.8rem; margin-bottom: 0.3rem; }

    /* Suggestion cards */
    .suggestion-grid { display: flex; flex-wrap: wrap; gap: 0.5rem; margin: 1rem 0; }

    /* Progress bar for risk */
    .risk-bar-container { width: 100%; background: #e2e8f0; border-radius: 10px; height: 24px; position: relative; overflow: hidden; }
    .risk-bar-fill { height: 100%; border-radius: 10px; transition: width 0.5s; display: flex; align-items: center; justify-content: center; color: white; font-weight: 700; font-size: 0.8rem; }

    /* Info card */
    .info-card { background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 1rem; margin-bottom: 0.5rem; }
    .info-card h4 { margin: 0 0 0.5rem 0; color: #2d3748; font-size: 0.9rem; }
    .info-row { display: flex; justify-content: space-between; padding: 0.25rem 0; font-size: 0.85rem; }
    .info-row .lbl { color: #718096; }
    .info-row .val { font-weight: 600; color: #2d3748; }

    /* Health status */
    .health-ok { color: #38a169; }
    .health-warn { color: #dd6b20; }
    .health-err { color: #e53e3e; }

    /* Section header */
    .section-header { display: flex; align-items: center; gap: 0.5rem; margin: 1.5rem 0 0.8rem 0; }
    .section-header h3 { margin: 0; font-size: 1.1rem; }
</style>
""", unsafe_allow_html=True)


# ── Helper functions ──

def run_query(sql):
    return session.sql(sql).to_pandas()

def run_query_safe(sql, default=None):
    try:
        return session.sql(sql).to_pandas()
    except Exception:
        return default if default is not None else pd.DataFrame()

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

def call_llm(prompt, model="llama3.1-70b"):
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

def kpi_card(label, value, css_class="kpi-blue"):
    return f'<div class="kpi-card {css_class}"><h2>{value}</h2><p>{label}</p></div>'

def severity_badge(sev):
    cls = {"CRITICAL": "badge-critical", "HIGH": "badge-high", "MEDIUM": "badge-medium", "LOW": "badge-low"}.get(sev, "badge-low")
    return f'<span class="badge {cls}">{sev}</span>'

def status_badge(stat):
    cls = {"OPEN": "badge-open", "INVESTIGATING": "badge-investigating", "CLOSED": "badge-closed"}.get(stat, "badge-open")
    return f'<span class="badge {cls}">{stat}</span>'

def risk_bar(score, max_score=100):
    pct = min(int((score / max_score) * 100), 100)
    if pct >= 75:
        color = "#e53e3e"
    elif pct >= 50:
        color = "#dd6b20"
    elif pct >= 25:
        color = "#ecc94b"
    else:
        color = "#38a169"
    return f"""<div class="risk-bar-container">
        <div class="risk-bar-fill" style="width: {pct}%; background: {color};">{score}</div>
    </div>"""


# ── Sidebar ──

st.sidebar.markdown("""
<div class="sidebar-header">
    <h1>Risk & Fraud Copilot</h1>
    <p>AI-Powered Intelligence Platform</p>
</div>
""", unsafe_allow_html=True)

st.sidebar.markdown("---")

# Quick stats
try:
    sidebar_stats = run_query("""
        SELECT
            (SELECT COUNT(*) FROM RISK_COPILOT.PUBLIC.CUSTOMERS) AS TOTAL_CUSTOMERS,
            (SELECT COUNT(*) FROM RISK_COPILOT.PUBLIC.TRANSACTIONS) AS TOTAL_TXNS,
            (SELECT COUNT(*) FROM RISK_COPILOT.PUBLIC.ALERTS WHERE STATUS IN ('OPEN','INVESTIGATING')) AS OPEN_ALERTS,
            (SELECT SUM(AMOUNT) FROM RISK_COPILOT.PUBLIC.TRANSACTIONS) AS TOTAL_VOLUME
    """)
    total_cust = int(sidebar_stats["TOTAL_CUSTOMERS"].iloc[0])
    total_txns = int(sidebar_stats["TOTAL_TXNS"].iloc[0])
    open_alerts_count = int(sidebar_stats["OPEN_ALERTS"].iloc[0])
    total_vol = float(sidebar_stats["TOTAL_VOLUME"].iloc[0])

    st.sidebar.markdown(f"""
    <div class="sidebar-stat"><span class="label">Customers</span><span class="value">{total_cust}</span></div>
    <div class="sidebar-stat"><span class="label">Transactions</span><span class="value">{total_txns:,}</span></div>
    <div class="sidebar-stat"><span class="label">Open Alerts</span><span class="value" style="color: #e53e3e;">{open_alerts_count}</span></div>
    <div class="sidebar-stat"><span class="label">Total Volume</span><span class="value">${total_vol:,.0f}</span></div>
    """, unsafe_allow_html=True)
except Exception:
    st.sidebar.caption("Stats loading...")

st.sidebar.markdown("---")

page = st.sidebar.radio(
    "Navigation",
    ["Dashboard", "Investigation", "Regulatory Chat", "Audit Trail", "System Health"],
    index=0
)

st.sidebar.markdown("---")
st.sidebar.caption(f"v1.2.0 | Cortex AI")
st.sidebar.caption(f"RISK_COPILOT.PUBLIC")


# ══════════════════════════════════════════════════════════════
# PAGE 1: RISK DASHBOARD
# ══════════════════════════════════════════════════════════════
if page == "Dashboard":
    st.markdown('<div class="section-header"><h3>Risk & Fraud Dashboard</h3></div>', unsafe_allow_html=True)
    st.caption("Real-time overview of alerts, risk scores, and detection coverage across the platform.")

    # Load data
    alerts_df = run_query("SELECT * FROM RISK_COPILOT.PUBLIC.ALERTS")
    open_count = len(alerts_df[alerts_df["STATUS"].isin(["OPEN", "INVESTIGATING"])])
    critical_count = len(alerts_df[(alerts_df["SEVERITY"] == "CRITICAL") & (alerts_df["STATUS"] != "CLOSED")])
    high_count = len(alerts_df[(alerts_df["SEVERITY"] == "HIGH") & (alerts_df["STATUS"] != "CLOSED")])
    closed_count = len(alerts_df[alerts_df["STATUS"] == "CLOSED"])
    investigating_count = len(alerts_df[alerts_df["STATUS"] == "INVESTIGATING"])

    # KPI row with colored cards
    c1, c2, c3, c4, c5 = st.columns(5)
    with c1:
        st.markdown(kpi_card("Open Alerts", open_count, "kpi-blue"), unsafe_allow_html=True)
    with c2:
        st.markdown(kpi_card("Critical", critical_count, "kpi-red"), unsafe_allow_html=True)
    with c3:
        st.markdown(kpi_card("High Severity", high_count, "kpi-orange"), unsafe_allow_html=True)
    with c4:
        st.markdown(kpi_card("Investigating", investigating_count, "kpi-purple"), unsafe_allow_html=True)
    with c5:
        st.markdown(kpi_card("Resolved", closed_count, "kpi-green"), unsafe_allow_html=True)

    st.markdown("")

    # Two-column layout: Alert table + Risk chart
    left_col, right_col = st.columns([3, 2])

    with left_col:
        st.markdown('<div class="section-header"><h3>Active Alerts</h3></div>', unsafe_allow_html=True)

        # Filters
        fcol1, fcol2 = st.columns(2)
        with fcol1:
            severity_filter = st.multiselect("Severity", ["CRITICAL", "HIGH", "MEDIUM", "LOW"], default=["CRITICAL", "HIGH", "MEDIUM"], key="dash_sev")
        with fcol2:
            status_filter = st.multiselect("Status", ["OPEN", "INVESTIGATING", "CLOSED"], default=["OPEN", "INVESTIGATING"], key="dash_stat")

        filtered = alerts_df[alerts_df["SEVERITY"].isin(severity_filter) & alerts_df["STATUS"].isin(status_filter)]

        if len(filtered) > 0:
            for _, row in filtered.iterrows():
                sev = severity_badge(row["SEVERITY"])
                stat = status_badge(row["STATUS"])
                st.markdown(f"""
                <div class="info-card">
                    <div style="display:flex; justify-content:space-between; align-items:center;">
                        <strong>{row['ALERT_ID']}</strong>
                        <div>{sev} {stat}</div>
                    </div>
                    <div style="font-size:0.85rem; color:#4a5568; margin-top:0.3rem;">
                        {row['ALERT_TYPE']} | Customer: {row['CUSTOMER_ID']} | Assigned: {row.get('ASSIGNED_TO', 'N/A')}
                    </div>
                </div>
                """, unsafe_allow_html=True)
        else:
            st.info("No alerts match the current filters.")

    with right_col:
        # Risk score distribution
        st.markdown('<div class="section-header"><h3>Top Risk Scores</h3></div>', unsafe_allow_html=True)
        risk_df = run_query("SELECT CUSTOMER_ID, COMPOSITE_SCORE, RISK_CATEGORY FROM RISK_COPILOT.PUBLIC.RISK_SCORES ORDER BY COMPOSITE_SCORE DESC")
        top_risk = risk_df.head(10)
        st.bar_chart(top_risk.set_index("CUSTOMER_ID")["COMPOSITE_SCORE"])

        # Alerts by type
        st.markdown('<div class="section-header"><h3>Alerts by Type</h3></div>', unsafe_allow_html=True)
        type_counts = alerts_df.groupby("ALERT_TYPE").size().reset_index(name="COUNT")
        st.bar_chart(type_counts.set_index("ALERT_TYPE"))

    st.markdown("")

    # Detection coverage + Transaction volume
    det_col, vol_col = st.columns(2)

    with det_col:
        st.markdown('<div class="section-header"><h3>Detection Coverage</h3></div>', unsafe_allow_html=True)
        det_data = {
            "Structuring": run_query_safe("SELECT COUNT(*) AS C FROM RISK_COPILOT.PUBLIC.V_STRUCTURING_ALERTS", pd.DataFrame({"C": [0]}))["C"].iloc[0],
            "Velocity Anomalies": run_query_safe("SELECT COUNT(*) AS C FROM RISK_COPILOT.PUBLIC.V_VELOCITY_ANOMALIES", pd.DataFrame({"C": [0]}))["C"].iloc[0],
            "High-Risk Jurisdictions": run_query_safe("SELECT COUNT(*) AS C FROM RISK_COPILOT.PUBLIC.V_HIGH_RISK_JURISDICTIONS", pd.DataFrame({"C": [0]}))["C"].iloc[0],
            "Dormant Reactivation": run_query_safe("SELECT COUNT(*) AS C FROM RISK_COPILOT.PUBLIC.V_DORMANT_REACTIVATION", pd.DataFrame({"C": [0]}))["C"].iloc[0],
        }
        for det_name, det_count in det_data.items():
            color = "#e53e3e" if int(det_count) > 0 else "#38a169"
            icon = "!" if int(det_count) > 0 else "OK"
            st.markdown(f"""
            <div class="info-card">
                <div style="display:flex; justify-content:space-between; align-items:center;">
                    <span>{det_name}</span>
                    <span style="color:{color}; font-weight:700;">{int(det_count)} flagged</span>
                </div>
            </div>
            """, unsafe_allow_html=True)

    with vol_col:
        st.markdown('<div class="section-header"><h3>Transaction Volume Over Time</h3></div>', unsafe_allow_html=True)
        txn_vol = run_query("SELECT TXN_DATE::DATE AS TXN_DAY, SUM(AMOUNT) AS DAILY_VOLUME, COUNT(*) AS TXN_COUNT FROM RISK_COPILOT.PUBLIC.TRANSACTIONS GROUP BY TXN_DAY ORDER BY TXN_DAY")
        if len(txn_vol) > 0:
            txn_vol["TXN_DAY"] = pd.to_datetime(txn_vol["TXN_DAY"])
            st.line_chart(txn_vol.set_index("TXN_DAY")["DAILY_VOLUME"])
        else:
            st.info("No transaction data available.")

    # Recent audit activity
    st.markdown('<div class="section-header"><h3>Recent AI Activity</h3></div>', unsafe_allow_html=True)
    recent_audit = run_query_safe("SELECT ACTION_TYPE, ALERT_ID, USER_QUERY, CREATED_AT, CREATED_BY FROM RISK_COPILOT.PUBLIC.COPILOT_AUDIT_LOG ORDER BY CREATED_AT DESC LIMIT 5")
    if len(recent_audit) > 0:
        for _, arow in recent_audit.iterrows():
            query_preview = str(arow.get("USER_QUERY", ""))[:80]
            st.markdown(f"""
            <div class="info-card">
                <div style="display:flex; justify-content:space-between; font-size:0.85rem;">
                    <span><strong>{arow['ACTION_TYPE']}</strong> {(' | ' + str(arow['ALERT_ID'])) if arow.get('ALERT_ID') else ''}</span>
                    <span style="color:#718096;">{arow.get('CREATED_AT', '')}</span>
                </div>
                <div style="font-size:0.8rem; color:#718096; margin-top:0.2rem;">{query_preview}...</div>
            </div>
            """, unsafe_allow_html=True)
    else:
        st.caption("No AI activity yet. Use Investigation or Regulatory Chat to generate entries.")


# ══════════════════════════════════════════════════════════════
# PAGE 2: TRANSACTION INVESTIGATION
# ══════════════════════════════════════════════════════════════
elif page == "Investigation":
    st.markdown('<div class="section-header"><h3>Transaction Investigation</h3></div>', unsafe_allow_html=True)
    st.caption("Investigate alerts and customers with AI-powered evidence generation backed by regulatory RAG.")

    tab_alert, tab_customer = st.tabs(["Investigate Alert", "Investigate Customer"])

    with tab_alert:
        alerts_df = run_query("SELECT ALERT_ID, CUSTOMER_ID, ALERT_TYPE, SEVERITY, STATUS, DESCRIPTION FROM RISK_COPILOT.PUBLIC.ALERTS WHERE STATUS != 'CLOSED' ORDER BY CASE SEVERITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END")
        if len(alerts_df) > 0:
            alert_options = alerts_df.apply(lambda r: f"{r['ALERT_ID']} | {r['ALERT_TYPE']} | {r['SEVERITY']} | {r['CUSTOMER_ID']}", axis=1).tolist()
            selected_alert = st.selectbox("Select Alert to Investigate", alert_options)
            alert_id = selected_alert.split(" | ")[0]
            alert_row = alerts_df[alerts_df["ALERT_ID"] == alert_id].iloc[0]

            # Alert header card
            sev = severity_badge(alert_row["SEVERITY"])
            stat = status_badge(alert_row["STATUS"])
            st.markdown(f"""
            <div class="info-card" style="border-left: 4px solid {'#e53e3e' if alert_row['SEVERITY']=='CRITICAL' else '#dd6b20' if alert_row['SEVERITY']=='HIGH' else '#ecc94b'};">
                <div style="display:flex; justify-content:space-between; align-items:center;">
                    <h4 style="margin:0;">{alert_row['ALERT_TYPE']}</h4>
                    <div>{sev} {stat}</div>
                </div>
                <div style="margin-top:0.5rem; font-size:0.9rem; color:#4a5568;">{alert_row['DESCRIPTION']}</div>
            </div>
            """, unsafe_allow_html=True)

            st.markdown("")

            # Customer profile + Risk scores side by side
            cust_id = alert_row["CUSTOMER_ID"]
            cust = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.CUSTOMERS WHERE CUSTOMER_ID = '{cust_id}'")
            risk = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.RISK_SCORES WHERE CUSTOMER_ID = '{cust_id}'")

            prof_col, risk_col = st.columns(2)
            with prof_col:
                st.markdown('<div class="section-header"><h3>Customer Profile</h3></div>', unsafe_allow_html=True)
                if len(cust) > 0:
                    cr = cust.iloc[0]
                    pep_color = "#e53e3e" if str(cr.get("PEP_FLAG", "")).upper() in ["TRUE", "YES", "1"] else "#38a169"
                    kyc_color = "#38a169" if str(cr.get("KYC_STATUS", "")).upper() == "VERIFIED" else "#dd6b20"
                    st.markdown(f"""
                    <div class="info-card">
                        <div class="info-row"><span class="lbl">Name</span><span class="val">{cr.get('FULL_NAME','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Customer ID</span><span class="val">{cust_id}</span></div>
                        <div class="info-row"><span class="lbl">Country</span><span class="val">{cr.get('COUNTRY','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Account Type</span><span class="val">{cr.get('ACCOUNT_TYPE','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">KYC Status</span><span class="val" style="color:{kyc_color};">{cr.get('KYC_STATUS','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">PEP Flag</span><span class="val" style="color:{pep_color};">{cr.get('PEP_FLAG','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Risk Tier</span><span class="val">{cr.get('RISK_TIER','N/A')}</span></div>
                    </div>
                    """, unsafe_allow_html=True)

            with risk_col:
                st.markdown('<div class="section-header"><h3>Risk Assessment</h3></div>', unsafe_allow_html=True)
                if len(risk) > 0:
                    rr = risk.iloc[0]
                    composite = float(rr.get("COMPOSITE_SCORE", 0))
                    st.markdown(f"""
                    <div class="info-card">
                        <div class="info-row"><span class="lbl">Composite Score</span><span class="val">{composite}</span></div>
                    </div>
                    """, unsafe_allow_html=True)
                    st.markdown(risk_bar(composite), unsafe_allow_html=True)
                    st.markdown(f"""
                    <div class="info-card" style="margin-top:0.5rem;">
                        <div class="info-row"><span class="lbl">Behavioral Risk</span><span class="val">{rr.get('BEHAVIORAL_RISK','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Jurisdictional Risk</span><span class="val">{rr.get('JURISDICTIONAL_RISK','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Network Risk</span><span class="val">{rr.get('NETWORK_RISK','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Risk Category</span><span class="val">{rr.get('RISK_CATEGORY','N/A')}</span></div>
                    </div>
                    """, unsafe_allow_html=True)

            # Transaction timeline
            st.markdown('<div class="section-header"><h3>Transaction Timeline</h3></div>', unsafe_allow_html=True)
            txns = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.TRANSACTIONS WHERE CUSTOMER_ID = '{cust_id}' ORDER BY TXN_DATE DESC")

            if len(txns) > 0:
                # Summary metrics for transactions
                tc1, tc2, tc3, tc4 = st.columns(4)
                tc1.metric("Total Transactions", len(txns))
                tc2.metric("Total Volume", f"${txns['AMOUNT'].sum():,.0f}")
                tc3.metric("Avg Amount", f"${txns['AMOUNT'].mean():,.0f}")
                tc4.metric("Max Amount", f"${txns['AMOUNT'].max():,.0f}")

                st.dataframe(txns[["TXN_ID", "TXN_DATE", "TXN_TYPE", "AMOUNT", "CURRENCY", "COUNTERPARTY", "CHANNEL", "COUNTRY"]], use_container_width=True)

                # Volume chart
                txns["TXN_DAY"] = pd.to_datetime(txns["TXN_DATE"]).dt.date
                daily = txns.groupby("TXN_DAY")["AMOUNT"].sum().reset_index()
                st.line_chart(daily.set_index("TXN_DAY"))

            # Alert actions
            st.markdown("---")
            act1, act2, act3 = st.columns(3)
            with act1:
                if st.button("Generate Evidence Report", type="primary"):
                    with st.spinner("Generating AI-powered evidence report..."):
                        alert_desc = alert_row["DESCRIPTION"]
                        txn_summary = txns.head(10).to_string(index=False) if len(txns) > 0 else "No transactions"
                        cust_summary = cust.to_string(index=False) if len(cust) > 0 else "N/A"
                        risk_summary = risk.to_string(index=False) if len(risk) > 0 else "N/A"

                        search_query = f"{alert_row['ALERT_TYPE']} {alert_desc[:200]}"
                        rag_results = search_regulatory_docs(search_query, limit=3)
                        rag_context = "\n\n".join([r.get("CHUNK_TEXT", "") for r in rag_results])

                        prompt = f"""You are a senior AML compliance investigator. Generate a structured investigation evidence report.

ALERT: {alert_id} | {alert_row['ALERT_TYPE']} | {alert_row['SEVERITY']}
Description: {alert_desc}

CUSTOMER: {cust_summary}
RISK SCORES: {risk_summary}
TRANSACTIONS: {txn_summary}
REGULATORY FRAMEWORK: {rag_context}

Generate sections:
1. EXECUTIVE SUMMARY (2-3 sentences)
2. SUSPICIOUS ACTIVITY ANALYSIS (patterns and why suspicious)
3. REGULATORY BASIS (cite specific policy sections)
4. RISK ASSESSMENT (overall risk with justification)
5. RECOMMENDED ACTIONS (SAR filing, restrictions, monitoring)
6. EVIDENCE CITATIONS (transaction IDs and amounts)

Be specific with transaction IDs, amounts, and regulatory citations."""

                        response = call_llm(prompt)
                        log_audit("EVIDENCE_GENERATION", alert_id, search_query, rag_context[:4000], response[:8000])

                        st.subheader("Evidence Report")
                        st.markdown(response)
                        with st.expander("Copy Full Report Text"):
                            st.code(response, language=None)

            with act2:
                if st.button("Escalate to CRITICAL"):
                    session.sql(f"UPDATE RISK_COPILOT.PUBLIC.ALERTS SET SEVERITY = 'CRITICAL', STATUS = 'INVESTIGATING' WHERE ALERT_ID = '{alert_id}'").collect()
                    st.success(f"Alert {alert_id} escalated to CRITICAL.")
                    st.experimental_rerun()

            with act3:
                if st.button("Close Alert"):
                    session.sql(f"UPDATE RISK_COPILOT.PUBLIC.ALERTS SET STATUS = 'CLOSED' WHERE ALERT_ID = '{alert_id}'").collect()
                    st.success(f"Alert {alert_id} closed.")
                    st.experimental_rerun()
        else:
            st.info("No open alerts to investigate. All alerts are closed.")

    with tab_customer:
        customers = run_query("SELECT CUSTOMER_ID, FULL_NAME, COUNTRY, RISK_TIER FROM RISK_COPILOT.PUBLIC.CUSTOMERS ORDER BY CUSTOMER_ID")
        cust_options = customers.apply(lambda r: f"{r['CUSTOMER_ID']} | {r['FULL_NAME']} | {r['RISK_TIER']}", axis=1).tolist()
        selected_cust = st.selectbox("Select Customer", cust_options)
        cust_id = selected_cust.split(" | ")[0]

        # Customer risk card
        cust_detail = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.CUSTOMERS WHERE CUSTOMER_ID = '{cust_id}'")
        cust_risk = run_query_safe(f"SELECT * FROM RISK_COPILOT.PUBLIC.RISK_SCORES WHERE CUSTOMER_ID = '{cust_id}'")

        if len(cust_detail) > 0:
            cr = cust_detail.iloc[0]
            rc1, rc2 = st.columns(2)
            with rc1:
                st.markdown(f"""
                <div class="info-card">
                    <h4>Customer Profile</h4>
                    <div class="info-row"><span class="lbl">Name</span><span class="val">{cr.get('FULL_NAME','N/A')}</span></div>
                    <div class="info-row"><span class="lbl">Country</span><span class="val">{cr.get('COUNTRY','N/A')}</span></div>
                    <div class="info-row"><span class="lbl">Account Type</span><span class="val">{cr.get('ACCOUNT_TYPE','N/A')}</span></div>
                    <div class="info-row"><span class="lbl">KYC Status</span><span class="val">{cr.get('KYC_STATUS','N/A')}</span></div>
                    <div class="info-row"><span class="lbl">PEP Flag</span><span class="val">{cr.get('PEP_FLAG','N/A')}</span></div>
                    <div class="info-row"><span class="lbl">Risk Tier</span><span class="val">{cr.get('RISK_TIER','N/A')}</span></div>
                </div>
                """, unsafe_allow_html=True)
            with rc2:
                if len(cust_risk) > 0:
                    rr = cust_risk.iloc[0]
                    composite = float(rr.get("COMPOSITE_SCORE", 0))
                    st.markdown(f'<div class="info-card"><h4>Composite Risk Score</h4></div>', unsafe_allow_html=True)
                    st.markdown(risk_bar(composite), unsafe_allow_html=True)
                    st.markdown(f"""
                    <div class="info-card" style="margin-top:0.5rem;">
                        <div class="info-row"><span class="lbl">Behavioral</span><span class="val">{rr.get('BEHAVIORAL_RISK','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Jurisdictional</span><span class="val">{rr.get('JURISDICTIONAL_RISK','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Network</span><span class="val">{rr.get('NETWORK_RISK','N/A')}</span></div>
                        <div class="info-row"><span class="lbl">Category</span><span class="val">{rr.get('RISK_CATEGORY','N/A')}</span></div>
                    </div>
                    """, unsafe_allow_html=True)

        # Transactions
        txns = run_query(f"SELECT * FROM RISK_COPILOT.PUBLIC.TRANSACTIONS WHERE CUSTOMER_ID = '{cust_id}' ORDER BY TXN_DATE DESC")
        st.markdown(f'<div class="section-header"><h3>Transaction History ({len(txns)} transactions)</h3></div>', unsafe_allow_html=True)
        if len(txns) > 0:
            tc1, tc2, tc3 = st.columns(3)
            tc1.metric("Total Volume", f"${txns['AMOUNT'].sum():,.0f}")
            tc2.metric("Avg Amount", f"${txns['AMOUNT'].mean():,.0f}")
            tc3.metric("Max Amount", f"${txns['AMOUNT'].max():,.0f}")

            st.dataframe(txns, use_container_width=True)

            txns["TXN_DAY"] = pd.to_datetime(txns["TXN_DATE"]).dt.date
            daily = txns.groupby("TXN_DAY")["AMOUNT"].sum().reset_index()
            st.line_chart(daily.set_index("TXN_DAY"))
        else:
            st.info("No transactions found for this customer.")

        # Customer alerts
        cust_alerts = run_query_safe(f"SELECT * FROM RISK_COPILOT.PUBLIC.ALERTS WHERE CUSTOMER_ID = '{cust_id}'")
        if len(cust_alerts) > 0:
            st.markdown(f'<div class="section-header"><h3>Customer Alerts ({len(cust_alerts)})</h3></div>', unsafe_allow_html=True)
            for _, arow in cust_alerts.iterrows():
                sev = severity_badge(arow["SEVERITY"])
                stat = status_badge(arow["STATUS"])
                st.markdown(f"""
                <div class="info-card">
                    <div style="display:flex; justify-content:space-between; align-items:center;">
                        <strong>{arow['ALERT_ID']}</strong> <span style="color:#718096;">| {arow['ALERT_TYPE']}</span>
                        <div>{sev} {stat}</div>
                    </div>
                </div>
                """, unsafe_allow_html=True)


# ══════════════════════════════════════════════════════════════
# PAGE 3: REGULATORY COPILOT CHAT
# ══════════════════════════════════════════════════════════════
elif page == "Regulatory Chat":
    st.markdown('<div class="section-header"><h3>Regulatory Intelligence Copilot</h3></div>', unsafe_allow_html=True)
    st.caption("Ask questions about AML/CFT policies, Basel III regulations, and internal risk procedures. Answers are grounded in the regulatory document corpus via RAG.")

    if "chat_history" not in st.session_state:
        st.session_state.chat_history = []

    # Controls row
    ctrl_col1, ctrl_col2 = st.columns([4, 1])
    with ctrl_col2:
        if st.button("Clear Chat"):
            st.session_state.chat_history = []
            st.experimental_rerun()

    # Display chat history with styled bubbles
    for msg in st.session_state.chat_history:
        if msg["role"] == "user":
            st.markdown(f"""
            <div class="chat-user">
                <div class="sender">You</div>
                {msg['content']}
            </div>
            """, unsafe_allow_html=True)
        else:
            st.markdown(f"""
            <div class="chat-assistant">
                <div class="sender">Copilot | {len(msg.get('sources', []))} sources found</div>
            </div>
            """, unsafe_allow_html=True)
            st.markdown(msg["content"])
            if msg.get("sources"):
                with st.expander(f"View {len(msg['sources'])} Sources"):
                    for i, s in enumerate(msg["sources"]):
                        st.markdown(f"""
                        <div class="info-card">
                            <div style="font-weight:600; color:#2b6cb0; font-size:0.85rem;">{s['doc']}</div>
                            <div style="font-size:0.8rem; color:#4a5568; margin-top:0.3rem;">{s['text'][:300]}...</div>
                        </div>
                        """, unsafe_allow_html=True)

    # Suggested questions (only when no history)
    if not st.session_state.chat_history:
        st.markdown("**Quick questions to get started:**")
        suggestions = [
            "What are the SAR filing thresholds and timelines?",
            "What defines structuring under AML regulations?",
            "What are the Basel III LCR requirements?",
            "What enhanced due diligence is required for PEPs?",
            "What are the investigation SLAs for CRITICAL alerts?",
            "What are the high-risk jurisdictions for wire transfers?",
        ]
        row1 = st.columns(3)
        row2 = st.columns(3)
        for i, q in enumerate(suggestions[:3]):
            with row1[i]:
                if st.button(q, key=f"sug_{i}"):
                    st.session_state["pending_question"] = q
                    st.experimental_rerun()
        for i, q in enumerate(suggestions[3:]):
            with row2[i]:
                if st.button(q, key=f"sug_{i+3}"):
                    st.session_state["pending_question"] = q
                    st.experimental_rerun()

    # Chat input
    st.markdown("---")
    user_input = st.text_input("Ask about regulations, policies, or compliance requirements...", key="chat_input", placeholder="e.g., What are the KYC requirements for high-risk customers?")
    pending = st.session_state.pop("pending_question", None)
    query = pending or user_input

    if query:
        st.session_state.chat_history.append({"role": "user", "content": query})
        st.markdown(f"""
        <div class="chat-user">
            <div class="sender">You</div>
            {query}
        </div>
        """, unsafe_allow_html=True)

        with st.spinner("Searching regulatory corpus and generating answer..."):
            rag_results = search_regulatory_docs(query, limit=4)
            rag_context = "\n\n---\n\n".join([f"[{r.get('DOC_NAME', 'Unknown')}]: {r.get('CHUNK_TEXT', '')}" for r in rag_results])
            sources = [{"doc": r.get("DOC_NAME", "Unknown"), "text": r.get("CHUNK_TEXT", "")} for r in rag_results]

            prompt = f"""You are a regulatory compliance expert assistant. Answer the user's question using ONLY the regulatory document excerpts below. If the answer is not in the context, say so.

REGULATORY CONTEXT:
{rag_context}

USER QUESTION: {query}

Provide a clear, structured answer. Cite specific document names and sections. Synthesize information from multiple documents when relevant."""

            response = call_llm(prompt)
            log_audit("REGULATORY_CHAT", None, query, rag_context[:4000], response[:8000])

            st.markdown(f"""
            <div class="chat-assistant">
                <div class="sender">Copilot | {len(sources)} sources found</div>
            </div>
            """, unsafe_allow_html=True)
            st.markdown(response)

            if sources:
                with st.expander(f"View {len(sources)} Sources"):
                    for s in sources:
                        st.markdown(f"""
                        <div class="info-card">
                            <div style="font-weight:600; color:#2b6cb0; font-size:0.85rem;">{s['doc']}</div>
                            <div style="font-size:0.8rem; color:#4a5568; margin-top:0.3rem;">{s['text'][:300]}...</div>
                        </div>
                        """, unsafe_allow_html=True)

            st.session_state.chat_history.append({"role": "assistant", "content": response, "sources": sources})


# ══════════════════════════════════════════════════════════════
# PAGE 4: AUDIT TRAIL
# ══════════════════════════════════════════════════════════════
elif page == "Audit Trail":
    st.markdown('<div class="section-header"><h3>Copilot Audit Trail</h3></div>', unsafe_allow_html=True)
    st.caption("Complete log of all AI-assisted actions for compliance and explainability.")

    audit_df = run_query("SELECT * FROM RISK_COPILOT.PUBLIC.COPILOT_AUDIT_LOG ORDER BY CREATED_AT DESC LIMIT 100")

    if len(audit_df) > 0:
        # Summary KPIs
        total_actions = len(audit_df)
        evidence_count = len(audit_df[audit_df["ACTION_TYPE"] == "EVIDENCE_GENERATION"])
        chat_count = len(audit_df[audit_df["ACTION_TYPE"] == "REGULATORY_CHAT"])
        other_count = total_actions - evidence_count - chat_count

        c1, c2, c3, c4 = st.columns(4)
        with c1:
            st.markdown(kpi_card("Total Actions", total_actions, "kpi-blue"), unsafe_allow_html=True)
        with c2:
            st.markdown(kpi_card("Evidence Reports", evidence_count, "kpi-purple"), unsafe_allow_html=True)
        with c3:
            st.markdown(kpi_card("Chat Queries", chat_count, "kpi-green"), unsafe_allow_html=True)
        with c4:
            st.markdown(kpi_card("Other Actions", other_count, "kpi-orange"), unsafe_allow_html=True)

        st.markdown("")

        # Charts row
        chart1, chart2 = st.columns(2)
        with chart1:
            st.markdown('<div class="section-header"><h3>Activity Over Time</h3></div>', unsafe_allow_html=True)
            audit_df["CREATED_AT"] = pd.to_datetime(audit_df["CREATED_AT"])
            audit_df["DAY"] = audit_df["CREATED_AT"].dt.date
            daily_actions = audit_df.groupby("DAY").size().reset_index(name="COUNT")
            if len(daily_actions) > 0:
                st.bar_chart(daily_actions.set_index("DAY"))

        with chart2:
            st.markdown('<div class="section-header"><h3>Actions by Type</h3></div>', unsafe_allow_html=True)
            type_dist = audit_df.groupby("ACTION_TYPE").size().reset_index(name="COUNT")
            st.bar_chart(type_dist.set_index("ACTION_TYPE"))

        # Filter & table
        st.markdown('<div class="section-header"><h3>Log Entries</h3></div>', unsafe_allow_html=True)
        action_filter = st.multiselect("Filter by Action Type", audit_df["ACTION_TYPE"].unique().tolist(), default=audit_df["ACTION_TYPE"].unique().tolist())
        filtered_audit = audit_df[audit_df["ACTION_TYPE"].isin(action_filter)]

        st.dataframe(
            filtered_audit[["LOG_ID", "ACTION_TYPE", "ALERT_ID", "USER_QUERY", "CREATED_AT", "CREATED_BY"]],
            use_container_width=True,
        )

        # Detail view
        st.markdown('<div class="section-header"><h3>Detail View</h3></div>', unsafe_allow_html=True)
        if len(filtered_audit) > 0:
            selected_log = st.selectbox("Select log entry", filtered_audit["LOG_ID"].tolist())
            log_row = filtered_audit[filtered_audit["LOG_ID"] == selected_log].iloc[0]

            with st.expander("User Query", expanded=True):
                st.markdown(f"""<div class="info-card">{log_row['USER_QUERY']}</div>""", unsafe_allow_html=True)
            with st.expander("RAG Context Retrieved"):
                st.markdown(f"""<div class="info-card" style="font-size:0.85rem;">{log_row['RAG_CONTEXT']}</div>""", unsafe_allow_html=True)
            with st.expander("LLM Response"):
                st.markdown(log_row["LLM_RESPONSE"])

        # Export
        st.markdown("---")
        with st.expander("Export Audit Log (Copy CSV)"):
            csv = filtered_audit.to_csv(index=False)
            st.code(csv, language=None)
    else:
        st.info("No audit entries yet. Use the Investigation or Regulatory Chat pages to generate entries.")


# ══════════════════════════════════════════════════════════════
# PAGE 5: SYSTEM HEALTH
# ══════════════════════════════════════════════════════════════
elif page == "System Health":
    st.markdown('<div class="section-header"><h3>System Health & Operations</h3></div>', unsafe_allow_html=True)
    st.caption("Monitor pipeline status, object inventory, and system health for the Risk Copilot platform.")

    # Object inventory
    st.markdown('<div class="section-header"><h3>Object Inventory</h3></div>', unsafe_allow_html=True)
    inv_data = {}
    inv_data["Tables"] = run_query_safe("SELECT COUNT(*) AS C FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'PUBLIC' AND TABLE_TYPE = 'BASE TABLE'", pd.DataFrame({"C": [0]}))["C"].iloc[0]
    inv_data["Views"] = run_query_safe("SELECT COUNT(*) AS C FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'PUBLIC'", pd.DataFrame({"C": [0]}))["C"].iloc[0]
    inv_data["Dynamic Tables"] = run_query_safe("SELECT COUNT(*) AS C FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'PUBLIC' AND TABLE_TYPE = 'DYNAMIC TABLE'", pd.DataFrame({"C": [0]}))["C"].iloc[0]
    inv_data["Streams"] = run_query_safe("SELECT COUNT(*) AS C FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'PUBLIC' AND TABLE_TYPE LIKE '%STREAM%'", pd.DataFrame({"C": [0]}))["C"].iloc[0]

    inv_cols = st.columns(4)
    colors = ["kpi-blue", "kpi-purple", "kpi-green", "kpi-orange"]
    for i, (obj_type, obj_count) in enumerate(inv_data.items()):
        with inv_cols[i]:
            st.markdown(kpi_card(obj_type, int(obj_count), colors[i]), unsafe_allow_html=True)

    st.markdown("")

    # Task history
    st.markdown('<div class="section-header"><h3>Scheduled Task Status</h3></div>', unsafe_allow_html=True)
    task_names = ["TASK_AUTO_ALERT_DETECTION", "TASK_DAILY_RISK_REFRESH"]
    for tname in task_names:
        try:
            task_hist = run_query(f"SELECT NAME, STATE, SCHEDULED_TIME, COMPLETED_TIME, ERROR_MESSAGE FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => '{tname}', RESULT_LIMIT => 3)) ORDER BY SCHEDULED_TIME DESC")
            if len(task_hist) > 0:
                last = task_hist.iloc[0]
                state = str(last.get("STATE", "UNKNOWN"))
                if state == "SUCCEEDED":
                    icon_html = '<span class="health-ok">SUCCEEDED</span>'
                elif state == "FAILED":
                    icon_html = '<span class="health-err">FAILED</span>'
                else:
                    icon_html = f'<span class="health-warn">{state}</span>'

                st.markdown(f"""
                <div class="info-card">
                    <div style="display:flex; justify-content:space-between; align-items:center;">
                        <strong>{tname}</strong>
                        {icon_html}
                    </div>
                    <div style="font-size:0.8rem; color:#718096; margin-top:0.3rem;">
                        Last run: {last.get('SCHEDULED_TIME', 'N/A')} | Completed: {last.get('COMPLETED_TIME', 'N/A')}
                    </div>
                </div>
                """, unsafe_allow_html=True)

                if state == "FAILED" and last.get("ERROR_MESSAGE"):
                    st.error(f"Error: {last['ERROR_MESSAGE']}")
            else:
                st.markdown(f"""
                <div class="info-card">
                    <div style="display:flex; justify-content:space-between;">
                        <strong>{tname}</strong>
                        <span class="health-warn">NO HISTORY</span>
                    </div>
                </div>
                """, unsafe_allow_html=True)
        except Exception:
            st.markdown(f"""
            <div class="info-card">
                <div style="display:flex; justify-content:space-between;">
                    <strong>{tname}</strong>
                    <span class="health-warn">UNABLE TO QUERY</span>
                </div>
            </div>
            """, unsafe_allow_html=True)

    st.markdown("")

    # Dynamic table status
    st.markdown('<div class="section-header"><h3>Dynamic Table Freshness</h3></div>', unsafe_allow_html=True)
    try:
        dt_info = run_query("SELECT COUNT(*) AS ROW_COUNT FROM RISK_COPILOT.PUBLIC.DT_CUSTOMER_RISK_SUMMARY")
        dt_rows = int(dt_info["ROW_COUNT"].iloc[0])
        st.markdown(f"""
        <div class="info-card">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <strong>DT_CUSTOMER_RISK_SUMMARY</strong>
                <span class="health-ok">{dt_rows} rows</span>
            </div>
            <div style="font-size:0.8rem; color:#718096; margin-top:0.3rem;">Dynamic table auto-refreshes based on target lag</div>
        </div>
        """, unsafe_allow_html=True)
    except Exception:
        st.markdown("""
        <div class="info-card">
            <div style="display:flex; justify-content:space-between;">
                <strong>DT_CUSTOMER_RISK_SUMMARY</strong>
                <span class="health-warn">UNABLE TO QUERY</span>
            </div>
        </div>
        """, unsafe_allow_html=True)

    # Search service status
    st.markdown('<div class="section-header"><h3>Cortex Search Service</h3></div>', unsafe_allow_html=True)
    try:
        chunks = run_query("SELECT COUNT(*) AS C FROM RISK_COPILOT.PUBLIC.REGULATORY_CHUNKS")
        chunk_count = int(chunks["C"].iloc[0])
        st.markdown(f"""
        <div class="info-card">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <strong>REGULATORY_SEARCH_SERVICE</strong>
                <span class="health-ok">ACTIVE | {chunk_count} chunks indexed</span>
            </div>
            <div style="font-size:0.8rem; color:#718096; margin-top:0.3rem;">Cortex Search over regulatory documents (AML/CFT, Basel III, Internal Policy)</div>
        </div>
        """, unsafe_allow_html=True)
    except Exception:
        st.markdown("""
        <div class="info-card">
            <div style="display:flex; justify-content:space-between;">
                <strong>REGULATORY_SEARCH_SERVICE</strong>
                <span class="health-warn">UNABLE TO QUERY</span>
            </div>
        </div>
        """, unsafe_allow_html=True)

    # Cortex Agent
    st.markdown('<div class="section-header"><h3>Cortex Agent & MCP</h3></div>', unsafe_allow_html=True)
    try:
        agent_check = run_query("SHOW CORTEX AGENTS LIKE 'RISK_INTELLIGENCE_AGENT' IN SCHEMA RISK_COPILOT.PUBLIC")
        agent_exists = len(agent_check) > 0
    except Exception:
        agent_exists = False
    try:
        mcp_check = run_query("SHOW CORTEX MCP SERVERS LIKE 'RISK_COPILOT_MCP_SERVER' IN SCHEMA RISK_COPILOT.PUBLIC")
        mcp_exists = len(mcp_check) > 0
    except Exception:
        mcp_exists = False

    st.markdown(f"""
    <div class="info-card">
        <div class="info-row"><span class="lbl">RISK_INTELLIGENCE_AGENT</span><span class="{'health-ok' if agent_exists else 'health-err'}">{'ACTIVE' if agent_exists else 'NOT FOUND'}</span></div>
        <div class="info-row"><span class="lbl">RISK_COPILOT_MCP_SERVER</span><span class="{'health-ok' if mcp_exists else 'health-err'}">{'ACTIVE' if mcp_exists else 'NOT FOUND'}</span></div>
    </div>
    """, unsafe_allow_html=True)

    # Governance status
    st.markdown('<div class="section-header"><h3>Governance Controls</h3></div>', unsafe_allow_html=True)
    gov_items = []
    try:
        roles = run_query("SHOW ROLES LIKE 'RISK_%'")
        gov_items.append(("RBAC Roles (RISK_ANALYST, RISK_AUDITOR)", len(roles) >= 2, f"{len(roles)} found"))
    except Exception:
        gov_items.append(("RBAC Roles", False, "Unable to check"))

    try:
        policies = run_query("SHOW MASKING POLICIES IN SCHEMA RISK_COPILOT.PUBLIC")
        gov_items.append(("Masking Policies", len(policies) > 0, f"{len(policies)} active"))
    except Exception:
        gov_items.append(("Masking Policies", False, "Unable to check"))

    for item_name, item_ok, item_detail in gov_items:
        cls = "health-ok" if item_ok else "health-warn"
        st.markdown(f"""
        <div class="info-card">
            <div style="display:flex; justify-content:space-between;">
                <span>{item_name}</span>
                <span class="{cls}">{item_detail}</span>
            </div>
        </div>
        """, unsafe_allow_html=True)
