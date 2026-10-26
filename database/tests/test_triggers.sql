INSERT INTO sgroup (group_name, group_type, formed_on, monthly_contribution, loan_rate_pct)
VALUES ('Test Group', 'SHG', '2026-01-01', 500, 12);
INSERT INTO member (full_name, phone, joined_on) VALUES ('Asha', '9000000001', '2026-01-01');
INSERT INTO membership (group_id, member_id, joined_on) VALUES (1, 1, '2026-01-01');

SELECT 'ACCOUNTS: expect 5 rows' AS check_name;
SELECT account_id, group_id, type_id, member_id FROM account;

SELECT 'AUDIT LOG: expect 3 rows' AS check_name;
SELECT table_name, action, changed_by FROM audit_log;

INSERT INTO app_user (username, password_hash, role_id, group_id) VALUES ('t', 'x', 2, 1);
INSERT INTO journal_entry (group_id, entry_date, description, entry_type, posted_by)
VALUES (1, '2026-01-02', 'test', 'ADJUSTMENT', 1);
INSERT INTO journal_line (entry_id, account_id, debit) VALUES (1, 1, 100);

SELECT 'NEXT 4 STATEMENTS MUST FAIL with: Ledger is append-only' AS check_name;
UPDATE journal_line SET debit = 200 WHERE line_id = 1;
DELETE FROM journal_line WHERE line_id = 1;
UPDATE journal_entry SET description = 'changed' WHERE entry_id = 1;
DELETE FROM journal_entry WHERE entry_id = 1;
