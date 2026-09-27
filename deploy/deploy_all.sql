-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  RISK, FRAUD & REGULATORY INTELLIGENCE COPILOT                         ║
-- ║  Single-Script Deployment Package                                       ║
-- ║                                                                         ║
-- ║  INSTRUCTIONS: Paste this entire script into a Snowsight SQL Worksheet  ║
-- ║  and click "Run All". No git clone, no file uploads needed.             ║
-- ║                                                                         ║
-- ║  Prerequisites:                                                         ║
-- ║    - ACCOUNTADMIN role                                                  ║
-- ║    - Warehouse named COMPUTE_WH (or find-replace with yours)            ║
-- ║    - Cortex AI enabled region (llama3.1-70b + e5-base-v2)               ║
-- ║                                                                         ║
-- ║  After this script: deploy Streamlit app separately (see bottom)        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ════════════════════════════════════════════════════════════
-- STEP 1: DATABASE & SCHEMAS
-- ════════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS RISK_COPILOT;
CREATE SCHEMA IF NOT EXISTS RISK_COPILOT.RAW;
CREATE SCHEMA IF NOT EXISTS RISK_COPILOT.TRANSFORM;
CREATE SCHEMA IF NOT EXISTS RISK_COPILOT.SEMANTIC;

-- ════════════════════════════════════════════════════════════
-- STEP 2: RAW LAYER - TABLES + SYNTHETIC DATA
-- ════════════════════════════════════════════════════════════

USE SCHEMA RISK_COPILOT.RAW;

