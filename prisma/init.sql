-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "RoleName" AS ENUM ('Admin', 'CostManager', 'AllocationManager', 'Approver', 'BillingManager', 'Auditor', 'Viewer');

-- CreateEnum
CREATE TYPE "PeriodCadence" AS ENUM ('SEMI_ANNUAL', 'MONTHLY');

-- CreateEnum
CREATE TYPE "CompanyType" AS ENUM ('DOMESTIC', 'OVERSEAS');

-- CreateEnum
CREATE TYPE "BillingLanguage" AS ENUM ('KO', 'EN');

-- CreateEnum
CREATE TYPE "Currency" AS ENUM ('KRW', 'USD', 'EUR', 'JPY', 'CNY');

-- CreateEnum
CREATE TYPE "CostStatus" AS ENUM ('DRAFT', 'CONFIRMED', 'LOCKED');

-- CreateEnum
CREATE TYPE "ProjectStatus" AS ENUM ('DRAFT', 'COST_CONFIRMED', 'RATES_APPROVED', 'CALCULATED', 'RECONCILED', 'BILLING_APPROVED', 'CLOSED');

-- CreateEnum
CREATE TYPE "RateVersionStatus" AS ENUM ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'SUPERSEDED');

-- CreateEnum
CREATE TYPE "RunStatus" AS ENUM ('PREVIEW', 'EXECUTED', 'APPROVED', 'SUPERSEDED');

-- CreateEnum
CREATE TYPE "RunType" AS ENUM ('PREVIEW', 'FINAL');

-- CreateEnum
CREATE TYPE "InvoiceStatus" AS ENUM ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'ISSUED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "InvoiceType" AS ENUM ('DOMESTIC', 'OVERSEAS');

-- CreateEnum
CREATE TYPE "ApprovalType" AS ENUM ('COST_CONFIRMATION', 'RATE_APPROVAL', 'ALLOCATION_APPROVAL', 'INVOICE_APPROVAL', 'INVOICE_ISSUE');

