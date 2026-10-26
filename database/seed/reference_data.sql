-- Fixed lookup data every group depends on.
INSERT INTO role (role_id, role_name) VALUES
  (1, 'ADMIN'),
  (2, 'TREASURER'),
  (3, 'PRESIDENT'),
  (4, 'MEMBER'),
  (5, 'AUDITOR');

INSERT INTO account_type (type_id, type_name, category) VALUES
  (1, 'CASH',            'ASSET'),
  (2, 'MEMBER_SAVINGS',  'LIABILITY'),
  (3, 'LOAN_RECEIVABLE', 'ASSET'),
  (4, 'INTEREST_INCOME', 'INCOME'),
  (5, 'PENALTY_INCOME',  'INCOME');
