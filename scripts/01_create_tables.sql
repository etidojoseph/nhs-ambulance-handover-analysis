-- ============================================================
-- 01_create_tables.sql
-- Sets up the database schema and validates data integrity.
--
-- NOTE ON TABLE CREATION: the two tables were NOT created with
-- a CREATE TABLE statement. They were created using SSMS's
-- Import Flat File wizard, pointing directly at trusts.csv and
-- handovers.csv, which auto-generates a table from the file.
-- Default column types from the wizard were manually corrected
-- on the "Modify Columns" screen before import:
--   - count columns (over_15, over_30, etc.): tinyint -> int
--     (tinyint maxes out at 255, too small for daily counts)
--   - pct_over_* and mean_time: kept as nvarchar(50), NOT float,
--     because the raw data contains '-' placeholders that a
--     numeric type would reject on import (see 02_data_cleaning.sql)
--
-- The equivalent schema, for anyone reproducing this without
-- the wizard, would be:
--
--   CREATE TABLE trusts (
--       trust_code CHAR(3) PRIMARY KEY,
--       trust_name VARCHAR(255),
--       region VARCHAR(100)
--   );
--
--   CREATE TABLE handovers (
--       trust_code CHAR(3),
--       handover_date DATE,
--       handover_known INT, over_15 INT, over_30 INT, over_45 INT,
--       over_60 INT, handover_unknown INT, all_handovers INT,
--       total_hours FLOAT,
--       mean_time NVARCHAR(50),
--       pct_over_15 NVARCHAR(50), pct_over_30 NVARCHAR(50),
--       pct_over_45 NVARCHAR(50), pct_over_60 NVARCHAR(50),
--       pct_unknown NVARCHAR(50)
--   );
--
-- Everything below this line IS what was actually run, after
-- both tables existed via the import wizard.
--
-- Constraints are wrapped in IF NOT EXISTS checks so this script
-- is idempotent -- it can be run more than once (e.g. on a fresh
-- database, or by someone else reproducing this project) without
-- failing on "constraint already exists" errors.
-- ============================================================

-- Composite primary key: no single column uniquely identifies a
-- row (a trust appears once per date, a date applies to ~148
-- trusts) -- the combination of the two does.
IF NOT EXISTS (SELECT * FROM sys.key_constraints WHERE name = 'PK_handovers')
BEGIN
    ALTER TABLE handovers
    ADD CONSTRAINT PK_handovers PRIMARY KEY (trust_code, handover_date);
END;

-- Foreign key: every trust_code in handovers must exist in trusts.
-- Both constraints succeeding on first run (no errors) is itself
-- evidence the Python reshape produced clean, non-duplicated,
-- fully-referenced data -- if a duplicate or an orphaned trust
-- code existed, these statements would have failed immediately.
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_handovers_trusts')
BEGIN
    ALTER TABLE handovers
    ADD CONSTRAINT FK_handovers_trusts
        FOREIGN KEY (trust_code) REFERENCES trusts(trust_code);
END;

-- Validation: confirm no duplicate trust-day rows exist.
-- Expected result: 0 rows.
SELECT trust_code, handover_date, COUNT(*) AS row_count
FROM handovers
GROUP BY trust_code, handover_date
HAVING COUNT(*) > 1;

-- Validation: confirm no duplicate trust codes in the trusts table.
-- Expected result: 0 rows.
SELECT trust_code, COUNT(*) AS row_count
FROM trusts
GROUP BY trust_code
HAVING COUNT(*) > 1;
