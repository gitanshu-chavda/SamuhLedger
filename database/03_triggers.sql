-- 03_triggers.sql
-- Every trigger body is a single statement, so no DELIMITER is needed.

-- ===== A. Auto-create accounts ==========================================

CREATE TRIGGER trg_sgroup_ai AFTER INSERT ON sgroup FOR EACH ROW
  INSERT INTO account (group_id, type_id, member_id)
  SELECT NEW.group_id, t.type_id, NULL
  FROM account_type t
  WHERE t.type_name IN ('CASH', 'INTEREST_INCOME', 'PENALTY_INCOME');

CREATE TRIGGER trg_membership_ai AFTER INSERT ON membership FOR EACH ROW
  INSERT INTO account (group_id, type_id, member_id)
  SELECT NEW.group_id, t.type_id, NEW.member_id
  FROM account_type t
  WHERE t.type_name IN ('MEMBER_SAVINGS', 'LOAN_RECEIVABLE');

-- ===== B. Append-only ledger ============================================

CREATE TRIGGER trg_je_no_update BEFORE UPDATE ON journal_entry FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'Ledger is append-only: post a reversal instead';

CREATE TRIGGER trg_je_no_delete BEFORE DELETE ON journal_entry FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'Ledger is append-only: post a reversal instead';

CREATE TRIGGER trg_jl_no_update BEFORE UPDATE ON journal_line FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'Ledger is append-only: post a reversal instead';

CREATE TRIGGER trg_jl_no_delete BEFORE DELETE ON journal_line FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'Ledger is append-only: post a reversal instead';

-- ===== C. Audit log for non-ledger tables ===============================
-- app_user is not audited, so password hashes never enter the log.

-- member
CREATE TRIGGER trg_member_audit_ai AFTER INSERT ON member FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, new_value, changed_by)
  VALUES ('member', NEW.member_id, 'INSERT',
    JSON_OBJECT('full_name', NEW.full_name, 'phone', NEW.phone, 'address', NEW.address,
                'joined_on', NEW.joined_on, 'is_active', NEW.is_active), USER());

CREATE TRIGGER trg_member_audit_au AFTER UPDATE ON member FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, old_value, new_value, changed_by)
  VALUES ('member', NEW.member_id, 'UPDATE',
    JSON_OBJECT('full_name', OLD.full_name, 'phone', OLD.phone, 'address', OLD.address,
                'joined_on', OLD.joined_on, 'is_active', OLD.is_active),
    JSON_OBJECT('full_name', NEW.full_name, 'phone', NEW.phone, 'address', NEW.address,
                'joined_on', NEW.joined_on, 'is_active', NEW.is_active), USER());

CREATE TRIGGER trg_member_audit_ad AFTER DELETE ON member FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, old_value, changed_by)
  VALUES ('member', OLD.member_id, 'DELETE',
    JSON_OBJECT('full_name', OLD.full_name, 'phone', OLD.phone, 'address', OLD.address,
                'joined_on', OLD.joined_on, 'is_active', OLD.is_active), USER());

-- sgroup
CREATE TRIGGER trg_sgroup_audit_ai AFTER INSERT ON sgroup FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, new_value, changed_by)
  VALUES ('sgroup', NEW.group_id, 'INSERT',
    JSON_OBJECT('group_name', NEW.group_name, 'group_type', NEW.group_type,
                'formed_on', NEW.formed_on, 'monthly_contribution', NEW.monthly_contribution,
                'loan_rate_pct', NEW.loan_rate_pct, 'loan_limit_multiple', NEW.loan_limit_multiple,
                'grace_days', NEW.grace_days, 'penalty_per_day', NEW.penalty_per_day), USER());

CREATE TRIGGER trg_sgroup_audit_au AFTER UPDATE ON sgroup FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, old_value, new_value, changed_by)
  VALUES ('sgroup', NEW.group_id, 'UPDATE',
    JSON_OBJECT('group_name', OLD.group_name, 'group_type', OLD.group_type,
                'formed_on', OLD.formed_on, 'monthly_contribution', OLD.monthly_contribution,
                'loan_rate_pct', OLD.loan_rate_pct, 'loan_limit_multiple', OLD.loan_limit_multiple,
                'grace_days', OLD.grace_days, 'penalty_per_day', OLD.penalty_per_day),
    JSON_OBJECT('group_name', NEW.group_name, 'group_type', NEW.group_type,
                'formed_on', NEW.formed_on, 'monthly_contribution', NEW.monthly_contribution,
                'loan_rate_pct', NEW.loan_rate_pct, 'loan_limit_multiple', NEW.loan_limit_multiple,
                'grace_days', NEW.grace_days, 'penalty_per_day', NEW.penalty_per_day), USER());

