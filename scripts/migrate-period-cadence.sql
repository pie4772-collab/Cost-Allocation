DO $$ BEGIN
  CREATE TYPE "PeriodCadence" AS ENUM ('SEMI_ANNUAL', 'MONTHLY');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE accounting_periods ADD COLUMN IF NOT EXISTS month INT;

UPDATE accounting_periods SET period_key = half WHERE period_key IS NULL;
UPDATE accounting_periods SET cadence = 'SEMI_ANNUAL' WHERE cadence IS NULL OR cadence = '';

ALTER TABLE accounting_periods ALTER COLUMN cadence DROP DEFAULT;
ALTER TABLE accounting_periods
  ALTER COLUMN cadence TYPE "PeriodCadence"
  USING cadence::"PeriodCadence";
ALTER TABLE accounting_periods ALTER COLUMN cadence SET DEFAULT 'SEMI_ANNUAL'::"PeriodCadence";
ALTER TABLE accounting_periods ALTER COLUMN cadence SET NOT NULL;

ALTER TABLE accounting_periods DROP CONSTRAINT IF EXISTS accounting_periods_year_half_key;
DROP INDEX IF EXISTS accounting_periods_year_cadence_period_key_key;
CREATE UNIQUE INDEX accounting_periods_year_cadence_period_key_key
  ON accounting_periods (year, cadence, period_key);
