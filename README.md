# Snowflake Intelligence Resource Budget

Minimal, production-ready script to set up a monthly credit budget for a Snowflake Intelligence object with an email alert at 80% projected spend. No access revocation — alert only.

## What it does

| Step | Statement | Purpose |
|------|-----------|---------|
| 1 | `ACCOUNT_ROOT_BUDGET!ACTIVATE()` | Enable the budget framework (idempotent) |
| 2 | `CREATE DATABASE/SCHEMA IF NOT EXISTS` | Ensure storage locations exist |
| 3 | `CREATE TAG` + `ALTER SNOWFLAKE INTELLIGENCE SET TAG` | Tag the SI object for cost tracking |
| 4 | `CREATE BUDGET` + `SET_SPENDING_LIMIT` | Create budget with monthly credit cap |
| 5 | `SET_RESOURCE_TAGS` | Link the tag to the budget |
| 6 | `SET_EMAIL_NOTIFICATIONS` + `SET_NOTIFICATION_THRESHOLD` | Email alert at 80% projected spend |
| 7 | `GET_SPENDING_LIMIT` + `GET_BUDGET_SCOPE` | Verify everything is configured |

## Prerequisites

Complete these **before** running the script. Most failures come from skipping these.

### 1. Role
Run as **ACCOUNTADMIN**, or a custom role with:
- `SNOWFLAKE.BUDGET_CREATOR` database role
- `CREATE SNOWFLAKE.CORE.BUDGET` privilege on the budget schema
- `APPLYBUDGET` privilege on the tag

### 2. Verified emails
Every email address in `{{EMAIL_RECIPIENTS}}` **must** be [verified in Snowflake](https://docs.snowflake.com/en/user-guide/notifications/email-notifications#verify-an-email-address).

Go to: **Snowsight > Admin > Notifications > Verify Email**

If even one email is unverified, `SET_EMAIL_NOTIFICATIONS` will fail.

### 3. Account parameters
These must be at their default values. The script includes preflight checks that show you the current values.

| Parameter | Required Value |
|-----------|---------------|
| `AUTOCOMMIT` | `TRUE` (default) |
| `TIMESTAMP_INPUT_FORMAT` | `AUTO` (default) |
| `DATE_INPUT_FORMAT` | `AUTO` (default) |

If any are non-default, fix with: `ALTER ACCOUNT SET <param> = <value>;`

### 4. Snowflake Intelligence object
The SI object must already exist. Confirm with:
```sql
SHOW SNOWFLAKE INTELLIGENCE;
```

## Parameters

Find-and-replace all `{{...}}` placeholders before running:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `{{BUDGET_DB}}` | Database for the budget object | `BUDGETS_DB` |
| `{{BUDGET_SCHEMA}}` | Schema for the budget object | `BUDGETS_SCHEMA` |
| `{{TAG_DB}}` | Database for the cost-center tag | `COST_MGMT_DB` |
| `{{TAG_SCHEMA}}` | Schema for the cost-center tag | `TAGS` |
| `{{SI_OBJECT_NAME}}` | Your Snowflake Intelligence object name | `SI_INSTANCE_1` |
| `{{BUDGET_NAME}}` | Name for the new budget | `SI_BUDGET` |
| `{{CREDIT_LIMIT}}` | Monthly credit limit (positive integer) | `10000` |
| `{{EMAIL_RECIPIENTS}}` | Comma-separated verified email addresses | `finops@example.com,admin@example.com` |

## Usage

```
1. Replace all {{...}} parameters in si_resource_budget.sql
2. Verify email addresses are verified in Snowflake
3. Run sequentially in Snowsight or any Snowflake SQL client
4. Review output of the final two verification steps
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `SET_EMAIL_NOTIFICATIONS` fails | Unverified email address | Verify at Snowsight > Admin > Notifications |
| Budget created but no spend tracked | `ALTER SNOWFLAKE INTELLIGENCE IF EXISTS` silently skipped | Check SI object name with `SHOW SNOWFLAKE INTELLIGENCE;` |
| Budget never triggers alerts | `AUTOCOMMIT` set to `FALSE` at account level | `ALTER ACCOUNT SET AUTOCOMMIT = TRUE;` |
| Spending data delayed | Normal — budget refresh is up to 6.5 hours | Enable low-latency: `CALL budget!SET_REFRESH_TIER('LOW');` (increases budget compute cost 12x) |

## References

- [Resource budgets for Snowflake Intelligence](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence/si-resource-budgets)
- [BUDGET class reference](https://docs.snowflake.com/en/sql-reference/classes/budget)
- [Budget notifications](https://docs.snowflake.com/en/user-guide/budgets/notifications)
- [Monitor credit usage with budgets](https://docs.snowflake.com/en/user-guide/budgets)
