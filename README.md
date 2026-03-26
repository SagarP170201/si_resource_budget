# Snowflake Intelligence Resource Budget

Minimal script to set up a monthly credit budget for a Snowflake Intelligence object with an email alert at 80% projected spend.

## What it does

1. Activates the Snowflake budget framework
2. Creates a cost-center tag and applies it to your SI object
3. Creates a budget with a monthly credit limit
4. Links the tag to the budget so SI spend is tracked
5. Sends an email alert when projected spend hits 80%

## Prerequisites

- **Role**: ACCOUNTADMIN (or a role with `SNOWFLAKE.BUDGET_CREATOR` + `APPLYBUDGET`)
- **Verified emails**: Every email address in `{{EMAIL_RECIPIENTS}}` must be [verified in Snowflake](https://docs.snowflake.com/en/user-guide/notifications/email-notifications#verify-an-email-address) — the script will fail otherwise
- **Account parameters** (must be at default values):
  - `AUTOCOMMIT` = `TRUE`
  - `TIMESTAMP_INPUT_FORMAT` = `AUTO`
  - `DATE_INPUT_FORMAT` = `AUTO`
- **Snowflake Intelligence object** must already exist

## Parameters

Replace these before running:

| Parameter | Example |
|---|---|
| `{{BUDGET_DB}}` | `BUDGETS_DB` |
| `{{BUDGET_SCHEMA}}` | `BUDGETS_SCHEMA` |
| `{{TAG_DB}}` | `COST_MGMT_DB` |
| `{{TAG_SCHEMA}}` | `TAGS` |
| `{{SI_OBJECT_NAME}}` | `SI_INSTANCE_1` |
| `{{BUDGET_NAME}}` | `SI_BUDGET` |
| `{{CREDIT_LIMIT}}` | `10000` |
| `{{EMAIL_RECIPIENTS}}` | `finops@example.com,admin@example.com` |

## Usage

1. Replace all `{{...}}` parameters
2. Verify your email addresses are verified in Snowflake
3. Run in Snowsight or any Snowflake SQL client

## References

- [Resource budgets for Snowflake Intelligence](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence/si-resource-budgets)
- [BUDGET class reference](https://docs.snowflake.com/en/sql-reference/classes/budget)
- [Budget notifications](https://docs.snowflake.com/en/user-guide/budgets/notifications)
