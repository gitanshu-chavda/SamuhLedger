-- 02_indexes.sql
-- Run after 01_schema.sql.
-- Already created in 01_schema.sql (do not repeat them here):
--   journal_entry       idx_entry_group_date (group_id, entry_date)
--   journal_line        idx_line_entry (entry_id), idx_line_account (account_id, entry_id)
--   repayment_schedule  idx_sched_due (due_date)
--   audit_log           idx_audit_table (table_name, record_id), idx_audit_time (changed_at)

-- 1. Amount paid per instalment (covering index)
-- Used by: overdue aging, collection efficiency, penalty event, v_schedule_status.
CREATE INDEX idx_repay_sched_amt ON repayment (schedule_id, amount_paid);

-- 2. Loans of a membership, filtered by status
-- Used by: BR8 (no leaving with an ACTIVE loan), BR3 checks, "my loans".
CREATE INDEX idx_loan_member_status ON loan (membership_id, status);

-- 3. Entries posted by one user in a date range
-- Used by: the audit view.
CREATE INDEX idx_entry_poster_date ON journal_entry (posted_by, entry_date);

-- 4. Who paid in a given month
-- Used by: contribution compliance report.
CREATE INDEX idx_contrib_month ON contribution (for_month, membership_id);

-- 5. Attendance rate per member (covering index)
-- Used by: attendance report.
CREATE INDEX idx_att_member_present ON attendance (membership_id, present);