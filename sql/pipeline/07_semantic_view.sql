-- ============================================================
-- Risk, Fraud & Regulatory Intelligence Copilot
-- Step 7: Semantic View (SEMANTIC schema, reads from TRANSFORM)
-- ============================================================

USE SCHEMA RISK_COPILOT.SEMANTIC;

CREATE OR REPLACE SEMANTIC VIEW SV_RISK_INTELLIGENCE
  TABLES (
    customers AS RISK_COPILOT.TRANSFORM.DT_CUSTOMERS PRIMARY KEY (CUSTOMER_ID)
      COMMENT = 'Enriched customer profiles with KYC status and activity flags',
    transactions AS RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS PRIMARY KEY (TXN_ID)
      COMMENT = 'Enriched transactions with amount buckets and risk flags',
    alerts AS RISK_COPILOT.TRANSFORM.DT_ALERT_ENRICHED PRIMARY KEY (ALERT_ID)
      COMMENT = 'Enriched alerts with customer context and SLA tracking',
    risk_scores AS RISK_COPILOT.TRANSFORM.DT_RISK_ENRICHED PRIMARY KEY (CUSTOMER_ID)
      COMMENT = 'Customer risk scores with monitoring level classification'
  )
  RELATIONSHIPS (
    txn_to_cust AS transactions(CUSTOMER_ID) REFERENCES customers,
    alert_to_cust AS alerts(CUSTOMER_ID) REFERENCES customers,
    score_to_cust AS risk_scores(CUSTOMER_ID) REFERENCES customers
  )
  DIMENSIONS (
    customers.customer_country AS customers.COUNTRY COMMENT = 'Customer country',
    customers.risk_tier AS customers.RISK_TIER COMMENT = 'Customer risk tier',
    customers.kyc_status AS customers.KYC_STATUS COMMENT = 'KYC verification status',
    customers.is_pep AS customers.PEP_FLAG COMMENT = 'Politically Exposed Person flag',
    customers.account_type AS customers.ACCOUNT_TYPE COMMENT = 'Account type',
    customers.is_active AS customers.IS_ACTIVE COMMENT = 'Whether customer is active (activity within 90 days)',
    customers.kyc_action AS customers.KYC_ACTION_NEEDED COMMENT = 'KYC action needed: CURRENT, RENEWAL_REQUIRED, or REVIEW_REQUIRED',
    transactions.txn_type AS transactions.TXN_TYPE COMMENT = 'Transaction type',
    transactions.txn_date AS transactions.TXN_DATE COMMENT = 'Transaction date',
    transactions.counterparty_country AS transactions.COUNTERPARTY_COUNTRY COMMENT = 'Counterparty country',
    transactions.currency AS transactions.CURRENCY COMMENT = 'Transaction currency',
    transactions.amount_bucket AS transactions.AMOUNT_BUCKET COMMENT = 'Transaction size: MICRO, SMALL, MEDIUM, LARGE, JUMBO',
    transactions.is_high_value AS transactions.IS_HIGH_VALUE COMMENT = 'Whether transaction amount exceeds 100k',
    transactions.is_high_risk_dest AS transactions.IS_HIGH_RISK_DESTINATION COMMENT = 'Whether destination is a high-risk jurisdiction',
    alerts.alert_type AS alerts.ALERT_TYPE COMMENT = 'Alert type',
    alerts.severity AS alerts.SEVERITY COMMENT = 'Alert severity level',
    alerts.alert_status AS alerts.STATUS COMMENT = 'Alert status',
    alerts.sla_status AS alerts.SLA_STATUS COMMENT = 'SLA tracking: WITHIN_SLA, SLA_WARNING, SLA_BREACHED',
    risk_scores.risk_category AS risk_scores.RISK_CATEGORY COMMENT = 'Risk category',
    risk_scores.monitoring_level AS risk_scores.MONITORING_LEVEL COMMENT = 'Required monitoring level based on risk score'
  )
  METRICS (
    transactions.total_volume AS SUM(transactions.AMOUNT) COMMENT = 'Total transaction volume',
    transactions.avg_amount AS AVG(transactions.AMOUNT) COMMENT = 'Average transaction amount',
    transactions.txn_count AS COUNT(transactions.TXN_ID) COMMENT = 'Transaction count',
    alerts.total_alerts AS COUNT(alerts.ALERT_ID) COMMENT = 'Total alerts',
    risk_scores.avg_risk_score AS AVG(risk_scores.COMPOSITE_SCORE) COMMENT = 'Average risk score'
  )
  COMMENT = 'Risk, Fraud & Regulatory Intelligence semantic model - reads from TRANSFORM dynamic tables'
  AI_VERIFIED_QUERIES (
    vq_open_alerts AS (
      QUESTION 'Show all open and investigating alerts with customer details'
      SQL 'SELECT a.ALERT_ID, a.ALERT_TYPE, a.SEVERITY, a.STATUS, a.CUSTOMER_NAME, a.CUSTOMER_ID, a.SLA_STATUS FROM RISK_COPILOT.TRANSFORM.DT_ALERT_ENRICHED a WHERE a.STATUS IN (''OPEN'', ''INVESTIGATING'') ORDER BY a.SEVERITY DESC'
    ),
    vq_critical_customers AS (
      QUESTION 'List all high and critical risk customers with their scores'
      SQL 'SELECT r.CUSTOMER_ID, r.FULL_NAME, r.COUNTRY, r.COMPOSITE_SCORE, r.RISK_CATEGORY, r.MONITORING_LEVEL, r.PEP_FLAG FROM RISK_COPILOT.TRANSFORM.DT_RISK_ENRICHED r WHERE r.RISK_CATEGORY IN (''CRITICAL'', ''HIGH'') ORDER BY r.COMPOSITE_SCORE DESC'
    ),
    vq_structuring AS (
      QUESTION 'Detect potential structuring patterns with multiple cash deposits under 10000 dollars in one day'
      SQL 'SELECT t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY, COUNT(*) AS DEPOSIT_COUNT, SUM(t.AMOUNT) AS TOTAL_AMOUNT FROM RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS t JOIN RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c ON t.CUSTOMER_ID = c.CUSTOMER_ID WHERE t.TXN_TYPE = ''CASH_DEPOSIT'' AND t.AMOUNT BETWEEN 8000 AND 9999 GROUP BY t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY HAVING COUNT(*) >= 2'
    ),
    vq_high_risk_wires AS (
      QUESTION 'Show wire transfers to high risk jurisdictions sorted by amount'
      SQL 'SELECT t.TXN_ID, t.CUSTOMER_ID, c.FULL_NAME, t.AMOUNT, t.COUNTERPARTY_COUNTRY, t.TXN_DATE, t.AMOUNT_BUCKET FROM RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS t JOIN RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c ON t.CUSTOMER_ID = c.CUSTOMER_ID WHERE t.IS_HIGH_RISK_DESTINATION = TRUE AND t.TXN_TYPE = ''WIRE_TRANSFER'' ORDER BY t.AMOUNT DESC'
    )
  );