-- CreateEnum
CREATE TYPE "ApprovalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "supabase_id" TEXT,
    "email" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "password_hash" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roles" (
    "id" TEXT NOT NULL,
    "name" "RoleName" NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_roles" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "role_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "companies" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name_ko" TEXT NOT NULL,
    "name_en" TEXT,
    "company_type" "CompanyType" NOT NULL,
    "billing_language" "BillingLanguage" NOT NULL DEFAULT 'KO',
    "currency" "Currency" NOT NULL DEFAULT 'KRW',
    "contact_email" TEXT,
    "contact_phone" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "deleted_at" TIMESTAMP(3),
    "created_by_id" TEXT,

    CONSTRAINT "companies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "company_addresses" (
    "id" TEXT NOT NULL,
    "company_id" TEXT NOT NULL,
    "address_type" TEXT NOT NULL DEFAULT 'BILLING',
    "line1" TEXT NOT NULL,
    "line2" TEXT,
    "city" TEXT,
    "state" TEXT,
    "postal_code" TEXT,
    "country" TEXT NOT NULL DEFAULT 'KR',
    "is_primary" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "company_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "accounting_periods" (
    "id" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "cadence" "PeriodCadence" NOT NULL DEFAULT 'SEMI_ANNUAL',
    "period_key" INTEGER NOT NULL,
    "half" INTEGER NOT NULL,
    "month" INTEGER,
    "label" TEXT NOT NULL,
    "start_date" TIMESTAMP(3) NOT NULL,
    "end_date" TIMESTAMP(3) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "accounting_periods_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cost_accounts" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name_ko" TEXT NOT NULL,
    "name_en" TEXT,
    "description" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "cost_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "monthly_costs" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "cost_account_id" TEXT NOT NULL,
    "month" INTEGER NOT NULL,
    "amount" BIGINT NOT NULL,
    "status" "CostStatus" NOT NULL DEFAULT 'DRAFT',
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_by_id" TEXT NOT NULL,

    CONSTRAINT "monthly_costs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "allocation_projects" (
    "id" TEXT NOT NULL,
    "period_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "status" "ProjectStatus" NOT NULL DEFAULT 'DRAFT',
    "markup_rate" DECIMAL(8,6) NOT NULL DEFAULT 0.05,
    "strict_rate_validation" BOOLEAN NOT NULL DEFAULT true,
    "version" INTEGER NOT NULL DEFAULT 1,
    "notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_by_id" TEXT NOT NULL,

    CONSTRAINT "allocation_projects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "allocation_rate_versions" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "status" "RateVersionStatus" NOT NULL DEFAULT 'DRAFT',
    "total_rate" DECIMAL(18,12) NOT NULL DEFAULT 0,
    "notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_by_id" TEXT NOT NULL,
    "approved_at" TIMESTAMP(3),

    CONSTRAINT "allocation_rate_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "allocation_rates" (
    "id" TEXT NOT NULL,
    "rate_version_id" TEXT NOT NULL,
    "company_id" TEXT NOT NULL,
    "rate" DECIMAL(18,12) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "allocation_rates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "allocation_runs" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "rate_version_id" TEXT NOT NULL,
    "run_number" INTEGER NOT NULL,
    "run_type" "RunType" NOT NULL,
    "status" "RunStatus" NOT NULL DEFAULT 'PREVIEW',
    "input_snapshot" JSONB NOT NULL,
    "checksum" TEXT NOT NULL,
    "total_cost" BIGINT NOT NULL,
    "total_allocated" BIGINT NOT NULL,
    "total_markup" BIGINT NOT NULL DEFAULT 0,
    "total_billing" BIGINT NOT NULL,
    "rounding_diff" BIGINT NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_by_id" TEXT NOT NULL,
    "approved_at" TIMESTAMP(3),

    CONSTRAINT "allocation_runs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "allocation_details" (
    "id" TEXT NOT NULL,
    "run_id" TEXT NOT NULL,
    "company_id" TEXT NOT NULL,
    "cost_account_id" TEXT NOT NULL,
    "account_total" BIGINT NOT NULL,
    "rate" DECIMAL(18,12) NOT NULL,
    "raw_amount" BIGINT NOT NULL,
    "allocated_amount" BIGINT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "allocation_details_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "company_allocation_summaries" (
    "id" TEXT NOT NULL,
    "run_id" TEXT NOT NULL,
    "company_id" TEXT NOT NULL,
    "pre_round_total" BIGINT NOT NULL,
    "allocation_amount" BIGINT NOT NULL,
    "markup_amount" BIGINT NOT NULL DEFAULT 0,
    "billing_amount" BIGINT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "company_allocation_summaries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "invoices" (
    "id" TEXT NOT NULL,
    "run_id" TEXT NOT NULL,
    "company_id" TEXT NOT NULL,
    "invoice_number" TEXT,
    "invoice_type" "InvoiceType" NOT NULL,
    "status" "InvoiceStatus" NOT NULL DEFAULT 'DRAFT',
    "issue_date" TIMESTAMP(3),
    "period_label" TEXT NOT NULL,
    "subtotal" BIGINT NOT NULL,
    "markup_amount" BIGINT NOT NULL DEFAULT 0,
    "total_amount" BIGINT NOT NULL,
    "billing_address" JSONB,
    "notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "invoices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "invoice_lines" (
    "id" TEXT NOT NULL,
    "invoice_id" TEXT NOT NULL,
    "line_number" INTEGER NOT NULL,
    "cost_account_id" TEXT,
    "description" TEXT NOT NULL,
    "amount" BIGINT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "invoice_lines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "approval_requests" (
    "id" TEXT NOT NULL,
    "type" "ApprovalType" NOT NULL,
    "status" "ApprovalStatus" NOT NULL DEFAULT 'PENDING',
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "requested_by" TEXT NOT NULL,
    "reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "approval_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "approval_actions" (
    "id" TEXT NOT NULL,
    "request_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "action" "ApprovalStatus" NOT NULL,
    "comment" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "approval_actions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reconciliation_results" (
    "id" TEXT NOT NULL,
    "run_id" TEXT NOT NULL,
    "total_source_cost" BIGINT NOT NULL,
    "total_account_allocated" BIGINT NOT NULL,
    "account_rounding_diff" BIGINT NOT NULL,
    "total_company_allocated" BIGINT NOT NULL,
    "company_rounding_diff" BIGINT NOT NULL,
    "total_markup" BIGINT NOT NULL,
    "total_billing" BIGINT NOT NULL,
    "is_balanced" BOOLEAN NOT NULL,
    "details" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reconciliation_results_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" TEXT NOT NULL,
    "user_id" TEXT,
    "action" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "before_data" JSONB,
    "after_data" JSONB,
    "reason" TEXT,
    "ip_address" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "system_settings" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "system_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attachments" (
    "id" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "file_name" TEXT NOT NULL,
    "file_path" TEXT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "file_size" INTEGER NOT NULL,
    "uploaded_by" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attachments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_supabase_id_key" ON "users"("supabase_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "roles_name_key" ON "roles"("name");

-- CreateIndex
CREATE UNIQUE INDEX "user_roles_user_id_role_id_key" ON "user_roles"("user_id", "role_id");

-- CreateIndex
CREATE UNIQUE INDEX "companies_code_key" ON "companies"("code");

-- CreateIndex
CREATE UNIQUE INDEX "accounting_periods_year_cadence_period_key_key" ON "accounting_periods"("year", "cadence", "period_key");

-- CreateIndex
CREATE UNIQUE INDEX "cost_accounts_code_key" ON "cost_accounts"("code");

-- CreateIndex
CREATE INDEX "monthly_costs_project_id_status_idx" ON "monthly_costs"("project_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "monthly_costs_project_id_cost_account_id_month_version_key" ON "monthly_costs"("project_id", "cost_account_id", "month", "version");

-- CreateIndex
CREATE UNIQUE INDEX "allocation_projects_period_id_version_key" ON "allocation_projects"("period_id", "version");

-- CreateIndex
CREATE UNIQUE INDEX "allocation_rate_versions_project_id_version_key" ON "allocation_rate_versions"("project_id", "version");

-- CreateIndex
CREATE UNIQUE INDEX "allocation_rates_rate_version_id_company_id_key" ON "allocation_rates"("rate_version_id", "company_id");

-- CreateIndex
CREATE INDEX "allocation_runs_project_id_status_idx" ON "allocation_runs"("project_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "allocation_runs_project_id_rate_version_id_run_number_key" ON "allocation_runs"("project_id", "rate_version_id", "run_number");

-- CreateIndex
CREATE UNIQUE INDEX "allocation_details_run_id_company_id_cost_account_id_key" ON "allocation_details"("run_id", "company_id", "cost_account_id");

-- CreateIndex
CREATE UNIQUE INDEX "company_allocation_summaries_run_id_company_id_key" ON "company_allocation_summaries"("run_id", "company_id");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_invoice_number_key" ON "invoices"("invoice_number");

-- CreateIndex
CREATE INDEX "invoices_status_idx" ON "invoices"("status");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_run_id_company_id_key" ON "invoices"("run_id", "company_id");

-- CreateIndex
CREATE UNIQUE INDEX "invoice_lines_invoice_id_line_number_key" ON "invoice_lines"("invoice_id", "line_number");

-- CreateIndex
CREATE INDEX "approval_requests_entity_type_entity_id_idx" ON "approval_requests"("entity_type", "entity_id");

-- CreateIndex
CREATE INDEX "approval_requests_status_idx" ON "approval_requests"("status");

-- CreateIndex
CREATE UNIQUE INDEX "reconciliation_results_run_id_key" ON "reconciliation_results"("run_id");

-- CreateIndex
CREATE INDEX "audit_logs_entity_type_entity_id_idx" ON "audit_logs"("entity_type", "entity_id");

-- CreateIndex
CREATE INDEX "audit_logs_user_id_idx" ON "audit_logs"("user_id");

-- CreateIndex
CREATE INDEX "audit_logs_created_at_idx" ON "audit_logs"("created_at");

-- CreateIndex
CREATE UNIQUE INDEX "system_settings_key_key" ON "system_settings"("key");

-- CreateIndex
CREATE INDEX "attachments_entity_type_entity_id_idx" ON "attachments"("entity_type", "entity_id");

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "company_addresses" ADD CONSTRAINT "company_addresses_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "companies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "monthly_costs" ADD CONSTRAINT "monthly_costs_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "allocation_projects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "monthly_costs" ADD CONSTRAINT "monthly_costs_cost_account_id_fkey" FOREIGN KEY ("cost_account_id") REFERENCES "cost_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "monthly_costs" ADD CONSTRAINT "monthly_costs_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_projects" ADD CONSTRAINT "allocation_projects_period_id_fkey" FOREIGN KEY ("period_id") REFERENCES "accounting_periods"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_projects" ADD CONSTRAINT "allocation_projects_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_rate_versions" ADD CONSTRAINT "allocation_rate_versions_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "allocation_projects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_rate_versions" ADD CONSTRAINT "allocation_rate_versions_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_rates" ADD CONSTRAINT "allocation_rates_rate_version_id_fkey" FOREIGN KEY ("rate_version_id") REFERENCES "allocation_rate_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_rates" ADD CONSTRAINT "allocation_rates_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "companies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_runs" ADD CONSTRAINT "allocation_runs_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "allocation_projects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_runs" ADD CONSTRAINT "allocation_runs_rate_version_id_fkey" FOREIGN KEY ("rate_version_id") REFERENCES "allocation_rate_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_runs" ADD CONSTRAINT "allocation_runs_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_details" ADD CONSTRAINT "allocation_details_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "allocation_runs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_details" ADD CONSTRAINT "allocation_details_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "companies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "allocation_details" ADD CONSTRAINT "allocation_details_cost_account_id_fkey" FOREIGN KEY ("cost_account_id") REFERENCES "cost_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "company_allocation_summaries" ADD CONSTRAINT "company_allocation_summaries_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "allocation_runs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "company_allocation_summaries" ADD CONSTRAINT "company_allocation_summaries_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "companies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "allocation_runs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "companies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoice_lines" ADD CONSTRAINT "invoice_lines_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "invoices"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "approval_actions" ADD CONSTRAINT "approval_actions_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "approval_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "approval_actions" ADD CONSTRAINT "approval_actions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reconciliation_results" ADD CONSTRAINT "reconciliation_results_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "allocation_runs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