CREATE OR REPLACE TABLE RAW_CUSTOMERS (
    CUSTOMER_ID VARCHAR(20), FULL_NAME VARCHAR(100), EMAIL VARCHAR(100), PHONE VARCHAR(20),
    ADDRESS VARCHAR(200), COUNTRY VARCHAR(50), JURISDICTION_RISK VARCHAR(10), ACCOUNT_TYPE VARCHAR(20),
    KYC_STATUS VARCHAR(20), PEP_FLAG BOOLEAN, ACCOUNT_OPEN_DATE DATE, LAST_ACTIVITY_DATE DATE,
    RISK_TIER VARCHAR(10), INGESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW_CUSTOMERS (CUSTOMER_ID,FULL_NAME,EMAIL,PHONE,ADDRESS,COUNTRY,JURISDICTION_RISK,ACCOUNT_TYPE,KYC_STATUS,PEP_FLAG,ACCOUNT_OPEN_DATE,LAST_ACTIVITY_DATE,RISK_TIER) VALUES
('CUST-001','John Smith','jsmith@email.com','555-0101','123 Main St, New York, NY','United States','LOW','PERSONAL','VERIFIED',FALSE,'2019-03-15','2026-09-15','LOW'),
('CUST-002','Maria Garcia','mgarcia@email.com','555-0102','456 Oak Ave, Miami, FL','United States','LOW','PERSONAL','VERIFIED',FALSE,'2020-01-20','2026-09-14','MEDIUM'),
('CUST-003','Alexei Volkov','avolkov@mail.ru','555-0103','78 Nevsky Prospect, Moscow','Russia','HIGH','BUSINESS','VERIFIED',FALSE,'2021-06-10','2026-09-10','HIGH'),
('CUST-004','Chen Wei','cwei@email.cn','555-0104','99 Nanjing Rd, Shanghai','China','MEDIUM','BUSINESS','VERIFIED',FALSE,'2018-11-01','2026-09-12','MEDIUM'),
('CUST-005','Ahmed Al-Rashid','arashid@email.ae','555-0105','Tower 3, DIFC, Dubai','UAE','MEDIUM','PRIVATE_BANK','VERIFIED',TRUE,'2017-05-22','2026-09-15','HIGH'),
('CUST-006','Isabella Rossi','irossi@email.it','555-0106','Via Roma 12, Milan','Italy','LOW','PERSONAL','VERIFIED',FALSE,'2022-02-14','2026-09-13','LOW'),
('CUST-007','David Okonkwo','dokonkwo@email.ng','555-0107','15 Victoria Island, Lagos','Nigeria','HIGH','BUSINESS','PENDING',FALSE,'2023-08-30','2026-09-15','HIGH'),
('CUST-008','Sarah Chen','schen@email.com','555-0108','789 Pine St, San Francisco, CA','United States','LOW','PERSONAL','VERIFIED',FALSE,'2020-07-15','2026-08-01','LOW'),
('CUST-009','Viktor Petrov','vpetrov@email.com','555-0109','45 Bankova St, Kyiv','Ukraine','HIGH','BUSINESS','VERIFIED',FALSE,'2021-01-10','2026-09-14','HIGH'),
('CUST-010','Elena Marcos','emarcos@email.ph','555-0110','88 Ayala Ave, Makati','Philippines','MEDIUM','PERSONAL','VERIFIED',TRUE,'2019-09-05','2026-09-11','HIGH'),
('CUST-011','James Mitchell','jmitchell@email.com','555-0111','321 Elm St, Chicago, IL','United States','LOW','PERSONAL','VERIFIED',FALSE,'2021-04-18','2026-09-15','LOW'),
('CUST-012','Fatima Al-Saud','falsaud@email.sa','555-0112','King Fahd Rd, Riyadh','Saudi Arabia','MEDIUM','PRIVATE_BANK','VERIFIED',TRUE,'2016-12-01','2026-09-14','HIGH'),
('CUST-013','Carlos Mendez','cmendez@email.pa','555-0113','Calle 50, Panama City','Panama','HIGH','BUSINESS','VERIFIED',FALSE,'2022-05-20','2026-09-15','HIGH'),
('CUST-014','Liu Xiaoming','lxiaoming@email.hk','555-0114','Central Tower, Hong Kong','Hong Kong','MEDIUM','BUSINESS','VERIFIED',FALSE,'2020-10-10','2026-09-09','MEDIUM'),
('CUST-015','Rachel Adams','radams@email.com','555-0115','555 Broadway, New York, NY','United States','LOW','PERSONAL','VERIFIED',FALSE,'2023-01-15','2023-03-01','LOW'),
('CUST-016','Omar Hassan','ohassan@email.com','555-0116','12 Corniche Rd, Beirut','Lebanon','HIGH','PERSONAL','EXPIRED',FALSE,'2019-06-20','2026-09-15','HIGH'),
('CUST-017','Anna Kowalski','akowalski@email.pl','555-0117','Marszalkowska 10, Warsaw','Poland','LOW','PERSONAL','VERIFIED',FALSE,'2021-11-30','2026-09-12','LOW'),
('CUST-018','Roberto Silva','rsilva@email.br','555-0118','Av Paulista 1000, Sao Paulo','Brazil','MEDIUM','BUSINESS','VERIFIED',FALSE,'2020-03-25','2026-09-14','MEDIUM'),
('CUST-019','Yuki Tanaka','ytanaka@email.jp','555-0119','Marunouchi 1-1, Tokyo','Japan','LOW','BUSINESS','VERIFIED',FALSE,'2019-08-12','2026-09-15','LOW'),
('CUST-020','Shell Corp Holdings','info@shellcorp.bz','555-0120','PO Box 999, Belize City','Belize','HIGH','BUSINESS','PENDING',FALSE,'2024-01-05','2026-09-15','HIGH');

CREATE OR REPLACE TABLE RAW_TRANSACTIONS (
    TXN_ID VARCHAR(30), CUSTOMER_ID VARCHAR(20), TXN_DATE TIMESTAMP_NTZ, TXN_TYPE VARCHAR(30),
    AMOUNT FLOAT, CURRENCY VARCHAR(5), COUNTERPARTY VARCHAR(100), COUNTERPARTY_COUNTRY VARCHAR(50),
    CHANNEL VARCHAR(20), STATUS VARCHAR(15), DESCRIPTION VARCHAR(200),
    INGESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW_TRANSACTIONS (TXN_ID,CUSTOMER_ID,TXN_DATE,TXN_TYPE,AMOUNT,CURRENCY,COUNTERPARTY,COUNTERPARTY_COUNTRY,CHANNEL,STATUS,DESCRIPTION) VALUES
('TXN-0001','CUST-002','2026-09-10 09:15:00','CASH_DEPOSIT',9800,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 101'),
('TXN-0002','CUST-002','2026-09-10 11:30:00','CASH_DEPOSIT',9500,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 205'),
('TXN-0003','CUST-002','2026-09-10 14:45:00','CASH_DEPOSIT',9700,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 312'),
('TXN-0004','CUST-002','2026-09-11 10:00:00','CASH_DEPOSIT',9900,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 101'),
('TXN-0005','CUST-002','2026-09-11 13:20:00','CASH_DEPOSIT',9600,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 445'),
('TXN-0006','CUST-002','2026-09-12 09:00:00','WIRE_TRANSFER',45000,'USD','Offshore Holdings Ltd','Cayman Islands','ONLINE','COMPLETED','Wire to Cayman account'),
('TXN-0007','CUST-003','2026-09-13 08:00:00','WIRE_TRANSFER',150000,'USD','Baltic Trade LLC','Latvia','ONLINE','COMPLETED','Consulting services'),
('TXN-0008','CUST-003','2026-09-13 09:30:00','WIRE_TRANSFER',120000,'EUR','Cyprus Holdings SA','Cyprus','ONLINE','COMPLETED','Investment transfer'),
('TXN-0009','CUST-003','2026-09-13 14:00:00','WIRE_TRANSFER',200000,'USD','Dubai Commodities FZE','UAE','ONLINE','COMPLETED','Commodity purchase'),
('TXN-0010','CUST-003','2026-09-14 07:45:00','WIRE_TRANSFER',175000,'GBP','London Capital Partners','United Kingdom','ONLINE','COMPLETED','Portfolio rebalancing'),
('TXN-0011','CUST-003','2026-09-14 11:00:00','WIRE_TRANSFER',95000,'CHF','Geneva Wealth AG','Switzerland','ONLINE','COMPLETED','Asset management fee'),
('TXN-0012','CUST-013','2026-09-08 10:00:00','WIRE_TRANSFER',500000,'USD','Shell Corp Holdings','Belize','ONLINE','COMPLETED','Loan disbursement'),
('TXN-0013','CUST-020','2026-09-09 09:00:00','WIRE_TRANSFER',490000,'USD','Mendez Enterprises SA','Panama','ONLINE','COMPLETED','Repayment of loan'),
('TXN-0014','CUST-013','2026-09-10 10:30:00','WIRE_TRANSFER',485000,'USD','Shell Corp Holdings','Belize','ONLINE','COMPLETED','Investment capital'),
('TXN-0015','CUST-020','2026-09-11 08:15:00','WIRE_TRANSFER',480000,'USD','Mendez Enterprises SA','Panama','ONLINE','COMPLETED','Return of investment'),
('TXN-0016','CUST-020','2026-09-12 14:00:00','WIRE_TRANSFER',250000,'USD','Cayman Reserve Trust','Cayman Islands','ONLINE','COMPLETED','Trust fund allocation'),
('TXN-0017','CUST-015','2023-02-28 12:00:00','DEBIT_CARD',45.99,'USD','Amazon','United States','ONLINE','COMPLETED','Online purchase'),
('TXN-0018','CUST-015','2026-09-14 08:00:00','WIRE_TRANSFER',75000,'USD','Caribbean Investments LLC','Bahamas','ONLINE','COMPLETED','Investment wire'),
('TXN-0019','CUST-015','2026-09-14 10:00:00','WIRE_TRANSFER',60000,'USD','Pacific Rim Holdings','Singapore','ONLINE','COMPLETED','Business payment'),
('TXN-0020','CUST-015','2026-09-15 09:00:00','CASH_DEPOSIT',25000,'USD','Self','United States','BRANCH','COMPLETED','Large cash deposit'),
('TXN-0021','CUST-007','2026-09-14 06:00:00','WIRE_TRANSFER',4500,'USD','Account A','Ghana','ONLINE','COMPLETED','Payment 1'),
('TXN-0022','CUST-007','2026-09-14 06:30:00','WIRE_TRANSFER',4800,'USD','Account B','Senegal','ONLINE','COMPLETED','Payment 2'),
('TXN-0023','CUST-007','2026-09-14 07:00:00','WIRE_TRANSFER',4200,'USD','Account C','Cameroon','ONLINE','COMPLETED','Payment 3'),
('TXN-0024','CUST-007','2026-09-14 07:30:00','WIRE_TRANSFER',4600,'USD','Account D','Kenya','ONLINE','COMPLETED','Payment 4'),
('TXN-0025','CUST-007','2026-09-14 08:00:00','WIRE_TRANSFER',4900,'USD','Account E','Tanzania','ONLINE','COMPLETED','Payment 5'),
('TXN-0026','CUST-007','2026-09-14 08:30:00','WIRE_TRANSFER',4100,'USD','Account F','Uganda','ONLINE','COMPLETED','Payment 6'),
('TXN-0027','CUST-007','2026-09-14 09:00:00','WIRE_TRANSFER',4700,'USD','Account G','Rwanda','ONLINE','COMPLETED','Payment 7'),
('TXN-0028','CUST-007','2026-09-14 09:30:00','WIRE_TRANSFER',4300,'USD','Account H','Ethiopia','ONLINE','COMPLETED','Payment 8'),
('TXN-0029','CUST-001','2026-09-10 12:00:00','DEBIT_CARD',125.50,'USD','Whole Foods','United States','POS','COMPLETED','Grocery shopping'),
('TXN-0030','CUST-001','2026-09-12 09:00:00','ACH_TRANSFER',3200,'USD','Landlord LLC','United States','ONLINE','COMPLETED','Monthly rent'),
('TXN-0031','CUST-001','2026-09-14 15:00:00','DEBIT_CARD',89.99,'USD','Netflix/Spotify','United States','ONLINE','COMPLETED','Subscriptions'),
('TXN-0032','CUST-005','2026-09-05 10:00:00','WIRE_TRANSFER',2000000,'USD','Royal Investment Fund','UAE','ONLINE','COMPLETED','Sovereign fund allocation'),
('TXN-0033','CUST-005','2026-09-08 11:00:00','WIRE_TRANSFER',1500000,'GBP','London Real Estate PLC','United Kingdom','ONLINE','COMPLETED','Property acquisition'),
('TXN-0034','CUST-005','2026-09-12 14:00:00','WIRE_TRANSFER',750000,'EUR','Swiss Private Bank AG','Switzerland','ONLINE','COMPLETED','Wealth management transfer'),
('TXN-0035','CUST-012','2026-09-09 16:00:00','WIRE_TRANSFER',3200000,'USD','Christies Auction House','United Kingdom','ONLINE','COMPLETED','Art acquisition'),
('TXN-0036','CUST-012','2026-09-14 10:00:00','WIRE_TRANSFER',850000,'EUR','Monaco Yacht Sales','Monaco','ONLINE','COMPLETED','Yacht maintenance deposit'),
('TXN-0037','CUST-016','2026-09-13 09:00:00','WIRE_TRANSFER',35000,'USD','Istanbul Trading Co','Turkey','ONLINE','COMPLETED','Trade payment'),
('TXN-0038','CUST-016','2026-09-14 11:00:00','CASH_DEPOSIT',9800,'USD','Self','Lebanon','BRANCH','COMPLETED','Cash deposit'),
('TXN-0039','CUST-016','2026-09-15 08:00:00','WIRE_TRANSFER',28000,'EUR','Berlin Import GmbH','Germany','ONLINE','COMPLETED','Invoice payment'),
('TXN-0040','CUST-006','2026-09-10 08:30:00','DEBIT_CARD',230,'EUR','Zara Milano','Italy','POS','COMPLETED','Shopping'),
('TXN-0041','CUST-006','2026-09-13 12:00:00','ACH_TRANSFER',1800,'EUR','Telecom Italia','Italy','ONLINE','COMPLETED','Utility bill'),
('TXN-0042','CUST-011','2026-09-11 14:00:00','DEBIT_CARD',67.50,'USD','Target','United States','POS','COMPLETED','Household items'),
('TXN-0043','CUST-011','2026-09-14 09:00:00','ACH_TRANSFER',2100,'USD','Chase Mortgage','United States','ONLINE','COMPLETED','Mortgage payment'),
('TXN-0044','CUST-019','2026-09-12 10:00:00','WIRE_TRANSFER',50000,'JPY','Toyota Financial','Japan','ONLINE','COMPLETED','Auto lease payment'),
('TXN-0045','CUST-019','2026-09-14 15:00:00','DEBIT_CARD',15000,'JPY','Isetan Dept Store','Japan','POS','COMPLETED','Department store'),
('TXN-0046','CUST-009','2026-09-10 07:00:00','WIRE_TRANSFER',180000,'USD','Georgian Trading LLC','Georgia','ONLINE','COMPLETED','Export payment'),
('TXN-0047','CUST-009','2026-09-11 08:00:00','WIRE_TRANSFER',175000,'EUR','Malta Holdings Ltd','Malta','ONLINE','COMPLETED','Investment transfer'),
('TXN-0048','CUST-009','2026-09-12 09:00:00','WIRE_TRANSFER',170000,'GBP','Scottish LP Fund','United Kingdom','ONLINE','COMPLETED','LP contribution'),
('TXN-0049','CUST-009','2026-09-13 10:00:00','WIRE_TRANSFER',165000,'USD','Delaware Corp Inc','United States','ONLINE','COMPLETED','Corporate funding'),
('TXN-0050','CUST-009','2026-09-14 11:00:00','WIRE_TRANSFER',160000,'CHF','Zurich Fiduciary SA','Switzerland','ONLINE','COMPLETED','Fiduciary account');

CREATE OR REPLACE TABLE RAW_RISK_SCORES (
    CUSTOMER_ID VARCHAR(20), SCORE_DATE DATE, BEHAVIORAL_RISK FLOAT, JURISDICTIONAL_RISK FLOAT,
    NETWORK_RISK FLOAT, COMPOSITE_SCORE FLOAT, RISK_CATEGORY VARCHAR(10), MODEL_VERSION VARCHAR(10),
    INGESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW_RISK_SCORES (CUSTOMER_ID,SCORE_DATE,BEHAVIORAL_RISK,JURISDICTIONAL_RISK,NETWORK_RISK,COMPOSITE_SCORE,RISK_CATEGORY,MODEL_VERSION) VALUES
('CUST-001','2026-09-15',0.05,0.02,0.03,0.03,'LOW','v2.1'),('CUST-002','2026-09-15',0.82,0.02,0.15,0.65,'HIGH','v2.1'),
('CUST-003','2026-09-15',0.90,0.85,0.70,0.88,'CRITICAL','v2.1'),('CUST-004','2026-09-15',0.30,0.45,0.20,0.32,'MEDIUM','v2.1'),
('CUST-005','2026-09-15',0.60,0.40,0.55,0.58,'HIGH','v2.1'),('CUST-006','2026-09-15',0.04,0.05,0.02,0.04,'LOW','v2.1'),
('CUST-007','2026-09-15',0.88,0.75,0.65,0.82,'CRITICAL','v2.1'),('CUST-008','2026-09-15',0.03,0.02,0.01,0.02,'LOW','v2.1'),
('CUST-009','2026-09-15',0.85,0.80,0.75,0.84,'CRITICAL','v2.1'),('CUST-010','2026-09-15',0.55,0.35,0.45,0.48,'HIGH','v2.1'),
('CUST-011','2026-09-15',0.06,0.02,0.04,0.04,'LOW','v2.1'),('CUST-012','2026-09-15',0.50,0.30,0.40,0.42,'HIGH','v2.1'),
('CUST-013','2026-09-15',0.92,0.80,0.88,0.90,'CRITICAL','v2.1'),('CUST-014','2026-09-15',0.25,0.35,0.15,0.25,'MEDIUM','v2.1'),
('CUST-015','2026-09-15',0.78,0.02,0.10,0.55,'HIGH','v2.1'),('CUST-016','2026-09-15',0.70,0.75,0.50,0.68,'HIGH','v2.1'),
('CUST-017','2026-09-15',0.08,0.05,0.03,0.05,'LOW','v2.1'),('CUST-018','2026-09-15',0.20,0.30,0.15,0.22,'MEDIUM','v2.1'),
('CUST-019','2026-09-15',0.07,0.03,0.05,0.05,'LOW','v2.1'),('CUST-020','2026-09-15',0.95,0.90,0.92,0.94,'CRITICAL','v2.1');

CREATE OR REPLACE TABLE RAW_ALERTS (
    ALERT_ID VARCHAR(30), CUSTOMER_ID VARCHAR(20), ALERT_TYPE VARCHAR(40), SEVERITY VARCHAR(10),
    STATUS VARCHAR(20), CREATED_AT TIMESTAMP_NTZ, ASSIGNED_TO VARCHAR(50), DESCRIPTION VARCHAR(500),
    RELATED_TXNS VARCHAR(200), INGESTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW_ALERTS (ALERT_ID,CUSTOMER_ID,ALERT_TYPE,SEVERITY,STATUS,CREATED_AT,ASSIGNED_TO,DESCRIPTION,RELATED_TXNS) VALUES
('ALT-001','CUST-002','STRUCTURING','HIGH','OPEN','2026-09-12 16:00:00','analyst_jones','Multiple cash deposits just under $10,000 CTR threshold across branches within 48 hours. Total: $48,500 in 5 deposits. Followed by $45,000 wire to Cayman Islands.','TXN-0001,TXN-0002,TXN-0003,TXN-0004,TXN-0005,TXN-0006'),
('ALT-002','CUST-003','RAPID_INTERNATIONAL_TRANSFERS','CRITICAL','INVESTIGATING','2026-09-14 12:00:00','analyst_smith','5 international wires totaling $740k+ to 5 countries within 30 hours.','TXN-0007,TXN-0008,TXN-0009,TXN-0010,TXN-0011'),
('ALT-003','CUST-013','ROUND_TRIPPING','CRITICAL','OPEN','2026-09-12 15:00:00','analyst_jones','Circular fund flows between CUST-013 (Panama) and CUST-020 (Belize shell company).','TXN-0012,TXN-0013,TXN-0014,TXN-0015,TXN-0016'),
('ALT-004','CUST-015','DORMANT_REACTIVATION','HIGH','OPEN','2026-09-14 17:00:00','analyst_chen','Account dormant since March 2023 reactivated with $160k in wires to Bahamas/Singapore.','TXN-0018,TXN-0019,TXN-0020'),
('ALT-005','CUST-007','VELOCITY_ANOMALY','HIGH','OPEN','2026-09-14 10:00:00','analyst_smith','8 wires totaling $36,100 to 8 African countries within 3.5 hours.','TXN-0021,TXN-0022,TXN-0023,TXN-0024,TXN-0025,TXN-0026,TXN-0027,TXN-0028'),
('ALT-006','CUST-005','PEP_LARGE_TRANSACTIONS','MEDIUM','INVESTIGATING','2026-09-12 18:00:00','analyst_chen','PEP customer with $4.25M in transfers over 7 days.','TXN-0032,TXN-0033,TXN-0034'),
('ALT-007','CUST-009','LAYERING','CRITICAL','OPEN','2026-09-14 14:00:00','analyst_jones','Sequential wires $180k-$160k through 5 jurisdictions over 5 days. Classic layering.','TXN-0046,TXN-0047,TXN-0048,TXN-0049,TXN-0050'),
('ALT-008','CUST-016','KYC_EXPIRED_ACTIVITY','MEDIUM','OPEN','2026-09-15 09:00:00','analyst_smith','Customer with EXPIRED KYC conducting $72,800 in wire transfers.','TXN-0037,TXN-0038,TXN-0039'),
('ALT-009','CUST-020','SHELL_COMPANY_ACTIVITY','CRITICAL','INVESTIGATING','2026-09-13 11:00:00','analyst_jones','Potential shell company in $1.22M circular flows.','TXN-0013,TXN-0015,TXN-0016'),
('ALT-010','CUST-012','PEP_LUXURY_PURCHASES','MEDIUM','CLOSED','2026-09-14 16:00:00','analyst_chen','PEP: $3.2M art + $850k yacht. Consistent with known lifestyle. EDD completed.','TXN-0035,TXN-0036');

-- ════════════════════════════════════════════════════════════
-- STEP 3: REGULATORY DOCUMENTS (RAG CORPUS)
-- ════════════════════════════════════════════════════════════

USE SCHEMA RISK_COPILOT.PUBLIC;

CREATE OR REPLACE TABLE REGULATORY_CHUNKS (
    CHUNK_ID INT, DOC_NAME VARCHAR(100), DOC_TYPE VARCHAR(50), CHUNK_INDEX INT, CHUNK_TEXT VARCHAR(4000)
);

INSERT INTO REGULATORY_CHUNKS VALUES
(1,'AML_CFT_POLICY','POLICY',1,'ANTI-MONEY LAUNDERING AND COUNTER-FINANCING OF TERRORISM POLICY - Version 3.2, Effective Date: January 2026. SECTION 1: PURPOSE AND SCOPE. This policy establishes the framework for detecting, preventing, and reporting money laundering, terrorist financing, and other financial crimes. It applies to all employees, contractors, and agents of the institution across all business lines and jurisdictions. Compliance with this policy is mandatory and failure to adhere may result in disciplinary action, regulatory penalties, and criminal prosecution.'),
(2,'AML_CFT_POLICY','POLICY',2,'SECTION 2: CURRENCY TRANSACTION REPORTING (CTR). All cash transactions exceeding $10,000 USD (or equivalent in foreign currency) must be reported via Currency Transaction Report (CTR) filed with FinCEN within 15 calendar days. Multiple cash transactions by or on behalf of the same person that aggregate to more than $10,000 in a single business day must also be reported. Structuring: The deliberate breaking up of transactions to avoid CTR filing thresholds is a federal crime under 31 USC 5324. Indicators include: (a) Multiple cash deposits just below $10,000, (b) Deposits at multiple branches on the same day, (c) Deposits by multiple individuals for a single account, (d) Customer awareness of reporting thresholds.'),
(3,'AML_CFT_POLICY','POLICY',3,'SECTION 3: SUSPICIOUS ACTIVITY REPORTING (SAR). A SAR must be filed with FinCEN within 30 calendar days of initial detection when the institution knows, suspects, or has reason to suspect that a transaction: (a) involves funds from illegal activity, (b) is designed to evade reporting requirements, (c) lacks a lawful purpose, or (d) involves use of the institution to facilitate criminal activity. SAR filing thresholds: Mandatory SAR for transactions of $5,000 or more involving a known suspect. For transactions of $25,000 or more, a SAR must be filed regardless of whether a suspect is identified.'),
(4,'AML_CFT_POLICY','POLICY',4,'SECTION 4: CUSTOMER DUE DILIGENCE (CDD) AND ENHANCED DUE DILIGENCE (EDD). Standard CDD: All customers must undergo identity verification at account opening including full legal name, date of birth, address, government-issued ID, and beneficial ownership for legal entities (25% or greater). EDD is required for: (a) PEPs and close associates, (b) Customers from high-risk jurisdictions, (c) Private banking relationships exceeding $1 million, (d) Correspondent banking, (e) Non-profits in high-risk sectors. EDD measures include senior management approval, source of wealth documentation, enhanced monitoring, and annual review.'),
(5,'AML_CFT_POLICY','POLICY',5,'SECTION 5: POLITICALLY EXPOSED PERSONS (PEP) SCREENING. PEPs include current or former senior government officials, senior executives of state-owned enterprises, senior political party officials, and their immediate family members and close associates. All customers must be screened against PEP databases at onboarding and annually. PEP accounts require: (a) Senior management approval, (b) Source of wealth and funds documentation, (c) Enhanced ongoing monitoring, (d) Annual compliance review. Transactions by PEPs exceeding $100,000 trigger automatic enhanced review. Art, real estate, and luxury goods purchases by PEPs require additional scrutiny.'),
(6,'AML_CFT_POLICY','POLICY',6,'SECTION 6: HIGH-RISK JURISDICTIONS AND GEOGRAPHIC RISK. Transactions involving these jurisdictions require enhanced monitoring: FATF Blacklist: North Korea, Iran, Myanmar. Institution High-Risk List: Russia, Belarus, Belize, Panama, Cayman Islands, British Virgin Islands, and jurisdictions with Transparency International CPI scores below 40. Wire transfers to or from high-risk jurisdictions exceeding $25,000 require compliance officer review within 24 hours. Correspondent banking with institutions in high-risk jurisdictions is prohibited without Board approval.'),
(7,'AML_CFT_POLICY','POLICY',7,'SECTION 7: TRANSACTION MONITORING RULES. RULE TM-001 (Structuring): Flag when a customer conducts 3+ cash transactions below $10,000 within 24 hours. RULE TM-002 (Rapid Transfer): Flag when wires to 3+ countries within 48 hours exceed $100,000 aggregate. RULE TM-003 (Round-Tripping): Flag when funds cycle between related accounts within 7 days with no economic purpose. RULE TM-004 (Dormant Reactivation): Flag when accounts inactive 90+ days receive or send transfers exceeding $10,000. RULE TM-005 (Velocity Spike): Flag when 24-hour transaction count exceeds 3x the 90-day average.'),
(8,'AML_CFT_POLICY','POLICY',8,'SECTION 8: INVESTIGATION AND ESCALATION PROCEDURES. Alert Triage SLA: All alerts triaged within 4 hours. Severity levels: CRITICAL - Investigated within 24 hours, potential immediate regulatory reporting. HIGH - Investigated within 48 hours. MEDIUM - Investigated within 5 business days. LOW - Reviewed within 10 business days. CRITICAL and HIGH alerts unresolved after 48 hours must be escalated to the BSA Officer. Cases requiring SAR filing escalated to SAR Review Committee within 72 hours.'),
(9,'BASEL_III_LIQUIDITY','REGULATION',1,'BASEL III LIQUIDITY COVERAGE RATIO (LCR) GUIDANCE - BCBS 238. The LCR requires banks to hold sufficient HQLA to cover total net cash outflows over a 30-day stress scenario. Minimum LCR = 100%. LCR = Stock of HQLA / Total Net Cash Outflows over 30 days >= 100%.'),
(10,'BASEL_III_LIQUIDITY','REGULATION',2,'SECTION 2: HIGH-QUALITY LIQUID ASSETS (HQLA). Level 1 (no haircut, unlimited): Cash, central bank reserves, sovereign debt rated AA- or higher. Level 2A (15% haircut, max 40%): Sovereign debt A+ to BBB-, covered bonds AA- or higher, corporate bonds AA- or higher. Level 2B (25-50% haircut, max 15%): Corporate bonds A+ to BBB-, publicly traded equity, RMBS rated AA or higher.'),
(11,'BASEL_III_LIQUIDITY','REGULATION',3,'SECTION 3: CASH OUTFLOW ASSUMPTIONS. Retail deposits: Stable 5% run-off, less stable 10%. Unsecured wholesale: Operational 25%, non-operational from FIs 100%, non-financial corporates 40%. Secured funding: Level 1 backed 0%, Level 2A backed 15%, other 100%. Credit facilities to non-financial corporates: 10% drawdown. Liquidity facilities: 30% drawdown.'),
(12,'BASEL_III_LIQUIDITY','REGULATION',4,'SECTION 4: STRESS SCENARIO PARAMETERS. The LCR stress assumes a combined idiosyncratic and market-wide shock lasting 30 days including: credit rating downgrade up to 3 notches, partial loss of retail deposits, complete loss of unsecured wholesale funding from FIs, increased secured funding haircuts, derivative collateral calls, committed facility drawdowns. Institutions must conduct additional stress tests including 1-day, 7-day, 14-day, 90-day horizons.'),
(13,'BASEL_III_LIQUIDITY','REGULATION',5,'SECTION 5: NET STABLE FUNDING RATIO (NSFR). NSFR = ASF / RSF >= 100%. ASF: Tier 1/2 capital 100%, stable retail deposits >1yr 95%, less stable retail 90%, wholesale >1yr 100%, wholesale 6m-1yr 50%. RSF: Cash 0%, Level 1 HQLA 5%, Level 2A 15%, performing loans to FIs <6m 10%, non-financial corporate loans <1yr 50%, residential mortgages 65%, all other assets 100%.'),
(14,'INTERNAL_RISK_POLICY','POLICY',1,'INTERNAL RISK MANAGEMENT FRAMEWORK - Version 2.0. SECTION 1: RISK APPETITE. Key metrics: Operational loss tolerance max 2% of annual revenue, zero tolerance for willful AML facilitation, NPL ratio max 3%, LCR above 110% (10% buffer), no tolerance for material enforcement actions. Reviewed quarterly by Board Risk Committee.'),
(15,'INTERNAL_RISK_POLICY','POLICY',2,'SECTION 2: THREE LINES OF DEFENSE. First Line: Business units own and manage risk daily. Second Line: Risk management and compliance provide oversight (AML/BSA Team, ERM, InfoSec). Third Line: Internal Audit provides independent assurance, reports to Audit Committee. BSA/AML Officer reports to CCO with direct Board escalation path.'),
(16,'INTERNAL_RISK_POLICY','POLICY',3,'SECTION 3: ESCALATION MATRIX AND INVESTIGATION SLAs. Level 1 (Analyst): MEDIUM/LOW alerts. Level 2 (Senior Analyst): HIGH alerts and complex cases. Level 3 (BSA Officer): CRITICAL alerts, SAR determinations. Level 4 (Board): Systemic issues, enforcement. SLAs: Initial triage 4 hours, CRITICAL completion 24 hours, HIGH 48 hours, MEDIUM 5 business days, SAR filing 30 calendar days. QA: 10% random sample reviewed monthly.'),
(17,'INTERNAL_RISK_POLICY','POLICY',4,'SECTION 4: EVIDENCE DOCUMENTATION STANDARDS. All investigation files must contain: (a) Alert details, (b) Customer profile with risk tier, KYC, PEP status, (c) Transaction analysis with timeline, amounts, counterparties, jurisdictions, (d) Regulatory citations, (e) Peer comparison, (f) Investigator narrative with findings and reasoning, (g) Disposition recommendation, (h) Supporting exhibits. Retained 5 years per BSA requirements.'),
(18,'INTERNAL_RISK_POLICY','POLICY',5,'SECTION 5: COPILOT AND AI-ASSISTED INVESTIGATION GUIDELINES. Guidelines: (a) AI-generated narratives must be reviewed by a human investigator before finalization, (b) AI risk assessments are advisory only for SAR decisions, (c) All regulatory citations must be verified against source documents, (d) All Copilot interactions are audit-logged, (e) Model subject to quarterly validation by Model Risk Management, (f) Outputs monitored for demographic bias.');

-- ════════════════════════════════════════════════════════════
-- STEP 4: RAG PIPELINE - EMBEDDINGS + CORTEX SEARCH
-- ════════════════════════════════════════════════════════════

ALTER TABLE REGULATORY_CHUNKS ADD COLUMN IF NOT EXISTS CHUNK_EMBEDDING VECTOR(FLOAT, 768);
UPDATE REGULATORY_CHUNKS SET CHUNK_EMBEDDING = SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', CHUNK_TEXT);

CREATE OR REPLACE CORTEX SEARCH SERVICE REGULATORY_SEARCH_SERVICE
  ON CHUNK_TEXT
  ATTRIBUTES DOC_NAME, DOC_TYPE
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
  AS (SELECT CHUNK_TEXT, DOC_NAME, DOC_TYPE, CHUNK_ID FROM REGULATORY_CHUNKS);

-- ════════════════════════════════════════════════════════════
-- STEP 5: DETECTION VIEWS + AUDIT LOG
-- ════════════════════════════════════════════════════════════

-- Keep legacy views in PUBLIC for backward compatibility
CREATE OR REPLACE TABLE COPILOT_AUDIT_LOG (
    LOG_ID INT AUTOINCREMENT, ACTION_TYPE VARCHAR(50), ALERT_ID VARCHAR(30),
    USER_QUERY VARCHAR(2000), RAG_CONTEXT VARCHAR(8000), LLM_RESPONSE VARCHAR(16000),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), CREATED_BY VARCHAR(100) DEFAULT CURRENT_USER()
);

-- Also keep PUBLIC copies for detection views (used by governance/tests)
CREATE OR REPLACE TABLE CUSTOMERS AS SELECT * EXCLUDE INGESTED_AT FROM RISK_COPILOT.RAW.RAW_CUSTOMERS;
CREATE OR REPLACE TABLE TRANSACTIONS AS SELECT * EXCLUDE INGESTED_AT FROM RISK_COPILOT.RAW.RAW_TRANSACTIONS;
CREATE OR REPLACE TABLE RISK_SCORES AS SELECT * EXCLUDE INGESTED_AT FROM RISK_COPILOT.RAW.RAW_RISK_SCORES;
CREATE OR REPLACE TABLE ALERTS AS SELECT * EXCLUDE INGESTED_AT FROM RISK_COPILOT.RAW.RAW_ALERTS;

CREATE OR REPLACE VIEW V_STRUCTURING_ALERTS AS
SELECT t.CUSTOMER_ID, c.FULL_NAME, DATE(t.TXN_DATE) AS TXN_DAY, COUNT(*) AS CASH_DEPOSIT_COUNT,
    SUM(t.AMOUNT) AS TOTAL_AMOUNT, LISTAGG(t.TXN_ID, ', ') WITHIN GROUP (ORDER BY t.TXN_DATE) AS RELATED_TXNS
FROM TRANSACTIONS t JOIN CUSTOMERS c ON t.CUSTOMER_ID = c.CUSTOMER_ID
WHERE t.TXN_TYPE = 'CASH_DEPOSIT' AND t.AMOUNT BETWEEN 8000 AND 9999
GROUP BY t.CUSTOMER_ID, c.FULL_NAME, DATE(t.TXN_DATE) HAVING COUNT(*) >= 2;

CREATE OR REPLACE VIEW V_VELOCITY_ANOMALIES AS
WITH daily_counts AS (SELECT CUSTOMER_ID, DATE(TXN_DATE) AS TXN_DAY, COUNT(*) AS DAILY_TXN_COUNT FROM TRANSACTIONS GROUP BY CUSTOMER_ID, DATE(TXN_DATE)),
avg_counts AS (SELECT CUSTOMER_ID, AVG(DAILY_TXN_COUNT) AS AVG_DAILY_COUNT FROM daily_counts GROUP BY CUSTOMER_ID)
SELECT d.CUSTOMER_ID, c.FULL_NAME, d.TXN_DAY, d.DAILY_TXN_COUNT, ROUND(a.AVG_DAILY_COUNT,1) AS AVG_DAILY_COUNT
FROM daily_counts d JOIN avg_counts a ON d.CUSTOMER_ID=a.CUSTOMER_ID JOIN CUSTOMERS c ON d.CUSTOMER_ID=c.CUSTOMER_ID
WHERE d.DAILY_TXN_COUNT >= 3*a.AVG_DAILY_COUNT AND d.DAILY_TXN_COUNT >= 3;

CREATE OR REPLACE VIEW V_HIGH_RISK_JURISDICTIONS AS
SELECT t.TXN_ID, t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DATE, t.AMOUNT, t.COUNTERPARTY_COUNTRY
FROM TRANSACTIONS t JOIN CUSTOMERS c ON t.CUSTOMER_ID=c.CUSTOMER_ID
WHERE t.COUNTERPARTY_COUNTRY IN ('Russia','Belarus','Belize','Panama','Cayman Islands','British Virgin Islands','Iran','North Korea','Myanmar','Cyprus','Malta','Latvia')
   OR c.JURISDICTION_RISK = 'HIGH';

CREATE OR REPLACE VIEW V_DORMANT_REACTIVATION AS
WITH last_old AS (SELECT CUSTOMER_ID, MAX(TXN_DATE) AS LAST_BEFORE FROM TRANSACTIONS WHERE TXN_DATE < DATEADD('day',-90,CURRENT_TIMESTAMP()) GROUP BY CUSTOMER_ID),
recent AS (SELECT CUSTOMER_ID, MIN(TXN_DATE) AS REACT_DATE, COUNT(*) AS CNT, SUM(AMOUNT) AS AMT FROM TRANSACTIONS WHERE TXN_DATE >= DATEADD('day',-30,CURRENT_TIMESTAMP()) GROUP BY CUSTOMER_ID)
SELECT r.CUSTOMER_ID, c.FULL_NAME, l.LAST_BEFORE, r.REACT_DATE, DATEDIFF('day',l.LAST_BEFORE,r.REACT_DATE) AS DORMANCY_DAYS, r.CNT, r.AMT
FROM recent r JOIN last_old l ON r.CUSTOMER_ID=l.CUSTOMER_ID JOIN CUSTOMERS c ON r.CUSTOMER_ID=c.CUSTOMER_ID
WHERE DATEDIFF('day',l.LAST_BEFORE,r.REACT_DATE) >= 90;

-- ════════════════════════════════════════════════════════════
-- STEP 6: TRANSFORM LAYER (DYNAMIC TABLES)
-- ════════════════════════════════════════════════════════════

USE SCHEMA RISK_COPILOT.TRANSFORM;

CREATE OR REPLACE DYNAMIC TABLE DT_CUSTOMERS TARGET_LAG='1 minute' WAREHOUSE=COMPUTE_WH AS
SELECT *, DATEDIFF('day',ACCOUNT_OPEN_DATE,CURRENT_DATE()) AS ACCOUNT_AGE_DAYS,
    CASE WHEN DATEDIFF('day',LAST_ACTIVITY_DATE,CURRENT_DATE())<=90 THEN TRUE ELSE FALSE END AS IS_ACTIVE,
    DATEDIFF('day',LAST_ACTIVITY_DATE,CURRENT_DATE()) AS DAYS_SINCE_LAST_ACTIVITY,
    CASE WHEN KYC_STATUS='EXPIRED' THEN 'RENEWAL_REQUIRED' WHEN KYC_STATUS='PENDING' THEN 'REVIEW_REQUIRED' ELSE 'CURRENT' END AS KYC_ACTION_NEEDED
FROM RISK_COPILOT.RAW.RAW_CUSTOMERS;

CREATE OR REPLACE DYNAMIC TABLE DT_TRANSACTIONS TARGET_LAG='1 minute' WAREHOUSE=COMPUTE_WH AS
SELECT *, TXN_DATE::DATE AS TXN_DAY,
    CASE WHEN AMOUNT<1000 THEN 'MICRO' WHEN AMOUNT<10000 THEN 'SMALL' WHEN AMOUNT<100000 THEN 'MEDIUM' WHEN AMOUNT<1000000 THEN 'LARGE' ELSE 'JUMBO' END AS AMOUNT_BUCKET,
    CASE WHEN AMOUNT>=10000 THEN TRUE ELSE FALSE END AS IS_CTR_REPORTABLE,
    CASE WHEN AMOUNT>=100000 THEN TRUE ELSE FALSE END AS IS_HIGH_VALUE,
    CASE WHEN COUNTERPARTY_COUNTRY IN ('Belize','Panama','Cayman Islands','Cyprus','Malta','Latvia','Bahamas') THEN TRUE ELSE FALSE END AS IS_HIGH_RISK_DESTINATION
FROM RISK_COPILOT.RAW.RAW_TRANSACTIONS;

CREATE OR REPLACE DYNAMIC TABLE DT_RISK_ENRICHED TARGET_LAG='1 minute' WAREHOUSE=COMPUTE_WH AS
SELECT c.CUSTOMER_ID, c.FULL_NAME, c.COUNTRY, c.ACCOUNT_TYPE, c.KYC_STATUS, c.PEP_FLAG, c.RISK_TIER, c.IS_ACTIVE, c.KYC_ACTION_NEEDED,
    COALESCE(rs.BEHAVIORAL_RISK,0) AS BEHAVIORAL_RISK, COALESCE(rs.JURISDICTIONAL_RISK,0) AS JURISDICTIONAL_RISK,
    COALESCE(rs.NETWORK_RISK,0) AS NETWORK_RISK, COALESCE(rs.COMPOSITE_SCORE,0) AS COMPOSITE_SCORE,
    COALESCE(rs.RISK_CATEGORY,'UNSCORED') AS RISK_CATEGORY, rs.MODEL_VERSION, rs.SCORE_DATE,
    CASE WHEN rs.COMPOSITE_SCORE>=0.8 THEN 'IMMEDIATE_REVIEW' WHEN rs.COMPOSITE_SCORE>=0.5 THEN 'ENHANCED_MONITORING'
         WHEN rs.COMPOSITE_SCORE>=0.3 THEN 'STANDARD_MONITORING' ELSE 'LOW_TOUCH' END AS MONITORING_LEVEL
FROM RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c LEFT JOIN RISK_COPILOT.RAW.RAW_RISK_SCORES rs ON c.CUSTOMER_ID=rs.CUSTOMER_ID;

CREATE OR REPLACE DYNAMIC TABLE DT_ALERT_ENRICHED TARGET_LAG='1 minute' WAREHOUSE=COMPUTE_WH AS
SELECT a.ALERT_ID, a.CUSTOMER_ID, a.ALERT_TYPE, a.SEVERITY, a.STATUS, a.CREATED_AT, a.ASSIGNED_TO, a.DESCRIPTION, a.RELATED_TXNS,
    c.FULL_NAME AS CUSTOMER_NAME, c.COUNTRY AS CUSTOMER_COUNTRY, c.PEP_FLAG, c.KYC_STATUS, c.RISK_TIER,
    DATEDIFF('day',a.CREATED_AT,CURRENT_TIMESTAMP()) AS ALERT_AGE_DAYS,
    CASE WHEN a.SEVERITY='CRITICAL' AND DATEDIFF('hour',a.CREATED_AT,CURRENT_TIMESTAMP())>24 THEN 'SLA_BREACHED'
         WHEN a.SEVERITY='HIGH' AND DATEDIFF('hour',a.CREATED_AT,CURRENT_TIMESTAMP())>72 THEN 'SLA_BREACHED'
         WHEN a.SEVERITY='CRITICAL' AND DATEDIFF('hour',a.CREATED_AT,CURRENT_TIMESTAMP())>12 THEN 'SLA_WARNING'
         WHEN a.SEVERITY='HIGH' AND DATEDIFF('hour',a.CREATED_AT,CURRENT_TIMESTAMP())>48 THEN 'SLA_WARNING'
         ELSE 'WITHIN_SLA' END AS SLA_STATUS
FROM RISK_COPILOT.RAW.RAW_ALERTS a LEFT JOIN RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c ON a.CUSTOMER_ID=c.CUSTOMER_ID;

CREATE OR REPLACE DYNAMIC TABLE DT_CUSTOMER_RISK_SUMMARY TARGET_LAG='1 minute' WAREHOUSE=COMPUTE_WH AS
SELECT c.CUSTOMER_ID, c.FULL_NAME, c.COUNTRY, c.RISK_TIER, c.KYC_STATUS, c.PEP_FLAG,
    COALESCE(rs.COMPOSITE_SCORE,0) AS COMPOSITE_RISK_SCORE, COALESCE(rs.RISK_CATEGORY,'UNKNOWN') AS RISK_CATEGORY,
    COUNT(t.TXN_ID) AS TOTAL_TRANSACTIONS, COALESCE(SUM(t.AMOUNT),0) AS TOTAL_AMOUNT,
    COUNT(CASE WHEN t.TXN_TYPE='WIRE_TRANSFER' THEN 1 END) AS WIRE_COUNT,
    COUNT(CASE WHEN t.IS_HIGH_VALUE THEN 1 END) AS HIGH_VALUE_TXN_COUNT,
    COUNT(DISTINCT t.COUNTERPARTY_COUNTRY) AS UNIQUE_COUNTRIES,
    MAX(t.TXN_DATE) AS LAST_TRANSACTION_DATE,
    COUNT(a.ALERT_ID) AS OPEN_ALERT_COUNT
FROM RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c
LEFT JOIN RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS t ON c.CUSTOMER_ID=t.CUSTOMER_ID
LEFT JOIN RISK_COPILOT.RAW.RAW_RISK_SCORES rs ON c.CUSTOMER_ID=rs.CUSTOMER_ID
LEFT JOIN RISK_COPILOT.RAW.RAW_ALERTS a ON c.CUSTOMER_ID=a.CUSTOMER_ID AND a.STATUS!='CLOSED'
GROUP BY c.CUSTOMER_ID, c.FULL_NAME, c.COUNTRY, c.RISK_TIER, c.KYC_STATUS, c.PEP_FLAG, rs.COMPOSITE_SCORE, rs.RISK_CATEGORY;

CREATE OR REPLACE DYNAMIC TABLE DT_SUSPICIOUS_PATTERNS TARGET_LAG='1 minute' WAREHOUSE=COMPUTE_WH AS
SELECT 'STRUCTURING' AS PATTERN_TYPE, t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY AS DETECTION_DATE, COUNT(*) AS EVENT_COUNT, SUM(t.AMOUNT) AS TOTAL_AMOUNT, 'Multiple cash deposits under $10k' AS PATTERN_DESCRIPTION
FROM RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS t JOIN RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c ON t.CUSTOMER_ID=c.CUSTOMER_ID
WHERE t.TXN_TYPE='CASH_DEPOSIT' AND t.AMOUNT BETWEEN 8000 AND 9999 GROUP BY t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY HAVING COUNT(*)>=2
UNION ALL
SELECT 'VELOCITY_ANOMALY', t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY, COUNT(*), SUM(t.AMOUNT), 'High velocity transfers to multiple countries'
FROM RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS t JOIN RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c ON t.CUSTOMER_ID=c.CUSTOMER_ID
WHERE t.TXN_TYPE='WIRE_TRANSFER' GROUP BY t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY HAVING COUNT(DISTINCT t.COUNTERPARTY_COUNTRY)>=3
UNION ALL
SELECT 'HIGH_RISK_DESTINATION', t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY, COUNT(*), SUM(t.AMOUNT), 'Wire transfers to high-risk jurisdictions'
FROM RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS t JOIN RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c ON t.CUSTOMER_ID=c.CUSTOMER_ID
WHERE t.IS_HIGH_RISK_DESTINATION=TRUE AND t.TXN_TYPE='WIRE_TRANSFER' GROUP BY t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY;

-- ════════════════════════════════════════════════════════════
-- STEP 7: SCHEDULED TASKS (DAILY INGESTION + DETECTION)
-- ════════════════════════════════════════════════════════════

USE SCHEMA RISK_COPILOT.RAW;

CREATE OR REPLACE STREAM RAW_TRANSACTIONS_STREAM ON TABLE RAW_TRANSACTIONS APPEND_ONLY=TRUE;

CREATE OR REPLACE TASK TASK_DAILY_DATA_INGESTION WAREHOUSE=COMPUTE_WH SCHEDULE='USING CRON 0 2 * * * UTC'
  COMMENT='Daily synthetic transaction ingestion at 2AM UTC'
AS INSERT INTO RAW_TRANSACTIONS (TXN_ID,CUSTOMER_ID,TXN_DATE,TXN_TYPE,AMOUNT,CURRENCY,COUNTERPARTY,COUNTERPARTY_COUNTRY,CHANNEL,STATUS,DESCRIPTION)
SELECT 'TXN-AUTO-'||TO_CHAR(CURRENT_TIMESTAMP(),'YYYYMMDD')||'-'||SEQ4(), cust.CUSTOMER_ID,
    DATEADD('hour',-1*UNIFORM(1,23,RANDOM()),CURRENT_TIMESTAMP()), txn.TXN_TYPE,
    ROUND(UNIFORM(100,500000,RANDOM())::FLOAT*CASE WHEN cust.RISK_TIER='HIGH' THEN 2.0 WHEN cust.RISK_TIER='MEDIUM' THEN 1.0 ELSE 0.3 END,2),
    CASE WHEN UNIFORM(1,10,RANDOM())<=7 THEN 'USD' WHEN UNIFORM(1,10,RANDOM())<=9 THEN 'EUR' ELSE 'GBP' END,
    CASE txn.TXN_TYPE WHEN 'WIRE_TRANSFER' THEN ctry.CP WHEN 'CASH_DEPOSIT' THEN 'Self' ELSE 'Domestic Entity' END,
    CASE txn.TXN_TYPE WHEN 'WIRE_TRANSFER' THEN ctry.CN ELSE cust.COUNTRY END,
    CASE WHEN txn.TXN_TYPE IN ('WIRE_TRANSFER','ACH_TRANSFER') THEN 'ONLINE' WHEN txn.TXN_TYPE='CASH_DEPOSIT' THEN 'BRANCH' ELSE 'POS' END,
    'COMPLETED', 'Auto-generated - '||txn.TXN_TYPE
FROM (SELECT CUSTOMER_ID,COUNTRY,RISK_TIER FROM RAW_CUSTOMERS ORDER BY RANDOM() LIMIT 8) cust
CROSS JOIN (SELECT column1 AS TXN_TYPE FROM VALUES('WIRE_TRANSFER'),('CASH_DEPOSIT'),('ACH_TRANSFER'),('DEBIT_CARD') ORDER BY RANDOM() LIMIT 1) txn
CROSS JOIN (SELECT column1 AS CP, column2 AS CN FROM VALUES('Global Trading Corp','United Kingdom'),('Caribbean Trust','Cayman Islands'),('Malta Investments','Malta'),('Berlin GmbH','Germany') ORDER BY RANDOM() LIMIT 1) ctry;

ALTER TASK TASK_DAILY_DATA_INGESTION RESUME;

CREATE OR REPLACE TASK TASK_AUTO_ALERT_DETECTION WAREHOUSE=COMPUTE_WH SCHEDULE='USING CRON */15 * * * * UTC'
  COMMENT='Automated structuring detection from stream' WHEN SYSTEM$STREAM_HAS_DATA('RISK_COPILOT.RAW.RAW_TRANSACTIONS_STREAM')
AS INSERT INTO RAW_ALERTS (ALERT_ID,CUSTOMER_ID,ALERT_TYPE,SEVERITY,STATUS,CREATED_AT,ASSIGNED_TO,DESCRIPTION,RELATED_TXNS)
SELECT 'ALT-AUTO-'||TO_CHAR(CURRENT_TIMESTAMP(),'YYYYMMDDHH24MISS')||'-'||CUSTOMER_ID,
    CUSTOMER_ID,'STRUCTURING','HIGH','OPEN',CURRENT_TIMESTAMP(),'auto_detection',
    'Automated: '||COUNT(*)||' cash deposits under $10k totaling $'||ROUND(SUM(AMOUNT),2),
    LISTAGG(TXN_ID,',') WITHIN GROUP (ORDER BY TXN_DATE)
FROM RAW_TRANSACTIONS_STREAM WHERE TXN_TYPE='CASH_DEPOSIT' AND AMOUNT BETWEEN 8000 AND 9999
GROUP BY CUSTOMER_ID, DATE(TXN_DATE) HAVING COUNT(*)>=2;

ALTER TASK TASK_AUTO_ALERT_DETECTION RESUME;

CREATE OR REPLACE TASK TASK_DAILY_RISK_REFRESH WAREHOUSE=COMPUTE_WH SCHEDULE='USING CRON 0 6 * * * UTC'
  COMMENT='Daily risk score recalculation at 6AM UTC'
AS MERGE INTO RAW_RISK_SCORES rs USING (
    SELECT c.CUSTOMER_ID, CURRENT_DATE() AS SD,
      LEAST(1.0,COALESCE((SELECT COUNT(DISTINCT COUNTERPARTY_COUNTRY) FROM RAW_TRANSACTIONS t WHERE t.CUSTOMER_ID=c.CUSTOMER_ID AND t.TXN_DATE>=DATEADD('day',-30,CURRENT_TIMESTAMP()))*0.1,0)) AS BR,
      CASE c.JURISDICTION_RISK WHEN 'HIGH' THEN 0.8 WHEN 'MEDIUM' THEN 0.4 ELSE 0.05 END AS JR,
      LEAST(1.0,COALESCE((SELECT COUNT(*) FROM RAW_ALERTS a WHERE a.CUSTOMER_ID=c.CUSTOMER_ID AND a.STATUS!='CLOSED')*0.25,0)) AS NR
    FROM RAW_CUSTOMERS c
  ) calc ON rs.CUSTOMER_ID=calc.CUSTOMER_ID
  WHEN MATCHED THEN UPDATE SET SCORE_DATE=calc.SD, BEHAVIORAL_RISK=calc.BR, JURISDICTIONAL_RISK=calc.JR, NETWORK_RISK=calc.NR,
    COMPOSITE_SCORE=ROUND((calc.BR*0.4+calc.JR*0.3+calc.NR*0.3),2),
    RISK_CATEGORY=CASE WHEN (calc.BR*0.4+calc.JR*0.3+calc.NR*0.3)>=0.8 THEN 'CRITICAL' WHEN (calc.BR*0.4+calc.JR*0.3+calc.NR*0.3)>=0.5 THEN 'HIGH' WHEN (calc.BR*0.4+calc.JR*0.3+calc.NR*0.3)>=0.3 THEN 'MEDIUM' ELSE 'LOW' END;

ALTER TASK TASK_DAILY_RISK_REFRESH RESUME;

-- ════════════════════════════════════════════════════════════
-- STEP 8: SEMANTIC VIEW
-- ════════════════════════════════════════════════════════════

USE SCHEMA RISK_COPILOT.SEMANTIC;

CREATE OR REPLACE SEMANTIC VIEW SV_RISK_INTELLIGENCE
  TABLES (
    customers AS RISK_COPILOT.TRANSFORM.DT_CUSTOMERS PRIMARY KEY (CUSTOMER_ID) COMMENT='Enriched customer profiles',
    transactions AS RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS PRIMARY KEY (TXN_ID) COMMENT='Enriched transactions',
    alerts AS RISK_COPILOT.TRANSFORM.DT_ALERT_ENRICHED PRIMARY KEY (ALERT_ID) COMMENT='Enriched alerts with SLA tracking',
    risk_scores AS RISK_COPILOT.TRANSFORM.DT_RISK_ENRICHED PRIMARY KEY (CUSTOMER_ID) COMMENT='Risk scores with monitoring levels'
  )
  RELATIONSHIPS (
    txn_to_cust AS transactions(CUSTOMER_ID) REFERENCES customers,
    alert_to_cust AS alerts(CUSTOMER_ID) REFERENCES customers,
    score_to_cust AS risk_scores(CUSTOMER_ID) REFERENCES customers
  )
  DIMENSIONS (
    customers.customer_country AS customers.COUNTRY COMMENT='Customer country',
    customers.risk_tier AS customers.RISK_TIER COMMENT='Risk tier',
    customers.kyc_status AS customers.KYC_STATUS COMMENT='KYC status',
    customers.is_pep AS customers.PEP_FLAG COMMENT='PEP flag',
    customers.account_type AS customers.ACCOUNT_TYPE COMMENT='Account type',
    transactions.txn_type AS transactions.TXN_TYPE COMMENT='Transaction type',
    transactions.txn_date AS transactions.TXN_DATE COMMENT='Transaction date',
    transactions.counterparty_country AS transactions.COUNTERPARTY_COUNTRY COMMENT='Counterparty country',
    transactions.amount_bucket AS transactions.AMOUNT_BUCKET COMMENT='Amount bucket',
    transactions.is_high_risk_dest AS transactions.IS_HIGH_RISK_DESTINATION COMMENT='High-risk destination flag',
    alerts.alert_type AS alerts.ALERT_TYPE COMMENT='Alert type',
    alerts.severity AS alerts.SEVERITY COMMENT='Alert severity',
    alerts.alert_status AS alerts.STATUS COMMENT='Alert status',
    alerts.sla_status AS alerts.SLA_STATUS COMMENT='SLA tracking status',
    risk_scores.risk_category AS risk_scores.RISK_CATEGORY COMMENT='Risk category',
    risk_scores.monitoring_level AS risk_scores.MONITORING_LEVEL COMMENT='Monitoring level'
  )
  METRICS (
    transactions.total_volume AS SUM(transactions.AMOUNT) COMMENT='Total volume',
    transactions.txn_count AS COUNT(transactions.TXN_ID) COMMENT='Transaction count',
    alerts.total_alerts AS COUNT(alerts.ALERT_ID) COMMENT='Total alerts',
    risk_scores.avg_risk_score AS AVG(risk_scores.COMPOSITE_SCORE) COMMENT='Average risk score'
  )
  COMMENT='Risk, Fraud & Regulatory Intelligence - reads from TRANSFORM dynamic tables'
  AI_VERIFIED_QUERIES (
    vq_open_alerts AS (QUESTION 'Show all open and investigating alerts with customer details'
      SQL 'SELECT a.ALERT_ID, a.ALERT_TYPE, a.SEVERITY, a.STATUS, a.CUSTOMER_NAME, a.CUSTOMER_ID, a.SLA_STATUS FROM RISK_COPILOT.TRANSFORM.DT_ALERT_ENRICHED a WHERE a.STATUS IN (''OPEN'',''INVESTIGATING'') ORDER BY a.SEVERITY DESC'),
    vq_critical_customers AS (QUESTION 'List all high and critical risk customers with their scores'
      SQL 'SELECT r.CUSTOMER_ID, r.FULL_NAME, r.COUNTRY, r.COMPOSITE_SCORE, r.RISK_CATEGORY, r.MONITORING_LEVEL FROM RISK_COPILOT.TRANSFORM.DT_RISK_ENRICHED r WHERE r.RISK_CATEGORY IN (''CRITICAL'',''HIGH'') ORDER BY r.COMPOSITE_SCORE DESC'),
    vq_structuring AS (QUESTION 'Detect structuring patterns with multiple cash deposits under 10000 dollars'
      SQL 'SELECT t.CUSTOMER_ID, c.FULL_NAME, t.TXN_DAY, COUNT(*) AS CNT, SUM(t.AMOUNT) AS TOTAL FROM RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS t JOIN RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c ON t.CUSTOMER_ID=c.CUSTOMER_ID WHERE t.TXN_TYPE=''CASH_DEPOSIT'' AND t.AMOUNT BETWEEN 8000 AND 9999 GROUP BY t.CUSTOMER_ID,c.FULL_NAME,t.TXN_DAY HAVING COUNT(*)>=2'),
    vq_high_risk_wires AS (QUESTION 'Show wire transfers to high risk jurisdictions sorted by amount'
      SQL 'SELECT t.TXN_ID, t.CUSTOMER_ID, c.FULL_NAME, t.AMOUNT, t.COUNTERPARTY_COUNTRY, t.TXN_DATE FROM RISK_COPILOT.TRANSFORM.DT_TRANSACTIONS t JOIN RISK_COPILOT.TRANSFORM.DT_CUSTOMERS c ON t.CUSTOMER_ID=c.CUSTOMER_ID WHERE t.IS_HIGH_RISK_DESTINATION=TRUE AND t.TXN_TYPE=''WIRE_TRANSFER'' ORDER BY t.AMOUNT DESC')
  );

-- ════════════════════════════════════════════════════════════
-- STEP 9: CORTEX AGENTS (3 SPECIALIZED + MCP SERVER)
-- ════════════════════════════════════════════════════════════

USE SCHEMA RISK_COPILOT.PUBLIC;

CREATE OR REPLACE AGENT RISK_TRIAGE_AGENT FROM SPECIFICATION $$
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "risk_data_analyst"
      description: "Query transaction data, customer profiles, risk scores, and alerts to triage risk signals."
tool_resources:
  risk_data_analyst:
    semantic_view: "RISK_COPILOT.SEMANTIC.SV_RISK_INTELLIGENCE"
$$;

CREATE OR REPLACE AGENT REGULATORY_COMPLIANCE_AGENT FROM SPECIFICATION $$
tools:
  - tool_spec:
      type: "cortex_search"
      name: "regulatory_knowledge"
      description: "Search regulatory documents for AML/CFT policies, Basel III rules, and internal risk procedures."
tool_resources:
  regulatory_knowledge:
    search_service: "RISK_COPILOT.PUBLIC.REGULATORY_SEARCH_SERVICE"
    max_results: 5
    title_column: "DOC_NAME"
    content_column: "CHUNK_TEXT"
$$;

CREATE OR REPLACE AGENT RISK_INTELLIGENCE_AGENT FROM SPECIFICATION $$
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "risk_analyst"
      description: "Query structured risk data including customers, transactions, alerts, and risk scores."
  - tool_spec:
      type: "cortex_search"
      name: "regulatory_search"
      description: "Search AML/CFT policies, Basel III regulations, and internal risk procedures."
tool_resources:
  risk_analyst:
    semantic_view: "RISK_COPILOT.SEMANTIC.SV_RISK_INTELLIGENCE"
  regulatory_search:
    search_service: "RISK_COPILOT.PUBLIC.REGULATORY_SEARCH_SERVICE"
    max_results: 3
    title_column: "DOC_NAME"
    content_column: "CHUNK_TEXT"
$$;

CREATE OR REPLACE MCP SERVER RISK_COPILOT_MCP_SERVER FROM SPECIFICATION $$
tools:
  - title: "Risk Intelligence Agent"
    name: "risk_intelligence_agent"
    type: "CORTEX_AGENT_RUN"
    identifier: "RISK_COPILOT.PUBLIC.RISK_INTELLIGENCE_AGENT"
    description: "AI-powered risk, fraud, and regulatory intelligence agent."
$$;

-- ════════════════════════════════════════════════════════════
-- STEP 10: GOVERNANCE (RBAC, TAGGING, MASKING)
-- ════════════════════════════════════════════════════════════

ALTER TABLE CUSTOMERS MODIFY COLUMN FULL_NAME SET TAG SNOWFLAKE.CORE.SEMANTIC_CATEGORY = 'NAME';
ALTER TABLE CUSTOMERS MODIFY COLUMN EMAIL SET TAG SNOWFLAKE.CORE.SEMANTIC_CATEGORY = 'EMAIL';
ALTER TABLE CUSTOMERS MODIFY COLUMN PHONE SET TAG SNOWFLAKE.CORE.SEMANTIC_CATEGORY = 'PHONE_NUMBER';

CREATE ROLE IF NOT EXISTS RISK_ANALYST COMMENT='Can investigate alerts and generate evidence';
CREATE ROLE IF NOT EXISTS RISK_AUDITOR COMMENT='Read-only access to all data and audit trail';
GRANT ROLE RISK_ANALYST TO ROLE ACCOUNTADMIN;
GRANT ROLE RISK_AUDITOR TO ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE RISK_COPILOT TO ROLE RISK_ANALYST;
GRANT USAGE ON DATABASE RISK_COPILOT TO ROLE RISK_AUDITOR;
GRANT USAGE ON ALL SCHEMAS IN DATABASE RISK_COPILOT TO ROLE RISK_ANALYST;
GRANT USAGE ON ALL SCHEMAS IN DATABASE RISK_COPILOT TO ROLE RISK_AUDITOR;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE RISK_ANALYST;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE RISK_AUDITOR;
GRANT SELECT ON ALL TABLES IN SCHEMA RISK_COPILOT.PUBLIC TO ROLE RISK_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA RISK_COPILOT.PUBLIC TO ROLE RISK_AUDITOR;
GRANT SELECT ON ALL VIEWS IN SCHEMA RISK_COPILOT.PUBLIC TO ROLE RISK_ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA RISK_COPILOT.PUBLIC TO ROLE RISK_AUDITOR;
GRANT INSERT ON TABLE COPILOT_AUDIT_LOG TO ROLE RISK_ANALYST;

CREATE OR REPLACE MASKING POLICY PII_MASK AS (val STRING) RETURNS STRING ->
    CASE WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN','RISK_ANALYST') THEN val ELSE '***MASKED***' END;

ALTER TABLE CUSTOMERS MODIFY COLUMN FULL_NAME SET MASKING POLICY PII_MASK;
ALTER TABLE CUSTOMERS MODIFY COLUMN EMAIL SET MASKING POLICY PII_MASK;
ALTER TABLE CUSTOMERS MODIFY COLUMN PHONE SET MASKING POLICY PII_MASK;

-- ════════════════════════════════════════════════════════════
-- STEP 11: VALIDATION TESTS
-- ════════════════════════════════════════════════════════════

SELECT 'TEST 1: STRUCTURING_DETECTION' AS TEST, CASE WHEN COUNT(*)>0 THEN 'PASS' ELSE 'FAIL' END AS RESULT FROM V_STRUCTURING_ALERTS WHERE CUSTOMER_ID='CUST-002';
SELECT 'TEST 2: DORMANT_REACTIVATION' AS TEST, CASE WHEN COUNT(*)>0 THEN 'PASS' ELSE 'FAIL' END AS RESULT FROM V_DORMANT_REACTIVATION WHERE CUSTOMER_ID='CUST-015';
SELECT 'TEST 3: HIGH_RISK_JURISDICTION' AS TEST, CASE WHEN COUNT(*)>0 THEN 'PASS' ELSE 'FAIL' END AS RESULT FROM V_HIGH_RISK_JURISDICTIONS WHERE CUSTOMER_ID='CUST-003';
SELECT 'TEST 4: RAG_EMBEDDINGS' AS TEST, CASE WHEN COUNT(*)=18 THEN 'PASS' ELSE 'FAIL' END AS RESULT FROM REGULATORY_CHUNKS WHERE CHUNK_EMBEDDING IS NOT NULL;
SELECT 'TEST 5: LLM_RESPONSE' AS TEST, CASE WHEN LEN(SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b','What is structuring in AML? One sentence.'))>20 THEN 'PASS' ELSE 'FAIL' END AS RESULT;

-- ════════════════════════════════════════════════════════════
-- DEPLOYMENT COMPLETE!
-- ════════════════════════════════════════════════════════════
-- 
-- Objects created:
--   3 schemas: RAW, TRANSFORM, SEMANTIC
--   4 RAW tables + 4 PUBLIC tables + 1 audit log + 1 regulatory chunks
--   6 dynamic tables in TRANSFORM
--   4 detection views
--   1 Cortex Search Service
--   1 Semantic View with 4 verified queries
--   3 Cortex Agents + 1 MCP Server
--   3 scheduled tasks + 1 stream
--   2 RBAC roles + 1 masking policy + PII tags
--
-- NEXT: Deploy the Streamlit app
--   1. Download streamlit_app.py from:
--      https://github.com/rdevath21/risk-fraud-regulatory-intelligence-copilot/blob/main/app/streamlit_app.py
--   2. In Snowsight: Projects > Streamlit > Create > Upload the file
--      Or run:
--        CREATE STAGE RISK_COPILOT.PUBLIC.STREAMLIT_STAGE;
--        PUT 'file:///path/to/streamlit_app.py' @RISK_COPILOT.PUBLIC.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--        CREATE STREAMLIT RISK_COPILOT.PUBLIC.RISK_FRAUD_COPILOT
--          ROOT_LOCATION='@RISK_COPILOT.PUBLIC.STREAMLIT_STAGE'
--          MAIN_FILE='streamlit_app.py' QUERY_WAREHOUSE=COMPUTE_WH;
