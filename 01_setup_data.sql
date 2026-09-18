-- ============================================================
-- Risk, Fraud & Regulatory Intelligence Copilot
-- Step 1: Database, Schema, and Mock Structured Data
-- ============================================================

CREATE DATABASE IF NOT EXISTS RISK_COPILOT;
USE SCHEMA RISK_COPILOT.PUBLIC;

-- Customers table with various risk profiles
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID VARCHAR(20),
    FULL_NAME VARCHAR(100),
    EMAIL VARCHAR(100),
    PHONE VARCHAR(20),
    ADDRESS VARCHAR(200),
    COUNTRY VARCHAR(50),
    JURISDICTION_RISK VARCHAR(10),
    ACCOUNT_TYPE VARCHAR(20),
    KYC_STATUS VARCHAR(20),
    PEP_FLAG BOOLEAN,
    ACCOUNT_OPEN_DATE DATE,
    LAST_ACTIVITY_DATE DATE,
    RISK_TIER VARCHAR(10)
);

INSERT INTO CUSTOMERS VALUES
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

-- Transactions with embedded fraud patterns
CREATE OR REPLACE TABLE TRANSACTIONS (
    TXN_ID VARCHAR(20),
    CUSTOMER_ID VARCHAR(20),
    TXN_DATE TIMESTAMP_NTZ,
    TXN_TYPE VARCHAR(30),
    AMOUNT FLOAT,
    CURRENCY VARCHAR(5),
    COUNTERPARTY VARCHAR(100),
    COUNTERPARTY_COUNTRY VARCHAR(50),
    CHANNEL VARCHAR(20),
    STATUS VARCHAR(15),
    DESCRIPTION VARCHAR(200)
);

