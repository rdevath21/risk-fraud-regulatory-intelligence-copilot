-- ============================================================
-- Risk, Fraud & Regulatory Intelligence Copilot
-- Step 7: Semantic View with Verified Queries
-- ============================================================

USE SCHEMA RISK_COPILOT.PUBLIC;

CREATE OR REPLACE SEMANTIC VIEW SV_RISK_INTELLIGENCE
  TABLES (
    customers AS RISK_COPILOT.PUBLIC.CUSTOMERS PRIMARY KEY (CUSTOMER_ID)
      COMMENT = 'Customer profiles with risk attributes and KYC status',
    transactions AS RISK_COPILOT.PUBLIC.TRANSACTIONS PRIMARY KEY (TXN_ID)
      COMMENT = 'Financial transactions',
    alerts AS RISK_COPILOT.PUBLIC.ALERTS PRIMARY KEY (ALERT_ID)
      COMMENT = 'Risk and fraud alerts',
    risk_scores AS RISK_COPILOT.PUBLIC.RISK_SCORES PRIMARY KEY (CUSTOMER_ID)
      COMMENT = 'Composite risk scores per customer'
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
    transactions.txn_type AS transactions.TXN_TYPE COMMENT = 'Transaction type',
    transactions.txn_date AS transactions.TXN_DATE COMMENT = 'Transaction date',
    transactions.counterparty_country AS transactions.COUNTERPARTY_COUNTRY COMMENT = 'Counterparty country',
    transactions.currency AS transactions.CURRENCY COMMENT = 'Transaction currency',
    alerts.alert_type AS alerts.ALERT_TYPE COMMENT = 'Alert type',
    alerts.severity AS alerts.SEVERITY COMMENT = 'Alert severity level',
    alerts.alert_status AS alerts.STATUS COMMENT = 'Alert status',
    risk_scores.risk_category AS risk_scores.RISK_CATEGORY COMMENT = 'Risk category'
  )
  METRICS (
    transactions.total_volume AS SUM(transactions.AMOUNT) COMMENT = 'Total transaction volume',
    transactions.avg_amount AS AVG(transactions.AMOUNT) COMMENT = 'Average transaction amount',
    transactions.txn_count AS COUNT(transactions.TXN_ID) COMMENT = 'Transaction count',
    alerts.total_alerts AS COUNT(alerts.ALERT_ID) COMMENT = 'Total alerts',
    risk_scores.avg_risk_score AS AVG(risk_scores.COMPOSITE_SCORE) COMMENT = 'Average risk score'
  )
  COMMENT = 'Risk, Fraud & Regulatory Intelligence semantic model'
  AI_VERIFIED_QUERIES (
    vq_open_alerts AS (
      QUESTION 'Show all open and investigating alerts with customer details'
      SQL 'SELECT a.ALERT_ID, a.ALERT_TYPE, a.SEVERITY, a.STATUS, c.FULL_NAME, c.CUSTOMER_ID FROM RISK_COPILOT.PUBLIC.ALERTS a JOIN RISK_COPILOT.PUBLIC.CUSTOMERS c ON a.CUSTOMER_ID = c.CUSTOMER_ID WHERE a.STATUS IN (''OPEN'', ''INVESTIGATING'') ORDER BY a.SEVERITY DESC'
    ),
    vq_critical_customers AS (
      QUESTION 'List all high and critical risk customers with their scores'
      SQL 'SELECT c.CUSTOMER_ID, c.FULL_NAME, c.COUNTRY, rs.COMPOSITE_SCORE, rs.RISK_CATEGORY, c.PEP_FLAG FROM RISK_COPILOT.PUBLIC.CUSTOMERS c JOIN RISK_COPILOT.PUBLIC.RISK_SCORES rs ON c.CUSTOMER_ID = rs.CUSTOMER_ID WHERE rs.RISK_CATEGORY IN (''CRITICAL'', ''HIGH'') ORDER BY rs.COMPOSITE_SCORE DESC'
    ),
    vq_structuring AS (
      QUESTION 'Detect potential structuring patterns with multiple cash deposits under 10000 dollars in one day'
      SQL 'SELECT t.CUSTOMER_ID, c.FULL_NAME, DATE(t.TXN_DATE) AS TXN_DAY, COUNT(*) AS DEPOSIT_COUNT, SUM(t.AMOUNT) AS TOTAL_AMOUNT FROM RISK_COPILOT.PUBLIC.TRANSACTIONS t JOIN RISK_COPILOT.PUBLIC.CUSTOMERS c ON t.CUSTOMER_ID = c.CUSTOMER_ID WHERE t.TXN_TYPE = ''CASH_DEPOSIT'' AND t.AMOUNT BETWEEN 8000 AND 9999 GROUP BY t.CUSTOMER_ID, c.FULL_NAME, DATE(t.TXN_DATE) HAVING COUNT(*) >= 2'
    ),
    vq_high_risk_wires AS (
      QUESTION 'Show wire transfers to high risk jurisdictions sorted by amount'
      SQL 'SELECT t.TXN_ID, t.CUSTOMER_ID, c.FULL_NAME, t.AMOUNT, t.COUNTERPARTY_COUNTRY, t.TXN_DATE FROM RISK_COPILOT.PUBLIC.TRANSACTIONS t JOIN RISK_COPILOT.PUBLIC.CUSTOMERS c ON t.CUSTOMER_ID = c.CUSTOMER_ID WHERE t.TXN_TYPE = ''WIRE_TRANSFER'' AND t.COUNTERPARTY_COUNTRY IN (''Belize'', ''Panama'', ''Cayman Islands'', ''Cyprus'', ''Malta'', ''Latvia'') ORDER BY t.AMOUNT DESC'
    )
  );
