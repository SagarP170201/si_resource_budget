-- =============================================================================
-- Snowflake Intelligence Resource Budget — Email Alert at 80%
-- =============================================================================
--
-- WHAT THIS DOES:
--   Sets up a monthly credit budget for a Snowflake Intelligence (SI) object.
--   You will receive an email alert when projected spend hits 80% of the limit.
--   No access revocation — alert only.
--
-- HOW TO USE:
--   1. Find-and-replace every {{PARAMETER}} below with your values
--   2. Read the PREREQUISITES section — skipping these causes failures
--   3. Run all statements sequentially in Snowsight or any SQL client
--
-- PARAMETERS (find-and-replace before running):
--
--   {{BUDGET_DB}}        — Database to store the budget object
--                          Example: BUDGETS_DB
--
--   {{BUDGET_SCHEMA}}    — Schema to store the budget object
--                          Example: BUDGETS_SCHEMA
--
--   {{TAG_DB}}           — Database to store the cost-center tag
--                          Example: COST_MGMT_DB
--
--   {{TAG_SCHEMA}}       — Schema to store the cost-center tag
--                          Example: TAGS
--
--   {{SI_OBJECT_NAME}}   — Name of your Snowflake Intelligence object
--                          Example: SI_INSTANCE_1
--                          Find it: SHOW SNOWFLAKE INTELLIGENCE;
--
--   {{BUDGET_NAME}}      — Name for the new budget object
--                          Example: SI_BUDGET
--
--   {{CREDIT_LIMIT}}     — Monthly credit limit (positive integer)
--                          Example: 10000
--
--   {{EMAIL_RECIPIENTS}} — Comma-separated email addresses for alerts
--                          Example: finops@example.com,admin@example.com
--
-- PREREQUISITES (read before running — these cause the most failures):
--
--   1. ROLE: You must run this as ACCOUNTADMIN, or a custom role with:
--      - SNOWFLAKE.BUDGET_CREATOR database role
--      - CREATE SNOWFLAKE.CORE.BUDGET on the budget schema
--      - APPLYBUDGET on the tag
--
--   2. VERIFIED EMAILS: Every address in {{EMAIL_RECIPIENTS}} MUST be verified.
--      Go to: Snowsight > Admin > Notifications > Verify Email
--      If even one email is unverified, SET_EMAIL_NOTIFICATIONS will fail.
--
--   3. ACCOUNT PARAMETERS: These must be at default values (they usually are).
--      If changed, budgets silently malfunction:
--      - AUTOCOMMIT = TRUE
--      - TIMESTAMP_INPUT_FORMAT = AUTO
--      - DATE_INPUT_FORMAT = AUTO
--      The preflight checks below will show you the current values.
--
--   4. SI OBJECT: The Snowflake Intelligence object must already exist.
--      Run SHOW SNOWFLAKE INTELLIGENCE; to confirm.
--
-- REFERENCES:
--   https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence/si-resource-budgets
--   https://docs.snowflake.com/en/sql-reference/classes/budget
--   https://docs.snowflake.com/en/user-guide/budgets/notifications
--
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ---- PREFLIGHT CHECKS -------------------------------------------------------
-- These show current account parameter values. Review the output.
-- If any are non-default, fix them before proceeding (ALTER ACCOUNT SET ...).
SHOW PARAMETERS LIKE 'AUTOCOMMIT' IN ACCOUNT;
SHOW PARAMETERS LIKE 'TIMESTAMP_INPUT_FORMAT' IN ACCOUNT;
SHOW PARAMETERS LIKE 'DATE_INPUT_FORMAT' IN ACCOUNT;

-- ---- STEP 1: ACTIVATE BUDGET FRAMEWORK --------------------------------------
-- Idempotent — safe to run even if already activated.
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();

-- ---- STEP 2: ENSURE DATABASES AND SCHEMAS EXIST ----------------------------
-- Creates them if missing. No-op if they already exist.
CREATE DATABASE IF NOT EXISTS {{TAG_DB}};
CREATE SCHEMA IF NOT EXISTS {{TAG_DB}}.{{TAG_SCHEMA}};
CREATE DATABASE IF NOT EXISTS {{BUDGET_DB}};
CREATE SCHEMA IF NOT EXISTS {{BUDGET_DB}}.{{BUDGET_SCHEMA}};

-- ---- STEP 3: TAG THE SI OBJECT FOR COST TRACKING ----------------------------
-- SI budgets require a tag-based approach (you cannot add an SI object directly
-- to a budget). We create a tag, apply it to the SI object, then link the tag
-- to the budget in Step 5.
CREATE TAG IF NOT EXISTS {{TAG_DB}}.{{TAG_SCHEMA}}.SI_COST_CENTER
    ALLOWED_VALUES 'si-main'
    COMMENT = 'Cost center tag for SI resource budgets';

-- IF EXISTS: silently skips if the SI object doesn't exist.
-- If this skips, the budget will be created but won't track anything.
ALTER SNOWFLAKE INTELLIGENCE IF EXISTS {{SI_OBJECT_NAME}}
    SET TAG {{TAG_DB}}.{{TAG_SCHEMA}}.SI_COST_CENTER = 'si-main';

-- ---- STEP 4: CREATE BUDGET + SET SPENDING LIMIT ------------------------------
-- Budgets are MONTHLY only (no weekly/quarterly option).
-- The limit is in Snowflake credits, not dollars.
CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}();

CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!SET_SPENDING_LIMIT({{CREDIT_LIMIT}});

-- ---- STEP 5: LINK TAG TO BUDGET ----------------------------------------------
-- This tells the budget to track all objects tagged with SI_COST_CENTER = 'si-main'.
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!SET_RESOURCE_TAGS(
    [
        [
            (SELECT SYSTEM$REFERENCE('TAG', '{{TAG_DB}}.{{TAG_SCHEMA}}.SI_COST_CENTER', 'SESSION', 'APPLYBUDGET')),
            'si-main'
        ]
    ],
    'UNION'
);

-- ---- STEP 6: EMAIL ALERT AT 80% PROJECTED SPEND -----------------------------
-- IMPORTANT: Every email address must be verified in Snowflake BEFORE running.
-- This will ERROR if any email is unverified.
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!SET_EMAIL_NOTIFICATIONS(
    '{{EMAIL_RECIPIENTS}}'
);

-- Threshold is based on PROJECTED spend (Snowflake forecasts end-of-month usage).
-- Range: 0-1000. Default (if not set) is 110 (alerts only if projected to exceed limit).
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!SET_NOTIFICATION_THRESHOLD(80);

-- ---- STEP 7: VERIFY SETUP ---------------------------------------------------
-- Review the output of these to confirm everything is configured correctly.
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!GET_SPENDING_LIMIT();
CALL {{BUDGET_DB}}.{{BUDGET_SCHEMA}}.{{BUDGET_NAME}}!GET_BUDGET_SCOPE();
