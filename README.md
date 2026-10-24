# SamuhLedger

**Self-help group and chit fund ledger with double-entry accounting.**
A DBMS course project built on MySQL 8 and Streamlit.

Self-help groups (SHGs), chit funds and small cooperatives collect monthly contributions, lend to members and recover instalments, usually in notebooks or loose spreadsheets. Errors creep in, balances are disputed, nobody can prove what happened afterwards, and defaulters are noticed late.

SamuhLedger records every rupee as a balanced double-entry journal entry. Any balance can be traced to the transactions behind it, and the books can never silently drift.

---

## Contents

1. [Features](#features)
2. [Tech stack](#tech-stack)
3. [How the ledger works](#how-the-ledger-works)
4. [Business rules](#business-rules)
5. [Roles and permissions](#roles-and-permissions)
6. [Project structure](#project-structure)
7. [Getting started (Windows)](#getting-started-windows)
8. [Running the app](#running-the-app)
9. [Testing](#testing)
10. [Deployment](#deployment)
11. [Project status](#project-status)
12. [Documentation](#documentation)
13. [Team](#team)

---

## Features

- **Groups, members and memberships** with an automatically created account set for each group and each member.
- **Atomic double-entry posting.** Every money movement (contribution, loan disbursal, repayment, penalty, withdrawal) is one balanced journal entry, posted only through stored procedures.
- **Append-only ledger.** History is never edited or deleted. Corrections are reversal entries, and an entry can be reversed only once.
- **Loan lifecycle.** Application, approval against a savings-based limit, disbursal with an EMI schedule, repayments (interest first, then principal), closure.
- **Penalties.** A daily database event assesses late penalties after the group's grace period; the Treasurer posts them.
- **Reports.** Trial balance, member passbooks with running balances, overdue aging, portfolio at risk, collection efficiency, group balance sheet, contribution compliance, attendance.
- **Role-based access.** Five roles with separation of duties: the person who approves a loan cannot post its disbursal, and nobody can edit history.
- **Audit log** of changes to non-ledger tables, stored as JSON old and new values.

### Database features demonstrated

ACID transactions with locking reads, isolation-level and deadlock demonstrations, triggers, stored procedures, recursive CTE (EMI schedule), window functions (running balances), scheduled events, views, role-based database security, JSON handling (`JSON_TABLE`), and indexing with `EXPLAIN ANALYZE` performance analysis.

---

## Tech stack

| Layer | Choice |
|---|---|
| Database | MySQL 8.0 (InnoDB), run in Docker |
| Application | Python 3.11+ and Streamlit |
| DB driver | `mysql-connector-python` |
| Passwords | `bcrypt` |
| Data handling | `pandas` |
| Seed data | `Faker` |
| Tests | `pytest` |

Design rules: **no ORM** (money logic must be visible SQL), **`DECIMAL` for every amount** (never floating point), and **business logic lives in SQL**. Python only calls procedures and displays results.

---

## How the ledger works

Every event is a journal entry whose debits equal its credits.

| Event | Debit | Credit |
|---|---|---|
| Contribution received | Cash | Member savings (member) |
| Loan disbursed | Loan receivable (member) | Cash |
| Repayment received | Cash (total) | Loan receivable (principal part) and Interest income (interest part) |
| Penalty assessed | Member savings (member) | Penalty income |
| Savings withdrawal | Member savings (member) | Cash |
| Reversal of any entry | The original credits | The original debits |

Balances are never stored. They are computed from `journal_line` by the view `v_account_balance`. The view `v_unbalanced_entries` must always return zero rows.

Repayments are allocated to interest first, then principal. Interest is recognised when received (a deliberate simplification).

---

## Business rules

| ID | Rule |
|---|---|
| BR1 | Every journal entry balances and is posted only through the posting procedure. |
| BR2 | The ledger is append-only; an entry can be reversed once. |
| BR3 | A loan principal cannot exceed the group's limit multiple times the member's savings balance. |
| BR4 | A repayment cannot exceed the outstanding amount on that instalment. |
| BR5 | One contribution per member per month. |
| BR6 | Penalties start only after the group's grace days, and at most one per instalment per day. |
| BR7 | The group's cash account can never go negative. |
| BR8 | A member cannot leave a group while holding an active loan. |

---

## Roles and permissions

| Role | Who | Can do | Cannot do |
|---|---|---|---|
| Admin | Federation or NGO officer | Create groups, manage users and policies, view all groups | Post or reverse entries |
| Treasurer | Group treasurer | Record contributions, disbursals, repayments, penalties; post and reverse entries; run reports | Approve loans |
| President | Group president | Approve or reject loans, view reports | Post entries |
| Member | Group member | View own passbook, loans and schedule; apply for a loan | See other members' data |
| Auditor | External or federation auditor | Read-only access to ledger, trial balance and audit log | Change anything |

Enforcement happens at two levels: the Streamlit app shows each role only its own pages and takes identity from the login session, and MySQL gives each role its own database account with `SELECT` on views and `EXECUTE` on specific procedures. No application account has write access to `journal_entry` or `journal_line`.

---

## Project structure

```
samuhledger/
|-- README.md
|-- .gitignore                  (lists .env and .streamlit/secrets.toml)
|-- .env                        (local MySQL root password, never committed)
|-- docker-compose.yml          (MySQL 8 container)
|-- requirements.txt
|-- streamlit_app.py            (entry point: login, then role-based menu)
|-- .streamlit/
|   |-- config.toml
|   `-- secrets.toml            (DB credentials, never committed)
|-- core/                       (db connections, auth, money helpers)
|-- repositories/               (all SQL called from Python lives here)
|-- views/                      (one Streamlit page per file)
|-- database/
|   |-- 01_schema.sql           (17 tables)
|   |-- 02_indexes.sql
|   |-- 03_triggers.sql
|   |-- 04_procedures.sql
|   |-- 05_views.sql
|   |-- 06_events.sql
|   |-- 07_roles_grants.sql
|   |-- seed/                   (reference_data.sql, generate_seed.py)
|   |-- queries/                (reports.sql, emi_schedule.sql)
|   `-- tests/                  (test_cases.sql, isolation and deadlock demos)
|-- tests/                      (pytest)
|-- docs/                       (ER diagram, schema, normalization, report, screenshots)
`-- scripts/
    |-- runsql.ps1              (run one SQL file against the Docker database)
    `-- dbshell.ps1             (open a MySQL prompt in the container)
```

The Streamlit page folder is called `views/`, not `pages/`, on purpose: Streamlit auto-builds a menu from a `pages/` folder, and each role needs its own menu.

---

## Getting started (Windows)

### Prerequisites

- Python 3.11 or newer
- Docker Desktop (running)
- Git
- VS Code (recommended extensions: Python, Docker, SQLTools with the MySQL driver)

### 1. Get the code

```powershell
git clone <your-repo-url>
cd samuhledger
```

### 2. Create `.env`

Create a file named `.env` in the project root:

```
MYSQL_ROOT_PASSWORD=choose-a-strong-password
```

### 3. Python environment

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

In VS Code, choose the interpreter inside `.venv` (Ctrl+Shift+P, then "Python: Select Interpreter").

### 4. Start MySQL

```powershell
docker compose up -d
docker ps
```

You should see `samuhledger-db` with status `Up`. Wait about 30 seconds on first start.

> **Port note:** the container's MySQL is published on port **3307** of your machine, because a local MySQL installation often already uses 3306. Anything connecting from your computer (Python, Streamlit, SQLTools) must use `127.0.0.1:3307`.

### 5. Create the database and load the schema

```powershell
$dbPass = ((Get-Content .env | Where-Object { $_ -match '^MYSQL_ROOT_PASSWORD=' }) -replace '^MYSQL_ROOT_PASSWORD=','').Trim()
docker exec -i -e MYSQL_PWD=$dbPass samuhledger-db mysql -uroot -e "CREATE DATABASE IF NOT EXISTS samuhledger CHARACTER SET utf8mb4;"

.\scripts\runsql.ps1 database\01_schema.sql
```

If PowerShell blocks the script, run it as:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\runsql.ps1 database\01_schema.sql
```

Check the result:

```powershell
.\scripts\dbshell.ps1
```

```sql
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'samuhledger';
```

It should return **17**.

### 6. Load the remaining SQL, in order

As each file is written, load it the same way, in numeric order:

```powershell
.\scripts\runsql.ps1 database\02_indexes.sql
.\scripts\runsql.ps1 database\03_triggers.sql
.\scripts\runsql.ps1 database\04_procedures.sql
.\scripts\runsql.ps1 database\05_views.sql
.\scripts\runsql.ps1 database\06_events.sql
.\scripts\runsql.ps1 database\seed\reference_data.sql
.\scripts\runsql.ps1 database\07_roles_grants.sql
python database\seed\generate_seed.py --small
```

Dropping and recreating the whole database is the clean way to reset it. Do not use `TRUNCATE` on ledger tables: it bypasses the append-only triggers.

### 7. Configure the app

Create `.streamlit/secrets.toml` (never commit it):

```toml
[db]
host = "127.0.0.1"
port = 3307
name = "samuhledger"

[roles.login]
user = "app_login"
password = "change-me"

[roles.treasurer]
user = "app_treasurer"
password = "change-me"

# ...one block each for president, member, auditor, admin

[roles.seed]            # local only: used by the seeder and tests
user = "root"
password = "your-root-password"
```

---

## Running the app

```powershell
streamlit run streamlit_app.py
```

Open the address Streamlit prints (usually http://localhost:8501) and sign in with one of the seeded demo users.

---

## Testing

Two layers:

1. **SQL test script** (`database/tests/test_cases.sql`) covering TC01 to TC13: unbalanced entries, cross-group accounts, append-only triggers, double reversals, duplicate contributions, loan limit, overpayment, cash overdraft, deadlock, penalty idempotency.
2. **pytest** (`tests/`) automating the same cases, including threaded concurrency tests and role-permission checks.

```powershell
pytest
```

After every full test run, `v_unbalanced_entries` must return zero rows.

Live demonstrations, run in two MySQL terminals, are described in `database/tests/isolation_demo.md` and `database/tests/deadlock_demo.md`.

---

## Deployment

The Streamlit app and the database are deployed separately.

- **App:** Streamlit Community Cloud, connected to the `main` branch, entry file `streamlit_app.py`, secrets pasted into the app's Secrets setting. Never paste the local root credentials.
- **Database:** a real MySQL 8 host that supports stored procedures, triggers, `CREATE USER` and `GRANT` (for example Aiven, Railway MySQL, or a MySQL container on a VPS). Avoid services that do not support procedures and triggers. Require TLS.
- **Events:** if the host does not allow the event scheduler, use the Treasurer-only "Run penalty assessment" button, which calls the same procedure.
- Load only the small seed data on the hosted database; run the two-million-line benchmark locally.

---

## Project status

- [x] Requirements, plan and Streamlit build guide
- [x] Project folders and configuration files
- [x] MySQL 8 running in Docker
- [x] `01_schema.sql` written (17 tables)
- [ ] Schema loaded and verified
- [ ] Reference data (roles, account types)
- [ ] Triggers (account auto-creation, append-only ledger, audit)
- [ ] Posting procedures (`sp_post_entry_core`, business procedures)
- [ ] Views (balances, ledger lines, schedule status, unbalanced entries)
- [ ] Events (penalty assessment)
- [ ] Roles and grants
- [ ] Seed data generator
- [ ] Core Python layer (`core/`, `repositories/`)
- [ ] Streamlit pages
- [ ] Reports and dashboard
- [ ] Tests, performance analysis, final report

---

## Documentation

Full project documentation lives in `docs/`:

| File | Contents |
|---|---|
| `01-problem-statement.md` | Executive summary, problem statement, objectives |
| `02-er-diagram.png` | Entity-relationship diagram |
| `03-relational-schema.md` | Relational schema |
| `04-data-dictionary.md` | Every table and column |
| `05-normalization-proof.md` | Functional dependencies and 1NF to BCNF checks |
| `06-advanced-dbms-topics.md` | Transactions, locking, triggers, procedures, events, security |
| `07-test-cases-and-results.md` | Test cases and recorded results |
| `08-performance-analysis.md` | Indexing and `EXPLAIN ANALYZE` results |

---

## Team

| Member | Role |
|---|---|
| A: _name_ | Database architect: schema, normalization, triggers, views, grants |
| B: _name_ | Data layer: core Python files, procedures, login, transaction helper |
| C: _name_ | Streamlit pages, charts, screenshots |
| D: _name_ | QA, seed data, events, reports, demos, performance, final report |

Git conventions: `main` is always demo-ready; work on `feature/<module>` branches; one pull request per module, reviewed by a different teammate.

---

*All SQL and code in this repository is course-project code. Every team member should be able to explain each line.*
