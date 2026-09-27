"""
Risk, Fraud & Regulatory Intelligence Copilot - Slack Bot
=========================================================
Connects Slack to the Snowflake Cortex Risk Intelligence Agent.
Users can ask risk/compliance questions in Slack and get AI-powered
answers backed by regulatory RAG and transaction data.

Setup:
  1. Create a Slack App at https://api.slack.com/apps
  2. Enable Socket Mode and get an App-Level Token (xapp-...)
  3. Add Bot Token Scopes: chat:write, app_mentions:read, im:history, im:read, im:write
  4. Install the app to your workspace and get Bot Token (xoxb-...)
  5. Set environment variables (see below)
  6. pip install slack-bolt snowflake-connector-python requests
  7. python slack_bot.py

Environment Variables:
  SLACK_BOT_TOKEN=xoxb-your-bot-token
  SLACK_APP_TOKEN=xapp-your-app-level-token
  SNOWFLAKE_ACCOUNT=YSGKMCK-EP41823
  SNOWFLAKE_USER=RDEVATH21
  SNOWFLAKE_PASSWORD=your-password (or use SNOWFLAKE_PAT for PAT auth)
  SNOWFLAKE_WAREHOUSE=COMPUTE_WH
  SNOWFLAKE_DATABASE=RISK_COPILOT
"""

import os
import json
import logging
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
import snowflake.connector

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Slack App ──
app = App(token=os.environ["SLACK_BOT_TOKEN"])

# ── Snowflake Connection ──
def get_snowflake_connection():
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ.get("SNOWFLAKE_PASSWORD", ""),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        database=os.environ.get("SNOWFLAKE_DATABASE", "RISK_COPILOT"),
        schema="PUBLIC",
    )

def query_cortex_agent(question):
    """Call the Risk Intelligence Agent via Cortex Agent API."""
    conn = get_snowflake_connection()
    try:
        cursor = conn.cursor()
        escaped = question.replace("'", "''")
        cursor.execute(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-70b',
                'You are the Risk Intelligence Copilot. Answer concisely for Slack. Question: {escaped}'
            ) AS RESPONSE
        """)
        result = cursor.fetchone()
        return result[0] if result else "Sorry, I couldn't generate a response."
    except Exception as e:
        logger.error(f"Cortex Agent error: {e}")
        return f"Error connecting to Risk Copilot: {str(e)[:200]}"
    finally:
        conn.close()

def search_regulatory_docs(query):
    """Search regulatory corpus via direct SQL."""
    conn = get_snowflake_connection()
    try:
        cursor = conn.cursor()
        escaped = query.replace("'", "''")
        cursor.execute(f"""
            SELECT CHUNK_TEXT, DOC_NAME
            FROM RISK_COPILOT.PUBLIC.REGULATORY_CHUNKS
            ORDER BY VECTOR_COSINE_SIMILARITY(
                CHUNK_EMBEDDING,
                SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', '{escaped}')
            ) DESC
            LIMIT 3
        """)
        results = cursor.fetchall()
        return [(r[0], r[1]) for r in results]
    except Exception as e:
        logger.error(f"Search error: {e}")
        return []
    finally:
        conn.close()

def get_alert_summary():
    """Get current open alerts summary."""
    conn = get_snowflake_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT ALERT_ID, ALERT_TYPE, SEVERITY, STATUS, CUSTOMER_ID
            FROM RISK_COPILOT.TRANSFORM.DT_ALERT_ENRICHED
            WHERE STATUS IN ('OPEN', 'INVESTIGATING')
            ORDER BY CASE SEVERITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 ELSE 3 END
            LIMIT 10
        """)
        return cursor.fetchall()
    except Exception as e:
        logger.error(f"Alert query error: {e}")
        return []
    finally:
        conn.close()

def format_alert_summary(alerts):
    """Format alerts for Slack message."""
    if not alerts:
        return "No open alerts found."
    severity_emoji = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🟢"}
    lines = ["*Open Alerts:*\n"]
    for alert_id, alert_type, severity, status, customer_id in alerts:
        emoji = severity_emoji.get(severity, "⚪")
        lines.append(f"{emoji} *{alert_id}* | {alert_type} | {severity} | {status} | {customer_id}")
    return "\n".join(lines)


# ── Slash Command: /risk-alerts ──
@app.command("/risk-alerts")
def handle_alerts_command(ack, respond):
    ack()
    alerts = get_alert_summary()
    respond(format_alert_summary(alerts))


# ── Slash Command: /risk-ask ──
@app.command("/risk-ask")
def handle_ask_command(ack, respond, command):
    ack()
    question = command.get("text", "").strip()
    if not question:
        respond("Please provide a question. Usage: `/risk-ask What are the SAR filing thresholds?`")
        return

    respond(f"Searching regulatory corpus for: _{question}_...")

    # Search regulatory docs for context
    docs = search_regulatory_docs(question)
    rag_context = "\n\n".join([f"[{doc_name}]: {text[:500]}" for text, doc_name in docs])

    # Generate response with RAG context
    conn = get_snowflake_connection()
    try:
        cursor = conn.cursor()
        escaped_q = question.replace("'", "''")
        escaped_ctx = rag_context.replace("'", "''")
        cursor.execute(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b',
                'You are a regulatory compliance expert. Answer using ONLY the context below. Be concise for Slack.

CONTEXT:
{escaped_ctx}

QUESTION: {escaped_q}

Cite document names. Keep response under 500 words.') AS RESPONSE
        """)
        result = cursor.fetchone()
        response = result[0] if result else "Could not generate response."
    except Exception as e:
        response = f"Error: {str(e)[:200]}"
    finally:
        conn.close()

    # Format response with sources
    source_names = list(set([doc_name for _, doc_name in docs]))
    sources_text = ", ".join(source_names) if source_names else "None"

    respond({
        "blocks": [
            {"type": "section", "text": {"type": "mrkdwn", "text": f"*Question:* {question}"}},
            {"type": "divider"},
            {"type": "section", "text": {"type": "mrkdwn", "text": response[:3000]}},
            {"type": "context", "elements": [
                {"type": "mrkdwn", "text": f"Sources: {sources_text} | Powered by Risk Copilot + Cortex AI"}
            ]}
        ]
    })


# ── App Mention: @RiskCopilot <question> ──
@app.event("app_mention")
def handle_mention(event, say):
    text = event.get("text", "")
    # Remove the bot mention from the text
    question = text.split(">", 1)[-1].strip() if ">" in text else text.strip()

    if not question:
        say("Hi! Ask me about risk alerts, regulatory compliance, or fraud patterns. Try: `@RiskCopilot What are the SAR filing thresholds?`")
        return

    say(f"Looking into: _{question}_...")

    response = query_cortex_agent(question)
    say(response[:3000])


# ── Direct Message ──
@app.event("message")
def handle_dm(event, say):
    if event.get("channel_type") == "im":
        question = event.get("text", "").strip()
        if question:
            response = query_cortex_agent(question)
            say(response[:3000])


# ── Start Bot ──
if __name__ == "__main__":
    logger.info("Starting Risk Copilot Slack Bot...")
    handler = SocketModeHandler(app, os.environ["SLACK_APP_TOKEN"])
    handler.start()