-- Pattern: Structuring (CUST-002)
INSERT INTO TRANSACTIONS VALUES
('TXN-0001','CUST-002','2026-09-10 09:15:00','CASH_DEPOSIT',9800.00,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 101'),
('TXN-0002','CUST-002','2026-09-10 11:30:00','CASH_DEPOSIT',9500.00,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 205'),
('TXN-0003','CUST-002','2026-09-10 14:45:00','CASH_DEPOSIT',9700.00,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 312'),
('TXN-0004','CUST-002','2026-09-11 10:00:00','CASH_DEPOSIT',9900.00,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 101'),
('TXN-0005','CUST-002','2026-09-11 13:20:00','CASH_DEPOSIT',9600.00,'USD','Self','United States','BRANCH','COMPLETED','Cash deposit - branch 445'),
('TXN-0006','CUST-002','2026-09-12 09:00:00','WIRE_TRANSFER',45000.00,'USD','Offshore Holdings Ltd','Cayman Islands','ONLINE','COMPLETED','Wire transfer to Cayman account');

-- Pattern: Rapid international transfers (CUST-003)
INSERT INTO TRANSACTIONS VALUES
('TXN-0007','CUST-003','2026-09-13 08:00:00','WIRE_TRANSFER',150000.00,'USD','Baltic Trade LLC','Latvia','ONLINE','COMPLETED','Payment for consulting services'),
('TXN-0008','CUST-003','2026-09-13 09:30:00','WIRE_TRANSFER',120000.00,'EUR','Cyprus Holdings SA','Cyprus','ONLINE','COMPLETED','Investment transfer'),
('TXN-0009','CUST-003','2026-09-13 14:00:00','WIRE_TRANSFER',200000.00,'USD','Dubai Commodities FZE','UAE','ONLINE','COMPLETED','Commodity purchase'),
('TXN-0010','CUST-003','2026-09-14 07:45:00','WIRE_TRANSFER',175000.00,'GBP','London Capital Partners','United Kingdom','ONLINE','COMPLETED','Portfolio rebalancing'),
('TXN-0011','CUST-003','2026-09-14 11:00:00','WIRE_TRANSFER',95000.00,'CHF','Geneva Wealth AG','Switzerland','ONLINE','COMPLETED','Asset management fee');

-- Pattern: Round-tripping (CUST-013 <-> CUST-020)
INSERT INTO TRANSACTIONS VALUES
('TXN-0012','CUST-013','2026-09-08 10:00:00','WIRE_TRANSFER',500000.00,'USD','Shell Corp Holdings','Belize','ONLINE','COMPLETED','Loan disbursement'),
('TXN-0013','CUST-020','2026-09-09 09:00:00','WIRE_TRANSFER',490000.00,'USD','Mendez Enterprises SA','Panama','ONLINE','COMPLETED','Repayment of loan'),
('TXN-0014','CUST-013','2026-09-10 10:30:00','WIRE_TRANSFER',485000.00,'USD','Shell Corp Holdings','Belize','ONLINE','COMPLETED','Investment capital'),
('TXN-0015','CUST-020','2026-09-11 08:15:00','WIRE_TRANSFER',480000.00,'USD','Mendez Enterprises SA','Panama','ONLINE','COMPLETED','Return of investment'),
('TXN-0016','CUST-020','2026-09-12 14:00:00','WIRE_TRANSFER',250000.00,'USD','Cayman Reserve Trust','Cayman Islands','ONLINE','COMPLETED','Trust fund allocation');

-- Pattern: Dormant reactivation (CUST-015)
INSERT INTO TRANSACTIONS VALUES
('TXN-0017','CUST-015','2023-02-28 12:00:00','DEBIT_CARD',45.99,'USD','Amazon','United States','ONLINE','COMPLETED','Online purchase'),
('TXN-0018','CUST-015','2026-09-14 08:00:00','WIRE_TRANSFER',75000.00,'USD','Caribbean Investments LLC','Bahamas','ONLINE','COMPLETED','Investment wire'),
('TXN-0019','CUST-015','2026-09-14 10:00:00','WIRE_TRANSFER',60000.00,'USD','Pacific Rim Holdings','Singapore','ONLINE','COMPLETED','Business payment'),
('TXN-0020','CUST-015','2026-09-15 09:00:00','CASH_DEPOSIT',25000.00,'USD','Self','United States','BRANCH','COMPLETED','Large cash deposit');

-- Pattern: Velocity spike (CUST-007)
INSERT INTO TRANSACTIONS VALUES
('TXN-0021','CUST-007','2026-09-14 06:00:00','WIRE_TRANSFER',4500.00,'USD','Account A','Ghana','ONLINE','COMPLETED','Payment 1'),
('TXN-0022','CUST-007','2026-09-14 06:30:00','WIRE_TRANSFER',4800.00,'USD','Account B','Senegal','ONLINE','COMPLETED','Payment 2'),
('TXN-0023','CUST-007','2026-09-14 07:00:00','WIRE_TRANSFER',4200.00,'USD','Account C','Cameroon','ONLINE','COMPLETED','Payment 3'),
('TXN-0024','CUST-007','2026-09-14 07:30:00','WIRE_TRANSFER',4600.00,'USD','Account D','Kenya','ONLINE','COMPLETED','Payment 4'),
('TXN-0025','CUST-007','2026-09-14 08:00:00','WIRE_TRANSFER',4900.00,'USD','Account E','Tanzania','ONLINE','COMPLETED','Payment 5'),
('TXN-0026','CUST-007','2026-09-14 08:30:00','WIRE_TRANSFER',4100.00,'USD','Account F','Uganda','ONLINE','COMPLETED','Payment 6'),
('TXN-0027','CUST-007','2026-09-14 09:00:00','WIRE_TRANSFER',4700.00,'USD','Account G','Rwanda','ONLINE','COMPLETED','Payment 7'),
('TXN-0028','CUST-007','2026-09-14 09:30:00','WIRE_TRANSFER',4300.00,'USD','Account H','Ethiopia','ONLINE','COMPLETED','Payment 8');

-- Normal baseline transactions
INSERT INTO TRANSACTIONS VALUES
('TXN-0029','CUST-001','2026-09-10 12:00:00','DEBIT_CARD',125.50,'USD','Whole Foods','United States','POS','COMPLETED','Grocery shopping'),
('TXN-0030','CUST-001','2026-09-12 09:00:00','ACH_TRANSFER',3200.00,'USD','Landlord LLC','United States','ONLINE','COMPLETED','Monthly rent'),
('TXN-0031','CUST-001','2026-09-14 15:00:00','DEBIT_CARD',89.99,'USD','Netflix/Spotify','United States','ONLINE','COMPLETED','Subscriptions'),
('TXN-0032','CUST-005','2026-09-05 10:00:00','WIRE_TRANSFER',2000000.00,'USD','Royal Investment Fund','UAE','ONLINE','COMPLETED','Sovereign fund allocation'),
('TXN-0033','CUST-005','2026-09-08 11:00:00','WIRE_TRANSFER',1500000.00,'GBP','London Real Estate PLC','United Kingdom','ONLINE','COMPLETED','Property acquisition'),
('TXN-0034','CUST-005','2026-09-12 14:00:00','WIRE_TRANSFER',750000.00,'EUR','Swiss Private Bank AG','Switzerland','ONLINE','COMPLETED','Wealth management transfer'),
('TXN-0035','CUST-012','2026-09-09 16:00:00','WIRE_TRANSFER',3200000.00,'USD','Christies Auction House','United Kingdom','ONLINE','COMPLETED','Art acquisition - lot 4521'),
('TXN-0036','CUST-012','2026-09-14 10:00:00','WIRE_TRANSFER',850000.00,'EUR','Monaco Yacht Sales','Monaco','ONLINE','COMPLETED','Yacht maintenance deposit'),
('TXN-0037','CUST-016','2026-09-13 09:00:00','WIRE_TRANSFER',35000.00,'USD','Istanbul Trading Co','Turkey','ONLINE','COMPLETED','Trade payment'),
('TXN-0038','CUST-016','2026-09-14 11:00:00','CASH_DEPOSIT',9800.00,'USD','Self','Lebanon','BRANCH','COMPLETED','Cash deposit'),
('TXN-0039','CUST-016','2026-09-15 08:00:00','WIRE_TRANSFER',28000.00,'EUR','Berlin Import GmbH','Germany','ONLINE','COMPLETED','Invoice payment'),
('TXN-0040','CUST-006','2026-09-10 08:30:00','DEBIT_CARD',230.00,'EUR','Zara Milano','Italy','POS','COMPLETED','Shopping'),
('TXN-0041','CUST-006','2026-09-13 12:00:00','ACH_TRANSFER',1800.00,'EUR','Telecom Italia','Italy','ONLINE','COMPLETED','Utility bill'),
('TXN-0042','CUST-011','2026-09-11 14:00:00','DEBIT_CARD',67.50,'USD','Target','United States','POS','COMPLETED','Household items'),
('TXN-0043','CUST-011','2026-09-14 09:00:00','ACH_TRANSFER',2100.00,'USD','Chase Mortgage','United States','ONLINE','COMPLETED','Mortgage payment'),
('TXN-0044','CUST-019','2026-09-12 10:00:00','WIRE_TRANSFER',50000.00,'JPY','Toyota Financial','Japan','ONLINE','COMPLETED','Auto lease payment'),
('TXN-0045','CUST-019','2026-09-14 15:00:00','DEBIT_CARD',15000.00,'JPY','Isetan Dept Store','Japan','POS','COMPLETED','Department store'),
('TXN-0046','CUST-009','2026-09-10 07:00:00','WIRE_TRANSFER',180000.00,'USD','Georgian Trading LLC','Georgia','ONLINE','COMPLETED','Export payment'),
('TXN-0047','CUST-009','2026-09-11 08:00:00','WIRE_TRANSFER',175000.00,'EUR','Malta Holdings Ltd','Malta','ONLINE','COMPLETED','Investment transfer'),
('TXN-0048','CUST-009','2026-09-12 09:00:00','WIRE_TRANSFER',170000.00,'GBP','Scottish LP Fund','United Kingdom','ONLINE','COMPLETED','LP contribution'),
('TXN-0049','CUST-009','2026-09-13 10:00:00','WIRE_TRANSFER',165000.00,'USD','Delaware Corp Inc','United States','ONLINE','COMPLETED','Corporate funding'),
('TXN-0050','CUST-009','2026-09-14 11:00:00','WIRE_TRANSFER',160000.00,'CHF','Zurich Fiduciary SA','Switzerland','ONLINE','COMPLETED','Fiduciary account');

-- Risk scores
CREATE OR REPLACE TABLE RISK_SCORES (
    CUSTOMER_ID VARCHAR(20),
    SCORE_DATE DATE,
    BEHAVIORAL_RISK FLOAT,
    JURISDICTIONAL_RISK FLOAT,
    NETWORK_RISK FLOAT,
    COMPOSITE_SCORE FLOAT,
    RISK_CATEGORY VARCHAR(10),
    MODEL_VERSION VARCHAR(10)
);

INSERT INTO RISK_SCORES VALUES
('CUST-001','2026-09-15',0.05,0.02,0.03,0.03,'LOW','v2.1'),
('CUST-002','2026-09-15',0.82,0.02,0.15,0.65,'HIGH','v2.1'),
('CUST-003','2026-09-15',0.90,0.85,0.70,0.88,'CRITICAL','v2.1'),
('CUST-004','2026-09-15',0.30,0.45,0.20,0.32,'MEDIUM','v2.1'),
('CUST-005','2026-09-15',0.60,0.40,0.55,0.58,'HIGH','v2.1'),
('CUST-006','2026-09-15',0.04,0.05,0.02,0.04,'LOW','v2.1'),
('CUST-007','2026-09-15',0.88,0.75,0.65,0.82,'CRITICAL','v2.1'),
('CUST-008','2026-09-15',0.03,0.02,0.01,0.02,'LOW','v2.1'),
('CUST-009','2026-09-15',0.85,0.80,0.75,0.84,'CRITICAL','v2.1'),
('CUST-010','2026-09-15',0.55,0.35,0.45,0.48,'HIGH','v2.1'),
('CUST-011','2026-09-15',0.06,0.02,0.04,0.04,'LOW','v2.1'),
('CUST-012','2026-09-15',0.50,0.30,0.40,0.42,'HIGH','v2.1'),
('CUST-013','2026-09-15',0.92,0.80,0.88,0.90,'CRITICAL','v2.1'),
('CUST-014','2026-09-15',0.25,0.35,0.15,0.25,'MEDIUM','v2.1'),
('CUST-015','2026-09-15',0.78,0.02,0.10,0.55,'HIGH','v2.1'),
('CUST-016','2026-09-15',0.70,0.75,0.50,0.68,'HIGH','v2.1'),
('CUST-017','2026-09-15',0.08,0.05,0.03,0.05,'LOW','v2.1'),
('CUST-018','2026-09-15',0.20,0.30,0.15,0.22,'MEDIUM','v2.1'),
('CUST-019','2026-09-15',0.07,0.03,0.05,0.05,'LOW','v2.1'),
('CUST-020','2026-09-15',0.95,0.90,0.92,0.94,'CRITICAL','v2.1');

-- Alerts
CREATE OR REPLACE TABLE ALERTS (
    ALERT_ID VARCHAR(20),
    CUSTOMER_ID VARCHAR(20),
    ALERT_TYPE VARCHAR(40),
    SEVERITY VARCHAR(10),
    STATUS VARCHAR(20),
    CREATED_AT TIMESTAMP_NTZ,
    ASSIGNED_TO VARCHAR(50),
    DESCRIPTION VARCHAR(500),
    RELATED_TXNS VARCHAR(200)
);

INSERT INTO ALERTS VALUES
('ALT-001','CUST-002','STRUCTURING','HIGH','OPEN','2026-09-12 16:00:00','analyst_jones','Multiple cash deposits just under $10,000 CTR threshold detected across different branches within 48 hours. Total: $48,500 in 5 deposits. Followed by $45,000 wire to Cayman Islands.','TXN-0001,TXN-0002,TXN-0003,TXN-0004,TXN-0005,TXN-0006'),
('ALT-002','CUST-003','RAPID_INTERNATIONAL_TRANSFERS','CRITICAL','INVESTIGATING','2026-09-14 12:00:00','analyst_smith','5 international wire transfers totaling $740,000+ to 5 different countries within 30 hours. Countries: Latvia, Cyprus, UAE, UK, Switzerland. Counterparties appear unrelated.','TXN-0007,TXN-0008,TXN-0009,TXN-0010,TXN-0011'),
('ALT-003','CUST-013','ROUND_TRIPPING','CRITICAL','OPEN','2026-09-12 15:00:00','analyst_jones','Circular fund flows detected between CUST-013 (Panama) and CUST-020 (Belize shell company). Two cycles of ~$500k transfers with small decrements. Final outflow to Cayman Islands trust.','TXN-0012,TXN-0013,TXN-0014,TXN-0015,TXN-0016'),
('ALT-004','CUST-015','DORMANT_REACTIVATION','HIGH','OPEN','2026-09-14 17:00:00','analyst_chen','Account dormant since March 2023 suddenly reactivated with $160,000 in wire transfers to Bahamas and Singapore within 24 hours plus $25,000 cash deposit.','TXN-0018,TXN-0019,TXN-0020'),
('ALT-005','CUST-007','VELOCITY_ANOMALY','HIGH','OPEN','2026-09-14 10:00:00','analyst_smith','8 wire transfers totaling $36,100 to 8 different African countries within 3.5 hours. Pattern consistent with rapid layering or payment muling.','TXN-0021,TXN-0022,TXN-0023,TXN-0024,TXN-0025,TXN-0026,TXN-0027,TXN-0028'),
('ALT-006','CUST-005','PEP_LARGE_TRANSACTIONS','MEDIUM','INVESTIGATING','2026-09-12 18:00:00','analyst_chen','PEP customer with $4.25M in transfers over 7 days. Transactions to real estate and Swiss private banking. Requires enhanced due diligence review.','TXN-0032,TXN-0033,TXN-0034'),
('ALT-007','CUST-009','LAYERING','CRITICAL','OPEN','2026-09-14 14:00:00','analyst_jones','Sequential wire transfers of decreasing amounts ($180k to $160k) through 5 jurisdictions (Georgia, Malta, UK, US, Switzerland) over 5 consecutive days. Classic layering pattern.','TXN-0046,TXN-0047,TXN-0048,TXN-0049,TXN-0050'),
('ALT-008','CUST-016','KYC_EXPIRED_ACTIVITY','MEDIUM','OPEN','2026-09-15 09:00:00','analyst_smith','Customer with EXPIRED KYC status conducting wire transfers totaling $72,800. KYC renewal overdue. Transactions to Turkey and Germany from high-risk jurisdiction (Lebanon).','TXN-0037,TXN-0038,TXN-0039'),
('ALT-009','CUST-020','SHELL_COMPANY_ACTIVITY','CRITICAL','INVESTIGATING','2026-09-13 11:00:00','analyst_jones','Entity flagged as potential shell company (Belize, PO Box address, PENDING KYC). Involved in $1.22M circular flows with Panama entity and $250k transfer to Cayman trust.','TXN-0013,TXN-0015,TXN-0016'),
('ALT-010','CUST-012','PEP_LUXURY_PURCHASES','MEDIUM','CLOSED','2026-09-14 16:00:00','analyst_chen','PEP customer: $3.2M art auction purchase and $850k yacht deposit. While high-value, transactions consistent with known lifestyle. EDD completed and filed.','TXN-0035,TXN-0036');
