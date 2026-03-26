-- =============================================================================
-- Snowflake Intelligence Resource Budget — Alert at 80%
-- =============================================================================
-- Run as: ACCOUNTADMIN
--
-- PARAMETERS (replace before running):
--   {{BUDGET_DB}}        : e.g. 'BUDGETS_DB'
--   {{BUDGET_SCHEMA}}    : e.g. 'BUDGETS_SCHEMA'
--   {{TAG_DB}}           : e.g. 'COST_MGMT_DB'
--   {{TAG_SCHEMA}}       : e.g. 'TAGS'
--   {{SI_OBJECT_NAME}}   : e.g. 'SI_INSTANCE_1'
--   {{BUDGET_NAME}}      : e.g. 'SI_BUDGET'
--   {{CREDIT_LIMIT}}     : e.g. 10000
--   {{EMAIL_RECIPIENTS}} : e.g. 'finops@example.com,admin@example.com'
--
-- PREREQUISITES:
--   - Each email in {{EMAIL_RECIPIENTS}} must be verified in Snowflake
--     (Admin > Notifications > Verify Email)
--   - Account-level AUTOCOMMIT must be TRUE (default)
--   - Account-level TIMESTAMP_INPUT_FORMAT and DATE_INPUT_FORMAT must be AUTO (default)
--   - {{BUDGET_DB}}.{{BUDGET_SCHEMA}} and {{TAG_DB}}.{{TAG_SCHEMA}} must exist
--   - The Snowflake Intelligence object {{SI_OBJECT_NAME}} must exist
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- 0) Preflight: verify account params won't silently break budgets
SHOW PARAMETERS LIKE 'AUTOCOMMIT' IN ACCOUNT;
SHOW PARAMETERS LIKE 'TIMESTAMP_INPUT_FORMAT' IN ACCOUNT;
SHOW PARAMETERS LIKE 'DATE_INPUT_FORMAT' IN ACCOUNT;

-- 1) Activate root budget framework (idempotent)
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();

-- 2) Ensure databases and schemas exist
CREATE DATABASE IF NOT EXISTS {{TAG_DB}};
CREATE SCHEMA IF NOT EXISTS {{TAG_DB}}.{{TAG_SCHEMA}};
CREATE DATABASE IF NOT EXISTS {{BUDGET_DB}};
CREATE SCHEMA IF NOT EXISTS {{BUDGET_DB}}.{{BUDGET_SCHEMA}};

-- 3) Tag the SI object for cost tracking
CREATE TAG IF NOT EXISTS {{TAG_DB}}.{{TAG_SCHEMA}}.SI_COST_CENTER
    ALLOWED_VALUES 'si-main'
    COMMENT = 'Cost center tag for SI resource budgets';

ALTER SNOWFLAKE INTELLIGENCE IF EXISTS {{SI_OBJECT_NAME}}
    SET TAG {{TAG_DB}}.{{TAG_SCHEMA}}.SI_COST_CENTER = 'si-main';

-- 4) Create budget + set monthly spending limit
CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}();

CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!SET_SPENDING_LIMIT({{CREDIT_LIMIT}});

-- 5) Link tag to budget
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!SET_RESOURCE_TAGS(
    [
        [
            (SELECT SYSTEM$REFERENCE('TAG', '{{TAG_DB}}.{{TAG_SCHEMA}}.SI_COST_CENTER', 'SESSION', 'APPLYBUDGET')),
            'si-main'
        ]
    ],
    'UNION'
);

-- 6) Email alert at 80% projected spend
--    NOTE: Every email address below must already be verified in Snowflake,
--    otherwise this call will fail.
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!SET_EMAIL_NOTIFICATIONS(
    '{{EMAIL_RECIPIENTS}}'
);

CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!SET_NOTIFICATION_THRESHOLD(80);

-- 7) Verify setup
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!GET_SPENDING_LIMIT();
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!GET_BUDGET_SCOPE();
