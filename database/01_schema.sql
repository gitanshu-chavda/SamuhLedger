-- SamuhLedger schema. Run after: CREATE DATABASE samuhledger CHARACTER SET utf8mb4;
-- Tables are created in dependency order (parents before children).

-- 1. role -------------------------------------------------------------
CREATE TABLE role (
  role_id    TINYINT PRIMARY KEY,
  role_name  VARCHAR(20) NOT NULL UNIQUE
);

-- 2. member -----------------------------------------------------------
CREATE TABLE member (
  member_id  INT AUTO_INCREMENT PRIMARY KEY,
  full_name  VARCHAR(100) NOT NULL,
  phone      VARCHAR(15)  NOT NULL UNIQUE,
  address    VARCHAR(200) NULL,
  joined_on  DATE NOT NULL,
  is_active  BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3. sgroup (policy lives here) --------------------------------------
CREATE TABLE sgroup (
  group_id             INT AUTO_INCREMENT PRIMARY KEY,
  group_name           VARCHAR(60) NOT NULL UNIQUE,
  group_type           ENUM('SHG','CHIT','COOP') NOT NULL,
  formed_on            DATE NOT NULL,
  monthly_contribution DECIMAL(10,2) NOT NULL CHECK (monthly_contribution > 0),
  loan_rate_pct        DECIMAL(5,2)  NOT NULL CHECK (loan_rate_pct BETWEEN 0 AND 60),
  loan_limit_multiple  DECIMAL(4,1)  NOT NULL DEFAULT 3.0,
  grace_days           SMALLINT      NOT NULL DEFAULT 5,
  penalty_per_day      DECIMAL(8,2)  NOT NULL DEFAULT 0
);

-- 4. app_user ---------------------------------------------------------
CREATE TABLE app_user (
  user_id        INT AUTO_INCREMENT PRIMARY KEY,
  username       VARCHAR(50)  NOT NULL UNIQUE,
  password_hash  VARCHAR(100) NOT NULL,          -- bcrypt hash, 60 chars
  role_id        TINYINT NOT NULL,
  member_id      INT NULL,                       -- set for member logins
  group_id       INT NULL,                       -- NULL for admin and auditor
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  FOREIGN KEY (role_id)   REFERENCES role(role_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id),
  FOREIGN KEY (group_id)  REFERENCES sgroup(group_id)
);

-- 5. membership (resolves member <-> group, many to many) ------------
CREATE TABLE membership (
  membership_id  INT AUTO_INCREMENT PRIMARY KEY,
  group_id       INT NOT NULL,
  member_id      INT NOT NULL,
  role_in_group  ENUM('MEMBER','PRESIDENT','TREASURER') NOT NULL DEFAULT 'MEMBER',
  joined_on      DATE NOT NULL,
  left_on        DATE NULL,
  UNIQUE (group_id, member_id),
  CHECK (left_on IS NULL OR left_on >= joined_on),
  FOREIGN KEY (group_id)  REFERENCES sgroup(group_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id)
);

-- 6. account_type (no normal_side column on purpose: see normalization) --
CREATE TABLE account_type (
  type_id    TINYINT PRIMARY KEY,
  type_name  VARCHAR(30) NOT NULL UNIQUE,
  category   ENUM('ASSET','LIABILITY','EQUITY','INCOME','EXPENSE') NOT NULL
);

-- 7. account ----------------------------------------------------------
CREATE TABLE account (
  account_id  INT AUTO_INCREMENT PRIMARY KEY,
  group_id    INT NOT NULL,
  type_id     TINYINT NOT NULL,
  member_id   INT NULL,                          -- NULL for group-level accounts
  -- generated column only so UNIQUE works when member_id is NULL
  member_key  INT GENERATED ALWAYS AS (IFNULL(member_id, 0)) STORED,
  UNIQUE KEY uq_account (group_id, type_id, member_key),
  FOREIGN KEY (group_id)  REFERENCES sgroup(group_id),
  FOREIGN KEY (type_id)   REFERENCES account_type(type_id),
  FOREIGN KEY (member_id) REFERENCES member(member_id)
);

-- 8. journal_entry (append-only; enforced by triggers in 03) ----------
CREATE TABLE journal_entry (
  entry_id           INT AUTO_INCREMENT PRIMARY KEY,
  group_id           INT NOT NULL,
  entry_date         DATE NOT NULL,
  description        VARCHAR(200) NOT NULL,
  entry_type         ENUM('CONTRIBUTION','LOAN_DISBURSAL','REPAYMENT','PENALTY',
                          'WITHDRAWAL','REVERSAL','ADJUSTMENT') NOT NULL,
  reverses_entry_id  INT NULL UNIQUE,            -- an entry is reversed at most once
  posted_by          INT NOT NULL,
  posted_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (group_id)          REFERENCES sgroup(group_id),
  FOREIGN KEY (reverses_entry_id) REFERENCES journal_entry(entry_id),
  FOREIGN KEY (posted_by)         REFERENCES app_user(user_id),
  INDEX idx_entry_group_date (group_id, entry_date)
);

-- 9. journal_line (append-only, one-sided lines) ----------------------
CREATE TABLE journal_line (
  line_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
  entry_id    INT NOT NULL,
  account_id  INT NOT NULL,
  debit       DECIMAL(12,2) NOT NULL DEFAULT 0,
  credit      DECIMAL(12,2) NOT NULL DEFAULT 0,
  CHECK ((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)),
  FOREIGN KEY (entry_id)   REFERENCES journal_entry(entry_id),
  FOREIGN KEY (account_id) REFERENCES account(account_id),
  INDEX idx_line_entry (entry_id),
  INDEX idx_line_account (account_id, entry_id)
);

-- 10. contribution (BR5: one per member per month) --------------------
CREATE TABLE contribution (
  contribution_id  INT AUTO_INCREMENT PRIMARY KEY,
  membership_id    INT NOT NULL,
  for_month        DATE NOT NULL,                -- always the 1st of the month
  amount           DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  paid_on          DATE NOT NULL,
  entry_id         INT NOT NULL UNIQUE,
  CHECK (DAY(for_month) = 1),
  UNIQUE (membership_id, for_month),
  FOREIGN KEY (membership_id) REFERENCES membership(membership_id),
  FOREIGN KEY (entry_id)      REFERENCES journal_entry(entry_id)
);

-- 11. loan (EMI is NOT stored: derived from the schedule) -------------
CREATE TABLE loan (
  loan_id             INT AUTO_INCREMENT PRIMARY KEY,
  membership_id       INT NOT NULL,
  principal           DECIMAL(12,2) NOT NULL CHECK (principal > 0),
  annual_rate_pct     DECIMAL(5,2)  NOT NULL CHECK (annual_rate_pct >= 0),
  tenure_months       SMALLINT      NOT NULL CHECK (tenure_months BETWEEN 1 AND 60),
  applied_on          DATE NOT NULL,
  disbursed_on        DATE NULL,
  status              ENUM('APPLIED','APPROVED','ACTIVE','CLOSED','DEFAULTED','REJECTED')
                      NOT NULL DEFAULT 'APPLIED',
  approved_by         INT NULL,
  disbursal_entry_id  INT NULL UNIQUE,
  FOREIGN KEY (membership_id)      REFERENCES membership(membership_id),
  FOREIGN KEY (approved_by)        REFERENCES app_user(user_id),
  FOREIGN KEY (disbursal_entry_id) REFERENCES journal_entry(entry_id)
);

-- 12. repayment_schedule (generated at disbursal) ---------------------
CREATE TABLE repayment_schedule (
  schedule_id     INT AUTO_INCREMENT PRIMARY KEY,
  loan_id         INT NOT NULL,
  installment_no  SMALLINT NOT NULL,
  due_date        DATE NOT NULL,
  principal_due   DECIMAL(12,2) NOT NULL CHECK (principal_due >= 0),
  interest_due    DECIMAL(12,2) NOT NULL CHECK (interest_due >= 0),
  UNIQUE (loan_id, installment_no),
  FOREIGN KEY (loan_id) REFERENCES loan(loan_id),
  INDEX idx_sched_due (due_date)
);

-- 13. repayment (partial payments allowed) ----------------------------
CREATE TABLE repayment (
  repayment_id  INT AUTO_INCREMENT PRIMARY KEY,
  schedule_id   INT NOT NULL,
  paid_on       DATE NOT NULL,
  amount_paid   DECIMAL(12,2) NOT NULL CHECK (amount_paid > 0),
  entry_id      INT NOT NULL UNIQUE,
  FOREIGN KEY (schedule_id) REFERENCES repayment_schedule(schedule_id),
  FOREIGN KEY (entry_id)    REFERENCES journal_entry(entry_id)
);

-- 14. penalty (created by the daily event, posted later by the Treasurer) --
CREATE TABLE penalty (
  penalty_id   INT AUTO_INCREMENT PRIMARY KEY,
  schedule_id  INT NOT NULL,
  assessed_on  DATE NOT NULL,
  amount       DECIMAL(8,2) NOT NULL CHECK (amount > 0),
  entry_id     INT NULL UNIQUE,                  -- NULL until posted
  UNIQUE (schedule_id, assessed_on),             -- BR6: one per instalment per day
  FOREIGN KEY (schedule_id) REFERENCES repayment_schedule(schedule_id),
  FOREIGN KEY (entry_id)    REFERENCES journal_entry(entry_id)
);

-- 15. meeting ---------------------------------------------------------
CREATE TABLE meeting (
  meeting_id    INT AUTO_INCREMENT PRIMARY KEY,
  group_id      INT NOT NULL,
  meeting_date  DATE NOT NULL,
  minutes_text  TEXT NULL,
  UNIQUE (group_id, meeting_date),
  FOREIGN KEY (group_id) REFERENCES sgroup(group_id)
);

-- 16. attendance (resolves meeting <-> membership) --------------------
CREATE TABLE attendance (
  meeting_id     INT NOT NULL,
  membership_id  INT NOT NULL,
  present        BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (meeting_id, membership_id),
  FOREIGN KEY (meeting_id)    REFERENCES meeting(meeting_id),
  FOREIGN KEY (membership_id) REFERENCES membership(membership_id)
);

-- 17. audit_log (filled by triggers on non-ledger tables) -------------
CREATE TABLE audit_log (
  audit_id    BIGINT AUTO_INCREMENT PRIMARY KEY,
  table_name  VARCHAR(40) NOT NULL,
  record_id   BIGINT NOT NULL,
  action      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  old_value   JSON NULL,
  new_value   JSON NULL,
  changed_by  VARCHAR(100) NULL,                 -- database user, from USER()
  changed_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_table (table_name, record_id),
  INDEX idx_audit_time (changed_at)
);