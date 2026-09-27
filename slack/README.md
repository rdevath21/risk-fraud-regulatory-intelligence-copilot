# Risk Copilot Slack Bot

Connects the Risk Intelligence Copilot to Slack, enabling compliance teams to query risk data and regulatory policies directly from Slack channels.

## Features

| Command | What It Does |
|---------|-------------|
| `/risk-alerts` | Shows current open alerts with severity indicators |
| `/risk-ask <question>` | Asks the regulatory copilot a question with RAG-backed answers |
| `@RiskCopilot <question>` | Mention the bot in any channel to ask a question |
| Direct message | DM the bot for private queries |

## Setup (5 minutes)

### 1. Create Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps) > **Create New App** > **From scratch**
2. Name: `Risk Copilot` | Workspace: your workspace
3. **Socket Mode** > Enable > Create App-Level Token (name: `risk-copilot`) > Copy `xapp-...` token
4. **OAuth & Permissions** > Add Bot Token Scopes:
   - `chat:write`
   - `app_mentions:read`
   - `im:history`, `im:read`, `im:write`
   - `commands`
5. **Install to Workspace** > Copy `xoxb-...` Bot Token
6. **Slash Commands** > Create:
   - `/risk-alerts` — Description: "Show open risk alerts"
   - `/risk-ask` — Description: "Ask the regulatory copilot" — Usage hint: "What are the SAR filing thresholds?"
7. **Event Subscriptions** > Enable > Subscribe to bot events: `app_mention`, `message.im`

### 2. Set Environment Variables

```bash
export SLACK_BOT_TOKEN=xoxb-your-bot-token
export SLACK_APP_TOKEN=xapp-your-app-level-token
export SNOWFLAKE_ACCOUNT=YSGKMCK-EP41823
export SNOWFLAKE_USER=RDEVATH21
export SNOWFLAKE_PASSWORD=your-password
export SNOWFLAKE_WAREHOUSE=COMPUTE_WH
export SNOWFLAKE_DATABASE=RISK_COPILOT
```

### 3. Install & Run

```bash
cd slack/
pip install -r requirements.txt
python slack_bot.py
```

## Architecture

```
Slack User
    |
    v  (slash command or @mention)
Slack Bot (slack_bot.py)
    |
    v  (Snowflake Connector)
Snowflake Cortex
    |-- CORTEX.COMPLETE (llama3.1-70b) for answers
    |-- REGULATORY_CHUNKS + embeddings for RAG
    |-- DT_ALERT_ENRICHED for live alert data
```

## Example Interactions

```
User: /risk-alerts
Bot:  Open Alerts:
      🔴 ALT-002 | RAPID_INTERNATIONAL_TRANSFERS | CRITICAL | INVESTIGATING | CUST-003
      🔴 ALT-003 | ROUND_TRIPPING | CRITICAL | OPEN | CUST-013
      🟠 ALT-001 | STRUCTURING | HIGH | OPEN | CUST-002
      ...

User: /risk-ask What defines structuring under AML regulations?
Bot:  Question: What defines structuring under AML regulations?
      ─────
      According to the AML/CFT Policy Section 2, structuring is the deliberate
      breaking up of transactions to avoid CTR filing thresholds, which is a
      federal crime under 31 USC 5324. Indicators include:
      (a) Multiple cash deposits just below $10,000
      (b) Deposits at multiple branches on the same day...
      ─────
      Sources: AML_CFT_POLICY | Powered by Risk Copilot + Cortex AI
```