CREATE TRIGGER trg_sgroup_audit_ad AFTER DELETE ON sgroup FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, old_value, changed_by)
  VALUES ('sgroup', OLD.group_id, 'DELETE',
    JSON_OBJECT('group_name', OLD.group_name, 'group_type', OLD.group_type,
                'formed_on', OLD.formed_on, 'monthly_contribution', OLD.monthly_contribution,
                'loan_rate_pct', OLD.loan_rate_pct, 'loan_limit_multiple', OLD.loan_limit_multiple,
                'grace_days', OLD.grace_days, 'penalty_per_day', OLD.penalty_per_day), USER());

-- membership
CREATE TRIGGER trg_membership_audit_ai AFTER INSERT ON membership FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, new_value, changed_by)
  VALUES ('membership', NEW.membership_id, 'INSERT',
    JSON_OBJECT('group_id', NEW.group_id, 'member_id', NEW.member_id,
                'role_in_group', NEW.role_in_group, 'joined_on', NEW.joined_on,
                'left_on', NEW.left_on), USER());

CREATE TRIGGER trg_membership_audit_au AFTER UPDATE ON membership FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, old_value, new_value, changed_by)
  VALUES ('membership', NEW.membership_id, 'UPDATE',
    JSON_OBJECT('group_id', OLD.group_id, 'member_id', OLD.member_id,
                'role_in_group', OLD.role_in_group, 'joined_on', OLD.joined_on,
                'left_on', OLD.left_on),
    JSON_OBJECT('group_id', NEW.group_id, 'member_id', NEW.member_id,
                'role_in_group', NEW.role_in_group, 'joined_on', NEW.joined_on,
                'left_on', NEW.left_on), USER());

CREATE TRIGGER trg_membership_audit_ad AFTER DELETE ON membership FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, old_value, changed_by)
  VALUES ('membership', OLD.membership_id, 'DELETE',
    JSON_OBJECT('group_id', OLD.group_id, 'member_id', OLD.member_id,
                'role_in_group', OLD.role_in_group, 'joined_on', OLD.joined_on,
                'left_on', OLD.left_on), USER());

-- loan
CREATE TRIGGER trg_loan_audit_ai AFTER INSERT ON loan FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, new_value, changed_by)
  VALUES ('loan', NEW.loan_id, 'INSERT',
    JSON_OBJECT('membership_id', NEW.membership_id, 'principal', NEW.principal,
                'annual_rate_pct', NEW.annual_rate_pct, 'tenure_months', NEW.tenure_months,
                'applied_on', NEW.applied_on, 'disbursed_on', NEW.disbursed_on,
                'status', NEW.status, 'approved_by', NEW.approved_by,
                'disbursal_entry_id', NEW.disbursal_entry_id), USER());

CREATE TRIGGER trg_loan_audit_au AFTER UPDATE ON loan FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, old_value, new_value, changed_by)
  VALUES ('loan', NEW.loan_id, 'UPDATE',
    JSON_OBJECT('membership_id', OLD.membership_id, 'principal', OLD.principal,
                'annual_rate_pct', OLD.annual_rate_pct, 'tenure_months', OLD.tenure_months,
                'applied_on', OLD.applied_on, 'disbursed_on', OLD.disbursed_on,
                'status', OLD.status, 'approved_by', OLD.approved_by,
                'disbursal_entry_id', OLD.disbursal_entry_id),
    JSON_OBJECT('membership_id', NEW.membership_id, 'principal', NEW.principal,
                'annual_rate_pct', NEW.annual_rate_pct, 'tenure_months', NEW.tenure_months,
                'applied_on', NEW.applied_on, 'disbursed_on', NEW.disbursed_on,
                'status', NEW.status, 'approved_by', NEW.approved_by,
                'disbursal_entry_id', NEW.disbursal_entry_id), USER());

CREATE TRIGGER trg_loan_audit_ad AFTER DELETE ON loan FOR EACH ROW
  INSERT INTO audit_log (table_name, record_id, action, old_value, changed_by)
  VALUES ('loan', OLD.loan_id, 'DELETE',
    JSON_OBJECT('membership_id', OLD.membership_id, 'principal', OLD.principal,
                'annual_rate_pct', OLD.annual_rate_pct, 'tenure_months', OLD.tenure_months,
                'applied_on', OLD.applied_on, 'disbursed_on', OLD.disbursed_on,
                'status', OLD.status, 'approved_by', OLD.approved_by,
                'disbursal_entry_id', OLD.disbursal_entry_id), USER());
