--
-- PostgreSQL database dump
--

\restrict Wb1oWT0QR8NITaXtpuNgNrvLOASt39s9DAfXlGhg4FdaOqryXgWVratoTqe3Bde

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: ApprovalStatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."ApprovalStatus" AS ENUM (
    'PENDING',
    'APPROVED',
    'REJECTED',
    'CANCELLED'
);


--
-- Name: ApprovalType; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."ApprovalType" AS ENUM (
    'COST_CONFIRMATION',
    'RATE_APPROVAL',
    'ALLOCATION_APPROVAL',
    'INVOICE_APPROVAL',
    'INVOICE_ISSUE'
);


--
-- Name: BillingLanguage; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."BillingLanguage" AS ENUM (
    'KO',
    'EN'
);


--
-- Name: CompanyType; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."CompanyType" AS ENUM (
    'DOMESTIC',
    'OVERSEAS'
);


--
-- Name: CostStatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."CostStatus" AS ENUM (
    'DRAFT',
    'CONFIRMED',
    'LOCKED'
);


--
-- Name: Currency; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."Currency" AS ENUM (
    'KRW',
    'USD',
    'EUR',
    'JPY',
    'CNY'
);


--
-- Name: InvoiceStatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."InvoiceStatus" AS ENUM (
    'DRAFT',
    'PENDING_APPROVAL',
    'APPROVED',
    'ISSUED',
    'CANCELLED'
);


--
-- Name: InvoiceType; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."InvoiceType" AS ENUM (
    'DOMESTIC',
    'OVERSEAS'
);


--
-- Name: ProjectStatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."ProjectStatus" AS ENUM (
    'DRAFT',
    'COST_CONFIRMED',
    'RATES_APPROVED',
    'CALCULATED',
    'RECONCILED',
    'BILLING_APPROVED',
    'CLOSED'
);


--
-- Name: RateVersionStatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."RateVersionStatus" AS ENUM (
    'DRAFT',
    'PENDING_APPROVAL',
    'APPROVED',
    'REJECTED',
    'SUPERSEDED'
);


--
-- Name: RoleName; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."RoleName" AS ENUM (
    'Admin',
    'CostManager',
    'AllocationManager',
    'Approver',
    'BillingManager',
    'Auditor',
    'Viewer'
);


--
-- Name: RunStatus; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."RunStatus" AS ENUM (
    'PREVIEW',
    'EXECUTED',
    'APPROVED',
    'SUPERSEDED'
);


--
-- Name: RunType; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."RunType" AS ENUM (
    'PREVIEW',
    'FINAL'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounting_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounting_periods (
    id text NOT NULL,
    year integer NOT NULL,
    half integer NOT NULL,
    label text NOT NULL,
    start_date timestamp(3) without time zone NOT NULL,
    end_date timestamp(3) without time zone NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


--
-- Name: allocation_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation_details (
    id text NOT NULL,
    run_id text NOT NULL,
    company_id text NOT NULL,
    cost_account_id text NOT NULL,
    account_total bigint NOT NULL,
    rate numeric(18,12) NOT NULL,
    raw_amount bigint NOT NULL,
    allocated_amount bigint NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: allocation_projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation_projects (
    id text NOT NULL,
    period_id text NOT NULL,
    name text NOT NULL,
    status public."ProjectStatus" DEFAULT 'DRAFT'::public."ProjectStatus" NOT NULL,
    markup_rate numeric(8,6) DEFAULT 0.05 NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    notes text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    created_by_id text NOT NULL,
    strict_rate_validation boolean DEFAULT true NOT NULL
);


--
-- Name: allocation_rate_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation_rate_versions (
    id text NOT NULL,
    project_id text NOT NULL,
    version integer NOT NULL,
    status public."RateVersionStatus" DEFAULT 'DRAFT'::public."RateVersionStatus" NOT NULL,
    total_rate numeric(18,12) DEFAULT 0 NOT NULL,
    notes text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    created_by_id text NOT NULL,
    approved_at timestamp(3) without time zone
);


--
-- Name: allocation_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation_rates (
    id text NOT NULL,
    rate_version_id text NOT NULL,
    company_id text NOT NULL,
    rate numeric(18,12) NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


--
-- Name: allocation_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation_runs (
    id text NOT NULL,
    project_id text NOT NULL,
    rate_version_id text NOT NULL,
    run_number integer NOT NULL,
    run_type public."RunType" NOT NULL,
    status public."RunStatus" DEFAULT 'PREVIEW'::public."RunStatus" NOT NULL,
    input_snapshot jsonb NOT NULL,
    checksum text NOT NULL,
    total_cost bigint NOT NULL,
    total_allocated bigint NOT NULL,
    total_markup bigint DEFAULT 0 NOT NULL,
    total_billing bigint NOT NULL,
    rounding_diff bigint DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    created_by_id text NOT NULL,
    approved_at timestamp(3) without time zone
);


--
-- Name: approval_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_actions (
    id text NOT NULL,
    request_id text NOT NULL,
    user_id text NOT NULL,
    action public."ApprovalStatus" NOT NULL,
    comment text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: approval_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_requests (
    id text NOT NULL,
    type public."ApprovalType" NOT NULL,
    status public."ApprovalStatus" DEFAULT 'PENDING'::public."ApprovalStatus" NOT NULL,
    entity_type text NOT NULL,
    entity_id text NOT NULL,
    requested_by text NOT NULL,
    reason text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


--
-- Name: attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachments (
    id text NOT NULL,
    entity_type text NOT NULL,
    entity_id text NOT NULL,
    file_name text NOT NULL,
    file_path text NOT NULL,
    mime_type text NOT NULL,
    file_size integer NOT NULL,
    uploaded_by text NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id text NOT NULL,
    user_id text,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id text NOT NULL,
    before_data jsonb,
    after_data jsonb,
    reason text,
    ip_address text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id text NOT NULL,
    code text NOT NULL,
    name_ko text NOT NULL,
    name_en text,
    company_type public."CompanyType" NOT NULL,
    billing_language public."BillingLanguage" DEFAULT 'KO'::public."BillingLanguage" NOT NULL,
    currency public."Currency" DEFAULT 'KRW'::public."Currency" NOT NULL,
    contact_email text,
    contact_phone text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    deleted_at timestamp(3) without time zone,
    created_by_id text
);


--
-- Name: company_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_addresses (
    id text NOT NULL,
    company_id text NOT NULL,
    address_type text DEFAULT 'BILLING'::text NOT NULL,
    line1 text NOT NULL,
    line2 text,
    city text,
    state text,
    postal_code text,
    country text DEFAULT 'KR'::text NOT NULL,
    is_primary boolean DEFAULT true NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    deleted_at timestamp(3) without time zone
);


--
-- Name: company_allocation_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_allocation_summaries (
    id text NOT NULL,
    run_id text NOT NULL,
    company_id text NOT NULL,
    pre_round_total bigint NOT NULL,
    allocation_amount bigint NOT NULL,
    markup_amount bigint DEFAULT 0 NOT NULL,
    billing_amount bigint NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: cost_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_accounts (
    id text NOT NULL,
    code text NOT NULL,
    name_ko text NOT NULL,
    name_en text,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    deleted_at timestamp(3) without time zone
);


--
-- Name: invoice_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_lines (
    id text NOT NULL,
    invoice_id text NOT NULL,
    line_number integer NOT NULL,
    cost_account_id text,
    description text NOT NULL,
    amount bigint NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices (
    id text NOT NULL,
    run_id text NOT NULL,
    company_id text NOT NULL,
    invoice_number text,
    invoice_type public."InvoiceType" NOT NULL,
    status public."InvoiceStatus" DEFAULT 'DRAFT'::public."InvoiceStatus" NOT NULL,
    issue_date timestamp(3) without time zone,
    period_label text NOT NULL,
    subtotal bigint NOT NULL,
    markup_amount bigint DEFAULT 0 NOT NULL,
    total_amount bigint NOT NULL,
    billing_address jsonb,
    notes text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


--
-- Name: monthly_costs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.monthly_costs (
    id text NOT NULL,
    project_id text NOT NULL,
    cost_account_id text NOT NULL,
    month integer NOT NULL,
    amount bigint NOT NULL,
    status public."CostStatus" DEFAULT 'DRAFT'::public."CostStatus" NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    created_by_id text NOT NULL
);


--
-- Name: reconciliation_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reconciliation_results (
    id text NOT NULL,
    run_id text NOT NULL,
    total_source_cost bigint NOT NULL,
    total_account_allocated bigint NOT NULL,
    account_rounding_diff bigint NOT NULL,
    total_company_allocated bigint NOT NULL,
    company_rounding_diff bigint NOT NULL,
    total_markup bigint NOT NULL,
    total_billing bigint NOT NULL,
    is_balanced boolean NOT NULL,
    details jsonb NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id text NOT NULL,
    name public."RoleName" NOT NULL,
    description text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


--
-- Name: system_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_settings (
    id text NOT NULL,
    key text NOT NULL,
    value jsonb NOT NULL,
    description text,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    id text NOT NULL,
    user_id text NOT NULL,
    role_id text NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id text NOT NULL,
    supabase_id text,
    email text NOT NULL,
    name text NOT NULL,
    password_hash text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(3) without time zone NOT NULL,
    deleted_at timestamp(3) without time zone
);


--
-- Data for Name: accounting_periods; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.accounting_periods (id, year, half, label, start_date, end_date, is_active, created_at, updated_at) FROM stdin;
cmsgzh2zn000sv4z4v8577cif	2026	1	2026 H1	2026-01-01 00:00:00	2026-06-30 00:00:00	t	2026-08-06 03:55:57.923	2026-08-06 03:55:57.923
cmsh91g710000v4eskignzoni	2026	2	2026 H2	2026-07-01 00:00:00	2026-12-31 00:00:00	t	2026-08-06 08:23:44.701	2026-08-06 08:23:44.701
\.


--
-- Data for Name: allocation_details; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allocation_details (id, run_id, company_id, cost_account_id, account_total, rate, raw_amount, allocated_amount, created_at) FROM stdin;
cmsh7rith000bv4jw6ulpkrkm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b44c000hv45k8wyhshmu	0	0.255216617841	0	0	2026-08-06 07:48:01.912
cmsh7rith000cv4jwxmkovyxm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b44c000hv45k8wyhshmu	0	0.168145164377	0	0	2026-08-06 07:48:01.912
cmsh7rith000dv4jwh7ku8akm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b44c000hv45k8wyhshmu	0	0.095133111848	0	0	2026-08-06 07:48:01.912
cmsh7rith000ev4jwggffqp6s	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b44c000hv45k8wyhshmu	0	0.092682384743	0	0	2026-08-06 07:48:01.912
cmsh7rith000fv4jwri7422ie	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b44c000hv45k8wyhshmu	0	0.065256623277	0	0	2026-08-06 07:48:01.912
cmsh7rith000gv4jw6098bu4n	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b44c000hv45k8wyhshmu	0	0.060440002174	0	0	2026-08-06 07:48:01.912
cmsh7rith000hv4jw1huve9gr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b44c000hv45k8wyhshmu	0	0.028480772188	0	0	2026-08-06 07:48:01.912
cmsh7rith000iv4jwvvobhcx8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b44c000hv45k8wyhshmu	0	0.018465317230	0	0	2026-08-06 07:48:01.912
cmsh7rith000jv4jw41hz2v7p	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b44c000hv45k8wyhshmu	0	0.010234682770	0	0	2026-08-06 07:48:01.912
cmsh7rith000kv4jwvrc1zglm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b44c000hv45k8wyhshmu	0	0.028000272513	0	0	2026-08-06 07:48:01.912
cmsh7rith000lv4jwnr84k3bg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b44c000hv45k8wyhshmu	0	0.021882741181	0	0	2026-08-06 07:48:01.912
cmsh7rith000mv4jw1cc5smlv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b44c000hv45k8wyhshmu	0	0.020472951919	0	0	2026-08-06 07:48:01.912
cmsh7rith000nv4jw299evo8s	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b44c000hv45k8wyhshmu	0	0.019004825906	0	0	2026-08-06 07:48:01.912
cmsh7rith000ov4jw0n5qmivm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b44c000hv45k8wyhshmu	0	0.018298386399	0	0	2026-08-06 07:48:01.912
cmsh7rith000pv4jw64aly3lg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b44c000hv45k8wyhshmu	0	0.018139007098	0	0	2026-08-06 07:48:01.912
cmsh7rith000qv4jwlnzrtl8f	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b44c000hv45k8wyhshmu	0	0.017495463866	0	0	2026-08-06 07:48:01.912
cmsh7rith000rv4jwworffx0p	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b44c000hv45k8wyhshmu	0	0.016459215942	0	0	2026-08-06 07:48:01.912
cmsh7rith000sv4jwacvkan37	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b44c000hv45k8wyhshmu	0	0.011937806535	0	0	2026-08-06 07:48:01.912
cmsh7rith000tv4jwp734t6u6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b44c000hv45k8wyhshmu	0	0.008904380842	0	0	2026-08-06 07:48:01.912
cmsh7rith000uv4jwcnshfc8j	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b44c000hv45k8wyhshmu	0	0.006540173219	0	0	2026-08-06 07:48:01.912
cmsh7rith000vv4jwmy0sm7wn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b44c000hv45k8wyhshmu	0	0.003071908585	0	0	2026-08-06 07:48:01.912
cmsh7rith000wv4jwxw6rn6qy	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b44c000hv45k8wyhshmu	0	0.002740509916	0	0	2026-08-06 07:48:01.912
cmsh7riti000xv4jwgn14o4du	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b44c000hv45k8wyhshmu	0	0.002668665919	0	0	2026-08-06 07:48:01.912
cmsh7riti000yv4jwt4s12cie	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b44c000hv45k8wyhshmu	0	0.002403775653	0	0	2026-08-06 07:48:01.912
cmsh7riti000zv4jwg8a56lae	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b44c000hv45k8wyhshmu	0	0.002262265810	0	0	2026-08-06 07:48:01.912
cmsh7riti0010v4jwefsshk0s	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b44c000hv45k8wyhshmu	0	0.002047089677	0	0	2026-08-06 07:48:01.912
cmsh7riti0011v4jw5y6cscb2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b44c000hv45k8wyhshmu	0	0.001657893126	0	0	2026-08-06 07:48:01.912
cmsh7riti0012v4jwenzrv4bo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b44c000hv45k8wyhshmu	0	0.000793320088	0	0	2026-08-06 07:48:01.912
cmsh7riti0013v4jwrzlu83tr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b44c000hv45k8wyhshmu	0	0.000782975587	0	0	2026-08-06 07:48:01.912
cmsh7riti0014v4jwsq0u3czz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b44c000hv45k8wyhshmu	0	0.000397144122	0	0	2026-08-06 07:48:01.912
cmsh7riti0015v4jwmjphfwq7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.255216617841	671735	671734	2026-08-06 07:48:01.912
cmsh7riti0016v4jwfaaaqsij	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.168145164377	442561	442561	2026-08-06 07:48:01.912
cmsh7riti0017v4jwz628a0up	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.095133111848	250392	250392	2026-08-06 07:48:01.912
cmsh7riti0018v4jwq19eu9kn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.092682384743	243942	243941	2026-08-06 07:48:01.912
cmsh7riti0019v4jwrfqol96f	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.065256623277	171757	171756	2026-08-06 07:48:01.912
cmsh7riti001av4jwexrzjuk5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.060440002174	159079	159079	2026-08-06 07:48:01.912
cmsh7riti001bv4jwauqtlid8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.028480772188	74962	74961	2026-08-06 07:48:01.912
cmsh7riti001cv4jwkeyzlatw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.018465317230	48601	48601	2026-08-06 07:48:01.912
cmsh7riti001dv4jwntjyq9l9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.010234682770	26938	26937	2026-08-06 07:48:01.912
cmsh7riti001ev4jwmqk8l8ey	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.028000272513	73697	73697	2026-08-06 07:48:01.912
cmsh7riti001fv4jwzy1gbhnz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.021882741181	57596	57595	2026-08-06 07:48:01.912
cmsh7riti001gv4jwljx60ost	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.020472951919	53885	53885	2026-08-06 07:48:01.912
cmsh7riti001hv4jw30laa5l3	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.019004825906	50021	50021	2026-08-06 07:48:01.912
cmsh7riti001iv4jw2zx7pclh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.018298386399	48162	48161	2026-08-06 07:48:01.912
cmsh7riti001jv4jw8p7uu0ld	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.018139007098	47742	47742	2026-08-06 07:48:01.912
cmsh7riti001kv4jwlgy6db5y	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.017495463866	46048	46048	2026-08-06 07:48:01.912
cmsh7riti001lv4jw6k555u6h	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.016459215942	43321	43320	2026-08-06 07:48:01.912
cmsh7riti001mv4jw037p9p91	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.011937806535	31421	31420	2026-08-06 07:48:01.912
cmsh7riti001nv4jw412hchwb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.008904380842	23436	23436	2026-08-06 07:48:01.912
cmsh7riti001ov4jw1wb22gwy	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.006540173219	17214	17213	2026-08-06 07:48:01.912
cmsh7riti001pv4jw1fgq8rih	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.003071908585	8085	8085	2026-08-06 07:48:01.912
cmsh7riti001qv4jweff6qa1l	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.002740509916	7213	7213	2026-08-06 07:48:01.912
cmsh7riti001rv4jwulrdl6y0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.002668665919	7024	7023	2026-08-06 07:48:01.912
cmsh7riti001sv4jwz0u3qykq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.002403775653	6327	6326	2026-08-06 07:48:01.912
cmsh7riti001tv4jw8q3pl2qa	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.002262265810	5954	5954	2026-08-06 07:48:01.912
cmsh7riti001uv4jwt513uwnw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.002047089677	5388	5387	2026-08-06 07:48:01.912
cmsh7riti001vv4jwpa0kaq1j	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.001657893126	4364	4363	2026-08-06 07:48:01.912
cmsh7riti001wv4jw2t9kbjab	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.000793320088	2088	2088	2026-08-06 07:48:01.912
cmsh7riti001xv4jw5f1c7b78	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.000782975587	2061	2060	2026-08-06 07:48:01.912
cmsh7riti001yv4jwt45ki5fv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3v5000bv45kkg5k7jdr	2632018	0.000397144122	1045	1045	2026-08-06 07:48:01.912
cmsh7riti001zv4jwxypd7rsf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3tj000av45kp4w6n24d	6211549	0.255216617841	1585291	1585290	2026-08-06 07:48:01.912
cmsh7riti0020v4jwshe2ax8y	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3tj000av45kp4w6n24d	6211549	0.168145164377	1044442	1044441	2026-08-06 07:48:01.912
cmsh7riti0021v4jw53dnrfh5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3tj000av45kp4w6n24d	6211549	0.095133111848	590924	590923	2026-08-06 07:48:01.912
cmsh7riti0022v4jwwca7lzc4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3tj000av45kp4w6n24d	6211549	0.092682384743	575701	575701	2026-08-06 07:48:01.912
cmsh7riti0023v4jws6sf473x	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3tj000av45kp4w6n24d	6211549	0.065256623277	405345	405344	2026-08-06 07:48:01.912
cmsh7riti0024v4jw0z10kx6n	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3tj000av45kp4w6n24d	6211549	0.060440002174	375426	375426	2026-08-06 07:48:01.912
cmsh7riti0025v4jweoxqdpxo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3tj000av45kp4w6n24d	6211549	0.028480772188	176910	176909	2026-08-06 07:48:01.912
cmsh7riti0026v4jwmfgv1ha6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3tj000av45kp4w6n24d	6211549	0.018465317230	114698	114698	2026-08-06 07:48:01.912
cmsh7riti0027v4jw3pac0hkr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3tj000av45kp4w6n24d	6211549	0.010234682770	63573	63573	2026-08-06 07:48:01.912
cmsh7riti0028v4jw2tsn1hl2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3tj000av45kp4w6n24d	6211549	0.028000272513	173925	173925	2026-08-06 07:48:01.912
cmsh7riti0029v4jwmaj5o9fw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3tj000av45kp4w6n24d	6211549	0.021882741181	135926	135925	2026-08-06 07:48:01.912
cmsh7riti002av4jwt3ujmkz8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3tj000av45kp4w6n24d	6211549	0.020472951919	127169	127168	2026-08-06 07:48:01.912
cmsh7riti002bv4jwy4r4otsy	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3tj000av45kp4w6n24d	6211549	0.019004825906	118049	118049	2026-08-06 07:48:01.912
cmsh7riti002cv4jw8av518tv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3tj000av45kp4w6n24d	6211549	0.018298386399	113661	113661	2026-08-06 07:48:01.912
cmsh7ritj002dv4jw38324xjh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3tj000av45kp4w6n24d	6211549	0.018139007098	112671	112671	2026-08-06 07:48:01.912
cmsh7ritj002ev4jwls8rv61y	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3tj000av45kp4w6n24d	6211549	0.017495463866	108674	108673	2026-08-06 07:48:01.912
cmsh7ritj002fv4jw9rf6yju6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3tj000av45kp4w6n24d	6211549	0.016459215942	102237	102237	2026-08-06 07:48:01.912
cmsh7ritj002gv4jwq3mnizei	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3tj000av45kp4w6n24d	6211549	0.011937806535	74152	74152	2026-08-06 07:48:01.912
cmsh7ritj002hv4jwoz3isi3k	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3tj000av45kp4w6n24d	6211549	0.008904380842	55310	55309	2026-08-06 07:48:01.912
cmsh7ritj002iv4jwciwwg8v2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3tj000av45kp4w6n24d	6211549	0.006540173219	40625	40624	2026-08-06 07:48:01.912
cmsh7ritj002jv4jw3yv10org	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3tj000av45kp4w6n24d	6211549	0.003071908585	19081	19081	2026-08-06 07:48:01.912
cmsh7ritj002kv4jwc5riw1hj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3tj000av45kp4w6n24d	6211549	0.002740509916	17023	17022	2026-08-06 07:48:01.912
cmsh7ritj002lv4jwjashgvnm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3tj000av45kp4w6n24d	6211549	0.002668665919	16577	16576	2026-08-06 07:48:01.912
cmsh7ritj002mv4jwnsfdf1mh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3tj000av45kp4w6n24d	6211549	0.002403775653	14931	14931	2026-08-06 07:48:01.912
cmsh7ritj002nv4jwenigeb5l	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3tj000av45kp4w6n24d	6211549	0.002262265810	14052	14052	2026-08-06 07:48:01.912
cmsh7ritj002ov4jwh1symmzw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3tj000av45kp4w6n24d	6211549	0.002047089677	12716	12715	2026-08-06 07:48:01.912
cmsh7ritj002pv4jwlct0l659	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3tj000av45kp4w6n24d	6211549	0.001657893126	10298	10298	2026-08-06 07:48:01.912
cmsh7ritj002qv4jwvm1sm38p	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3tj000av45kp4w6n24d	6211549	0.000793320088	4928	4927	2026-08-06 07:48:01.912
cmsh7ritj002rv4jw1h8oj6bg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3tj000av45kp4w6n24d	6211549	0.000782975587	4863	4863	2026-08-06 07:48:01.912
cmsh7ritj002sv4jwt9kj2qdc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3tj000av45kp4w6n24d	6211549	0.000397144122	2467	2466	2026-08-06 07:48:01.912
cmsh7ritj002tv4jwaou4uayh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b41f000fv45k4qgcw4ac	697726	0.255216617841	178071	178071	2026-08-06 07:48:01.912
cmsh7ritj002uv4jwwrp8q9ya	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b41f000fv45k4qgcw4ac	697726	0.168145164377	117319	117319	2026-08-06 07:48:01.912
cmsh7ritj002vv4jw8g37c36g	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b41f000fv45k4qgcw4ac	697726	0.095133111848	66377	66376	2026-08-06 07:48:01.912
cmsh7ritj002wv4jwlpg254tg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b41f000fv45k4qgcw4ac	697726	0.092682384743	64667	64666	2026-08-06 07:48:01.912
cmsh7ritj002xv4jwvxpszkxm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b41f000fv45k4qgcw4ac	697726	0.065256623277	45531	45531	2026-08-06 07:48:01.912
cmsh7ritj002yv4jwbfo59wpi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b41f000fv45k4qgcw4ac	697726	0.060440002174	42171	42170	2026-08-06 07:48:01.912
cmsh7ritj002zv4jwzyztzj2a	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b41f000fv45k4qgcw4ac	697726	0.028480772188	19872	19871	2026-08-06 07:48:01.912
cmsh7ritj0030v4jw30fksxqo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b41f000fv45k4qgcw4ac	697726	0.018465317230	12884	12883	2026-08-06 07:48:01.912
cmsh7ritj0031v4jw52bguex7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b41f000fv45k4qgcw4ac	697726	0.010234682770	7141	7141	2026-08-06 07:48:01.912
cmsh7ritj0032v4jwpqjcazpf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b41f000fv45k4qgcw4ac	697726	0.028000272513	19537	19536	2026-08-06 07:48:01.912
cmsh7ritj0033v4jwhufieyb4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b41f000fv45k4qgcw4ac	697726	0.021882741181	15268	15268	2026-08-06 07:48:01.912
cmsh7ritj0034v4jwcwcy7hji	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b41f000fv45k4qgcw4ac	697726	0.020472951919	14285	14284	2026-08-06 07:48:01.912
cmsh7ritj0035v4jwd6cj05z4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b41f000fv45k4qgcw4ac	697726	0.019004825906	13260	13260	2026-08-06 07:48:01.912
cmsh7ritj0036v4jw4jhpvn3j	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b41f000fv45k4qgcw4ac	697726	0.018298386399	12767	12767	2026-08-06 07:48:01.912
cmsh7ritj0037v4jwgrwn1wz6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b41f000fv45k4qgcw4ac	697726	0.018139007098	12656	12656	2026-08-06 07:48:01.912
cmsh7ritj0038v4jwrngh66mj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b41f000fv45k4qgcw4ac	697726	0.017495463866	12207	12207	2026-08-06 07:48:01.912
cmsh7ritj0039v4jwg107yip4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b41f000fv45k4qgcw4ac	697726	0.016459215942	11484	11484	2026-08-06 07:48:01.912
cmsh7ritj003av4jwff1xr8vn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b41f000fv45k4qgcw4ac	697726	0.011937806535	8329	8329	2026-08-06 07:48:01.912
cmsh7ritj003bv4jw7iph7lr0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b41f000fv45k4qgcw4ac	697726	0.008904380842	6213	6212	2026-08-06 07:48:01.912
cmsh7ritj003cv4jwy51zgy0e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b41f000fv45k4qgcw4ac	697726	0.006540173219	4563	4563	2026-08-06 07:48:01.912
cmsh7ritj003dv4jw757dpvqm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b41f000fv45k4qgcw4ac	697726	0.003071908585	2143	2143	2026-08-06 07:48:01.912
cmsh7ritj003ev4jwl1kwxtvj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b41f000fv45k4qgcw4ac	697726	0.002740509916	1912	1912	2026-08-06 07:48:01.912
cmsh7ritj003fv4jw1ttrwgly	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b41f000fv45k4qgcw4ac	697726	0.002668665919	1862	1861	2026-08-06 07:48:01.912
cmsh7ritj003gv4jwj23g9xeh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b41f000fv45k4qgcw4ac	697726	0.002403775653	1677	1677	2026-08-06 07:48:01.912
cmsh7ritj003hv4jwuvyevhuv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b41f000fv45k4qgcw4ac	697726	0.002262265810	1578	1578	2026-08-06 07:48:01.912
cmsh7ritj003iv4jw9pkzljxw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b41f000fv45k4qgcw4ac	697726	0.002047089677	1428	1428	2026-08-06 07:48:01.912
cmsh7ritj003jv4jwuf0536k2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b41f000fv45k4qgcw4ac	697726	0.001657893126	1157	1156	2026-08-06 07:48:01.912
cmsh7ritj003kv4jw63h0123d	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b41f000fv45k4qgcw4ac	697726	0.000793320088	554	553	2026-08-06 07:48:01.912
cmsh7ritj003lv4jwxr9e182e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b41f000fv45k4qgcw4ac	697726	0.000782975587	546	546	2026-08-06 07:48:01.912
cmsh7ritj003mv4jw0vpr1b2l	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b41f000fv45k4qgcw4ac	697726	0.000397144122	277	277	2026-08-06 07:48:01.912
cmsh7ritj003nv4jwvpc8gol6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b45p000iv45krmpx8fmv	376200	0.255216617841	96012	96012	2026-08-06 07:48:01.912
cmsh7ritj003ov4jwi3pn1god	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b45p000iv45krmpx8fmv	376200	0.168145164377	63256	63256	2026-08-06 07:48:01.912
cmsh7ritj003pv4jw37aq04xg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b45p000iv45krmpx8fmv	376200	0.095133111848	35789	35789	2026-08-06 07:48:01.912
cmsh7ritj003qv4jwn6eut17z	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b45p000iv45krmpx8fmv	376200	0.092682384743	34867	34867	2026-08-06 07:48:01.912
cmsh7ritj003rv4jwj6vieiyy	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b45p000iv45krmpx8fmv	376200	0.065256623277	24550	24549	2026-08-06 07:48:01.912
cmsh7ritj003sv4jwycs54d98	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b45p000iv45krmpx8fmv	376200	0.060440002174	22738	22737	2026-08-06 07:48:01.912
cmsh7ritj003tv4jwz7ovvdaj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b45p000iv45krmpx8fmv	376200	0.028480772188	10714	10714	2026-08-06 07:48:01.912
cmsh7ritj003uv4jwi7foi2by	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b45p000iv45krmpx8fmv	376200	0.018465317230	6947	6946	2026-08-06 07:48:01.912
cmsh7ritj003vv4jw9eenhk8o	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b45p000iv45krmpx8fmv	376200	0.010234682770	3850	3850	2026-08-06 07:48:01.912
cmsh7ritj003wv4jwigmqmv5b	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b45p000iv45krmpx8fmv	376200	0.028000272513	10534	10533	2026-08-06 07:48:01.912
cmsh7ritj003xv4jwkg1qvd8h	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b45p000iv45krmpx8fmv	376200	0.021882741181	8232	8232	2026-08-06 07:48:01.912
cmsh7ritj003yv4jwhyvf60nm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b45p000iv45krmpx8fmv	376200	0.020472951919	7702	7701	2026-08-06 07:48:01.912
cmsh7ritj003zv4jw4c4faegh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b45p000iv45krmpx8fmv	376200	0.019004825906	7150	7149	2026-08-06 07:48:01.912
cmsh7ritj0040v4jwwhsfjpcj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b45p000iv45krmpx8fmv	376200	0.018298386399	6884	6883	2026-08-06 07:48:01.912
cmsh7ritj0041v4jw1lx4mwir	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b45p000iv45krmpx8fmv	376200	0.018139007098	6824	6823	2026-08-06 07:48:01.912
cmsh7ritj0042v4jwxqaef7vr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b45p000iv45krmpx8fmv	376200	0.017495463866	6582	6581	2026-08-06 07:48:01.912
cmsh7ritj0043v4jw7517ebso	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b45p000iv45krmpx8fmv	376200	0.016459215942	6192	6191	2026-08-06 07:48:01.912
cmsh7ritj0044v4jw0lu6qk5s	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b45p000iv45krmpx8fmv	376200	0.011937806535	4491	4491	2026-08-06 07:48:01.912
cmsh7ritk0045v4jwz0dcrtff	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b45p000iv45krmpx8fmv	376200	0.008904380842	3350	3349	2026-08-06 07:48:01.912
cmsh7ritk0046v4jwcbvgw6ii	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b45p000iv45krmpx8fmv	376200	0.006540173219	2460	2460	2026-08-06 07:48:01.912
cmsh7ritk0047v4jwi9bjfu3l	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b45p000iv45krmpx8fmv	376200	0.003071908585	1156	1155	2026-08-06 07:48:01.912
cmsh7ritk0048v4jwwjw5o08s	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b45p000iv45krmpx8fmv	376200	0.002740509916	1031	1030	2026-08-06 07:48:01.912
cmsh7ritk0049v4jwfauldma6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b45p000iv45krmpx8fmv	376200	0.002668665919	1004	1003	2026-08-06 07:48:01.912
cmsh7ritk004av4jw5blqbuek	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b45p000iv45krmpx8fmv	376200	0.002403775653	904	904	2026-08-06 07:48:01.912
cmsh7ritk004bv4jwlaryu6qz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b45p000iv45krmpx8fmv	376200	0.002262265810	851	851	2026-08-06 07:48:01.912
cmsh7ritk004cv4jwfg83vlt1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b45p000iv45krmpx8fmv	376200	0.002047089677	770	770	2026-08-06 07:48:01.912
cmsh7ritk004dv4jwzdizh576	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b45p000iv45krmpx8fmv	376200	0.001657893126	624	623	2026-08-06 07:48:01.912
cmsh7ritk004ev4jwn3gnmgp6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b45p000iv45krmpx8fmv	376200	0.000793320088	298	298	2026-08-06 07:48:01.912
cmsh7ritk004fv4jwja6q30xi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b45p000iv45krmpx8fmv	376200	0.000782975587	295	294	2026-08-06 07:48:01.912
cmsh7ritk004gv4jwbriiwqk9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b45p000iv45krmpx8fmv	376200	0.000397144122	149	149	2026-08-06 07:48:01.912
cmsh7ritk004hv4jw2xeafs6h	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3y6000dv45k9tvmq64r	15750	0.255216617841	4020	4019	2026-08-06 07:48:01.912
cmsh7ritk004iv4jw36pll5tr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3y6000dv45k9tvmq64r	15750	0.168145164377	2648	2648	2026-08-06 07:48:01.912
cmsh7ritk004jv4jw0egoruh8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3y6000dv45k9tvmq64r	15750	0.095133111848	1498	1498	2026-08-06 07:48:01.912
cmsh7ritk004kv4jw1o2yhblp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3y6000dv45k9tvmq64r	15750	0.092682384743	1460	1459	2026-08-06 07:48:01.912
cmsh7ritk004lv4jwaumn6abp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3y6000dv45k9tvmq64r	15750	0.065256623277	1028	1027	2026-08-06 07:48:01.912
cmsh7ritk004mv4jwrkhxb2gi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3y6000dv45k9tvmq64r	15750	0.060440002174	952	951	2026-08-06 07:48:01.912
cmsh7ritk004nv4jwvws36v6n	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3y6000dv45k9tvmq64r	15750	0.028480772188	449	448	2026-08-06 07:48:01.912
cmsh7ritk004ov4jwh67fd14w	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3y6000dv45k9tvmq64r	15750	0.018465317230	291	290	2026-08-06 07:48:01.912
cmsh7ritk004pv4jwokdgopf1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3y6000dv45k9tvmq64r	15750	0.010234682770	161	161	2026-08-06 07:48:01.912
cmsh7ritk004qv4jwaucb9oct	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3y6000dv45k9tvmq64r	15750	0.028000272513	441	441	2026-08-06 07:48:01.912
cmsh7ritk004rv4jw4od0f13w	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3y6000dv45k9tvmq64r	15750	0.021882741181	345	344	2026-08-06 07:48:01.912
cmsh7ritk004sv4jwiftw3exf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3y6000dv45k9tvmq64r	15750	0.020472951919	322	322	2026-08-06 07:48:01.912
cmsh7ritk004tv4jwv8rorjj6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3y6000dv45k9tvmq64r	15750	0.019004825906	299	299	2026-08-06 07:48:01.912
cmsh7ritk004uv4jw8jt20423	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3y6000dv45k9tvmq64r	15750	0.018298386399	288	288	2026-08-06 07:48:01.912
cmsh7ritk004vv4jwgj7hj39m	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3y6000dv45k9tvmq64r	15750	0.018139007098	286	285	2026-08-06 07:48:01.912
cmsh7ritk004wv4jw89x6tb69	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3y6000dv45k9tvmq64r	15750	0.017495463866	276	275	2026-08-06 07:48:01.912
cmsh7ritk004xv4jwiobv94sg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3y6000dv45k9tvmq64r	15750	0.016459215942	259	259	2026-08-06 07:48:01.912
cmsh7ritk004yv4jwmi5zjbs0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3y6000dv45k9tvmq64r	15750	0.011937806535	188	188	2026-08-06 07:48:01.912
cmsh7ritk004zv4jw6pttmadb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3y6000dv45k9tvmq64r	15750	0.008904380842	140	140	2026-08-06 07:48:01.912
cmsh7ritk0050v4jw34o7fneo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3y6000dv45k9tvmq64r	15750	0.006540173219	103	103	2026-08-06 07:48:01.912
cmsh7ritk0051v4jw4kinli20	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3y6000dv45k9tvmq64r	15750	0.003071908585	48	48	2026-08-06 07:48:01.912
cmsh7ritk0052v4jw3t8g4uw0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3y6000dv45k9tvmq64r	15750	0.002740509916	43	43	2026-08-06 07:48:01.912
cmsh7ritk0053v4jw1ybencxt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3y6000dv45k9tvmq64r	15750	0.002668665919	42	42	2026-08-06 07:48:01.912
cmsh7ritk0054v4jwjt76ol5i	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3y6000dv45k9tvmq64r	15750	0.002403775653	38	37	2026-08-06 07:48:01.912
cmsh7ritk0055v4jwcipc5uwh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3y6000dv45k9tvmq64r	15750	0.002262265810	36	35	2026-08-06 07:48:01.912
cmsh7ritk0056v4jw99tdi8gp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3y6000dv45k9tvmq64r	15750	0.002047089677	32	32	2026-08-06 07:48:01.912
cmsh7ritk0057v4jwrv7vhtcb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3y6000dv45k9tvmq64r	15750	0.001657893126	26	26	2026-08-06 07:48:01.912
cmsh7ritk0058v4jwhkvl0yjc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3y6000dv45k9tvmq64r	15750	0.000793320088	12	12	2026-08-06 07:48:01.912
cmsh7ritk0059v4jwdmra6cj1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3y6000dv45k9tvmq64r	15750	0.000782975587	12	12	2026-08-06 07:48:01.912
cmsh7ritk005av4jw57xy7061	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3y6000dv45k9tvmq64r	15750	0.000397144122	6	6	2026-08-06 07:48:01.912
cmsh7ritk005bv4jwzwgycejh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3kc0004v45kv13t1190	15123420	0.255216617841	3859748	3859748	2026-08-06 07:48:01.912
cmsh7ritk005cv4jwze23qyqv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3kc0004v45kv13t1190	15123420	0.168145164377	2542930	2542929	2026-08-06 07:48:01.912
cmsh7ritk005dv4jw9ig84hmo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3kc0004v45kv13t1190	15123420	0.095133111848	1438738	1438738	2026-08-06 07:48:01.912
cmsh7ritk005ev4jw9a64c50c	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3kc0004v45kv13t1190	15123420	0.092682384743	1401675	1401674	2026-08-06 07:48:01.912
cmsh7ritk005fv4jwtuoqzrew	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3kc0004v45kv13t1190	15123420	0.065256623277	986903	986903	2026-08-06 07:48:01.912
cmsh7ritk005gv4jwuedm000l	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3kc0004v45kv13t1190	15123420	0.060440002174	914060	914059	2026-08-06 07:48:01.912
cmsh7ritk005hv4jwisrqzcne	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3kc0004v45kv13t1190	15123420	0.028480772188	430727	430726	2026-08-06 07:48:01.912
cmsh7ritk005iv4jwcdrd9zxj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3kc0004v45kv13t1190	15123420	0.018465317230	279259	279258	2026-08-06 07:48:01.912
cmsh7ritk005jv4jw93gandyc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3kc0004v45kv13t1190	15123420	0.010234682770	154783	154783	2026-08-06 07:48:01.912
cmsh7ritk005kv4jwwtgpz3a4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3kc0004v45kv13t1190	15123420	0.028000272513	423460	423459	2026-08-06 07:48:01.912
cmsh7ritk005lv4jw77nwtfjf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3kc0004v45kv13t1190	15123420	0.021882741181	330942	330941	2026-08-06 07:48:01.912
cmsh7ritk005mv4jwvxcr6flg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3kc0004v45kv13t1190	15123420	0.020472951919	309621	309621	2026-08-06 07:48:01.912
cmsh7ritk005nv4jwjaplwzlp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3kc0004v45kv13t1190	15123420	0.019004825906	287418	287417	2026-08-06 07:48:01.912
cmsh7ritk005ov4jwbcak3xi4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3kc0004v45kv13t1190	15123420	0.018298386399	276734	276734	2026-08-06 07:48:01.912
cmsh7ritk005pv4jwdrrsbyef	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3kc0004v45kv13t1190	15123420	0.018139007098	274324	274323	2026-08-06 07:48:01.912
cmsh7ritk005qv4jwlkxfhggl	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3kc0004v45kv13t1190	15123420	0.017495463866	264591	264591	2026-08-06 07:48:01.912
cmsh7ritk005rv4jwtpgv48xg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3kc0004v45kv13t1190	15123420	0.016459215942	248920	248919	2026-08-06 07:48:01.912
cmsh7ritk005sv4jwhxk225fo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3kc0004v45kv13t1190	15123420	0.011937806535	180540	180540	2026-08-06 07:48:01.912
cmsh7ritk005tv4jw4hys4q5i	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3kc0004v45kv13t1190	15123420	0.008904380842	134665	134664	2026-08-06 07:48:01.912
cmsh7ritk005uv4jwhoaar7z5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3kc0004v45kv13t1190	15123420	0.006540173219	98910	98909	2026-08-06 07:48:01.912
cmsh7ritk005vv4jwqnpowol0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3kc0004v45kv13t1190	15123420	0.003071908585	46458	46457	2026-08-06 07:48:01.912
cmsh7ritk005wv4jw5qldwdlz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3kc0004v45kv13t1190	15123420	0.002740509916	41446	41445	2026-08-06 07:48:01.912
cmsh7ritk005xv4jw4k0ejqzu	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3kc0004v45kv13t1190	15123420	0.002668665919	40359	40359	2026-08-06 07:48:01.912
cmsh7ritk005yv4jwn6vh33it	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3kc0004v45kv13t1190	15123420	0.002403775653	36353	36353	2026-08-06 07:48:01.912
cmsh7ritk005zv4jwlz5agtw7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3kc0004v45kv13t1190	15123420	0.002262265810	34213	34213	2026-08-06 07:48:01.912
cmsh7ritk0060v4jw6t9vy1ji	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3kc0004v45kv13t1190	15123420	0.002047089677	30959	30958	2026-08-06 07:48:01.912
cmsh7ritk0061v4jwhm04e1sk	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3kc0004v45kv13t1190	15123420	0.001657893126	25073	25073	2026-08-06 07:48:01.912
cmsh7ritk0062v4jwhftncfb1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3kc0004v45kv13t1190	15123420	0.000793320088	11998	11997	2026-08-06 07:48:01.912
cmsh7ritl0063v4jwlru03uer	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3kc0004v45kv13t1190	15123420	0.000782975587	11841	11841	2026-08-06 07:48:01.912
cmsh7ritl0064v4jwegldpnd2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3kc0004v45kv13t1190	15123420	0.000397144122	6006	6006	2026-08-06 07:48:01.912
cmsh7ritl0065v4jwn3sorfkw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3ow0007v45kegisx5jd	6856725	0.255216617841	1749950	1749950	2026-08-06 07:48:01.912
cmsh7ritl0066v4jw80xaajug	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3ow0007v45kegisx5jd	6856725	0.168145164377	1152925	1152925	2026-08-06 07:48:01.912
cmsh7ritl0067v4jwolvxmlfb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3ow0007v45kegisx5jd	6856725	0.095133111848	652302	652301	2026-08-06 07:48:01.912
cmsh7ritl0068v4jwkcp983dx	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3ow0007v45kegisx5jd	6856725	0.092682384743	635498	635497	2026-08-06 07:48:01.912
cmsh7ritl0069v4jwccsu7tx8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3ow0007v45kegisx5jd	6856725	0.065256623277	447447	447446	2026-08-06 07:48:01.912
cmsh7ritl006av4jw8t6o2qcq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3ow0007v45kegisx5jd	6856725	0.060440002174	414420	414420	2026-08-06 07:48:01.912
cmsh7ritl006bv4jwcg9np5o7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3ow0007v45kegisx5jd	6856725	0.028480772188	195285	195284	2026-08-06 07:48:01.912
cmsh7ritl006cv4jwfi40eqm9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3ow0007v45kegisx5jd	6856725	0.018465317230	126612	126611	2026-08-06 07:48:01.912
cmsh7ritl006dv4jwkvc5fpee	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3ow0007v45kegisx5jd	6856725	0.010234682770	70176	70176	2026-08-06 07:48:01.912
cmsh7ritl006ev4jwfqwwh9mo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3ow0007v45kegisx5jd	6856725	0.028000272513	191990	191990	2026-08-06 07:48:01.912
cmsh7ritl006fv4jwm0szk8e9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3ow0007v45kegisx5jd	6856725	0.021882741181	150044	150043	2026-08-06 07:48:01.912
cmsh7ritl006gv4jwqf72e08e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3ow0007v45kegisx5jd	6856725	0.020472951919	140377	140377	2026-08-06 07:48:01.912
cmsh7ritl006hv4jw6xcy4ymc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3ow0007v45kegisx5jd	6856725	0.019004825906	130311	130310	2026-08-06 07:48:01.912
cmsh7ritl006iv4jwteuircwt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3ow0007v45kegisx5jd	6856725	0.018298386399	125467	125467	2026-08-06 07:48:01.912
cmsh7ritl006jv4jw1w190oxh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3ow0007v45kegisx5jd	6856725	0.018139007098	124374	124374	2026-08-06 07:48:01.912
cmsh7ritl006kv4jw20kig5zn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3ow0007v45kegisx5jd	6856725	0.017495463866	119962	119961	2026-08-06 07:48:01.912
cmsh7ritl006lv4jwahrt0f81	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3ow0007v45kegisx5jd	6856725	0.016459215942	112856	112856	2026-08-06 07:48:01.912
cmsh7ritl006mv4jwq1fg8mhs	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3ow0007v45kegisx5jd	6856725	0.011937806535	81854	81854	2026-08-06 07:48:01.912
cmsh7ritl006nv4jwaqb0lc2n	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3ow0007v45kegisx5jd	6856725	0.008904380842	61055	61054	2026-08-06 07:48:01.912
cmsh7ritl006ov4jwx2mtd9gv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3ow0007v45kegisx5jd	6856725	0.006540173219	44844	44844	2026-08-06 07:48:01.912
cmsh7ritl006pv4jw5k557xcl	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3ow0007v45kegisx5jd	6856725	0.003071908585	21063	21063	2026-08-06 07:48:01.912
cmsh7ritl006qv4jwno8658c6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3ow0007v45kegisx5jd	6856725	0.002740509916	18791	18790	2026-08-06 07:48:01.912
cmsh7ritl006rv4jwzzs5jl44	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3ow0007v45kegisx5jd	6856725	0.002668665919	18298	18298	2026-08-06 07:48:01.912
cmsh7ritl006sv4jw1ut54lgq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3ow0007v45kegisx5jd	6856725	0.002403775653	16482	16482	2026-08-06 07:48:01.912
cmsh7ritl006tv4jwi7xxiw7b	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3ow0007v45kegisx5jd	6856725	0.002262265810	15512	15511	2026-08-06 07:48:01.912
cmsh7ritl006uv4jwwhxa4joq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3ow0007v45kegisx5jd	6856725	0.002047089677	14036	14036	2026-08-06 07:48:01.912
cmsh7ritl006vv4jw5jsivo6r	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3ow0007v45kegisx5jd	6856725	0.001657893126	11368	11367	2026-08-06 07:48:01.912
cmsh7ritl006wv4jw5ie0370q	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3ow0007v45kegisx5jd	6856725	0.000793320088	5440	5439	2026-08-06 07:48:01.912
cmsh7ritl006xv4jw0t1aiub1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3ow0007v45kegisx5jd	6856725	0.000782975587	5369	5368	2026-08-06 07:48:01.912
cmsh7ritl006yv4jw52xix6fv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3ow0007v45kegisx5jd	6856725	0.000397144122	2723	2723	2026-08-06 07:48:01.912
cmsh7ritl006zv4jw2tp80zkr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3qm0008v45krlvaq333	7454730	0.255216617841	1902571	1902570	2026-08-06 07:48:01.912
cmsh7ritm0070v4jwclcffp0y	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3qm0008v45krlvaq333	7454730	0.168145164377	1253477	1253476	2026-08-06 07:48:01.912
cmsh7ritm0071v4jw450y2w1k	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3qm0008v45krlvaq333	7454730	0.095133111848	709192	709191	2026-08-06 07:48:01.912
cmsh7ritm0072v4jw2cocmrkh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3qm0008v45krlvaq333	7454730	0.092682384743	690922	690922	2026-08-06 07:48:01.912
cmsh7ritm0073v4jwi6ii0rvd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3qm0008v45krlvaq333	7454730	0.065256623277	486471	486470	2026-08-06 07:48:01.912
cmsh7ritm0074v4jwsgxey6r7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3qm0008v45krlvaq333	7454730	0.060440002174	450564	450563	2026-08-06 07:48:01.912
cmsh7ritm0075v4jwj0ywtbwm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3qm0008v45krlvaq333	7454730	0.028480772188	212316	212316	2026-08-06 07:48:01.912
cmsh7ritm0076v4jwtamtr59q	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3qm0008v45krlvaq333	7454730	0.018465317230	137654	137653	2026-08-06 07:48:01.912
cmsh7ritm0077v4jw94krixnc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3qm0008v45krlvaq333	7454730	0.010234682770	76297	76296	2026-08-06 07:48:01.912
cmsh7ritm0078v4jwkx16f426	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3qm0008v45krlvaq333	7454730	0.028000272513	208734	208734	2026-08-06 07:48:01.912
cmsh7ritm0079v4jwb1tky75d	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3qm0008v45krlvaq333	7454730	0.021882741181	163130	163129	2026-08-06 07:48:01.912
cmsh7ritm007av4jw0b7dpki9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3qm0008v45krlvaq333	7454730	0.020472951919	152620	152620	2026-08-06 07:48:01.912
cmsh7ritm007bv4jwp0ivpidr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3qm0008v45krlvaq333	7454730	0.019004825906	141676	141675	2026-08-06 07:48:01.912
cmsh7ritm007cv4jw7laxudm1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3qm0008v45krlvaq333	7454730	0.018298386399	136410	136409	2026-08-06 07:48:01.912
cmsh7ritm007dv4jw2yqpsp6v	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3qm0008v45krlvaq333	7454730	0.018139007098	135221	135221	2026-08-06 07:48:01.912
cmsh7ritm007ev4jwsxk14cy9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3qm0008v45krlvaq333	7454730	0.017495463866	130424	130423	2026-08-06 07:48:01.912
cmsh7ritm007fv4jw5af3u9pv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3qm0008v45krlvaq333	7454730	0.016459215942	122699	122699	2026-08-06 07:48:01.912
cmsh7ritm007gv4jwowkzh8km	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3qm0008v45krlvaq333	7454730	0.011937806535	88993	88993	2026-08-06 07:48:01.912
cmsh7ritm007hv4jwrplxmdbn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3qm0008v45krlvaq333	7454730	0.008904380842	66380	66379	2026-08-06 07:48:01.912
cmsh7ritm007iv4jwcx8ccsij	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3qm0008v45krlvaq333	7454730	0.006540173219	48755	48755	2026-08-06 07:48:01.912
cmsh7ritm007jv4jwzablhq1r	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3qm0008v45krlvaq333	7454730	0.003071908585	22900	22900	2026-08-06 07:48:01.912
cmsh7ritm007kv4jwdmwpus4s	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3qm0008v45krlvaq333	7454730	0.002740509916	20430	20429	2026-08-06 07:48:01.912
cmsh7ritn007lv4jwxnrquwq6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3qm0008v45krlvaq333	7454730	0.002668665919	19894	19894	2026-08-06 07:48:01.912
cmsh7ritn007mv4jwq4uljmd5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3qm0008v45krlvaq333	7454730	0.002403775653	17919	17919	2026-08-06 07:48:01.912
cmsh7ritn007nv4jwrmj1p9x6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3qm0008v45krlvaq333	7454730	0.002262265810	16865	16864	2026-08-06 07:48:01.912
cmsh7ritn007ov4jwmjs01sse	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3qm0008v45krlvaq333	7454730	0.002047089677	15261	15260	2026-08-06 07:48:01.912
cmsh7ritn007pv4jwcmm6wjhd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3qm0008v45krlvaq333	7454730	0.001657893126	12359	12359	2026-08-06 07:48:01.912
cmsh7ritn007qv4jwfobr01io	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3qm0008v45krlvaq333	7454730	0.000793320088	5914	5913	2026-08-06 07:48:01.912
cmsh7ritn007rv4jwtn8q7s4y	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3qm0008v45krlvaq333	7454730	0.000782975587	5837	5836	2026-08-06 07:48:01.912
cmsh7ritn007sv4jwcaupbdri	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3qm0008v45krlvaq333	7454730	0.000397144122	2961	2960	2026-08-06 07:48:01.912
cmsh7ritn007tv4jw3vvnhzxa	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b42x000gv45kutf85p3y	723205	0.255216617841	184574	184573	2026-08-06 07:48:01.912
cmsh7ritn007uv4jwpecagwr9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b42x000gv45kutf85p3y	723205	0.168145164377	121603	121603	2026-08-06 07:48:01.912
cmsh7ritn007vv4jwm5hz855q	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b42x000gv45kutf85p3y	723205	0.095133111848	68801	68800	2026-08-06 07:48:01.912
cmsh7ritn007wv4jw5xzvouh6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b42x000gv45kutf85p3y	723205	0.092682384743	67028	67028	2026-08-06 07:48:01.912
cmsh7ritn007xv4jw3c4slhnq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b42x000gv45kutf85p3y	723205	0.065256623277	47194	47193	2026-08-06 07:48:01.912
cmsh7ritn007yv4jwvr6h24fx	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b42x000gv45kutf85p3y	723205	0.060440002174	43711	43710	2026-08-06 07:48:01.912
cmsh7ritn007zv4jwahp8dvzm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b42x000gv45kutf85p3y	723205	0.028480772188	20597	20597	2026-08-06 07:48:01.912
cmsh7ritn0080v4jwlzko727m	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b42x000gv45kutf85p3y	723205	0.018465317230	13354	13354	2026-08-06 07:48:01.912
cmsh7ritn0081v4jwvt7ozkxi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b42x000gv45kutf85p3y	723205	0.010234682770	7402	7401	2026-08-06 07:48:01.912
cmsh7ritn0082v4jwqchnb2r0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b42x000gv45kutf85p3y	723205	0.028000272513	20250	20249	2026-08-06 07:48:01.912
cmsh7ritn0083v4jwewiy793c	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b42x000gv45kutf85p3y	723205	0.021882741181	15826	15825	2026-08-06 07:48:01.912
cmsh7ritn0084v4jwxvu8wprn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b42x000gv45kutf85p3y	723205	0.020472951919	14806	14806	2026-08-06 07:48:01.912
cmsh7ritn0085v4jw0vi3n3rs	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b42x000gv45kutf85p3y	723205	0.019004825906	13744	13744	2026-08-06 07:48:01.912
cmsh7ritn0086v4jwgicfogpb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b42x000gv45kutf85p3y	723205	0.018298386399	13233	13233	2026-08-06 07:48:01.912
cmsh7ritn0087v4jw39pvj8dj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b42x000gv45kutf85p3y	723205	0.018139007098	13118	13118	2026-08-06 07:48:01.912
cmsh7rito0088v4jwlw3cky4e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b42x000gv45kutf85p3y	723205	0.017495463866	12653	12652	2026-08-06 07:48:01.912
cmsh7rito0089v4jw5bboidif	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b42x000gv45kutf85p3y	723205	0.016459215942	11903	11903	2026-08-06 07:48:01.912
cmsh7rito008av4jw0h46ch9b	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b42x000gv45kutf85p3y	723205	0.011937806535	8633	8633	2026-08-06 07:48:01.912
cmsh7rito008bv4jw1ojfsffn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b42x000gv45kutf85p3y	723205	0.008904380842	6440	6439	2026-08-06 07:48:01.912
cmsh7rito008cv4jw9livsymd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b42x000gv45kutf85p3y	723205	0.006540173219	4730	4729	2026-08-06 07:48:01.912
cmsh7rito008dv4jwkkaec305	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b42x000gv45kutf85p3y	723205	0.003071908585	2222	2221	2026-08-06 07:48:01.912
cmsh7rito008ev4jwa32oec5q	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b42x000gv45kutf85p3y	723205	0.002740509916	1982	1981	2026-08-06 07:48:01.912
cmsh7rito008fv4jwtscwmexo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b42x000gv45kutf85p3y	723205	0.002668665919	1930	1929	2026-08-06 07:48:01.912
cmsh7rito008gv4jw0o740qtn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b42x000gv45kutf85p3y	723205	0.002403775653	1738	1738	2026-08-06 07:48:01.912
cmsh7rito008hv4jw35n7jvsl	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b42x000gv45kutf85p3y	723205	0.002262265810	1636	1636	2026-08-06 07:48:01.912
cmsh7rito008iv4jwv3o9kqh6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b42x000gv45kutf85p3y	723205	0.002047089677	1480	1480	2026-08-06 07:48:01.912
cmsh7rito008jv4jwsyel7tku	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b42x000gv45kutf85p3y	723205	0.001657893126	1199	1198	2026-08-06 07:48:01.912
cmsh7rito008kv4jwd1h1f02r	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b42x000gv45kutf85p3y	723205	0.000793320088	574	573	2026-08-06 07:48:01.912
cmsh7rito008lv4jw7ztfgx9n	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b42x000gv45kutf85p3y	723205	0.000782975587	566	566	2026-08-06 07:48:01.912
cmsh7rito008mv4jw9phpbau9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b42x000gv45kutf85p3y	723205	0.000397144122	287	287	2026-08-06 07:48:01.912
cmsh7rito008nv4jwcne9d9cc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3wp000cv45k0eshx54k	367670	0.255216617841	93835	93835	2026-08-06 07:48:01.912
cmsh7rito008ov4jwk7rpono2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3wp000cv45k0eshx54k	367670	0.168145164377	61822	61821	2026-08-06 07:48:01.912
cmsh7rito008pv4jwq83a9gse	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3wp000cv45k0eshx54k	367670	0.095133111848	34978	34977	2026-08-06 07:48:01.912
cmsh7rito008qv4jw8xga9t25	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3wp000cv45k0eshx54k	367670	0.092682384743	34077	34076	2026-08-06 07:48:01.912
cmsh7rito008rv4jwt66jl2mm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3wp000cv45k0eshx54k	367670	0.065256623277	23993	23992	2026-08-06 07:48:01.912
cmsh7ritp008sv4jwmoivqope	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3wp000cv45k0eshx54k	367670	0.060440002174	22222	22221	2026-08-06 07:48:01.912
cmsh7ritp008tv4jwrmye7g76	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3wp000cv45k0eshx54k	367670	0.028480772188	10472	10471	2026-08-06 07:48:01.912
cmsh7ritp008uv4jwsb80mo8e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3wp000cv45k0eshx54k	367670	0.018465317230	6789	6789	2026-08-06 07:48:01.912
cmsh7ritp008vv4jwzgtwuin1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3wp000cv45k0eshx54k	367670	0.010234682770	3763	3762	2026-08-06 07:48:01.912
cmsh7ritp008wv4jwcaoabop3	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3wp000cv45k0eshx54k	367670	0.028000272513	10295	10294	2026-08-06 07:48:01.912
cmsh7ritp008xv4jwf7fx0gjj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3wp000cv45k0eshx54k	367670	0.021882741181	8046	8045	2026-08-06 07:48:01.912
cmsh7ritp008yv4jw5lorjmbf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3wp000cv45k0eshx54k	367670	0.020472951919	7527	7527	2026-08-06 07:48:01.912
cmsh7ritp008zv4jwrrpvwrl3	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3wp000cv45k0eshx54k	367670	0.019004825906	6988	6987	2026-08-06 07:48:01.912
cmsh7ritp0090v4jw9m94cyrp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3wp000cv45k0eshx54k	367670	0.018298386399	6728	6727	2026-08-06 07:48:01.912
cmsh7ritp0091v4jwyw4b1bvk	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3wp000cv45k0eshx54k	367670	0.018139007098	6669	6669	2026-08-06 07:48:01.912
cmsh7ritp0092v4jwsre0iwex	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3wp000cv45k0eshx54k	367670	0.017495463866	6433	6432	2026-08-06 07:48:01.912
cmsh7ritp0093v4jwadm6flbv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3wp000cv45k0eshx54k	367670	0.016459215942	6052	6051	2026-08-06 07:48:01.912
cmsh7ritp0094v4jwxqi5fhfh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3wp000cv45k0eshx54k	367670	0.011937806535	4389	4389	2026-08-06 07:48:01.912
cmsh7ritp0095v4jw1zjmzxpz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3wp000cv45k0eshx54k	367670	0.008904380842	3274	3273	2026-08-06 07:48:01.912
cmsh7ritp0096v4jw1c56mznh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3wp000cv45k0eshx54k	367670	0.006540173219	2405	2404	2026-08-06 07:48:01.912
cmsh7ritp0097v4jwyaw75si0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3wp000cv45k0eshx54k	367670	0.003071908585	1129	1129	2026-08-06 07:48:01.912
cmsh7ritp0098v4jwtazb4utm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3wp000cv45k0eshx54k	367670	0.002740509916	1008	1007	2026-08-06 07:48:01.912
cmsh7ritp0099v4jwbzbtuh3b	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3wp000cv45k0eshx54k	367670	0.002668665919	981	981	2026-08-06 07:48:01.912
cmsh7ritp009av4jwuwefosyz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3wp000cv45k0eshx54k	367670	0.002403775653	884	883	2026-08-06 07:48:01.912
cmsh7ritp009bv4jw24wuxb46	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3wp000cv45k0eshx54k	367670	0.002262265810	832	831	2026-08-06 07:48:01.912
cmsh7ritp009cv4jwwqqjz65i	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3wp000cv45k0eshx54k	367670	0.002047089677	753	752	2026-08-06 07:48:01.912
cmsh7ritp009dv4jw67r0ijeg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3wp000cv45k0eshx54k	367670	0.001657893126	610	609	2026-08-06 07:48:01.912
cmsh7ritp009ev4jw2sxp3j0c	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3wp000cv45k0eshx54k	367670	0.000793320088	292	291	2026-08-06 07:48:01.912
cmsh7ritq009fv4jwcxo6k07r	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3wp000cv45k0eshx54k	367670	0.000782975587	288	287	2026-08-06 07:48:01.912
cmsh7ritq009gv4jw5k0mwhkv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3wp000cv45k0eshx54k	367670	0.000397144122	146	146	2026-08-06 07:48:01.912
cmsh7ritq009hv4jwr0dh1ih2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3rx0009v45kvzp0f6by	14915660	0.255216617841	3806724	3806724	2026-08-06 07:48:01.912
cmsh7ritq009iv4jw5sy14qzd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3rx0009v45kvzp0f6by	14915660	0.168145164377	2507996	2507996	2026-08-06 07:48:01.912
cmsh7ritq009jv4jwtmpa8hhu	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3rx0009v45kvzp0f6by	14915660	0.095133111848	1418973	1418973	2026-08-06 07:48:01.912
cmsh7ritq009kv4jwmeabi67v	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3rx0009v45kvzp0f6by	14915660	0.092682384743	1382419	1382418	2026-08-06 07:48:01.912
cmsh7ritq009lv4jwfw5813qh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3rx0009v45kvzp0f6by	14915660	0.065256623277	973346	973345	2026-08-06 07:48:01.912
cmsh7ritq009mv4jwcqrtd9oi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3rx0009v45kvzp0f6by	14915660	0.060440002174	901503	901502	2026-08-06 07:48:01.912
cmsh7ritq009nv4jwae4j4xt2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3rx0009v45kvzp0f6by	14915660	0.028480772188	424810	424809	2026-08-06 07:48:01.912
cmsh7ritq009ov4jwvz69825c	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3rx0009v45kvzp0f6by	14915660	0.018465317230	275422	275422	2026-08-06 07:48:01.912
cmsh7ritq009pv4jwavbyg6p3	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3rx0009v45kvzp0f6by	14915660	0.010234682770	152657	152657	2026-08-06 07:48:01.912
cmsh7ritq009qv4jwbtvyqmhi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3rx0009v45kvzp0f6by	14915660	0.028000272513	417643	417642	2026-08-06 07:48:01.912
cmsh7ritq009rv4jwt7oir5zj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3rx0009v45kvzp0f6by	14915660	0.021882741181	326396	326395	2026-08-06 07:48:01.912
cmsh7ritq009sv4jw39yjnspt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3rx0009v45kvzp0f6by	14915660	0.020472951919	305368	305367	2026-08-06 07:48:01.912
cmsh7ritq009tv4jw7ibf3y7v	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3rx0009v45kvzp0f6by	14915660	0.019004825906	283470	283469	2026-08-06 07:48:01.912
cmsh7ritq009uv4jwzlvr8eog	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3rx0009v45kvzp0f6by	14915660	0.018298386399	272933	272932	2026-08-06 07:48:01.912
cmsh7ritq009vv4jwusjeedds	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3rx0009v45kvzp0f6by	14915660	0.018139007098	270555	270555	2026-08-06 07:48:01.912
cmsh7ritq009wv4jw8mvegbzw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3rx0009v45kvzp0f6by	14915660	0.017495463866	260956	260956	2026-08-06 07:48:01.912
cmsh7ritq009xv4jwsfy5qwz7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3rx0009v45kvzp0f6by	14915660	0.016459215942	245500	245500	2026-08-06 07:48:01.912
cmsh7ritq009yv4jwy4gp8fvy	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3rx0009v45kvzp0f6by	14915660	0.011937806535	178060	178060	2026-08-06 07:48:01.912
cmsh7ritq009zv4jwl9dy662r	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3rx0009v45kvzp0f6by	14915660	0.008904380842	132815	132814	2026-08-06 07:48:01.912
cmsh7ritr00a0v4jwy6ix3od1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3rx0009v45kvzp0f6by	14915660	0.006540173219	97551	97551	2026-08-06 07:48:01.912
cmsh7ritr00a1v4jw8hbu1mnk	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3rx0009v45kvzp0f6by	14915660	0.003071908585	45820	45819	2026-08-06 07:48:01.912
cmsh7ritr00a2v4jwekqrerto	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3rx0009v45kvzp0f6by	14915660	0.002740509916	40877	40876	2026-08-06 07:48:01.912
cmsh7ritr00a3v4jw5ttukwa4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3rx0009v45kvzp0f6by	14915660	0.002668665919	39805	39804	2026-08-06 07:48:01.912
cmsh7ritr00a4v4jwu5c9vlew	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3rx0009v45kvzp0f6by	14915660	0.002403775653	35854	35853	2026-08-06 07:48:01.912
cmsh7ritr00a5v4jwfprbwna2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3rx0009v45kvzp0f6by	14915660	0.002262265810	33743	33743	2026-08-06 07:48:01.912
cmsh7ritr00a6v4jwq32g69pv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3rx0009v45kvzp0f6by	14915660	0.002047089677	30534	30533	2026-08-06 07:48:01.912
cmsh7ritr00a7v4jwjp1s207v	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3rx0009v45kvzp0f6by	14915660	0.001657893126	24729	24728	2026-08-06 07:48:01.912
cmsh7ritr00a8v4jwtlm240pc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3rx0009v45kvzp0f6by	14915660	0.000793320088	11833	11832	2026-08-06 07:48:01.912
cmsh7ritr00a9v4jwe8rttqyb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3rx0009v45kvzp0f6by	14915660	0.000782975587	11679	11678	2026-08-06 07:48:01.912
cmsh7ritr00aav4jwph6oask6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3rx0009v45kvzp0f6by	14915660	0.000397144122	5924	5923	2026-08-06 07:48:01.912
cmsh7ritr00abv4jwrorg3ahr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3lv0005v45k1i15ud1r	2820330	0.255216617841	719795	719795	2026-08-06 07:48:01.912
cmsh7ritr00acv4jwwqsqsuge	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3lv0005v45k1i15ud1r	2820330	0.168145164377	474225	474224	2026-08-06 07:48:01.912
cmsh7ritr00adv4jwyrw00xpj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3lv0005v45k1i15ud1r	2820330	0.095133111848	268307	268306	2026-08-06 07:48:01.912
cmsh7ritr00aev4jwwoaat6ek	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3lv0005v45k1i15ud1r	2820330	0.092682384743	261395	261394	2026-08-06 07:48:01.912
cmsh7ritr00afv4jw3dtuppop	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3lv0005v45k1i15ud1r	2820330	0.065256623277	184045	184045	2026-08-06 07:48:01.912
cmsh7ritr00agv4jw99sz8gn0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3lv0005v45k1i15ud1r	2820330	0.060440002174	170461	170460	2026-08-06 07:48:01.912
cmsh7ritr00ahv4jwtd99e8hs	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3lv0005v45k1i15ud1r	2820330	0.028480772188	80325	80325	2026-08-06 07:48:01.912
cmsh7ritr00aiv4jwi661x3p6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3lv0005v45k1i15ud1r	2820330	0.018465317230	52078	52078	2026-08-06 07:48:01.912
cmsh7ritr00ajv4jw4vgx5rcm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3lv0005v45k1i15ud1r	2820330	0.010234682770	28865	28865	2026-08-06 07:48:01.912
cmsh7rits00akv4jwrmrggrdd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3lv0005v45k1i15ud1r	2820330	0.028000272513	78970	78970	2026-08-06 07:48:01.912
cmsh7rits00alv4jwbep2g81r	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3lv0005v45k1i15ud1r	2820330	0.021882741181	61717	61716	2026-08-06 07:48:01.912
cmsh7rits00amv4jwvdxwcg2r	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3lv0005v45k1i15ud1r	2820330	0.020472951919	57740	57740	2026-08-06 07:48:01.912
cmsh7rits00anv4jwejasdaed	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3lv0005v45k1i15ud1r	2820330	0.019004825906	53600	53599	2026-08-06 07:48:01.912
cmsh7rits00aov4jwvc925fft	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3lv0005v45k1i15ud1r	2820330	0.018298386399	51607	51607	2026-08-06 07:48:01.912
cmsh7rits00apv4jwyirfxcja	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3lv0005v45k1i15ud1r	2820330	0.018139007098	51158	51157	2026-08-06 07:48:01.912
cmsh7rits00aqv4jw4o70lka6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3lv0005v45k1i15ud1r	2820330	0.017495463866	49343	49342	2026-08-06 07:48:01.912
cmsh7rits00arv4jwgrnc30nj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3lv0005v45k1i15ud1r	2820330	0.016459215942	46420	46420	2026-08-06 07:48:01.912
cmsh7rits00asv4jwk10ahnb7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3lv0005v45k1i15ud1r	2820330	0.011937806535	33669	33668	2026-08-06 07:48:01.912
cmsh7rits00atv4jwub9agqch	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3lv0005v45k1i15ud1r	2820330	0.008904380842	25113	25113	2026-08-06 07:48:01.912
cmsh7rits00auv4jwwyhvxr0o	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3lv0005v45k1i15ud1r	2820330	0.006540173219	18445	18445	2026-08-06 07:48:01.912
cmsh7rits00avv4jw0ohrd7vo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3lv0005v45k1i15ud1r	2820330	0.003071908585	8664	8663	2026-08-06 07:48:01.912
cmsh7rits00awv4jw4bxmqb11	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3lv0005v45k1i15ud1r	2820330	0.002740509916	7729	7729	2026-08-06 07:48:01.912
cmsh7rits00axv4jwlv1offoy	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3lv0005v45k1i15ud1r	2820330	0.002668665919	7527	7526	2026-08-06 07:48:01.912
cmsh7rits00ayv4jw5otyiyij	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3lv0005v45k1i15ud1r	2820330	0.002403775653	6779	6779	2026-08-06 07:48:01.912
cmsh7rits00azv4jwavvo68cf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3lv0005v45k1i15ud1r	2820330	0.002262265810	6380	6380	2026-08-06 07:48:01.912
cmsh7rits00b0v4jwmj0x2seu	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3lv0005v45k1i15ud1r	2820330	0.002047089677	5773	5773	2026-08-06 07:48:01.912
cmsh7rits00b1v4jwz1ox9819	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3lv0005v45k1i15ud1r	2820330	0.001657893126	4676	4675	2026-08-06 07:48:01.912
cmsh7rits00b2v4jw86irut68	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3lv0005v45k1i15ud1r	2820330	0.000793320088	2237	2237	2026-08-06 07:48:01.912
cmsh7rits00b3v4jwrmipnw1m	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3lv0005v45k1i15ud1r	2820330	0.000782975587	2208	2208	2026-08-06 07:48:01.912
cmsh7rits00b4v4jw54piskum	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3lv0005v45k1i15ud1r	2820330	0.000397144122	1120	1120	2026-08-06 07:48:01.912
cmsh7rits00b5v4jwtb4w18jq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.255216617841	612520	612519	2026-08-06 07:48:01.912
cmsh7ritt00b6v4jwwf117rwf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.168145164377	403548	403548	2026-08-06 07:48:01.912
cmsh7ritt00b7v4jwqcrii0z6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.095133111848	228319	228319	2026-08-06 07:48:01.912
cmsh7ritt00b8v4jwm67yoytv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.092682384743	222438	222437	2026-08-06 07:48:01.912
cmsh7ritt00b9v4jwq6iwk8n0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.065256623277	156616	156615	2026-08-06 07:48:01.912
cmsh7ritt00bav4jwgj3oxocx	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.060440002174	145056	145056	2026-08-06 07:48:01.912
cmsh7ritt00bbv4jwzjrbciim	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.028480772188	68354	68353	2026-08-06 07:48:01.912
cmsh7ritt00bcv4jw40kqgaqo	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.018465317230	44317	44316	2026-08-06 07:48:01.912
cmsh7ritt00bdv4jw9henw1gz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.010234682770	24563	24563	2026-08-06 07:48:01.912
cmsh7ritt00bev4jwtaq9adrx	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.028000272513	67201	67200	2026-08-06 07:48:01.912
cmsh7ritt00bfv4jwbo3hhu49	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.021882741181	52519	52518	2026-08-06 07:48:01.912
cmsh7ritt00bgv4jwl3gp31h9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.020472951919	49135	49135	2026-08-06 07:48:01.912
cmsh7ritt00bhv4jwhxbbo2rn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.019004825906	45612	45611	2026-08-06 07:48:01.912
cmsh7ritt00biv4jwi45lilwd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.018298386399	43916	43916	2026-08-06 07:48:01.912
cmsh7ritt00bjv4jw2otrrypr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.018139007098	43534	43533	2026-08-06 07:48:01.912
cmsh7ritt00bkv4jwbwfhupbd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.017495463866	41989	41989	2026-08-06 07:48:01.912
cmsh7ritt00blv4jwnzflzgyi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.016459215942	39502	39502	2026-08-06 07:48:01.912
cmsh7ritt00bmv4jwpdamn898	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.011937806535	28651	28650	2026-08-06 07:48:01.912
cmsh7ritu00bnv4jwo8f9cnz7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.008904380842	21371	21370	2026-08-06 07:48:01.912
cmsh7ritu00bov4jwe2umkkl9	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.006540173219	15696	15696	2026-08-06 07:48:01.912
cmsh7ritu00bpv4jw0oj1383m	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.003071908585	7373	7372	2026-08-06 07:48:01.912
cmsh7ritu00bqv4jwarfxxpr2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.002740509916	6577	6577	2026-08-06 07:48:01.912
cmsh7ritu00brv4jwy5c88vr5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.002668665919	6405	6404	2026-08-06 07:48:01.912
cmsh7ritu00bsv4jwa70oxioj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.002403775653	5769	5769	2026-08-06 07:48:01.912
cmsh7ritu00btv4jwcwcwjizr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.002262265810	5429	5429	2026-08-06 07:48:01.912
cmsh7ritu00buv4jwh3ub3p33	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.002047089677	4913	4913	2026-08-06 07:48:01.912
cmsh7ritu00bvv4jww1x41ovr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.001657893126	3979	3978	2026-08-06 07:48:01.912
cmsh7ritu00bwv4jwnpbi83cq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.000793320088	1904	1903	2026-08-06 07:48:01.912
cmsh7ritu00bxv4jwfrt810pi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.000782975587	1879	1879	2026-08-06 07:48:01.912
cmsh7ritu00byv4jw22zs72nr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3hc0002v45kkzg3z9wd	2400000	0.000397144122	953	953	2026-08-06 07:48:01.912
cmsh7ritu00bzv4jwroj0jm7a	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3zn000ev45ke50rracp	17810067	0.255216617841	4545425	4545425	2026-08-06 07:48:01.912
cmsh7ritu00c0v4jw9cka10un	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3zn000ev45ke50rracp	17810067	0.168145164377	2994677	2994676	2026-08-06 07:48:01.912
cmsh7ritu00c1v4jwow3661vt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3zn000ev45ke50rracp	17810067	0.095133111848	1694327	1694327	2026-08-06 07:48:01.912
cmsh7ritu00c2v4jwgc8v1lq4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3zn000ev45ke50rracp	17810067	0.092682384743	1650679	1650679	2026-08-06 07:48:01.912
cmsh7ritu00c3v4jwr2r7npge	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3zn000ev45ke50rracp	17810067	0.065256623277	1162225	1162224	2026-08-06 07:48:01.912
cmsh7ritu00c4v4jw1i9wal5q	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3zn000ev45ke50rracp	17810067	0.060440002174	1076440	1076440	2026-08-06 07:48:01.912
cmsh7ritu00c5v4jweib0r8vl	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3zn000ev45ke50rracp	17810067	0.028480772188	507244	507244	2026-08-06 07:48:01.912
cmsh7ritv00c6v4jwlrcrjomt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3zn000ev45ke50rracp	17810067	0.018465317230	328869	328868	2026-08-06 07:48:01.912
cmsh7ritv00c7v4jw2uzfmak8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3zn000ev45ke50rracp	17810067	0.010234682770	182280	182280	2026-08-06 07:48:01.912
cmsh7ritv00c8v4jw5u3rt854	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3zn000ev45ke50rracp	17810067	0.028000272513	498687	498686	2026-08-06 07:48:01.912
cmsh7ritv00c9v4jwqv0vppnv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3zn000ev45ke50rracp	17810067	0.021882741181	389733	389733	2026-08-06 07:48:01.912
cmsh7ritv00cav4jw7pm9wyt8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3zn000ev45ke50rracp	17810067	0.020472951919	364625	364624	2026-08-06 07:48:01.912
cmsh7ritv00cbv4jwn8ep8jjc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3zn000ev45ke50rracp	17810067	0.019004825906	338477	338477	2026-08-06 07:48:01.912
cmsh7ritv00ccv4jw8hgzt48w	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3zn000ev45ke50rracp	17810067	0.018298386399	325895	325895	2026-08-06 07:48:01.912
cmsh7ritv00cdv4jwurb1ek7e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3zn000ev45ke50rracp	17810067	0.018139007098	323057	323056	2026-08-06 07:48:01.912
cmsh7ritw00cev4jwksnf0y3y	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3zn000ev45ke50rracp	17810067	0.017495463866	311595	311595	2026-08-06 07:48:01.912
cmsh7ritw00cfv4jwws7gp6mi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3zn000ev45ke50rracp	17810067	0.016459215942	293140	293139	2026-08-06 07:48:01.912
cmsh7ritw00cgv4jwtgkmn0yv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3zn000ev45ke50rracp	17810067	0.011937806535	212613	212613	2026-08-06 07:48:01.912
cmsh7ritw00chv4jwe1wl3gvr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3zn000ev45ke50rracp	17810067	0.008904380842	158588	158587	2026-08-06 07:48:01.912
cmsh7ritw00civ4jwe86rou5s	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3zn000ev45ke50rracp	17810067	0.006540173219	116481	116480	2026-08-06 07:48:01.912
cmsh7ritw00cjv4jw4pm8bpi3	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3zn000ev45ke50rracp	17810067	0.003071908585	54711	54710	2026-08-06 07:48:01.912
cmsh7ritw00ckv4jw09fwxnfx	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3zn000ev45ke50rracp	17810067	0.002740509916	48809	48808	2026-08-06 07:48:01.912
cmsh7ritw00clv4jwj9vxs1qc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3zn000ev45ke50rracp	17810067	0.002668665919	47529	47529	2026-08-06 07:48:01.912
cmsh7ritw00cmv4jwprzpyihp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3zn000ev45ke50rracp	17810067	0.002403775653	42811	42811	2026-08-06 07:48:01.912
cmsh7ritx00cnv4jwnv74t1vp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3zn000ev45ke50rracp	17810067	0.002262265810	40291	40291	2026-08-06 07:48:01.912
cmsh7ritx00cov4jwrzpgjfga	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3zn000ev45ke50rracp	17810067	0.002047089677	36459	36458	2026-08-06 07:48:01.912
cmsh7ritx00cpv4jw6ncgka06	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3zn000ev45ke50rracp	17810067	0.001657893126	29527	29527	2026-08-06 07:48:01.912
cmsh7ritx00cqv4jwkc8arzsk	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3zn000ev45ke50rracp	17810067	0.000793320088	14129	14129	2026-08-06 07:48:01.912
cmsh7ritx00crv4jwtx5oyx5v	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3zn000ev45ke50rracp	17810067	0.000782975587	13945	13944	2026-08-06 07:48:01.912
cmsh7ritx00csv4jwszernivw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3zn000ev45ke50rracp	17810067	0.000397144122	7073	7073	2026-08-06 07:48:01.912
cmsh7ritx00ctv4jwruaoo686	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.255216617841	68515326	68515326	2026-08-06 07:48:01.912
cmsh7ritx00cuv4jw9fa2yhwu	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.168145164377	45140167	45140167	2026-08-06 07:48:01.912
cmsh7ritx00cvv4jwy5des08e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.095133111848	25539388	25539387	2026-08-06 07:48:01.912
cmsh7ritx00cwv4jw8ejp5s05	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.092682384743	24881467	24881466	2026-08-06 07:48:01.912
cmsh7ritx00cxv4jw5zer5jjz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.065256623277	17518761	17518760	2026-08-06 07:48:01.912
cmsh7ritx00cyv4jwbiddoa35	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.060440002174	16225693	16225692	2026-08-06 07:48:01.912
cmsh7ritx00czv4jwmf5ky9zk	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.028480772188	7645934	7645933	2026-08-06 07:48:01.912
cmsh7ritx00d0v4jw5gy2iiii	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.018465317230	4957190	4957189	2026-08-06 07:48:01.912
cmsh7ritx00d1v4jwtq02qhy1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.010234682770	2747598	2747597	2026-08-06 07:48:01.912
cmsh7ritx00d2v4jw1apdsu3n	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.028000272513	7516939	7516939	2026-08-06 07:48:01.912
cmsh7ritx00d3v4jwo0v5q7fm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.021882741181	5874630	5874629	2026-08-06 07:48:01.912
cmsh7ritx00d4v4jwzuj001k8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.020472951919	5496158	5496158	2026-08-06 07:48:01.912
cmsh7ritx00d5v4jwibmojozs	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.019004825906	5102026	5102026	2026-08-06 07:48:01.912
cmsh7ritx00d6v4jwrt4ds00x	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.018298386399	4912376	4912375	2026-08-06 07:48:01.912
cmsh7rity00d7v4jwu3p7h9us	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.018139007098	4869589	4869588	2026-08-06 07:48:01.912
cmsh7rity00d8v4jwsr5t12h6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.017495463866	4696824	4696823	2026-08-06 07:48:01.912
cmsh7rity00d9v4jwuakg9z6q	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.016459215942	4418633	4418632	2026-08-06 07:48:01.912
cmsh7rity00dav4jwrf4yu8wl	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.011937806535	3204818	3204817	2026-08-06 07:48:01.912
cmsh7rity00dbv4jwi26e5erq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.008904380842	2390466	2390465	2026-08-06 07:48:01.912
cmsh7rity00dcv4jwab58sqb2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.006540173219	1755772	1755771	2026-08-06 07:48:01.912
cmsh7rity00ddv4jwdfakna6o	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.003071908585	824683	824683	2026-08-06 07:48:01.912
cmsh7rity00dev4jwg8toduf5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.002740509916	735716	735715	2026-08-06 07:48:01.912
cmsh7rity00dfv4jw5wmawc0h	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.002668665919	716429	716428	2026-08-06 07:48:01.912
cmsh7rity00dgv4jwu9m5geg0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.002403775653	645316	645316	2026-08-06 07:48:01.912
cmsh7rity00dhv4jwswmz1mhp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.002262265810	607327	607326	2026-08-06 07:48:01.912
cmsh7rity00div4jwljdrwve6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.002047089677	549561	549560	2026-08-06 07:48:01.912
cmsh7rity00djv4jwj56ykvv4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.001657893126	445077	445077	2026-08-06 07:48:01.912
cmsh7rity00dkv4jw9xplswjw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.000793320088	212974	212974	2026-08-06 07:48:01.912
cmsh7rity00dlv4jwwmgry4c0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.000782975587	210197	210197	2026-08-06 07:48:01.912
cmsh7rity00dmv4jwot1rn49l	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3cp0000v45kdnl2mv4k	268459502	0.000397144122	106617	106617	2026-08-06 07:48:01.912
cmsh7rity00dnv4jwhubfe0nq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.255216617841	1222651	1222650	2026-08-06 07:48:01.912
cmsh7rity00dov4jwj7asvtwv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.168145164377	805523	805522	2026-08-06 07:48:01.912
cmsh7rity00dpv4jwmbe1jv0b	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.095133111848	455748	455748	2026-08-06 07:48:01.912
cmsh7rity00dqv4jwjgxk9bok	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.092682384743	444008	444007	2026-08-06 07:48:01.912
cmsh7rity00drv4jwcja4hahd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.065256623277	312621	312620	2026-08-06 07:48:01.912
cmsh7rity00dsv4jwbkjwnqtz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.060440002174	289546	289546	2026-08-06 07:48:01.912
cmsh7rity00dtv4jw8o5del2f	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.028480772188	136441	136441	2026-08-06 07:48:01.912
cmsh7ritz00duv4jwbkansk04	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.018465317230	88461	88460	2026-08-06 07:48:01.912
cmsh7ritz00dvv4jwf3a342od	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.010234682770	49031	49030	2026-08-06 07:48:01.912
cmsh7ritz00dwv4jwobmiqzaw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.028000272513	134139	134139	2026-08-06 07:48:01.912
cmsh7ritz00dxv4jwm1vz6djy	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.021882741181	104832	104832	2026-08-06 07:48:01.912
cmsh7ritz00dyv4jwete10t8r	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.020472951919	98079	98078	2026-08-06 07:48:01.912
cmsh7ritz00dzv4jw8wxzm4pi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.019004825906	91045	91045	2026-08-06 07:48:01.912
cmsh7ritz00e0v4jwl33c73r8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.018298386399	87661	87660	2026-08-06 07:48:01.912
cmsh7ritz00e1v4jwlnifr7te	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.018139007098	86897	86897	2026-08-06 07:48:01.912
cmsh7ritz00e2v4jwl8aqljvl	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.017495463866	83814	83814	2026-08-06 07:48:01.912
cmsh7ritz00e3v4jw7cdrnla8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.016459215942	78850	78850	2026-08-06 07:48:01.912
cmsh7ritz00e4v4jws4b8homs	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.011937806535	57190	57189	2026-08-06 07:48:01.912
cmsh7ritz00e5v4jwob5pjcga	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.008904380842	42658	42657	2026-08-06 07:48:01.912
cmsh7ritz00e6v4jwtve2vd8g	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.006540173219	31332	31331	2026-08-06 07:48:01.912
cmsh7ritz00e7v4jw703m277b	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.003071908585	14716	14716	2026-08-06 07:48:01.912
cmsh7ritz00e8v4jwuund5k9n	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.002740509916	13129	13128	2026-08-06 07:48:01.912
cmsh7ritz00e9v4jwp8k8vyv2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.002668665919	12785	12784	2026-08-06 07:48:01.912
cmsh7ritz00eav4jwjd9k1i87	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.002403775653	11516	11515	2026-08-06 07:48:01.912
cmsh7ritz00ebv4jwehs3lgit	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.002262265810	10838	10837	2026-08-06 07:48:01.912
cmsh7ritz00ecv4jwjpjntl2k	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.002047089677	9807	9806	2026-08-06 07:48:01.912
cmsh7ritz00edv4jwkomlgytl	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.001657893126	7942	7942	2026-08-06 07:48:01.912
cmsh7ritz00eev4jwyciwmk9x	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.000793320088	3801	3800	2026-08-06 07:48:01.912
cmsh7ritz00efv4jw6wu50nhb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.000782975587	3751	3750	2026-08-06 07:48:01.912
cmsh7ritz00egv4jwvwciqe7d	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3ne0006v45ka0wrz3cs	4790640	0.000397144122	1903	1902	2026-08-06 07:48:01.912
cmsh7riu000ehv4jw2vbk966q	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.255216617841	22494380	22494380	2026-08-06 07:48:01.912
cmsh7riu000eiv4jwt51ecms7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.168145164377	14820043	14820042	2026-08-06 07:48:01.912
cmsh7riu000ejv4jw6l9g8jvr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.095133111848	8384879	8384878	2026-08-06 07:48:01.912
cmsh7riu000ekv4jwedxxko90	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.092682384743	8168876	8168875	2026-08-06 07:48:01.912
cmsh7riu000elv4jwjnzd1z0l	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.065256623277	5751613	5751613	2026-08-06 07:48:01.912
cmsh7riu000emv4jwmezpckcv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.060440002174	5327084	5327084	2026-08-06 07:48:01.912
cmsh7riu000env4jw59bp3060	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.028480772188	2510249	2510249	2026-08-06 07:48:01.912
cmsh7riu000eov4jw2obvh3wi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.018465317230	1627503	1627503	2026-08-06 07:48:01.912
cmsh7riu000epv4jwifxaut46	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.010234682770	902068	902068	2026-08-06 07:48:01.912
cmsh7riu000eqv4jwj8vflkfb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.028000272513	2467899	2467898	2026-08-06 07:48:01.912
cmsh7riu000erv4jwpocde1jt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.021882741181	1928709	1928709	2026-08-06 07:48:01.912
cmsh7riu000esv4jwxts8zbjg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.020472951919	1804453	1804452	2026-08-06 07:48:01.912
cmsh7riu000etv4jwieywgnpu	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.019004825906	1675055	1675054	2026-08-06 07:48:01.912
cmsh7riu000euv4jw03c6kju5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.018298386399	1612790	1612790	2026-08-06 07:48:01.912
cmsh7riu100evv4jwo8b8xlni	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.018139007098	1598743	1598742	2026-08-06 07:48:01.912
cmsh7riu100ewv4jw24kfdly1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.017495463866	1542022	1542021	2026-08-06 07:48:01.912
cmsh7riu100exv4jw8z473lyj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.016459215942	1450689	1450688	2026-08-06 07:48:01.912
cmsh7riu100eyv4jwnce8s769	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.011937806535	1052179	1052178	2026-08-06 07:48:01.912
cmsh7riu100ezv4jw5fdurhtu	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.008904380842	784818	784817	2026-08-06 07:48:01.912
cmsh7riu100f0v4jw95hkf086	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.006540173219	576440	576440	2026-08-06 07:48:01.912
cmsh7riu100f1v4jwrrpe3xzz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.003071908585	270753	270753	2026-08-06 07:48:01.912
cmsh7riu100f2v4jwuv45i8ap	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.002740509916	241544	241544	2026-08-06 07:48:01.912
cmsh7riu100f3v4jwsrx8xup8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.002668665919	235212	235211	2026-08-06 07:48:01.912
cmsh7riu100f4v4jwgunynsai	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.002403775653	211865	211864	2026-08-06 07:48:01.912
cmsh7riu100f5v4jw6ijcgd7b	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.002262265810	199392	199392	2026-08-06 07:48:01.912
cmsh7riu100f6v4jwqvm45gyh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.002047089677	180427	180427	2026-08-06 07:48:01.912
cmsh7riu100f7v4jw85mbbvcc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.001657893126	146124	146124	2026-08-06 07:48:01.912
cmsh7riu100f8v4jwoah8m2lh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.000793320088	69922	69921	2026-08-06 07:48:01.912
cmsh7riu200f9v4jw26zbdc2h	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.000782975587	69010	69010	2026-08-06 07:48:01.912
cmsh7riu200fav4jw5oi2pnma	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3fq0001v45k1k7ywxzg	88138383	0.000397144122	35004	35003	2026-08-06 07:48:01.912
cmsh7riu200fbv4jwg3xkttxb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	cmsh1b3iy0003v45kozth7aas	14488900	0.255216617841	3697808	3697808	2026-08-06 07:48:01.912
cmsh7riu200fcv4jw4vxhvfdf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	cmsh1b3iy0003v45kozth7aas	14488900	0.168145164377	2436238	2436238	2026-08-06 07:48:01.912
cmsh7riu200fdv4jw7hpkoqt8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	cmsh1b3iy0003v45kozth7aas	14488900	0.095133111848	1378374	1378374	2026-08-06 07:48:01.912
cmsh7riu200fev4jw93n6l861	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	cmsh1b3iy0003v45kozth7aas	14488900	0.092682384743	1342866	1342865	2026-08-06 07:48:01.912
cmsh7riu200ffv4jwrbfe6345	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	cmsh1b3iy0003v45kozth7aas	14488900	0.065256623277	945497	945496	2026-08-06 07:48:01.912
cmsh7riu200fgv4jwhlcc1x48	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	cmsh1b3iy0003v45kozth7aas	14488900	0.060440002174	875709	875709	2026-08-06 07:48:01.912
cmsh7riu200fhv4jwxgbxdrob	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	cmsh1b3iy0003v45kozth7aas	14488900	0.028480772188	412655	412655	2026-08-06 07:48:01.912
cmsh7riu200fiv4jwtnoxj5bp	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	cmsh1b3iy0003v45kozth7aas	14488900	0.018465317230	267542	267542	2026-08-06 07:48:01.912
cmsh7riu200fjv4jwc8wziscn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	cmsh1b3iy0003v45kozth7aas	14488900	0.010234682770	148289	148289	2026-08-06 07:48:01.912
cmsh7riu200fkv4jwf9kix2wn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	cmsh1b3iy0003v45kozth7aas	14488900	0.028000272513	405693	405693	2026-08-06 07:48:01.912
cmsh7riu200flv4jwi2sdooid	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	cmsh1b3iy0003v45kozth7aas	14488900	0.021882741181	317057	317056	2026-08-06 07:48:01.912
cmsh7riu200fmv4jww2k0wqih	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	cmsh1b3iy0003v45kozth7aas	14488900	0.020472951919	296631	296630	2026-08-06 07:48:01.912
cmsh7riu200fnv4jw0k7m529p	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	cmsh1b3iy0003v45kozth7aas	14488900	0.019004825906	275359	275359	2026-08-06 07:48:01.912
cmsh7riu200fov4jw851ciypg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	cmsh1b3iy0003v45kozth7aas	14488900	0.018298386399	265123	265123	2026-08-06 07:48:01.912
cmsh7riu200fpv4jw3f7d1782	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	cmsh1b3iy0003v45kozth7aas	14488900	0.018139007098	262814	262814	2026-08-06 07:48:01.912
cmsh7riu200fqv4jw0iz45tzv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	cmsh1b3iy0003v45kozth7aas	14488900	0.017495463866	253490	253490	2026-08-06 07:48:01.912
cmsh7riu200frv4jwi97dvfzi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	cmsh1b3iy0003v45kozth7aas	14488900	0.016459215942	238476	238475	2026-08-06 07:48:01.912
cmsh7riu200fsv4jwudj9depx	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	cmsh1b3iy0003v45kozth7aas	14488900	0.011937806535	172966	172965	2026-08-06 07:48:01.912
cmsh7riu300ftv4jwfhbca75i	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	cmsh1b3iy0003v45kozth7aas	14488900	0.008904380842	129015	129014	2026-08-06 07:48:01.912
cmsh7riu300fuv4jw5e4munh1	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	cmsh1b3iy0003v45kozth7aas	14488900	0.006540173219	94760	94759	2026-08-06 07:48:01.912
cmsh7riu300fvv4jw33m6jvnr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	cmsh1b3iy0003v45kozth7aas	14488900	0.003071908585	44509	44508	2026-08-06 07:48:01.912
cmsh7riu300fwv4jw6w5x6cm0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	cmsh1b3iy0003v45kozth7aas	14488900	0.002740509916	39707	39706	2026-08-06 07:48:01.912
cmsh7riu300fxv4jwdskyrgj0	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	cmsh1b3iy0003v45kozth7aas	14488900	0.002668665919	38666	38666	2026-08-06 07:48:01.912
cmsh7riu300fyv4jwtmknn3zt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	cmsh1b3iy0003v45kozth7aas	14488900	0.002403775653	34828	34828	2026-08-06 07:48:01.912
cmsh7riu300fzv4jwfowiy9sf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	cmsh1b3iy0003v45kozth7aas	14488900	0.002262265810	32778	32777	2026-08-06 07:48:01.912
cmsh7riu300g0v4jwhupt43wg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	cmsh1b3iy0003v45kozth7aas	14488900	0.002047089677	29660	29660	2026-08-06 07:48:01.912
cmsh7riu300g1v4jw4ma3v7y7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	cmsh1b3iy0003v45kozth7aas	14488900	0.001657893126	24021	24021	2026-08-06 07:48:01.912
cmsh7riu300g2v4jwusufx0pr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	cmsh1b3iy0003v45kozth7aas	14488900	0.000793320088	11494	11494	2026-08-06 07:48:01.912
cmsh7riu300g3v4jw5ltqb0d3	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	cmsh1b3iy0003v45kozth7aas	14488900	0.000782975587	11344	11344	2026-08-06 07:48:01.912
cmsh7riu300g4v4jwp70w68rz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	cmsh1b3iy0003v45kozth7aas	14488900	0.000397144122	5754	5754	2026-08-06 07:48:01.912
\.


--
-- Data for Name: allocation_projects; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allocation_projects (id, period_id, name, status, markup_rate, version, notes, created_at, updated_at, created_by_id, strict_rate_validation) FROM stdin;
cmsh91gb90002v4esaf6df04n	cmsh91g710000v4eskignzoni	2026년 하반기 공동비용 배부	DRAFT	0.050000	1	\N	2026-08-06 08:23:44.853	2026-08-06 08:23:44.853	cmsh72get0000v4fcr7uaqxdq	t
cmsgzh31v000uv4z40z4iq9r4	cmsgzh2zn000sv4z4v8577cif	2026 상반기 공동비용 배부	RECONCILED	0.050000	1	\N	2026-08-06 03:55:58.003	2026-08-14 00:32:08.692	cmsgzh1nn0007v4z4im98e204	f
\.


--
-- Data for Name: allocation_rate_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allocation_rate_versions (id, project_id, version, status, total_rate, notes, created_at, updated_at, created_by_id, approved_at) FROM stdin;
cmsgzh5e0003kv4z4for9fbns	cmsgzh31v000uv4z40z4iq9r4	1	SUPERSEDED	1.000000000000	\N	2026-08-06 03:56:01.032	2026-08-06 04:47:27.196	cmsgzh1nn0007v4z4im98e204	\N
cmsh1baqc007tv45kkhlal15n	cmsgzh31v000uv4z40z4iq9r4	2	APPROVED	1.000015450351	Excel import 2026-08-06	2026-08-06 04:47:27.252	2026-08-06 07:45:47.722	cmsgzh1nn0007v4z4im98e204	2026-08-06 07:45:47.655
cmsh9g3wa004yv4esja68ui5b	cmsh91gb90002v4esaf6df04n	1	DRAFT	1.000015450351	이전 반기(2026 H1) 배분율 불러옴	2026-08-06 08:35:08.602	2026-08-06 08:55:23.647	cmsh72get0000v4fcr7uaqxdq	\N
\.


--
-- Data for Name: allocation_rates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allocation_rates (id, rate_version_id, company_id, rate, created_at, updated_at) FROM stdin;
cmsgzh5e1003mv4z4tblcww63	cmsgzh5e0003kv4z4for9fbns	cmsgzh1qk000ev4z465dsa31f	0.233333333333	2026-08-06 03:56:01.032	2026-08-06 03:56:01.032
cmsgzh5e1003nv4z4tl3fmckx	cmsgzh5e0003kv4z4for9fbns	cmsgzh1v0000fv4z49m2akyhl	0.233333333333	2026-08-06 03:56:01.032	2026-08-06 03:56:01.032
cmsgzh5e1003ov4z4ystajr9t	cmsgzh5e0003kv4z4for9fbns	cmsgzh1zk000gv4z4qwke5rbo	0.233333333333	2026-08-06 03:56:01.032	2026-08-06 03:56:01.032
cmsgzh5e1003pv4z456mrwn5z	cmsgzh5e0003kv4z4for9fbns	cmsgzh249000hv4z4chsbifrv	0.100000000000	2026-08-06 03:56:01.032	2026-08-06 03:56:01.032
cmsgzh5e1003qv4z44a0shc4a	cmsgzh5e0003kv4z4for9fbns	cmsgzh28u000iv4z41ypn17aq	0.100000000000	2026-08-06 03:56:01.032	2026-08-06 03:56:01.032
cmsgzh5e1003rv4z448tgv6rx	cmsgzh5e0003kv4z4for9fbns	cmsgzh2db000jv4z4hyo2q4m1	0.100000000000	2026-08-06 03:56:01.032	2026-08-06 03:56:01.032
cmsh1baqd007vv45kmt4hjbfn	cmsh1baqc007tv45kkhlal15n	cmsh1b47a000jv45kt8g2btbf	0.255216617841	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd007wv45ktc1shatu	cmsh1baqc007tv45kkhlal15n	cmsh1b48y000kv45kqdgbm8j3	0.168145164377	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd007xv45ko8cu1pq0	cmsh1baqc007tv45kkhlal15n	cmsh1b4ae000lv45kgcv15flb	0.095133111848	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd007yv45kervf9w7r	cmsh1baqc007tv45kkhlal15n	cmsh1b4bt000mv45km6tt3ls4	0.092682384743	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd007zv45k60487vhn	cmsh1baqc007tv45kkhlal15n	cmsh1b4en000nv45k8o15vdeq	0.065256623277	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0080v45kx4mlqcrf	cmsh1baqc007tv45kkhlal15n	cmsh1b4g2000ov45ko6r97c9s	0.060440002174	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0081v45kmxbxh9i7	cmsh1baqc007tv45kkhlal15n	cmsh1b4hk000pv45kwzbq77t0	0.028480772188	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0082v45kbcu8wyr8	cmsh1baqc007tv45kkhlal15n	cmsh1b4ja000qv45k2n1ynwji	0.018465317230	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0083v45kr1pimhwv	cmsh1baqc007tv45kkhlal15n	cmsh1b4m4000rv45kwto42p9x	0.010234682770	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0084v45ks3ip44ek	cmsh1baqc007tv45kkhlal15n	cmsh1b4os000sv45kzco6xvgf	0.028000272513	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0085v45k4hauubc7	cmsh1baqc007tv45kkhlal15n	cmsh1b4q4000tv45kyya9ob77	0.021882741181	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0086v45ki96zz7tt	cmsh1baqc007tv45kkhlal15n	cmsh1b4sp000uv45krukvxdaz	0.020472951919	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0087v45k8uf4aiyf	cmsh1baqc007tv45kkhlal15n	cmsh1b4vb000vv45k58zhvwf2	0.019004825906	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0088v45ks5wxitj2	cmsh1baqc007tv45kkhlal15n	cmsh1b4wm000wv45k8lzp87ri	0.018298386399	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd0089v45kngz2rah4	cmsh1baqc007tv45kkhlal15n	cmsh1b4xx000xv45kg9lrhu6l	0.018139007098	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008av45kxdkfgf8k	cmsh1baqc007tv45kkhlal15n	cmsh1b4z9000yv45kfk582b97	0.017495463866	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008bv45kvr58gh15	cmsh1baqc007tv45kkhlal15n	cmsh1b51t000zv45k9adb5siw	0.016459215942	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008cv45kp47qaggt	cmsh1baqc007tv45kkhlal15n	cmsh1b5340010v45kazu0fg9d	0.011937806535	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008dv45k7x1xvfgp	cmsh1baqc007tv45kkhlal15n	cmsh1b54g0011v45kev87ke0m	0.008904380842	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008ev45ktpulb1rl	cmsh1baqc007tv45kkhlal15n	cmsh1b55v0012v45k9b9yxq0s	0.006540173219	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008fv45k3z17wjgx	cmsh1baqc007tv45kkhlal15n	cmsh1b58h0013v45knn7t3ki3	0.003071908585	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008gv45kne2shwdt	cmsh1baqc007tv45kkhlal15n	cmsh1b59s0014v45k3thfg7eo	0.002740509916	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008hv45kc5zws3o7	cmsh1baqc007tv45kkhlal15n	cmsh1b5b40015v45k8mcig9nr	0.002668665919	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008iv45kur79kktp	cmsh1baqc007tv45kkhlal15n	cmsh1b5ci0016v45kk7vqptov	0.002403775653	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008jv45ktitakge8	cmsh1baqc007tv45kkhlal15n	cmsh1b5fb0017v45kavuhad0r	0.002262265810	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008kv45k9izvhd9g	cmsh1baqc007tv45kkhlal15n	cmsh1b5ip0018v45kvj32jt75	0.002047089677	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008lv45kg1vwqosr	cmsh1baqc007tv45kkhlal15n	cmsh1b5k40019v45ku5nghgym	0.001657893126	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008mv45kbnqf39rk	cmsh1baqc007tv45kkhlal15n	cmsh1b5le001av45kliboorof	0.000793320088	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008nv45k1ra46v0f	cmsh1baqc007tv45kkhlal15n	cmsh1b5mu001bv45kjxfmgyyz	0.000782975587	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh1baqd008ov45kfvvgnuzc	cmsh1baqc007tv45kkhlal15n	cmsh1b5oa001cv45kedokcq0k	0.000397144122	2026-08-06 04:47:27.252	2026-08-06 04:47:27.252
cmsh9g3xf0051v4es2l97wpq6	cmsh9g3wa004yv4esja68ui5b	cmsgzh1qk000ev4z465dsa31f	0.000000000000	2026-08-06 08:35:08.602	2026-08-06 08:35:08.602
cmsh9g3xf0053v4es7np4504l	cmsh9g3wa004yv4esja68ui5b	cmsgzh1v0000fv4z49m2akyhl	0.000000000000	2026-08-06 08:35:08.602	2026-08-06 08:35:08.602
cmsh9g3xf0054v4es34ls9b7o	cmsh9g3wa004yv4esja68ui5b	cmsgzh1zk000gv4z4qwke5rbo	0.000000000000	2026-08-06 08:35:08.602	2026-08-06 08:35:08.602
cmsh9g3xf0057v4esx1cjkns5	cmsh9g3wa004yv4esja68ui5b	cmsgzh249000hv4z4chsbifrv	0.000000000000	2026-08-06 08:35:08.602	2026-08-06 08:35:08.602
cmsh9g3xf0058v4es9xxo1c3a	cmsh9g3wa004yv4esja68ui5b	cmsgzh28u000iv4z41ypn17aq	0.000000000000	2026-08-06 08:35:08.602	2026-08-06 08:35:08.602
cmsh9g3xf005av4es3rvn3vao	cmsh9g3wa004yv4esja68ui5b	cmsgzh2db000jv4z4hyo2q4m1	0.000000000000	2026-08-06 08:35:08.602	2026-08-06 08:35:08.602
cmsh9g3xf0052v4esrgjfeh1y	cmsh9g3wa004yv4esja68ui5b	cmsh1b48y000kv45kqdgbm8j3	0.168145164377	2026-08-06 08:35:08.602	2026-08-06 08:55:22.382
cmsh9g3xf0055v4esiv0600hb	cmsh9g3wa004yv4esja68ui5b	cmsh1b4ae000lv45kgcv15flb	0.095133111848	2026-08-06 08:35:08.602	2026-08-06 08:55:22.423
cmsh9g3xf0056v4esvhhfv4sf	cmsh9g3wa004yv4esja68ui5b	cmsh1b4bt000mv45km6tt3ls4	0.092682384743	2026-08-06 08:35:08.602	2026-08-06 08:55:22.461
cmsh9g3xf0059v4esr7r130c7	cmsh9g3wa004yv4esja68ui5b	cmsh1b4en000nv45k8o15vdeq	0.065256623277	2026-08-06 08:35:08.602	2026-08-06 08:55:22.5
cmsh9g3xf005bv4esqpsqgci8	cmsh9g3wa004yv4esja68ui5b	cmsh1b4g2000ov45ko6r97c9s	0.060440002174	2026-08-06 08:35:08.602	2026-08-06 08:55:22.54
cmsh9g3xg005cv4ese6lk137s	cmsh9g3wa004yv4esja68ui5b	cmsh1b4hk000pv45kwzbq77t0	0.028480772188	2026-08-06 08:35:08.602	2026-08-06 08:55:22.583
cmsh9g3xg005dv4esr0u596uy	cmsh9g3wa004yv4esja68ui5b	cmsh1b4ja000qv45k2n1ynwji	0.018465317230	2026-08-06 08:35:08.602	2026-08-06 08:55:22.623
cmsh9g3xg005ev4esggsrxkey	cmsh9g3wa004yv4esja68ui5b	cmsh1b4m4000rv45kwto42p9x	0.010234682770	2026-08-06 08:35:08.602	2026-08-06 08:55:22.665
cmsh9g3xg005fv4est075qatc	cmsh9g3wa004yv4esja68ui5b	cmsh1b4os000sv45kzco6xvgf	0.028000272513	2026-08-06 08:35:08.602	2026-08-06 08:55:22.704
cmsh9g3xg005gv4esdirhjii0	cmsh9g3wa004yv4esja68ui5b	cmsh1b4q4000tv45kyya9ob77	0.021882741181	2026-08-06 08:35:08.602	2026-08-06 08:55:22.743
cmsh9g3xg005hv4esyzj2ycls	cmsh9g3wa004yv4esja68ui5b	cmsh1b4sp000uv45krukvxdaz	0.020472951919	2026-08-06 08:35:08.602	2026-08-06 08:55:22.778
cmsh9g3xg005iv4esd3r33smo	cmsh9g3wa004yv4esja68ui5b	cmsh1b4vb000vv45k58zhvwf2	0.019004825906	2026-08-06 08:35:08.602	2026-08-06 08:55:22.816
cmsh9g3xg005jv4esne8d6odx	cmsh9g3wa004yv4esja68ui5b	cmsh1b4wm000wv45k8lzp87ri	0.018298386399	2026-08-06 08:35:08.602	2026-08-06 08:55:22.857
cmsh9g3xg005kv4es7uoda5si	cmsh9g3wa004yv4esja68ui5b	cmsh1b4xx000xv45kg9lrhu6l	0.018139007098	2026-08-06 08:35:08.602	2026-08-06 08:55:22.895
cmsh9g3xg005lv4es914mkljx	cmsh9g3wa004yv4esja68ui5b	cmsh1b4z9000yv45kfk582b97	0.017495463866	2026-08-06 08:35:08.602	2026-08-06 08:55:22.933
cmsh9g3xg005mv4espvjjqwra	cmsh9g3wa004yv4esja68ui5b	cmsh1b51t000zv45k9adb5siw	0.016459215942	2026-08-06 08:35:08.602	2026-08-06 08:55:22.976
cmsh9g3xg005nv4esr2ck3lo2	cmsh9g3wa004yv4esja68ui5b	cmsh1b5340010v45kazu0fg9d	0.011937806535	2026-08-06 08:35:08.602	2026-08-06 08:55:23.014
cmsh9g3xg005ov4esu1dddyp5	cmsh9g3wa004yv4esja68ui5b	cmsh1b54g0011v45kev87ke0m	0.008904380842	2026-08-06 08:35:08.602	2026-08-06 08:55:23.053
cmsh9g3xf0050v4esfhxydikz	cmsh9g3wa004yv4esja68ui5b	cmsh1b47a000jv45kt8g2btbf	0.255216617841	2026-08-06 08:35:08.602	2026-08-06 08:55:22.33
cmsh9g3xg005pv4esk8c6efhu	cmsh9g3wa004yv4esja68ui5b	cmsh1b55v0012v45k9b9yxq0s	0.006540173219	2026-08-06 08:35:08.602	2026-08-06 08:55:23.093
cmsh9g3xg005qv4eswdi9sfw3	cmsh9g3wa004yv4esja68ui5b	cmsh1b58h0013v45knn7t3ki3	0.003071908585	2026-08-06 08:35:08.602	2026-08-06 08:55:23.135
cmsh9g3xg005rv4esv3xb6892	cmsh9g3wa004yv4esja68ui5b	cmsh1b59s0014v45k3thfg7eo	0.002740509916	2026-08-06 08:35:08.602	2026-08-06 08:55:23.175
cmsh9g3xg005sv4es2o21jqfh	cmsh9g3wa004yv4esja68ui5b	cmsh1b5b40015v45k8mcig9nr	0.002668665919	2026-08-06 08:35:08.602	2026-08-06 08:55:23.216
cmsh9g3xg005tv4escs98zqqw	cmsh9g3wa004yv4esja68ui5b	cmsh1b5ci0016v45kk7vqptov	0.002403775653	2026-08-06 08:35:08.602	2026-08-06 08:55:23.257
cmsh9g3xg005uv4es5fk5bazh	cmsh9g3wa004yv4esja68ui5b	cmsh1b5fb0017v45kavuhad0r	0.002262265810	2026-08-06 08:35:08.602	2026-08-06 08:55:23.299
cmsh9g3xg005vv4es43swnt07	cmsh9g3wa004yv4esja68ui5b	cmsh1b5ip0018v45kvj32jt75	0.002047089677	2026-08-06 08:35:08.602	2026-08-06 08:55:23.339
cmsh9g3xg005wv4eskz5jrcrs	cmsh9g3wa004yv4esja68ui5b	cmsh1b5k40019v45ku5nghgym	0.001657893126	2026-08-06 08:35:08.602	2026-08-06 08:55:23.381
cmsh9g3xg005xv4es5e80t28t	cmsh9g3wa004yv4esja68ui5b	cmsh1b5le001av45kliboorof	0.000793320088	2026-08-06 08:35:08.602	2026-08-06 08:55:23.422
cmsh9g3xg005yv4esqf715u5f	cmsh9g3wa004yv4esja68ui5b	cmsh1b5mu001bv45kjxfmgyyz	0.000782975587	2026-08-06 08:35:08.602	2026-08-06 08:55:23.462
cmsh9g3xg005zv4es8p4zgs25	cmsh9g3wa004yv4esja68ui5b	cmsh1b5oa001cv45kedokcq0k	0.000397144122	2026-08-06 08:35:08.602	2026-08-06 08:55:23.507
\.


--
-- Data for Name: allocation_runs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allocation_runs (id, project_id, rate_version_id, run_number, run_type, status, input_snapshot, checksum, total_cost, total_allocated, total_markup, total_billing, rounding_diff, created_at, updated_at, created_by_id, approved_at) FROM stdin;
cmsh7rit90009v4jw0wy1a0dv	cmsgzh31v000uv4z40z4iq9r4	cmsh1baqc007tv45kkhlal15n	1	FINAL	EXECUTED	{"costs": [{"accountCode": "ACC-18", "accountName": "기타지급", "sourceTotal": "0", "allocatedSum": "0", "roundingDiff": "0", "costAccountId": "cmsh1b44c000hv45k8wyhshmu"}, {"accountCode": "ACC-12", "accountName": "지급수수료", "sourceTotal": "2632018", "allocatedSum": "2632044", "roundingDiff": "-26", "costAccountId": "cmsh1b3v5000bv45kkg5k7jdr"}, {"accountCode": "ACC-11", "accountName": "국내출장비", "sourceTotal": "6211549", "allocatedSum": "6211630", "roundingDiff": "-81", "costAccountId": "cmsh1b3tj000av45kp4w6n24d"}, {"accountCode": "ACC-16", "accountName": "감가상각비(차량)", "sourceTotal": "697726", "allocatedSum": "697725", "roundingDiff": "1", "costAccountId": "cmsh1b41f000fv45k4qgcw4ac"}, {"accountCode": "ACC-19", "accountName": "지급수수료(일반)", "sourceTotal": "376200", "allocatedSum": "376190", "roundingDiff": "10", "costAccountId": "cmsh1b45p000iv45krmpx8fmv"}, {"accountCode": "ACC-14", "accountName": "도서인쇄비", "sourceTotal": "15750", "allocatedSum": "15738", "roundingDiff": "12", "costAccountId": "cmsh1b3y6000dv45k9tvmq64r"}, {"accountCode": "ACC-05", "accountName": "국민연금", "sourceTotal": "15123420", "allocatedSum": "15123638", "roundingDiff": "-218", "costAccountId": "cmsh1b3kc0004v45kv13t1190"}, {"accountCode": "ACC-08", "accountName": "식대(식권)", "sourceTotal": "6856725", "allocatedSum": "6856817", "roundingDiff": "-92", "costAccountId": "cmsh1b3ow0007v45kegisx5jd"}, {"accountCode": "ACC-09", "accountName": "업무추진비", "sourceTotal": "7454730", "allocatedSum": "7454828", "roundingDiff": "-98", "costAccountId": "cmsh1b3qm0008v45krlvaq333"}, {"accountCode": "ACC-17", "accountName": "차량관리비", "sourceTotal": "723205", "allocatedSum": "723199", "roundingDiff": "6", "costAccountId": "cmsh1b42x000gv45kutf85p3y"}, {"accountCode": "ACC-13", "accountName": "통신비", "sourceTotal": "367670", "allocatedSum": "367658", "roundingDiff": "12", "costAccountId": "cmsh1b3wp000cv45k0eshx54k"}, {"accountCode": "ACC-10", "accountName": "소모품비", "sourceTotal": "14915660", "allocatedSum": "14915876", "roundingDiff": "-216", "costAccountId": "cmsh1b3rx0009v45kvzp0f6by"}, {"accountCode": "ACC-06", "accountName": "산재보험", "sourceTotal": "2820330", "allocatedSum": "2820359", "roundingDiff": "-29", "costAccountId": "cmsh1b3lv0005v45k1i15ud1r"}, {"accountCode": "ACC-03", "accountName": "복리후생비(기타)", "sourceTotal": "2400000", "allocatedSum": "2400023", "roundingDiff": "-23", "costAccountId": "cmsh1b3hc0002v45kkzg3z9wd"}, {"accountCode": "ACC-15", "accountName": "국외출장비", "sourceTotal": "17810067", "allocatedSum": "17810328", "roundingDiff": "-261", "costAccountId": "cmsh1b3zn000ev45ke50rracp"}, {"accountCode": "ACC-01", "accountName": "급료와임금", "sourceTotal": "268459502", "allocatedSum": "268463633", "roundingDiff": "-4131", "costAccountId": "cmsh1b3cp0000v45kdnl2mv4k"}, {"accountCode": "ACC-07", "accountName": "고용보험", "sourceTotal": "4790640", "allocatedSum": "4790696", "roundingDiff": "-56", "costAccountId": "cmsh1b3ne0006v45ka0wrz3cs"}, {"accountCode": "ACC-02", "accountName": "상여금", "sourceTotal": "88138383", "allocatedSum": "88139730", "roundingDiff": "-1347", "costAccountId": "cmsh1b3fq0001v45k1k7ywxzg"}, {"accountCode": "ACC-04", "accountName": "건강보험", "sourceTotal": "14488900", "allocatedSum": "14489112", "roundingDiff": "-212", "costAccountId": "cmsh1b3iy0003v45kozth7aas"}], "rateTotal": 100.0015450351, "markupRate": 0.05}	416c81b9	454282475	454289080	4371050	458660130	-6605	2026-08-06 07:48:01.912	2026-08-06 07:48:01.912	cmsh72get0000v4fcr7uaqxdq	\N
\.


--
-- Data for Name: approval_actions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.approval_actions (id, request_id, user_id, action, comment, created_at) FROM stdin;
\.


--
-- Data for Name: approval_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.approval_requests (id, type, status, entity_type, entity_id, requested_by, reason, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: attachments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attachments (id, entity_type, entity_id, file_name, file_path, mime_type, file_size, uploaded_by, created_at) FROM stdin;
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_logs (id, user_id, action, entity_type, entity_id, before_data, after_data, reason, ip_address, created_at) FROM stdin;
cmsh78zku0001v4jweaxlmrxa	cmsgzh1nn0007v4z4im98e204	UPDATE	AllocationProject	cmsgzh31v000uv4z40z4iq9r4	{"name": "2026 상반기 Scripture Room 공동비용 배부"}	{"name": "2026 상반기 Scripture Room 공동비용 배부"}	\N	\N	2026-08-06 07:33:37.177
cmsh7nguh0003v4jwgtv4eec9	cmsh72get0000v4fcr7uaqxdq	UPDATE	AllocationProject	cmsgzh31v000uv4z40z4iq9r4	{"name": "2026 상반기 Scripture Room 공동비용 배부"}	{"name": "2026 상반기 공동비용 배부"}	\N	\N	2026-08-06 07:44:52.746
cmsh7o2590005v4jwlj3hd4li	cmsh72get0000v4fcr7uaqxdq	COST_CONFIRM	AllocationProject	cmsgzh31v000uv4z40z4iq9r4	\N	\N	\N	\N	2026-08-06 07:45:20.349
cmsh7onaw0007v4jw1ufs9ko0	cmsh72get0000v4fcr7uaqxdq	RATE_APPROVE	AllocationRateVersion	cmsh1baqc007tv45kkhlal15n	\N	{"totalRate": 100.0015450351}	\N	\N	2026-08-06 07:45:47.768
cmsh7rj3600h1v4jwqzortrl6	cmsh72get0000v4fcr7uaqxdq	ALLOCATION_EXECUTE	AllocationRun	cmsh7rit90009v4jw0wy1a0dv	\N	{"runType": "FINAL", "checksum": "416c81b9", "runNumber": 1}	\N	\N	2026-08-06 07:48:02.274
cmsha65gu007pv4es5cg9b1sv	cmsh72get0000v4fcr7uaqxdq	RATE_IMPORT	AllocationRateVersion	cmsh9g3wa004yv4esja68ui5b	\N	{"totalRate": 100.0015450351, "companyCount": 30, "sourcePeriod": "2026 H1", "sourceVersionId": "cmsh1baqc007tv45kkhlal15n"}	\N	\N	2026-08-06 08:55:23.694
cmsha6v5l007rv4es4j9e4hfc	cmsh72get0000v4fcr7uaqxdq	DELETE	Company	cmsgzh1qk000ev4z465dsa31f	{"id": "cmsgzh1qk000ev4z465dsa31f", "code": "KR-HQ", "nameEn": "KBI Headquarters", "nameKo": "KBI 본사", "currency": "KRW", "isActive": true, "createdAt": "2026-08-06T03:55:56.301Z", "deletedAt": null, "sortOrder": 1, "updatedAt": "2026-08-06T03:55:56.301Z", "companyType": "DOMESTIC", "createdById": null, "contactEmail": null, "contactPhone": null, "billingLanguage": "KO"}	\N	\N	\N	2026-08-06 08:55:56.985
cmsha6ybe007tv4esdsn8rise	cmsh72get0000v4fcr7uaqxdq	DELETE	Company	cmsgzh1v0000fv4z49m2akyhl	{"id": "cmsgzh1v0000fv4z49m2akyhl", "code": "KR-01", "nameEn": "KBI Seoul", "nameKo": "KBI 서울", "currency": "KRW", "isActive": true, "createdAt": "2026-08-06T03:55:56.460Z", "deletedAt": null, "sortOrder": 2, "updatedAt": "2026-08-06T03:55:56.460Z", "companyType": "DOMESTIC", "createdById": null, "contactEmail": null, "contactPhone": null, "billingLanguage": "KO"}	\N	\N	\N	2026-08-06 08:56:01.082
cmsha7178007vv4eszq30sod5	cmsh72get0000v4fcr7uaqxdq	DELETE	Company	cmsgzh1zk000gv4z4qwke5rbo	{"id": "cmsgzh1zk000gv4z4qwke5rbo", "code": "KR-02", "nameEn": "KBI Busan", "nameKo": "KBI 부산", "currency": "KRW", "isActive": true, "createdAt": "2026-08-06T03:55:56.625Z", "deletedAt": null, "sortOrder": 3, "updatedAt": "2026-08-06T03:55:56.625Z", "companyType": "DOMESTIC", "createdById": null, "contactEmail": null, "contactPhone": null, "billingLanguage": "KO"}	\N	\N	\N	2026-08-06 08:56:04.82
cmsha7f2c007xv4esr2jeue5q	cmsh72get0000v4fcr7uaqxdq	DELETE	Company	cmsgzh249000hv4z4chsbifrv	{"id": "cmsgzh249000hv4z4chsbifrv", "code": "US-01", "nameEn": "KBI America Inc.", "nameKo": "KBI America", "currency": "KRW", "isActive": true, "createdAt": "2026-08-06T03:55:56.793Z", "deletedAt": null, "sortOrder": 4, "updatedAt": "2026-08-06T03:55:56.793Z", "companyType": "OVERSEAS", "createdById": null, "contactEmail": null, "contactPhone": null, "billingLanguage": "EN"}	\N	\N	\N	2026-08-06 08:56:22.788
cmsha7jbk007zv4eseyys833w	cmsh72get0000v4fcr7uaqxdq	DELETE	Company	cmsgzh2db000jv4z4hyo2q4m1	{"id": "cmsgzh2db000jv4z4hyo2q4m1", "code": "CN-01", "nameEn": "KBI China Ltd.", "nameKo": "KBI China", "currency": "KRW", "isActive": true, "createdAt": "2026-08-06T03:55:57.119Z", "deletedAt": null, "sortOrder": 6, "updatedAt": "2026-08-06T03:55:57.119Z", "companyType": "OVERSEAS", "createdById": null, "contactEmail": null, "contactPhone": null, "billingLanguage": "EN"}	\N	\N	\N	2026-08-06 08:56:28.305
cmss7ps3w0005v4fobmnj9ywz	cmsgzh1nn0007v4z4im98e204	RECONCILE	AllocationRun	cmsh7rit90009v4jw0wy1a0dv	\N	{"isBalanced": true}	\N	\N	2026-08-14 00:32:08.588
cmss7ps7g0007v4fo5tpidv5h	cmsgzh1nn0007v4z4im98e204	RECONCILE	AllocationRun	cmsh7rit90009v4jw0wy1a0dv	\N	{"isBalanced": true}	\N	\N	2026-08-14 00:32:08.716
cmss7q7q400xlv4foz2ww1xgx	cmsgzh1nn0007v4z4im98e204	INVOICE_GENERATE	AllocationRun	cmsh7rit90009v4jw0wy1a0dv	\N	{"count": 30}	\N	\N	2026-08-14 00:32:28.828
\.


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.companies (id, code, name_ko, name_en, company_type, billing_language, currency, contact_email, contact_phone, is_active, sort_order, created_at, updated_at, deleted_at, created_by_id) FROM stdin;
cmsgzh28u000iv4z41ypn17aq	JP-01	KBI Japan	KBI Japan K.K.	OVERSEAS	EN	KRW	\N	\N	t	5	2026-08-06 03:55:56.959	2026-08-06 03:55:56.959	\N	\N
cmsh1b47a000jv45kt8g2btbf	METAL	케이비아이메탈㈜ 음성공장	\N	DOMESTIC	KO	KRW	\N	\N	t	1	2026-08-06 04:47:18.791	2026-08-06 04:47:18.791	\N	\N
cmsh1b48y000kv45kqdgbm8j3	SILUP	케이비아이동국실업 ㈜ 신아산공장	\N	DOMESTIC	KO	KRW	\N	\N	t	2	2026-08-06 04:47:18.851	2026-08-06 04:47:18.851	\N	\N
cmsh1b4ae000lv45kgcv15flb	AT-HQ	케이비오토텍 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	3	2026-08-06 04:47:18.902	2026-08-06 04:47:18.902	\N	\N
cmsh1b4bt000mv45km6tt3ls4	KDK	KDK Automotive GmbH	KDK Automotive GmbH	OVERSEAS	EN	KRW	\N	\N	t	4	2026-08-06 04:47:18.953	2026-08-06 04:47:18.953	\N	\N
cmsh1b4en000nv45k8o15vdeq	COSMO	케이비아이코스모링크 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	5	2026-08-06 04:47:19.055	2026-08-06 04:47:19.055	\N	\N
cmsh1b4g2000ov45ko6r97c9s	STEEL	케이비아이동양철관 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	6	2026-08-06 04:47:19.106	2026-08-06 04:47:19.106	\N	\N
cmsh1b4hk000pv45kwzbq77t0	CONST	케이비아이건설 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	7	2026-08-06 04:47:19.16	2026-08-06 04:47:19.16	\N	\N
cmsh1b4ja000qv45k2n1ynwji	REMICON-AJ	KB REMICON L.L.C	KB REMICON L.L.C	OVERSEAS	EN	KRW	\N	\N	t	8	2026-08-06 04:47:19.222	2026-08-06 04:47:19.222	\N	\N
cmsh1b4m4000rv45kwto42p9x	REMICON-SH	K B READY MIX L.L.C	K B READY MIX L.L.C	OVERSEAS	EN	KRW	\N	\N	t	9	2026-08-06 04:47:19.324	2026-08-06 04:47:19.324	\N	\N
cmsh1b4os000sv45kzco6xvgf	HOSPITAL	의료법인갑을의료재단갑을장유병원	\N	DOMESTIC	KO	KRW	\N	\N	t	10	2026-08-06 04:47:19.42	2026-08-06 04:47:19.42	\N	\N
cmsh1b4q4000tv45kyya9ob77	MEXICO	DONG KOOK MEXICO	DONG KOOK MEXICO	OVERSEAS	EN	KRW	\N	\N	t	11	2026-08-06 04:47:19.468	2026-08-06 04:47:19.468	\N	\N
cmsh1b4sp000uv45krukvxdaz	VINA	KBI COSMOLINK VINA CABLE CO., LTD	KBI COSMOLINK VINA CABLE CO., LTD	OVERSEAS	EN	KRW	\N	\N	t	12	2026-08-06 04:47:19.561	2026-08-06 04:47:19.561	\N	\N
cmsh1b4vb000vv45k58zhvwf2	ACETEC	㈜케이비아이에이스텍 아산1공장	\N	DOMESTIC	KO	KRW	\N	\N	t	13	2026-08-06 04:47:19.655	2026-08-06 04:47:19.655	\N	\N
cmsh1b4wm000wv45k8lzp87ri	KUKIN	주식회사 케이비아이국인산업	\N	DOMESTIC	KO	KRW	\N	\N	t	14	2026-08-06 04:47:19.702	2026-08-06 04:47:19.702	\N	\N
cmsh1b4xx000xv45kg9lrhu6l	ALLOY	케이비아이알로이 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	15	2026-08-06 04:47:19.749	2026-08-06 04:47:19.749	\N	\N
cmsh1b4z9000yv45kfk582b97	YANCHENG	YANCHENG DONG KOOK AUTO PARTS CO., LTD.	YANCHENG DONG KOOK AUTO PARTS CO., LTD.	OVERSEAS	EN	KRW	\N	\N	t	16	2026-08-06 04:47:19.797	2026-08-06 04:47:19.797	\N	\N
cmsh1b51t000zv45k9adb5siw	SEOKMOON	주식회사 석문에너지	\N	DOMESTIC	KO	KRW	\N	\N	t	17	2026-08-06 04:47:19.889	2026-08-06 04:47:19.889	\N	\N
cmsh1b5340010v45kazu0fg9d	HAPSUM	갑을합섬㈜	\N	DOMESTIC	KO	KRW	\N	\N	t	18	2026-08-06 04:47:19.936	2026-08-06 04:47:19.936	\N	\N
cmsh1b54g0011v45kev87ke0m	KBI-TEC	㈜케이비아이텍	\N	DOMESTIC	KO	KRW	\N	\N	t	19	2026-08-06 04:47:19.984	2026-08-06 04:47:19.984	\N	\N
cmsh1b55v0012v45k9b9yxq0s	AT-IN	KB AUTOTECH INDIA PRIVATE LIMITED	KB AUTOTECH INDIA PRIVATE LIMITED	OVERSEAS	EN	KRW	\N	\N	t	20	2026-08-06 04:47:20.036	2026-08-06 04:47:20.036	\N	\N
cmsh1b58h0013v45knn7t3ki3	DAEGU-ECO	대구에코 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	21	2026-08-06 04:47:20.129	2026-08-06 04:47:20.129	\N	\N
cmsh1b59s0014v45k3thfg7eo	USANG	케이비아이유상테크 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	22	2026-08-06 04:47:20.176	2026-08-06 04:47:20.176	\N	\N
cmsh1b5b40015v45k8mcig9nr	C23	주식회사 케이비아이울트라	\N	DOMESTIC	KO	KRW	\N	\N	t	23	2026-08-06 04:47:20.224	2026-08-06 04:47:20.224	\N	\N
cmsh1b5ci0016v45kk7vqptov	JAPAN	KBI JAPAN CO., LTD.	KBI JAPAN CO., LTD.	OVERSEAS	EN	KRW	\N	\N	t	24	2026-08-06 04:47:20.274	2026-08-06 04:47:20.274	\N	\N
cmsh1b5fb0017v45kavuhad0r	C25	LAbO KIGOSHI CO., LTD.	LAbO KIGOSHI CO., LTD.	OVERSEAS	EN	KRW	\N	\N	t	25	2026-08-06 04:47:20.376	2026-08-06 04:47:20.376	\N	\N
cmsh1b5ip0018v45kvj32jt75	C26	케이비아이정무산업 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	26	2026-08-06 04:47:20.497	2026-08-06 04:47:20.497	\N	\N
cmsh1b5k40019v45ku5nghgym	BEAUTYN	케이비아이뷰티앤 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	27	2026-08-06 04:47:20.548	2026-08-06 04:47:20.548	\N	\N
cmsh1b5le001av45kliboorof	IND-DEV	케이비아이산업개발 주식회사	\N	DOMESTIC	KO	KRW	\N	\N	t	28	2026-08-06 04:47:20.595	2026-08-06 04:47:20.595	\N	\N
cmsh1b5mu001bv45kjxfmgyyz	C29	주식회사 케이비아이상사	\N	DOMESTIC	KO	KRW	\N	\N	t	29	2026-08-06 04:47:20.646	2026-08-06 04:47:20.646	\N	\N
cmsh1b5oa001cv45kedokcq0k	C30	동국화공㈜	\N	DOMESTIC	KO	KRW	\N	\N	t	30	2026-08-06 04:47:20.698	2026-08-06 04:47:20.698	\N	\N
cmsgzh1qk000ev4z465dsa31f	KR-HQ	KBI 본사	KBI Headquarters	DOMESTIC	KO	KRW	\N	\N	f	1	2026-08-06 03:55:56.301	2026-08-06 08:55:56.914	2026-08-06 08:55:56.911	\N
cmsgzh1v0000fv4z49m2akyhl	KR-01	KBI 서울	KBI Seoul	DOMESTIC	KO	KRW	\N	\N	f	2	2026-08-06 03:55:56.46	2026-08-06 08:56:01.004	2026-08-06 08:56:01	\N
cmsgzh1zk000gv4z4qwke5rbo	KR-02	KBI 부산	KBI Busan	DOMESTIC	KO	KRW	\N	\N	f	3	2026-08-06 03:55:56.625	2026-08-06 08:56:04.749	2026-08-06 08:56:04.745	\N
cmsgzh249000hv4z4chsbifrv	US-01	KBI America	KBI America Inc.	OVERSEAS	EN	KRW	\N	\N	f	4	2026-08-06 03:55:56.793	2026-08-06 08:56:22.706	2026-08-06 08:56:22.704	\N
cmsgzh2db000jv4z4hyo2q4m1	CN-01	KBI China	KBI China Ltd.	OVERSEAS	EN	KRW	\N	\N	f	6	2026-08-06 03:55:57.119	2026-08-06 08:56:28.237	2026-08-06 08:56:28.235	\N
\.


--
-- Data for Name: company_addresses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.company_addresses (id, company_id, address_type, line1, line2, city, state, postal_code, country, is_primary, created_at, updated_at, deleted_at) FROM stdin;
addr-KR-HQ	cmsgzh1qk000ev4z465dsa31f	BILLING	서울특별시 중구 세종대로 123	\N	서울	\N	\N	KR	t	2026-08-06 03:55:56.384	2026-08-06 03:55:56.384	\N
addr-KR-01	cmsgzh1v0000fv4z49m2akyhl	BILLING	서울특별시 중구 세종대로 123	\N	서울	\N	\N	KR	t	2026-08-06 03:55:56.544	2026-08-06 03:55:56.544	\N
addr-KR-02	cmsgzh1zk000gv4z4qwke5rbo	BILLING	서울특별시 중구 세종대로 123	\N	서울	\N	\N	KR	t	2026-08-06 03:55:56.716	2026-08-06 03:55:56.716	\N
addr-US-01	cmsgzh249000hv4z4chsbifrv	BILLING	123 Business Park Drive	\N	New York	\N	\N	US	t	2026-08-06 03:55:56.876	2026-08-06 03:55:56.876	\N
addr-JP-01	cmsgzh28u000iv4z41ypn17aq	BILLING	123 Business Park Drive	\N	New York	\N	\N	JP	t	2026-08-06 03:55:57.04	2026-08-06 03:55:57.04	\N
addr-CN-01	cmsgzh2db000jv4z4hyo2q4m1	BILLING	123 Business Park Drive	\N	New York	\N	\N	CN	t	2026-08-06 03:55:57.203	2026-08-06 03:55:57.203	\N
addr-KDK	cmsh1b4bt000mv45km6tt3ls4	BILLING	Industriestrasse 6, 63607 Wächtersbach, Germany	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:19.004	2026-08-06 04:47:19.004	\N
addr-REMICON-AJ	cmsh1b4ja000qv45k2n1ynwji	BILLING	Land No. 1, Bahya, Ajman, United Arab Emirates	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:19.274	2026-08-06 04:47:19.274	\N
addr-REMICON-SH	cmsh1b4m4000rv45kwto42p9x	BILLING	OFFICE 105, Al Qasba, Al Khan, Sharjah, UAE	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:19.371	2026-08-06 04:47:19.371	\N
addr-MEXICO	cmsh1b4q4000tv45kyya9ob77	BILLING	1255 Avenida del Parque, Colonia Otra No Especificada en el Catálogo,\nPesquería, Pesquería Municipality,\nNuevo León 66650,\nMexico	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:19.516	2026-08-06 04:47:19.516	\N
addr-VINA	cmsh1b4sp000uv45krukvxdaz	BILLING	Plot 1, Khai Quang Industrial Zone, Vinh Phuc Ward, Phu Tho Province, Vietnam	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:19.609	2026-08-06 04:47:19.609	\N
addr-YANCHENG	cmsh1b4z9000yv45kfk582b97	BILLING	No. 65, Huangshan South Road,\nYancheng Economic Development Zone,\nYancheng, Jiangsu, China	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:19.843	2026-08-06 04:47:19.843	\N
addr-AT-IN	cmsh1b55v0012v45k9b9yxq0s	BILLING	No. 679, Kottaiyur Village, Kannur Post, Thiruvallur, Thiruvallur, Tamil Nadu, India, 602108	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:20.081	2026-08-06 04:47:20.081	\N
addr-JAPAN	cmsh1b5ci0016v45kk7vqptov	BILLING	9-9 Yotsuya-Sakamachi, Shinjuku-ku, Tokyo, Japan	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:20.328	2026-08-06 04:47:20.328	\N
addr-C25	cmsh1b5fb0017v45kavuhad0r	BILLING	9-6 Imado 2-chome, Taito-ku, Tokyo, Japan	\N	\N	\N	\N	OVERSEAS	t	2026-08-06 04:47:20.447	2026-08-06 04:47:20.447	\N
\.


--
-- Data for Name: company_allocation_summaries; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.company_allocation_summaries (id, run_id, company_id, pre_round_total, allocation_amount, markup_amount, billing_amount, created_at) FROM stdin;
cmsh7riu800g6v4jwk37a79vl	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	115940429	115940420	0	115940420	2026-08-06 07:48:01.912
cmsh7riu800g7v4jw0ugrgjlv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	76385392	76385390	0	76385390	2026-08-06 07:48:01.912
cmsh7riu800g8v4jw7rfxyqdf	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	43217297	43217290	0	43217290	2026-08-06 07:48:01.912
cmsh7riu800g9v4jwr90ztn5d	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	42103972	42103970	2105190	44209160	2026-08-06 07:48:01.912
cmsh7riu800gav4jwcxsl8pvu	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	29644929	29644920	0	29644920	2026-08-06 07:48:01.912
cmsh7riu800gbv4jw1h9gbfxb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	27456825	27456820	0	27456820	2026-08-06 07:48:01.912
cmsh7riu800gcv4jwh4g6vtq8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	12938306	12938300	0	12938300	2026-08-06 07:48:01.912
cmsh7riu800gdv4jwcowhr00e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	8388461	8388460	419420	8807880	2026-08-06 07:48:01.912
cmsh7riu800gev4jwxe2lvlpy	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	4649429	4649420	232470	4881890	2026-08-06 07:48:01.912
cmsh7riu800gfv4jwa0za2tvi	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	12720025	12720020	0	12720020	2026-08-06 07:48:01.912
cmsh7riu800ggv4jwre0jiouc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	9940935	9940930	497040	10437970	2026-08-06 07:48:01.912
cmsh7riu800ghv4jwid85n31e	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	9300495	9300490	465020	9765510	2026-08-06 07:48:01.912
cmsh7riu800giv4jwgmsx4hxn	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	8633551	8633550	0	8633550	2026-08-06 07:48:01.912
cmsh7riu800gjv4jwp0skc483	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	8312628	8312620	0	8312620	2026-08-06 07:48:01.912
cmsh7riu800gkv4jwujwv1fin	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	8240224	8240220	0	8240220	2026-08-06 07:48:01.912
cmsh7riu800glv4jwkn6iwilx	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	7947873	7947870	397390	8345260	2026-08-06 07:48:01.912
cmsh7riu800gmv4jwo87il3hq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	7477125	7477120	0	7477120	2026-08-06 07:48:01.912
cmsh7riu800gnv4jwr9o18jxu	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	5423129	5423120	0	5423120	2026-08-06 07:48:01.912
cmsh7riu800gov4jwnev4h4le	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	4045092	4045090	0	4045090	2026-08-06 07:48:01.912
cmsh7riu800gpv4jwmfoh2ixv	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	2971077	2971070	148550	3119620	2026-08-06 07:48:01.912
cmsh7riu800gqv4jwqxa1lh8i	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	1395506	1395500	0	1395500	2026-08-06 07:48:01.912
cmsh7riu800grv4jw2dcg3cv5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	1244955	1244950	0	1244950	2026-08-06 07:48:01.912
cmsh7riu800gsv4jw4liyw41z	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	1212318	1212310	0	1212310	2026-08-06 07:48:01.912
cmsh7riu900gtv4jwc4y3kcfz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	1091985	1091980	54590	1146570	2026-08-06 07:48:01.912
cmsh7riu900guv4jwyr5xqchm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	1027700	1027700	51380	1079080	2026-08-06 07:48:01.912
cmsh7riu900gvv4jw0dlfigwh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	929948	929940	0	929940	2026-08-06 07:48:01.912
cmsh7riu900gwv4jwi2agutnt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	753144	753140	0	753140	2026-08-06 07:48:01.912
cmsh7riu900gxv4jwbd90oicg	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	360381	360380	0	360380	2026-08-06 07:48:01.912
cmsh7riu900gyv4jw7um28zy4	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	355683	355680	0	355680	2026-08-06 07:48:01.912
cmsh7riu900gzv4jwqlguv0xk	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	180410	180410	0	180410	2026-08-06 07:48:01.912
\.


--
-- Data for Name: cost_accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cost_accounts (id, code, name_ko, name_en, description, sort_order, is_active, created_at, updated_at, deleted_at) FROM stdin;
cmsgzh2hw000kv4z4f8g8xs9o	6100	임차료	Rent	\N	1	t	2026-08-06 03:55:57.284	2026-08-06 03:55:57.284	\N
cmsgzh2kb000lv4z45i7fszvy	6200	통신비	Communication	\N	2	t	2026-08-06 03:55:57.372	2026-08-06 03:55:57.372	\N
cmsgzh2mg000mv4z4tiforuzt	6300	전기료	Utilities	\N	3	t	2026-08-06 03:55:57.448	2026-08-06 03:55:57.448	\N
cmsgzh2om000nv4z4n0q3kl9g	6400	보험료	Insurance	\N	4	t	2026-08-06 03:55:57.526	2026-08-06 03:55:57.526	\N
cmsgzh2qs000ov4z4irmuzkh0	6500	감가상각비	Depreciation	\N	5	t	2026-08-06 03:55:57.605	2026-08-06 03:55:57.605	\N
cmsgzh2sx000pv4z4ugxp12nb	6600	수선비	Repairs	\N	6	t	2026-08-06 03:55:57.681	2026-08-06 03:55:57.681	\N
cmsgzh2v8000qv4z4jby0vwu0	6700	세금과공과	Taxes	\N	7	t	2026-08-06 03:55:57.765	2026-08-06 03:55:57.765	\N
cmsgzh2xd000rv4z4w3b9gj2f	6800	기타공동비용	Other Shared Costs	\N	8	t	2026-08-06 03:55:57.842	2026-08-06 03:55:57.842	\N
cmsh1b3cp0000v45kdnl2mv4k	ACC-01	급료와임금	\N	급상여	1	t	2026-08-06 04:47:17.68	2026-08-06 04:47:17.68	\N
cmsh1b3fq0001v45k1k7ywxzg	ACC-02	상여금	\N	급상여	2	t	2026-08-06 04:47:17.798	2026-08-06 04:47:17.798	\N
cmsh1b3hc0002v45kkzg3z9wd	ACC-03	복리후생비(기타)	\N	급상여	3	t	2026-08-06 04:47:17.856	2026-08-06 04:47:17.856	\N
cmsh1b3iy0003v45kozth7aas	ACC-04	건강보험	\N	복리후생	4	t	2026-08-06 04:47:17.914	2026-08-06 04:47:17.914	\N
cmsh1b3kc0004v45kv13t1190	ACC-05	국민연금	\N	복리후생	5	t	2026-08-06 04:47:17.964	2026-08-06 04:47:17.964	\N
cmsh1b3lv0005v45k1i15ud1r	ACC-06	산재보험	\N	복리후생	6	t	2026-08-06 04:47:18.019	2026-08-06 04:47:18.019	\N
cmsh1b3ne0006v45ka0wrz3cs	ACC-07	고용보험	\N	복리후생	7	t	2026-08-06 04:47:18.074	2026-08-06 04:47:18.074	\N
cmsh1b3ow0007v45kegisx5jd	ACC-08	식대(식권)	\N	기타	8	t	2026-08-06 04:47:18.128	2026-08-06 04:47:18.128	\N
cmsh1b3qm0008v45krlvaq333	ACC-09	업무추진비	\N	기타	9	t	2026-08-06 04:47:18.19	2026-08-06 04:47:18.19	\N
cmsh1b3rx0009v45kvzp0f6by	ACC-10	소모품비	\N	기타	10	t	2026-08-06 04:47:18.237	2026-08-06 04:47:18.237	\N
cmsh1b3tj000av45kp4w6n24d	ACC-11	국내출장비	\N	기타	11	t	2026-08-06 04:47:18.295	2026-08-06 04:47:18.295	\N
cmsh1b3v5000bv45kkg5k7jdr	ACC-12	지급수수료	\N	기타	12	t	2026-08-06 04:47:18.354	2026-08-06 04:47:18.354	\N
cmsh1b3wp000cv45k0eshx54k	ACC-13	통신비	\N	기타	13	t	2026-08-06 04:47:18.409	2026-08-06 04:47:18.409	\N
cmsh1b3y6000dv45k9tvmq64r	ACC-14	도서인쇄비	\N	기타	14	t	2026-08-06 04:47:18.462	2026-08-06 04:47:18.462	\N
cmsh1b3zn000ev45ke50rracp	ACC-15	국외출장비	\N	기타	15	t	2026-08-06 04:47:18.516	2026-08-06 04:47:18.516	\N
cmsh1b41f000fv45k4qgcw4ac	ACC-16	감가상각비(차량)	\N	기타	16	t	2026-08-06 04:47:18.579	2026-08-06 04:47:18.579	\N
cmsh1b42x000gv45kutf85p3y	ACC-17	차량관리비	\N	기타	17	t	2026-08-06 04:47:18.633	2026-08-06 04:47:18.633	\N
cmsh1b44c000hv45k8wyhshmu	ACC-18	기타지급	\N	기타	18	t	2026-08-06 04:47:18.684	2026-08-06 04:47:18.684	\N
cmsh1b45p000iv45krmpx8fmv	ACC-19	지급수수료(일반)	\N	기타	19	t	2026-08-06 04:47:18.733	2026-08-06 04:47:18.733	\N
\.


--
-- Data for Name: invoice_lines; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.invoice_lines (id, invoice_id, line_number, cost_account_id, description, amount, created_at) FROM stdin;
cmss7q4vc000av4forn33bs3r	cmss7q4vc0009v4fo1h5w8ckt	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:25.128
cmss7q4vc000bv4foifuftj3d	cmss7q4vc0009v4fo1h5w8ckt	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	671734	2026-08-14 00:32:25.128
cmss7q4vc000cv4fo9u9c06w2	cmss7q4vc0009v4fo1h5w8ckt	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	1585290	2026-08-14 00:32:25.128
cmss7q4vc000dv4fofk9mu5vp	cmss7q4vc0009v4fo1h5w8ckt	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	178071	2026-08-14 00:32:25.128
cmss7q4vc000ev4focjamgrql	cmss7q4vc0009v4fo1h5w8ckt	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	96012	2026-08-14 00:32:25.128
cmss7q4vc000fv4fo1wgomg1m	cmss7q4vc0009v4fo1h5w8ckt	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	4019	2026-08-14 00:32:25.128
cmss7q4vc000gv4foe21a1e96	cmss7q4vc0009v4fo1h5w8ckt	7	cmsh1b3kc0004v45kv13t1190	국민연금	3859748	2026-08-14 00:32:25.128
cmss7q4vc000hv4foom9ythhw	cmss7q4vc0009v4fo1h5w8ckt	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	1749950	2026-08-14 00:32:25.128
cmss7q4vc000iv4fo4xlzfhab	cmss7q4vc0009v4fo1h5w8ckt	9	cmsh1b3qm0008v45krlvaq333	업무추진비	1902570	2026-08-14 00:32:25.128
cmss7q4vc000jv4foyjgw8ac1	cmss7q4vc0009v4fo1h5w8ckt	10	cmsh1b42x000gv45kutf85p3y	차량관리비	184573	2026-08-14 00:32:25.128
cmss7q4vc000kv4fo3zefuhu4	cmss7q4vc0009v4fo1h5w8ckt	11	cmsh1b3wp000cv45k0eshx54k	통신비	93835	2026-08-14 00:32:25.128
cmss7q4vc000lv4foiovgfr24	cmss7q4vc0009v4fo1h5w8ckt	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	3806724	2026-08-14 00:32:25.128
cmss7q4vc000mv4fo42jbuo76	cmss7q4vc0009v4fo1h5w8ckt	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	719795	2026-08-14 00:32:25.128
cmss7q4vc000nv4fomhqox2eg	cmss7q4vc0009v4fo1h5w8ckt	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	612519	2026-08-14 00:32:25.128
cmss7q4vc000ov4fofe5qzqfh	cmss7q4vc0009v4fo1h5w8ckt	15	cmsh1b3zn000ev45ke50rracp	국외출장비	4545425	2026-08-14 00:32:25.128
cmss7q4vd000pv4fo9acftsed	cmss7q4vc0009v4fo1h5w8ckt	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	68515326	2026-08-14 00:32:25.128
cmss7q4vd000qv4fo0ubs6en1	cmss7q4vc0009v4fo1h5w8ckt	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	1222650	2026-08-14 00:32:25.128
cmss7q4vd000rv4fo52xcbm0k	cmss7q4vc0009v4fo1h5w8ckt	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	22494380	2026-08-14 00:32:25.128
cmss7q4vd000sv4foe8bhdmdt	cmss7q4vc0009v4fo1h5w8ckt	19	cmsh1b3iy0003v45kozth7aas	건강보험	3697808	2026-08-14 00:32:25.128
cmss7q4z6001ev4fowo7oeh1d	cmss7q4z6001dv4foh7r998kj	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:25.266
cmss7q4z6001fv4for0x6orb3	cmss7q4z6001dv4foh7r998kj	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	442561	2026-08-14 00:32:25.266
cmss7q4z6001gv4fo24yiaxe6	cmss7q4z6001dv4foh7r998kj	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	1044441	2026-08-14 00:32:25.266
cmss7q4z6001hv4fob8mweckz	cmss7q4z6001dv4foh7r998kj	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	117319	2026-08-14 00:32:25.266
cmss7q4z6001iv4fooo6nq3ty	cmss7q4z6001dv4foh7r998kj	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	63256	2026-08-14 00:32:25.266
cmss7q4z6001jv4fodkczj7jc	cmss7q4z6001dv4foh7r998kj	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	2648	2026-08-14 00:32:25.266
cmss7q4z6001kv4foa1kucuqx	cmss7q4z6001dv4foh7r998kj	7	cmsh1b3kc0004v45kv13t1190	국민연금	2542929	2026-08-14 00:32:25.266
cmss7q4z6001lv4fo399rzls2	cmss7q4z6001dv4foh7r998kj	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	1152925	2026-08-14 00:32:25.266
cmss7q4z6001mv4for3zw7maf	cmss7q4z6001dv4foh7r998kj	9	cmsh1b3qm0008v45krlvaq333	업무추진비	1253476	2026-08-14 00:32:25.266
cmss7q4z6001nv4foz22ohs6o	cmss7q4z6001dv4foh7r998kj	10	cmsh1b42x000gv45kutf85p3y	차량관리비	121603	2026-08-14 00:32:25.266
cmss7q4z6001ov4foxpdjfufa	cmss7q4z6001dv4foh7r998kj	11	cmsh1b3wp000cv45k0eshx54k	통신비	61821	2026-08-14 00:32:25.266
cmss7q4z6001pv4fodlns3zv8	cmss7q4z6001dv4foh7r998kj	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	2507996	2026-08-14 00:32:25.266
cmss7q4z6001qv4folszihez7	cmss7q4z6001dv4foh7r998kj	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	474224	2026-08-14 00:32:25.266
cmss7q4z6001rv4foh9px4n8d	cmss7q4z6001dv4foh7r998kj	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	403548	2026-08-14 00:32:25.266
cmss7q4z6001sv4fozc2b1x63	cmss7q4z6001dv4foh7r998kj	15	cmsh1b3zn000ev45ke50rracp	국외출장비	2994676	2026-08-14 00:32:25.266
cmss7q4z6001tv4fonuewai01	cmss7q4z6001dv4foh7r998kj	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	45140167	2026-08-14 00:32:25.266
cmss7q4z6001uv4foitgehua9	cmss7q4z6001dv4foh7r998kj	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	805522	2026-08-14 00:32:25.266
cmss7q4z6001vv4fo450r69l2	cmss7q4z6001dv4foh7r998kj	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	14820042	2026-08-14 00:32:25.266
cmss7q4z6001wv4fomuzunca5	cmss7q4z6001dv4foh7r998kj	19	cmsh1b3iy0003v45kozth7aas	건강보험	2436238	2026-08-14 00:32:25.266
cmss7q52n002iv4fotncfq8vd	cmss7q52m002hv4fok3pltxka	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:25.391
cmss7q52n002jv4foimuv31p1	cmss7q52m002hv4fok3pltxka	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	250392	2026-08-14 00:32:25.391
cmss7q52n002kv4foqowphq09	cmss7q52m002hv4fok3pltxka	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	590923	2026-08-14 00:32:25.391
cmss7q52n002lv4foni5v3mnh	cmss7q52m002hv4fok3pltxka	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	66376	2026-08-14 00:32:25.391
cmss7q52n002mv4fonjhlr9ti	cmss7q52m002hv4fok3pltxka	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	35789	2026-08-14 00:32:25.391
cmss7q52n002nv4fo361qh1wq	cmss7q52m002hv4fok3pltxka	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	1498	2026-08-14 00:32:25.391
cmss7q52n002ov4fos4rryzxv	cmss7q52m002hv4fok3pltxka	7	cmsh1b3kc0004v45kv13t1190	국민연금	1438738	2026-08-14 00:32:25.391
cmss7q52n002pv4foubs8mix4	cmss7q52m002hv4fok3pltxka	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	652301	2026-08-14 00:32:25.391
cmss7q52n002qv4foxn4ef1mw	cmss7q52m002hv4fok3pltxka	9	cmsh1b3qm0008v45krlvaq333	업무추진비	709191	2026-08-14 00:32:25.391
cmss7q52n002rv4foqcwicqw2	cmss7q52m002hv4fok3pltxka	10	cmsh1b42x000gv45kutf85p3y	차량관리비	68800	2026-08-14 00:32:25.391
cmss7q52n002sv4fox1kcxgi6	cmss7q52m002hv4fok3pltxka	11	cmsh1b3wp000cv45k0eshx54k	통신비	34977	2026-08-14 00:32:25.391
cmss7q52n002tv4fozy4gpl56	cmss7q52m002hv4fok3pltxka	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	1418973	2026-08-14 00:32:25.391
cmss7q52n002uv4foxcz2jh5s	cmss7q52m002hv4fok3pltxka	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	268306	2026-08-14 00:32:25.391
cmss7q52n002vv4fo0wq0wnbs	cmss7q52m002hv4fok3pltxka	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	228319	2026-08-14 00:32:25.391
cmss7q52n002wv4foynzo7kdv	cmss7q52m002hv4fok3pltxka	15	cmsh1b3zn000ev45ke50rracp	국외출장비	1694327	2026-08-14 00:32:25.391
cmss7q52n002xv4fojzsjnskz	cmss7q52m002hv4fok3pltxka	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	25539387	2026-08-14 00:32:25.391
cmss7q52n002yv4foua9jpqfz	cmss7q52m002hv4fok3pltxka	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	455748	2026-08-14 00:32:25.391
cmss7q52n002zv4fot402d8o2	cmss7q52m002hv4fok3pltxka	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	8384878	2026-08-14 00:32:25.391
cmss7q52n0030v4fon8g1zffv	cmss7q52m002hv4fok3pltxka	19	cmsh1b3iy0003v45kozth7aas	건강보험	1378374	2026-08-14 00:32:25.391
cmss7q564003mv4fo2nbfw6q6	cmss7q564003lv4fosq2qz1c8	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:25.516
cmss7q564003nv4fo4svhd1pp	cmss7q564003lv4fosq2qz1c8	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	243941	2026-08-14 00:32:25.516
cmss7q564003ov4foecntp8e6	cmss7q564003lv4fosq2qz1c8	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	575701	2026-08-14 00:32:25.516
cmss7q564003pv4fofehp41k8	cmss7q564003lv4fosq2qz1c8	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	64666	2026-08-14 00:32:25.516
cmss7q564003qv4fotns2pimq	cmss7q564003lv4fosq2qz1c8	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	34867	2026-08-14 00:32:25.516
cmss7q564003rv4foe94ygmwn	cmss7q564003lv4fosq2qz1c8	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	1459	2026-08-14 00:32:25.516
cmss7q564003sv4fog1he1hla	cmss7q564003lv4fosq2qz1c8	7	cmsh1b3kc0004v45kv13t1190	국민연금	1401674	2026-08-14 00:32:25.516
cmss7q564003tv4fomwtlw02x	cmss7q564003lv4fosq2qz1c8	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	635497	2026-08-14 00:32:25.516
cmss7q564003uv4fooqd9zzlx	cmss7q564003lv4fosq2qz1c8	9	cmsh1b3qm0008v45krlvaq333	업무추진비	690922	2026-08-14 00:32:25.516
cmss7q564003vv4fo1yw1x36s	cmss7q564003lv4fosq2qz1c8	10	cmsh1b42x000gv45kutf85p3y	차량관리비	67028	2026-08-14 00:32:25.516
cmss7q564003wv4folbb63qxt	cmss7q564003lv4fosq2qz1c8	11	cmsh1b3wp000cv45k0eshx54k	통신비	34076	2026-08-14 00:32:25.516
cmss7q565003xv4fozetzj2k0	cmss7q564003lv4fosq2qz1c8	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	1382418	2026-08-14 00:32:25.516
cmss7q565003yv4foyxsnzbsl	cmss7q564003lv4fosq2qz1c8	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	261394	2026-08-14 00:32:25.516
cmss7q565003zv4fog8574df5	cmss7q564003lv4fosq2qz1c8	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	222437	2026-08-14 00:32:25.516
cmss7q5650040v4fova2qtj8m	cmss7q564003lv4fosq2qz1c8	15	cmsh1b3zn000ev45ke50rracp	국외출장비	1650679	2026-08-14 00:32:25.516
cmss7q5650041v4foqyu1z6ss	cmss7q564003lv4fosq2qz1c8	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	24881466	2026-08-14 00:32:25.516
cmss7q5650042v4fo9j7kdvew	cmss7q564003lv4fosq2qz1c8	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	444007	2026-08-14 00:32:25.516
cmss7q5650043v4fotw7t9mc2	cmss7q564003lv4fosq2qz1c8	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	8168875	2026-08-14 00:32:25.516
cmss7q5650044v4foxn0y5bno	cmss7q564003lv4fosq2qz1c8	19	cmsh1b3iy0003v45kozth7aas	건강보험	1342865	2026-08-14 00:32:25.516
cmss7q59h004qv4fojiz91xk4	cmss7q59h004pv4fozy8ghusb	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:25.637
cmss7q59h004rv4fo9olorkh8	cmss7q59h004pv4fozy8ghusb	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	171756	2026-08-14 00:32:25.637
cmss7q59h004sv4for6tivusf	cmss7q59h004pv4fozy8ghusb	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	405344	2026-08-14 00:32:25.637
cmss7q59h004tv4foos9ykqi9	cmss7q59h004pv4fozy8ghusb	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	45531	2026-08-14 00:32:25.637
cmss7q59h004uv4fowcyj7fku	cmss7q59h004pv4fozy8ghusb	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	24549	2026-08-14 00:32:25.637
cmss7q59h004vv4foffi6x2pf	cmss7q59h004pv4fozy8ghusb	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	1027	2026-08-14 00:32:25.637
cmss7q59h004wv4fozjkscpmo	cmss7q59h004pv4fozy8ghusb	7	cmsh1b3kc0004v45kv13t1190	국민연금	986903	2026-08-14 00:32:25.637
cmss7q59h004xv4foyqdttwet	cmss7q59h004pv4fozy8ghusb	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	447446	2026-08-14 00:32:25.637
cmss7q59h004yv4fon5gvi1zi	cmss7q59h004pv4fozy8ghusb	9	cmsh1b3qm0008v45krlvaq333	업무추진비	486470	2026-08-14 00:32:25.637
cmss7q59h004zv4fothb1n9sh	cmss7q59h004pv4fozy8ghusb	10	cmsh1b42x000gv45kutf85p3y	차량관리비	47193	2026-08-14 00:32:25.637
cmss7q59h0050v4fotql82b5q	cmss7q59h004pv4fozy8ghusb	11	cmsh1b3wp000cv45k0eshx54k	통신비	23992	2026-08-14 00:32:25.637
cmss7q59h0051v4fo6hnfcqt3	cmss7q59h004pv4fozy8ghusb	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	973345	2026-08-14 00:32:25.637
cmss7q59h0052v4foxb2gst90	cmss7q59h004pv4fozy8ghusb	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	184045	2026-08-14 00:32:25.637
cmss7q59h0053v4fo3ezp46jz	cmss7q59h004pv4fozy8ghusb	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	156615	2026-08-14 00:32:25.637
cmss7q59h0054v4fothd13mwr	cmss7q59h004pv4fozy8ghusb	15	cmsh1b3zn000ev45ke50rracp	국외출장비	1162224	2026-08-14 00:32:25.637
cmss7q59i0055v4fo3t6i9lmw	cmss7q59h004pv4fozy8ghusb	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	17518760	2026-08-14 00:32:25.637
cmss7q59i0056v4fojsf20e6n	cmss7q59h004pv4fozy8ghusb	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	312620	2026-08-14 00:32:25.637
cmss7q59i0057v4fobu9l10fb	cmss7q59h004pv4fozy8ghusb	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	5751613	2026-08-14 00:32:25.637
cmss7q59i0058v4focw0wwenm	cmss7q59h004pv4fozy8ghusb	19	cmsh1b3iy0003v45kozth7aas	건강보험	945496	2026-08-14 00:32:25.637
cmss7q5cs005uv4fo7hb6zlcy	cmss7q5cs005tv4foahi0s8ab	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:25.756
cmss7q5cs005vv4foa9u1z0ic	cmss7q5cs005tv4foahi0s8ab	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	159079	2026-08-14 00:32:25.756
cmss7q5cs005wv4foqrl65l7d	cmss7q5cs005tv4foahi0s8ab	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	375426	2026-08-14 00:32:25.756
cmss7q5cs005xv4foqiv35k5j	cmss7q5cs005tv4foahi0s8ab	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	42170	2026-08-14 00:32:25.756
cmss7q5cs005yv4fo97q4f9dx	cmss7q5cs005tv4foahi0s8ab	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	22737	2026-08-14 00:32:25.756
cmss7q5cs005zv4folezexrbz	cmss7q5cs005tv4foahi0s8ab	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	951	2026-08-14 00:32:25.756
cmss7q5cs0060v4fot6y0vm6e	cmss7q5cs005tv4foahi0s8ab	7	cmsh1b3kc0004v45kv13t1190	국민연금	914059	2026-08-14 00:32:25.756
cmss7q5cs0061v4fo556zwc6c	cmss7q5cs005tv4foahi0s8ab	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	414420	2026-08-14 00:32:25.756
cmss7q5cs0062v4foxkghlieb	cmss7q5cs005tv4foahi0s8ab	9	cmsh1b3qm0008v45krlvaq333	업무추진비	450563	2026-08-14 00:32:25.756
cmss7q5cs0063v4fokqiqfvfo	cmss7q5cs005tv4foahi0s8ab	10	cmsh1b42x000gv45kutf85p3y	차량관리비	43710	2026-08-14 00:32:25.756
cmss7q5cs0064v4foqyjx37vn	cmss7q5cs005tv4foahi0s8ab	11	cmsh1b3wp000cv45k0eshx54k	통신비	22221	2026-08-14 00:32:25.756
cmss7q5cs0065v4fosuyhedbc	cmss7q5cs005tv4foahi0s8ab	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	901502	2026-08-14 00:32:25.756
cmss7q5cs0066v4foeml3lpyt	cmss7q5cs005tv4foahi0s8ab	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	170460	2026-08-14 00:32:25.756
cmss7q5cs0067v4foqvw0i21n	cmss7q5cs005tv4foahi0s8ab	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	145056	2026-08-14 00:32:25.756
cmss7q5cs0068v4fo8rj69o2s	cmss7q5cs005tv4foahi0s8ab	15	cmsh1b3zn000ev45ke50rracp	국외출장비	1076440	2026-08-14 00:32:25.756
cmss7q5cs0069v4foolrgu3vx	cmss7q5cs005tv4foahi0s8ab	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	16225692	2026-08-14 00:32:25.756
cmss7q5cs006av4foaoanxfne	cmss7q5cs005tv4foahi0s8ab	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	289546	2026-08-14 00:32:25.756
cmss7q5cs006bv4fotsazzyiu	cmss7q5cs005tv4foahi0s8ab	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	5327084	2026-08-14 00:32:25.756
cmss7q5cs006cv4foqvd20pml	cmss7q5cs005tv4foahi0s8ab	19	cmsh1b3iy0003v45kozth7aas	건강보험	875709	2026-08-14 00:32:25.756
cmss7q5g8006yv4fonam7m8lh	cmss7q5g8006xv4foar6v7dv7	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:25.88
cmss7q5g8006zv4foigfzxewq	cmss7q5g8006xv4foar6v7dv7	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	74961	2026-08-14 00:32:25.88
cmss7q5g80070v4foers6uuhr	cmss7q5g8006xv4foar6v7dv7	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	176909	2026-08-14 00:32:25.88
cmss7q5g80071v4foz7ols6ev	cmss7q5g8006xv4foar6v7dv7	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	19871	2026-08-14 00:32:25.88
cmss7q5g80072v4fo0a5qu3du	cmss7q5g8006xv4foar6v7dv7	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	10714	2026-08-14 00:32:25.88
cmss7q5g80073v4fohpi0pdzf	cmss7q5g8006xv4foar6v7dv7	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	448	2026-08-14 00:32:25.88
cmss7q5g80074v4foxkweuwh3	cmss7q5g8006xv4foar6v7dv7	7	cmsh1b3kc0004v45kv13t1190	국민연금	430726	2026-08-14 00:32:25.88
cmss7q5g80075v4fo50a1mpr2	cmss7q5g8006xv4foar6v7dv7	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	195284	2026-08-14 00:32:25.88
cmss7q5g80076v4fo0u0hkk4x	cmss7q5g8006xv4foar6v7dv7	9	cmsh1b3qm0008v45krlvaq333	업무추진비	212316	2026-08-14 00:32:25.88
cmss7q5g80077v4fo2cug8s4q	cmss7q5g8006xv4foar6v7dv7	10	cmsh1b42x000gv45kutf85p3y	차량관리비	20597	2026-08-14 00:32:25.88
cmss7q5g80078v4forz51dpaa	cmss7q5g8006xv4foar6v7dv7	11	cmsh1b3wp000cv45k0eshx54k	통신비	10471	2026-08-14 00:32:25.88
cmss7q5g80079v4fo6ekqfeu1	cmss7q5g8006xv4foar6v7dv7	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	424809	2026-08-14 00:32:25.88
cmss7q5g8007av4fo3rvik4ma	cmss7q5g8006xv4foar6v7dv7	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	80325	2026-08-14 00:32:25.88
cmss7q5g8007bv4foajbrj3oo	cmss7q5g8006xv4foar6v7dv7	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	68353	2026-08-14 00:32:25.88
cmss7q5g8007cv4fojnscjem3	cmss7q5g8006xv4foar6v7dv7	15	cmsh1b3zn000ev45ke50rracp	국외출장비	507244	2026-08-14 00:32:25.88
cmss7q5g8007dv4fohf4csldo	cmss7q5g8006xv4foar6v7dv7	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	7645933	2026-08-14 00:32:25.88
cmss7q5g8007ev4fody5l2c03	cmss7q5g8006xv4foar6v7dv7	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	136441	2026-08-14 00:32:25.88
cmss7q5g8007fv4foh1bcl6iz	cmss7q5g8006xv4foar6v7dv7	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	2510249	2026-08-14 00:32:25.88
cmss7q5g8007gv4fo4twiya8l	cmss7q5g8006xv4foar6v7dv7	19	cmsh1b3iy0003v45kozth7aas	건강보험	412655	2026-08-14 00:32:25.88
cmss7q5jk0082v4foif1mxzfw	cmss7q5jj0081v4foae13ugo6	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:26
cmss7q5jk0083v4fobw118kiz	cmss7q5jj0081v4foae13ugo6	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	48601	2026-08-14 00:32:26
cmss7q5jk0084v4fonvaxfjun	cmss7q5jj0081v4foae13ugo6	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	114698	2026-08-14 00:32:26
cmss7q5jk0085v4fom4cs5d41	cmss7q5jj0081v4foae13ugo6	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	12883	2026-08-14 00:32:26
cmss7q5jk0086v4fonhsxbxuo	cmss7q5jj0081v4foae13ugo6	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	6946	2026-08-14 00:32:26
cmss7q5jk0087v4fo3e1mn8nv	cmss7q5jj0081v4foae13ugo6	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	290	2026-08-14 00:32:26
cmss7q5jk0088v4fo3nqlfqy1	cmss7q5jj0081v4foae13ugo6	7	cmsh1b3kc0004v45kv13t1190	국민연금	279258	2026-08-14 00:32:26
cmss7q5jk0089v4fobvrwb5lr	cmss7q5jj0081v4foae13ugo6	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	126611	2026-08-14 00:32:26
cmss7q5jk008av4fokgng8md3	cmss7q5jj0081v4foae13ugo6	9	cmsh1b3qm0008v45krlvaq333	업무추진비	137653	2026-08-14 00:32:26
cmss7q5jk008bv4fourrt5buk	cmss7q5jj0081v4foae13ugo6	10	cmsh1b42x000gv45kutf85p3y	차량관리비	13354	2026-08-14 00:32:26
cmss7q5jk008cv4foy3ythvlc	cmss7q5jj0081v4foae13ugo6	11	cmsh1b3wp000cv45k0eshx54k	통신비	6789	2026-08-14 00:32:26
cmss7q5jk008dv4fo5igdvh14	cmss7q5jj0081v4foae13ugo6	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	275422	2026-08-14 00:32:26
cmss7q5jk008ev4fo10gpm14j	cmss7q5jj0081v4foae13ugo6	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	52078	2026-08-14 00:32:26
cmss7q5jk008fv4fojcp6yhis	cmss7q5jj0081v4foae13ugo6	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	44316	2026-08-14 00:32:26
cmss7q5jk008gv4fo2l6crom5	cmss7q5jj0081v4foae13ugo6	15	cmsh1b3zn000ev45ke50rracp	국외출장비	328868	2026-08-14 00:32:26
cmss7q5jk008hv4fob5s11xi5	cmss7q5jj0081v4foae13ugo6	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	4957189	2026-08-14 00:32:26
cmss7q5jk008iv4fokd3csf5w	cmss7q5jj0081v4foae13ugo6	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	88460	2026-08-14 00:32:26
cmss7q5jk008jv4fopbqry4bl	cmss7q5jj0081v4foae13ugo6	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1627503	2026-08-14 00:32:26
cmss7q5jk008kv4fo10ae59dt	cmss7q5jj0081v4foae13ugo6	19	cmsh1b3iy0003v45kozth7aas	건강보험	267542	2026-08-14 00:32:26
cmss7q5n00096v4fouyyagkmr	cmss7q5mz0095v4fok1ww2i69	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:26.124
cmss7q5n00097v4fothk1xrab	cmss7q5mz0095v4fok1ww2i69	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	26937	2026-08-14 00:32:26.124
cmss7q5n00098v4fol59z9glc	cmss7q5mz0095v4fok1ww2i69	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	63573	2026-08-14 00:32:26.124
cmss7q5n00099v4fot43xltsh	cmss7q5mz0095v4fok1ww2i69	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	7141	2026-08-14 00:32:26.124
cmss7q5n0009av4foiq03o1c6	cmss7q5mz0095v4fok1ww2i69	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	3850	2026-08-14 00:32:26.124
cmss7q5n0009bv4fow5pf5mbn	cmss7q5mz0095v4fok1ww2i69	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	161	2026-08-14 00:32:26.124
cmss7q5n0009cv4fo23wexgd8	cmss7q5mz0095v4fok1ww2i69	7	cmsh1b3kc0004v45kv13t1190	국민연금	154783	2026-08-14 00:32:26.124
cmss7q5n0009dv4fo8jvnvseg	cmss7q5mz0095v4fok1ww2i69	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	70176	2026-08-14 00:32:26.124
cmss7q5n0009ev4fom3o7vgfn	cmss7q5mz0095v4fok1ww2i69	9	cmsh1b3qm0008v45krlvaq333	업무추진비	76296	2026-08-14 00:32:26.124
cmss7q5n0009fv4folu2vsiew	cmss7q5mz0095v4fok1ww2i69	10	cmsh1b42x000gv45kutf85p3y	차량관리비	7401	2026-08-14 00:32:26.124
cmss7q5n0009gv4folgird5m0	cmss7q5mz0095v4fok1ww2i69	11	cmsh1b3wp000cv45k0eshx54k	통신비	3762	2026-08-14 00:32:26.124
cmss7q5n0009hv4fo0bdpt1nz	cmss7q5mz0095v4fok1ww2i69	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	152657	2026-08-14 00:32:26.124
cmss7q5n0009iv4fob643cgp8	cmss7q5mz0095v4fok1ww2i69	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	28865	2026-08-14 00:32:26.124
cmss7q5n0009jv4foy61rlxur	cmss7q5mz0095v4fok1ww2i69	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	24563	2026-08-14 00:32:26.124
cmss7q5n0009kv4foobhxt508	cmss7q5mz0095v4fok1ww2i69	15	cmsh1b3zn000ev45ke50rracp	국외출장비	182280	2026-08-14 00:32:26.124
cmss7q5n0009lv4fo7r4vb5qg	cmss7q5mz0095v4fok1ww2i69	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	2747597	2026-08-14 00:32:26.124
cmss7q5n0009mv4fop7csx582	cmss7q5mz0095v4fok1ww2i69	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	49030	2026-08-14 00:32:26.124
cmss7q5n0009nv4fosaill9ox	cmss7q5mz0095v4fok1ww2i69	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	902068	2026-08-14 00:32:26.124
cmss7q5n0009ov4foafg75mrk	cmss7q5mz0095v4fok1ww2i69	19	cmsh1b3iy0003v45kozth7aas	건강보험	148289	2026-08-14 00:32:26.124
cmss7q5qb00aav4fowfyw2o4b	cmss7q5qb00a9v4fodpgf0f12	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:26.244
cmss7q5qc00abv4fom0n2ewo1	cmss7q5qb00a9v4fodpgf0f12	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	73697	2026-08-14 00:32:26.244
cmss7q5qc00acv4foythqkk8a	cmss7q5qb00a9v4fodpgf0f12	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	173925	2026-08-14 00:32:26.244
cmss7q5qc00adv4foqto2vtgd	cmss7q5qb00a9v4fodpgf0f12	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	19536	2026-08-14 00:32:26.244
cmss7q5qc00aev4fox6t282fb	cmss7q5qb00a9v4fodpgf0f12	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	10533	2026-08-14 00:32:26.244
cmss7q5qc00afv4foyrtrsuzi	cmss7q5qb00a9v4fodpgf0f12	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	441	2026-08-14 00:32:26.244
cmss7q5qc00agv4foejh7qulp	cmss7q5qb00a9v4fodpgf0f12	7	cmsh1b3kc0004v45kv13t1190	국민연금	423459	2026-08-14 00:32:26.244
cmss7q5qc00ahv4fovjjdamk4	cmss7q5qb00a9v4fodpgf0f12	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	191990	2026-08-14 00:32:26.244
cmss7q5qc00aiv4fo2nlv40pp	cmss7q5qb00a9v4fodpgf0f12	9	cmsh1b3qm0008v45krlvaq333	업무추진비	208734	2026-08-14 00:32:26.244
cmss7q5qc00ajv4foq9d9mh2w	cmss7q5qb00a9v4fodpgf0f12	10	cmsh1b42x000gv45kutf85p3y	차량관리비	20249	2026-08-14 00:32:26.244
cmss7q5qc00akv4foirjvyjek	cmss7q5qb00a9v4fodpgf0f12	11	cmsh1b3wp000cv45k0eshx54k	통신비	10294	2026-08-14 00:32:26.244
cmss7q5qc00alv4fommxr2g0z	cmss7q5qb00a9v4fodpgf0f12	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	417642	2026-08-14 00:32:26.244
cmss7q5qc00amv4fobqvcjdb8	cmss7q5qb00a9v4fodpgf0f12	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	78970	2026-08-14 00:32:26.244
cmss7q5qc00anv4fok35ew410	cmss7q5qb00a9v4fodpgf0f12	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	67200	2026-08-14 00:32:26.244
cmss7q5qc00aov4fogq9ioxjy	cmss7q5qb00a9v4fodpgf0f12	15	cmsh1b3zn000ev45ke50rracp	국외출장비	498686	2026-08-14 00:32:26.244
cmss7q5qc00apv4fo6uuqarjg	cmss7q5qb00a9v4fodpgf0f12	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	7516939	2026-08-14 00:32:26.244
cmss7q5qc00aqv4fok2v6k0c6	cmss7q5qb00a9v4fodpgf0f12	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	134139	2026-08-14 00:32:26.244
cmss7q5qc00arv4fopxi3g361	cmss7q5qb00a9v4fodpgf0f12	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	2467898	2026-08-14 00:32:26.244
cmss7q5qc00asv4fosvht0318	cmss7q5qb00a9v4fodpgf0f12	19	cmsh1b3iy0003v45kozth7aas	건강보험	405693	2026-08-14 00:32:26.244
cmss7q5u200bev4fo5i89go7h	cmss7q5u200bdv4foqgdgbf69	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:26.378
cmss7q5u200bfv4fopa7l0jq6	cmss7q5u200bdv4foqgdgbf69	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	57595	2026-08-14 00:32:26.378
cmss7q5u200bgv4fobkdgs0u1	cmss7q5u200bdv4foqgdgbf69	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	135925	2026-08-14 00:32:26.378
cmss7q5u200bhv4fo7sti01jf	cmss7q5u200bdv4foqgdgbf69	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	15268	2026-08-14 00:32:26.378
cmss7q5u200biv4fodf6ppal5	cmss7q5u200bdv4foqgdgbf69	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	8232	2026-08-14 00:32:26.378
cmss7q5u200bjv4fob35nsruc	cmss7q5u200bdv4foqgdgbf69	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	344	2026-08-14 00:32:26.378
cmss7q5u200bkv4foeax17s9v	cmss7q5u200bdv4foqgdgbf69	7	cmsh1b3kc0004v45kv13t1190	국민연금	330941	2026-08-14 00:32:26.378
cmss7q5u200blv4fo3qvzxy6s	cmss7q5u200bdv4foqgdgbf69	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	150043	2026-08-14 00:32:26.378
cmss7q5u200bmv4fokjkq4bqe	cmss7q5u200bdv4foqgdgbf69	9	cmsh1b3qm0008v45krlvaq333	업무추진비	163129	2026-08-14 00:32:26.378
cmss7q5u200bnv4fop9isrlqx	cmss7q5u200bdv4foqgdgbf69	10	cmsh1b42x000gv45kutf85p3y	차량관리비	15825	2026-08-14 00:32:26.378
cmss7q5u200bov4foyalxe1hz	cmss7q5u200bdv4foqgdgbf69	11	cmsh1b3wp000cv45k0eshx54k	통신비	8045	2026-08-14 00:32:26.378
cmss7q5u200bpv4folkey9dfj	cmss7q5u200bdv4foqgdgbf69	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	326395	2026-08-14 00:32:26.378
cmss7q5u200bqv4for79rc4zy	cmss7q5u200bdv4foqgdgbf69	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	61716	2026-08-14 00:32:26.378
cmss7q5u200brv4foq4h9fbya	cmss7q5u200bdv4foqgdgbf69	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	52518	2026-08-14 00:32:26.378
cmss7q5u200bsv4fo9ktc5fgs	cmss7q5u200bdv4foqgdgbf69	15	cmsh1b3zn000ev45ke50rracp	국외출장비	389733	2026-08-14 00:32:26.378
cmss7q5u200btv4foovfx6ghc	cmss7q5u200bdv4foqgdgbf69	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	5874629	2026-08-14 00:32:26.378
cmss7q5u200buv4foh1o2u025	cmss7q5u200bdv4foqgdgbf69	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	104832	2026-08-14 00:32:26.378
cmss7q5u200bvv4fots4nbu0o	cmss7q5u200bdv4foqgdgbf69	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1928709	2026-08-14 00:32:26.378
cmss7q5u200bwv4fokh9lnjdk	cmss7q5u200bdv4foqgdgbf69	19	cmsh1b3iy0003v45kozth7aas	건강보험	317056	2026-08-14 00:32:26.378
cmss7q5xg00civ4fonlfsrfjp	cmss7q5xg00chv4fo3x6n4dza	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:26.5
cmss7q5xg00cjv4fotu1bvfhl	cmss7q5xg00chv4fo3x6n4dza	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	53885	2026-08-14 00:32:26.5
cmss7q5xg00ckv4fo0rz11zdy	cmss7q5xg00chv4fo3x6n4dza	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	127168	2026-08-14 00:32:26.5
cmss7q5xg00clv4fohuhjx4u4	cmss7q5xg00chv4fo3x6n4dza	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	14284	2026-08-14 00:32:26.5
cmss7q5xg00cmv4foo84smnb8	cmss7q5xg00chv4fo3x6n4dza	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	7701	2026-08-14 00:32:26.5
cmss7q5xg00cnv4foabg10eoi	cmss7q5xg00chv4fo3x6n4dza	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	322	2026-08-14 00:32:26.5
cmss7q5xg00cov4foymg7z9p9	cmss7q5xg00chv4fo3x6n4dza	7	cmsh1b3kc0004v45kv13t1190	국민연금	309621	2026-08-14 00:32:26.5
cmss7q5xg00cpv4foz6e3tr9f	cmss7q5xg00chv4fo3x6n4dza	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	140377	2026-08-14 00:32:26.5
cmss7q5xg00cqv4fovqg9rack	cmss7q5xg00chv4fo3x6n4dza	9	cmsh1b3qm0008v45krlvaq333	업무추진비	152620	2026-08-14 00:32:26.5
cmss7q5xg00crv4foc9dwepvu	cmss7q5xg00chv4fo3x6n4dza	10	cmsh1b42x000gv45kutf85p3y	차량관리비	14806	2026-08-14 00:32:26.5
cmss7q5xg00csv4fomhc6ixu3	cmss7q5xg00chv4fo3x6n4dza	11	cmsh1b3wp000cv45k0eshx54k	통신비	7527	2026-08-14 00:32:26.5
cmss7q5xg00ctv4fo31t0bor6	cmss7q5xg00chv4fo3x6n4dza	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	305367	2026-08-14 00:32:26.5
cmss7q5xg00cuv4fows616jgq	cmss7q5xg00chv4fo3x6n4dza	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	57740	2026-08-14 00:32:26.5
cmss7q5xh00cvv4foynf78z96	cmss7q5xg00chv4fo3x6n4dza	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	49135	2026-08-14 00:32:26.5
cmss7q5xh00cwv4fo5lvjmuzw	cmss7q5xg00chv4fo3x6n4dza	15	cmsh1b3zn000ev45ke50rracp	국외출장비	364624	2026-08-14 00:32:26.5
cmss7q5xh00cxv4fot1kabq8n	cmss7q5xg00chv4fo3x6n4dza	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	5496158	2026-08-14 00:32:26.5
cmss7q5xh00cyv4fokz05y0sd	cmss7q5xg00chv4fo3x6n4dza	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	98078	2026-08-14 00:32:26.5
cmss7q5xh00czv4for5wymcib	cmss7q5xg00chv4fo3x6n4dza	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1804452	2026-08-14 00:32:26.5
cmss7q5xh00d0v4fo65cr43uz	cmss7q5xg00chv4fo3x6n4dza	19	cmsh1b3iy0003v45kozth7aas	건강보험	296630	2026-08-14 00:32:26.5
cmss7q60r00dmv4foj36o63b3	cmss7q60r00dlv4foiei1vhxd	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:26.619
cmss7q60r00dnv4fo30kbkqpy	cmss7q60r00dlv4foiei1vhxd	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	50021	2026-08-14 00:32:26.619
cmss7q60r00dov4fo33i5z6rw	cmss7q60r00dlv4foiei1vhxd	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	118049	2026-08-14 00:32:26.619
cmss7q60r00dpv4fo2pbfqazn	cmss7q60r00dlv4foiei1vhxd	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	13260	2026-08-14 00:32:26.619
cmss7q60r00dqv4fokqnmxjzr	cmss7q60r00dlv4foiei1vhxd	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	7149	2026-08-14 00:32:26.619
cmss7q60r00drv4fo5p0043mu	cmss7q60r00dlv4foiei1vhxd	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	299	2026-08-14 00:32:26.619
cmss7q60r00dsv4foox7570da	cmss7q60r00dlv4foiei1vhxd	7	cmsh1b3kc0004v45kv13t1190	국민연금	287417	2026-08-14 00:32:26.619
cmss7q60r00dtv4foaejwn9s0	cmss7q60r00dlv4foiei1vhxd	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	130310	2026-08-14 00:32:26.619
cmss7q60r00duv4fo7bopi0l8	cmss7q60r00dlv4foiei1vhxd	9	cmsh1b3qm0008v45krlvaq333	업무추진비	141675	2026-08-14 00:32:26.619
cmss7q60r00dvv4fou4rbn78q	cmss7q60r00dlv4foiei1vhxd	10	cmsh1b42x000gv45kutf85p3y	차량관리비	13744	2026-08-14 00:32:26.619
cmss7q60r00dwv4foewkco23i	cmss7q60r00dlv4foiei1vhxd	11	cmsh1b3wp000cv45k0eshx54k	통신비	6987	2026-08-14 00:32:26.619
cmss7q60r00dxv4fopjoney0i	cmss7q60r00dlv4foiei1vhxd	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	283469	2026-08-14 00:32:26.619
cmss7q60r00dyv4fo0vgk6s35	cmss7q60r00dlv4foiei1vhxd	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	53599	2026-08-14 00:32:26.619
cmss7q60r00dzv4fookrwjkpk	cmss7q60r00dlv4foiei1vhxd	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	45611	2026-08-14 00:32:26.619
cmss7q60r00e0v4foa5w1su9b	cmss7q60r00dlv4foiei1vhxd	15	cmsh1b3zn000ev45ke50rracp	국외출장비	338477	2026-08-14 00:32:26.619
cmss7q60r00e1v4fouey6xjyq	cmss7q60r00dlv4foiei1vhxd	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	5102026	2026-08-14 00:32:26.619
cmss7q60r00e2v4foaas45ew0	cmss7q60r00dlv4foiei1vhxd	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	91045	2026-08-14 00:32:26.619
cmss7q60r00e3v4fodirrwtvk	cmss7q60r00dlv4foiei1vhxd	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1675054	2026-08-14 00:32:26.619
cmss7q60r00e4v4foat5phnlu	cmss7q60r00dlv4foiei1vhxd	19	cmsh1b3iy0003v45kozth7aas	건강보험	275359	2026-08-14 00:32:26.619
cmss7q64z00eqv4foqrwj5z2u	cmss7q64z00epv4foq50zqsav	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:26.771
cmss7q64z00erv4fo2w8zyrcd	cmss7q64z00epv4foq50zqsav	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	48161	2026-08-14 00:32:26.771
cmss7q64z00esv4foo8vi0ajg	cmss7q64z00epv4foq50zqsav	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	113661	2026-08-14 00:32:26.771
cmss7q64z00etv4foo40aidi5	cmss7q64z00epv4foq50zqsav	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	12767	2026-08-14 00:32:26.771
cmss7q64z00euv4fortakzj88	cmss7q64z00epv4foq50zqsav	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	6883	2026-08-14 00:32:26.771
cmss7q64z00evv4fohm45x4oo	cmss7q64z00epv4foq50zqsav	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	288	2026-08-14 00:32:26.771
cmss7q64z00ewv4fooov3fz4e	cmss7q64z00epv4foq50zqsav	7	cmsh1b3kc0004v45kv13t1190	국민연금	276734	2026-08-14 00:32:26.771
cmss7q64z00exv4fom9tgjiwl	cmss7q64z00epv4foq50zqsav	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	125467	2026-08-14 00:32:26.771
cmss7q64z00eyv4foiawkyaoc	cmss7q64z00epv4foq50zqsav	9	cmsh1b3qm0008v45krlvaq333	업무추진비	136409	2026-08-14 00:32:26.771
cmss7q64z00ezv4fom63q8o1s	cmss7q64z00epv4foq50zqsav	10	cmsh1b42x000gv45kutf85p3y	차량관리비	13233	2026-08-14 00:32:26.771
cmss7q64z00f0v4fobarl3ewv	cmss7q64z00epv4foq50zqsav	11	cmsh1b3wp000cv45k0eshx54k	통신비	6727	2026-08-14 00:32:26.771
cmss7q64z00f1v4fo0caa6ch7	cmss7q64z00epv4foq50zqsav	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	272932	2026-08-14 00:32:26.771
cmss7q64z00f2v4fofew38nd9	cmss7q64z00epv4foq50zqsav	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	51607	2026-08-14 00:32:26.771
cmss7q64z00f3v4foulbuljlz	cmss7q64z00epv4foq50zqsav	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	43916	2026-08-14 00:32:26.771
cmss7q64z00f4v4foljxnowzw	cmss7q64z00epv4foq50zqsav	15	cmsh1b3zn000ev45ke50rracp	국외출장비	325895	2026-08-14 00:32:26.771
cmss7q64z00f5v4fonucdann9	cmss7q64z00epv4foq50zqsav	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	4912375	2026-08-14 00:32:26.771
cmss7q64z00f6v4fo4ub8sua9	cmss7q64z00epv4foq50zqsav	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	87660	2026-08-14 00:32:26.771
cmss7q64z00f7v4fon5x3vrgs	cmss7q64z00epv4foq50zqsav	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1612790	2026-08-14 00:32:26.771
cmss7q64z00f8v4foxmtpfkud	cmss7q64z00epv4foq50zqsav	19	cmsh1b3iy0003v45kozth7aas	건강보험	265123	2026-08-14 00:32:26.771
cmss7q68c00fuv4fo7up8d7il	cmss7q68b00ftv4fox8895mcw	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:26.892
cmss7q68c00fvv4foxoc1h3v8	cmss7q68b00ftv4fox8895mcw	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	47742	2026-08-14 00:32:26.892
cmss7q68c00fwv4fogj9ccj3e	cmss7q68b00ftv4fox8895mcw	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	112671	2026-08-14 00:32:26.892
cmss7q68c00fxv4fo0v5b0znb	cmss7q68b00ftv4fox8895mcw	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	12656	2026-08-14 00:32:26.892
cmss7q68c00fyv4fo5dhdrlrd	cmss7q68b00ftv4fox8895mcw	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	6823	2026-08-14 00:32:26.892
cmss7q68c00fzv4focjcrfyae	cmss7q68b00ftv4fox8895mcw	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	285	2026-08-14 00:32:26.892
cmss7q68c00g0v4fopycfc7fg	cmss7q68b00ftv4fox8895mcw	7	cmsh1b3kc0004v45kv13t1190	국민연금	274323	2026-08-14 00:32:26.892
cmss7q68c00g1v4fo5za12i8w	cmss7q68b00ftv4fox8895mcw	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	124374	2026-08-14 00:32:26.892
cmss7q68c00g2v4fovgu9cg4v	cmss7q68b00ftv4fox8895mcw	9	cmsh1b3qm0008v45krlvaq333	업무추진비	135221	2026-08-14 00:32:26.892
cmss7q68c00g3v4foq92kg01z	cmss7q68b00ftv4fox8895mcw	10	cmsh1b42x000gv45kutf85p3y	차량관리비	13118	2026-08-14 00:32:26.892
cmss7q68c00g4v4foctjc5t9p	cmss7q68b00ftv4fox8895mcw	11	cmsh1b3wp000cv45k0eshx54k	통신비	6669	2026-08-14 00:32:26.892
cmss7q68c00g5v4foya1uhu2h	cmss7q68b00ftv4fox8895mcw	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	270555	2026-08-14 00:32:26.892
cmss7q68c00g6v4fo30qabjrr	cmss7q68b00ftv4fox8895mcw	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	51157	2026-08-14 00:32:26.892
cmss7q68c00g7v4foey2s83e7	cmss7q68b00ftv4fox8895mcw	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	43533	2026-08-14 00:32:26.892
cmss7q68c00g8v4fokamu16bi	cmss7q68b00ftv4fox8895mcw	15	cmsh1b3zn000ev45ke50rracp	국외출장비	323056	2026-08-14 00:32:26.892
cmss7q68c00g9v4foch2jod1n	cmss7q68b00ftv4fox8895mcw	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	4869588	2026-08-14 00:32:26.892
cmss7q68c00gav4fo40xatt59	cmss7q68b00ftv4fox8895mcw	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	86897	2026-08-14 00:32:26.892
cmss7q68c00gbv4foaug23sob	cmss7q68b00ftv4fox8895mcw	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1598742	2026-08-14 00:32:26.892
cmss7q68c00gcv4foicn32fzt	cmss7q68b00ftv4fox8895mcw	19	cmsh1b3iy0003v45kozth7aas	건강보험	262814	2026-08-14 00:32:26.892
cmss7q6bi00gyv4fopfbovbxl	cmss7q6bi00gxv4fos6bkbsnq	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:27.006
cmss7q6bi00gzv4fotb9gvq8d	cmss7q6bi00gxv4fos6bkbsnq	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	46048	2026-08-14 00:32:27.006
cmss7q6bi00h0v4foam3o85ne	cmss7q6bi00gxv4fos6bkbsnq	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	108673	2026-08-14 00:32:27.006
cmss7q6bi00h1v4fo275p0jfc	cmss7q6bi00gxv4fos6bkbsnq	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	12207	2026-08-14 00:32:27.006
cmss7q6bi00h2v4fopm8a8ccs	cmss7q6bi00gxv4fos6bkbsnq	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	6581	2026-08-14 00:32:27.006
cmss7q6bi00h3v4fold46p1k7	cmss7q6bi00gxv4fos6bkbsnq	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	275	2026-08-14 00:32:27.006
cmss7q6bi00h4v4fosf5wghdk	cmss7q6bi00gxv4fos6bkbsnq	7	cmsh1b3kc0004v45kv13t1190	국민연금	264591	2026-08-14 00:32:27.006
cmss7q6bi00h5v4fosf3x6ukk	cmss7q6bi00gxv4fos6bkbsnq	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	119961	2026-08-14 00:32:27.006
cmss7q6bi00h6v4fo5ty2ixi8	cmss7q6bi00gxv4fos6bkbsnq	9	cmsh1b3qm0008v45krlvaq333	업무추진비	130423	2026-08-14 00:32:27.006
cmss7q6bi00h7v4fons1brfag	cmss7q6bi00gxv4fos6bkbsnq	10	cmsh1b42x000gv45kutf85p3y	차량관리비	12652	2026-08-14 00:32:27.006
cmss7q6bi00h8v4fov2ejm019	cmss7q6bi00gxv4fos6bkbsnq	11	cmsh1b3wp000cv45k0eshx54k	통신비	6432	2026-08-14 00:32:27.006
cmss7q6bi00h9v4fovccqmepv	cmss7q6bi00gxv4fos6bkbsnq	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	260956	2026-08-14 00:32:27.006
cmss7q6bi00hav4fomy2f7s7r	cmss7q6bi00gxv4fos6bkbsnq	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	49342	2026-08-14 00:32:27.006
cmss7q6bi00hbv4fohql6qime	cmss7q6bi00gxv4fos6bkbsnq	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	41989	2026-08-14 00:32:27.006
cmss7q6bi00hcv4fomnmgfej7	cmss7q6bi00gxv4fos6bkbsnq	15	cmsh1b3zn000ev45ke50rracp	국외출장비	311595	2026-08-14 00:32:27.006
cmss7q6bi00hdv4fowqjj3b1q	cmss7q6bi00gxv4fos6bkbsnq	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	4696823	2026-08-14 00:32:27.006
cmss7q6bi00hev4fo4t6gi10t	cmss7q6bi00gxv4fos6bkbsnq	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	83814	2026-08-14 00:32:27.006
cmss7q6bi00hfv4foow676iy9	cmss7q6bi00gxv4fos6bkbsnq	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1542021	2026-08-14 00:32:27.006
cmss7q6bi00hgv4fo6mjsgq83	cmss7q6bi00gxv4fos6bkbsnq	19	cmsh1b3iy0003v45kozth7aas	건강보험	253490	2026-08-14 00:32:27.006
cmss7q6f300i2v4fohyelxpdd	cmss7q6f300i1v4foiyafg9wh	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:27.135
cmss7q6f300i3v4fomniu87u2	cmss7q6f300i1v4foiyafg9wh	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	43320	2026-08-14 00:32:27.135
cmss7q6f300i4v4fos97mfre9	cmss7q6f300i1v4foiyafg9wh	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	102237	2026-08-14 00:32:27.135
cmss7q6f300i5v4foo7v4pifl	cmss7q6f300i1v4foiyafg9wh	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	11484	2026-08-14 00:32:27.135
cmss7q6f300i6v4fodna555gf	cmss7q6f300i1v4foiyafg9wh	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	6191	2026-08-14 00:32:27.135
cmss7q6f300i7v4fo3rr9pbkv	cmss7q6f300i1v4foiyafg9wh	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	259	2026-08-14 00:32:27.135
cmss7q6f300i8v4foiiw7wnll	cmss7q6f300i1v4foiyafg9wh	7	cmsh1b3kc0004v45kv13t1190	국민연금	248919	2026-08-14 00:32:27.135
cmss7q6f300i9v4foarmh8fkc	cmss7q6f300i1v4foiyafg9wh	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	112856	2026-08-14 00:32:27.135
cmss7q6f300iav4fok3l0i6hf	cmss7q6f300i1v4foiyafg9wh	9	cmsh1b3qm0008v45krlvaq333	업무추진비	122699	2026-08-14 00:32:27.135
cmss7q6f300ibv4foizx6qdaa	cmss7q6f300i1v4foiyafg9wh	10	cmsh1b42x000gv45kutf85p3y	차량관리비	11903	2026-08-14 00:32:27.135
cmss7q6f300icv4fos0atfhr5	cmss7q6f300i1v4foiyafg9wh	11	cmsh1b3wp000cv45k0eshx54k	통신비	6051	2026-08-14 00:32:27.135
cmss7q6f300idv4fodigoqusr	cmss7q6f300i1v4foiyafg9wh	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	245500	2026-08-14 00:32:27.135
cmss7q6f300iev4focgt9744r	cmss7q6f300i1v4foiyafg9wh	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	46420	2026-08-14 00:32:27.135
cmss7q6f300ifv4fopmbalifc	cmss7q6f300i1v4foiyafg9wh	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	39502	2026-08-14 00:32:27.135
cmss7q6f300igv4fo7516c5rn	cmss7q6f300i1v4foiyafg9wh	15	cmsh1b3zn000ev45ke50rracp	국외출장비	293139	2026-08-14 00:32:27.135
cmss7q6f300ihv4fojz7hn88q	cmss7q6f300i1v4foiyafg9wh	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	4418632	2026-08-14 00:32:27.135
cmss7q6f300iiv4foi3pkg8c2	cmss7q6f300i1v4foiyafg9wh	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	78850	2026-08-14 00:32:27.135
cmss7q6f300ijv4fo0lnlkn3w	cmss7q6f300i1v4foiyafg9wh	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1450688	2026-08-14 00:32:27.135
cmss7q6f300ikv4foedyqkble	cmss7q6f300i1v4foiyafg9wh	19	cmsh1b3iy0003v45kozth7aas	건강보험	238475	2026-08-14 00:32:27.135
cmss7q6ih00j6v4foo8w8j2eb	cmss7q6ih00j5v4fo2w1i59pr	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:27.257
cmss7q6ih00j7v4fovxzu1jru	cmss7q6ih00j5v4fo2w1i59pr	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	31420	2026-08-14 00:32:27.257
cmss7q6ih00j8v4fov0v5fvlk	cmss7q6ih00j5v4fo2w1i59pr	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	74152	2026-08-14 00:32:27.257
cmss7q6ih00j9v4fovcbcctg2	cmss7q6ih00j5v4fo2w1i59pr	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	8329	2026-08-14 00:32:27.257
cmss7q6ih00jav4fouh3p5l11	cmss7q6ih00j5v4fo2w1i59pr	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	4491	2026-08-14 00:32:27.257
cmss7q6ih00jbv4foj7v2ciby	cmss7q6ih00j5v4fo2w1i59pr	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	188	2026-08-14 00:32:27.257
cmss7q6ih00jcv4fov9dhmuq8	cmss7q6ih00j5v4fo2w1i59pr	7	cmsh1b3kc0004v45kv13t1190	국민연금	180540	2026-08-14 00:32:27.257
cmss7q6ih00jdv4fozxeb83vg	cmss7q6ih00j5v4fo2w1i59pr	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	81854	2026-08-14 00:32:27.257
cmss7q6ih00jev4foluxj0iuw	cmss7q6ih00j5v4fo2w1i59pr	9	cmsh1b3qm0008v45krlvaq333	업무추진비	88993	2026-08-14 00:32:27.257
cmss7q6ih00jfv4fo88k8r9x4	cmss7q6ih00j5v4fo2w1i59pr	10	cmsh1b42x000gv45kutf85p3y	차량관리비	8633	2026-08-14 00:32:27.257
cmss7q6ih00jgv4fothynxuwk	cmss7q6ih00j5v4fo2w1i59pr	11	cmsh1b3wp000cv45k0eshx54k	통신비	4389	2026-08-14 00:32:27.257
cmss7q6ih00jhv4fom1kjm9rr	cmss7q6ih00j5v4fo2w1i59pr	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	178060	2026-08-14 00:32:27.257
cmss7q6ih00jiv4foknwhipkz	cmss7q6ih00j5v4fo2w1i59pr	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	33668	2026-08-14 00:32:27.257
cmss7q6ih00jjv4fovrkk6zt2	cmss7q6ih00j5v4fo2w1i59pr	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	28650	2026-08-14 00:32:27.257
cmss7q6ih00jkv4fok4vmjzh4	cmss7q6ih00j5v4fo2w1i59pr	15	cmsh1b3zn000ev45ke50rracp	국외출장비	212613	2026-08-14 00:32:27.257
cmss7q6ih00jlv4fopmx5ouo7	cmss7q6ih00j5v4fo2w1i59pr	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	3204817	2026-08-14 00:32:27.257
cmss7q6ih00jmv4folt97paw3	cmss7q6ih00j5v4fo2w1i59pr	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	57189	2026-08-14 00:32:27.257
cmss7q6ih00jnv4foj5kg1782	cmss7q6ih00j5v4fo2w1i59pr	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	1052178	2026-08-14 00:32:27.257
cmss7q6ih00jov4fo6yj45b1r	cmss7q6ih00j5v4fo2w1i59pr	19	cmsh1b3iy0003v45kozth7aas	건강보험	172965	2026-08-14 00:32:27.257
cmss7q6m200kav4fom6laay89	cmss7q6m200k9v4fo8twb4qjc	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:27.386
cmss7q6m200kbv4foxmjuwsed	cmss7q6m200k9v4fo8twb4qjc	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	23436	2026-08-14 00:32:27.386
cmss7q6m200kcv4fo8k71o1dc	cmss7q6m200k9v4fo8twb4qjc	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	55309	2026-08-14 00:32:27.386
cmss7q6m200kdv4fodygkaate	cmss7q6m200k9v4fo8twb4qjc	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	6212	2026-08-14 00:32:27.386
cmss7q6m200kev4fo1h1x2fqd	cmss7q6m200k9v4fo8twb4qjc	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	3349	2026-08-14 00:32:27.386
cmss7q6m200kfv4fovuv3dtuf	cmss7q6m200k9v4fo8twb4qjc	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	140	2026-08-14 00:32:27.386
cmss7q6m200kgv4foqxe2lwwq	cmss7q6m200k9v4fo8twb4qjc	7	cmsh1b3kc0004v45kv13t1190	국민연금	134664	2026-08-14 00:32:27.386
cmss7q6m200khv4fox3wgzzhd	cmss7q6m200k9v4fo8twb4qjc	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	61054	2026-08-14 00:32:27.386
cmss7q6m200kiv4fo3t4i1dbn	cmss7q6m200k9v4fo8twb4qjc	9	cmsh1b3qm0008v45krlvaq333	업무추진비	66379	2026-08-14 00:32:27.386
cmss7q6m200kjv4foogom2uey	cmss7q6m200k9v4fo8twb4qjc	10	cmsh1b42x000gv45kutf85p3y	차량관리비	6439	2026-08-14 00:32:27.386
cmss7q6m200kkv4fow7xklu7k	cmss7q6m200k9v4fo8twb4qjc	11	cmsh1b3wp000cv45k0eshx54k	통신비	3273	2026-08-14 00:32:27.386
cmss7q6m200klv4fodihh9bw8	cmss7q6m200k9v4fo8twb4qjc	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	132814	2026-08-14 00:32:27.386
cmss7q6m200kmv4fosmn9xrfi	cmss7q6m200k9v4fo8twb4qjc	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	25113	2026-08-14 00:32:27.386
cmss7q6m200knv4fo4i124fq6	cmss7q6m200k9v4fo8twb4qjc	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	21370	2026-08-14 00:32:27.386
cmss7q6m200kov4fosgu9floz	cmss7q6m200k9v4fo8twb4qjc	15	cmsh1b3zn000ev45ke50rracp	국외출장비	158587	2026-08-14 00:32:27.386
cmss7q6m200kpv4foj80wl0xz	cmss7q6m200k9v4fo8twb4qjc	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	2390465	2026-08-14 00:32:27.386
cmss7q6m200kqv4fokw9ej3p4	cmss7q6m200k9v4fo8twb4qjc	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	42657	2026-08-14 00:32:27.386
cmss7q6m200krv4fo3vtsuyv5	cmss7q6m200k9v4fo8twb4qjc	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	784817	2026-08-14 00:32:27.386
cmss7q6m200ksv4fo4bqcij7l	cmss7q6m200k9v4fo8twb4qjc	19	cmsh1b3iy0003v45kozth7aas	건강보험	129014	2026-08-14 00:32:27.386
cmss7q6po00lev4fob6fkbo22	cmss7q6po00ldv4fowwtscdjq	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:27.516
cmss7q6po00lfv4fo2uk87vb9	cmss7q6po00ldv4fowwtscdjq	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	17213	2026-08-14 00:32:27.516
cmss7q6po00lgv4fo6ige7tw3	cmss7q6po00ldv4fowwtscdjq	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	40624	2026-08-14 00:32:27.516
cmss7q6po00lhv4fod6c1gf38	cmss7q6po00ldv4fowwtscdjq	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	4563	2026-08-14 00:32:27.516
cmss7q6po00liv4fotajatlc0	cmss7q6po00ldv4fowwtscdjq	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	2460	2026-08-14 00:32:27.516
cmss7q6po00ljv4fotkhpot3h	cmss7q6po00ldv4fowwtscdjq	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	103	2026-08-14 00:32:27.516
cmss7q6po00lkv4fo998co7ob	cmss7q6po00ldv4fowwtscdjq	7	cmsh1b3kc0004v45kv13t1190	국민연금	98909	2026-08-14 00:32:27.516
cmss7q6po00llv4fo823wzhr9	cmss7q6po00ldv4fowwtscdjq	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	44844	2026-08-14 00:32:27.516
cmss7q6po00lmv4fo4cwbe2q1	cmss7q6po00ldv4fowwtscdjq	9	cmsh1b3qm0008v45krlvaq333	업무추진비	48755	2026-08-14 00:32:27.516
cmss7q6po00lnv4folj0wzg3m	cmss7q6po00ldv4fowwtscdjq	10	cmsh1b42x000gv45kutf85p3y	차량관리비	4729	2026-08-14 00:32:27.516
cmss7q6po00lov4foa4wteaha	cmss7q6po00ldv4fowwtscdjq	11	cmsh1b3wp000cv45k0eshx54k	통신비	2404	2026-08-14 00:32:27.516
cmss7q6po00lpv4foha7o8uz4	cmss7q6po00ldv4fowwtscdjq	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	97551	2026-08-14 00:32:27.516
cmss7q6po00lqv4fog5ucepid	cmss7q6po00ldv4fowwtscdjq	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	18445	2026-08-14 00:32:27.516
cmss7q6po00lrv4fo4lvloigw	cmss7q6po00ldv4fowwtscdjq	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	15696	2026-08-14 00:32:27.516
cmss7q6po00lsv4fowibtl1gn	cmss7q6po00ldv4fowwtscdjq	15	cmsh1b3zn000ev45ke50rracp	국외출장비	116480	2026-08-14 00:32:27.516
cmss7q6po00ltv4fodkp6u7iu	cmss7q6po00ldv4fowwtscdjq	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	1755771	2026-08-14 00:32:27.516
cmss7q6po00luv4forj4x1c2y	cmss7q6po00ldv4fowwtscdjq	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	31331	2026-08-14 00:32:27.516
cmss7q6po00lvv4fomuhtnfvt	cmss7q6po00ldv4fowwtscdjq	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	576440	2026-08-14 00:32:27.516
cmss7q6po00lwv4fo9bv2l46u	cmss7q6po00ldv4fowwtscdjq	19	cmsh1b3iy0003v45kozth7aas	건강보험	94759	2026-08-14 00:32:27.516
cmss7q6t000miv4fo7qfnq7zp	cmss7q6t000mhv4focggy6tc5	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:27.636
cmss7q6t000mjv4foif1ghgrl	cmss7q6t000mhv4focggy6tc5	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	8085	2026-08-14 00:32:27.636
cmss7q6t000mkv4fotx3l78lh	cmss7q6t000mhv4focggy6tc5	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	19081	2026-08-14 00:32:27.636
cmss7q6t000mlv4fot39drtgq	cmss7q6t000mhv4focggy6tc5	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	2143	2026-08-14 00:32:27.636
cmss7q6t000mmv4focxal9c9m	cmss7q6t000mhv4focggy6tc5	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	1155	2026-08-14 00:32:27.636
cmss7q6t000mnv4foner86egw	cmss7q6t000mhv4focggy6tc5	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	48	2026-08-14 00:32:27.636
cmss7q6t000mov4foxbvoyku0	cmss7q6t000mhv4focggy6tc5	7	cmsh1b3kc0004v45kv13t1190	국민연금	46457	2026-08-14 00:32:27.636
cmss7q6t000mpv4fovzmjmbix	cmss7q6t000mhv4focggy6tc5	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	21063	2026-08-14 00:32:27.636
cmss7q6t000mqv4fojofr08uv	cmss7q6t000mhv4focggy6tc5	9	cmsh1b3qm0008v45krlvaq333	업무추진비	22900	2026-08-14 00:32:27.636
cmss7q6t000mrv4fo7d9yj7iy	cmss7q6t000mhv4focggy6tc5	10	cmsh1b42x000gv45kutf85p3y	차량관리비	2221	2026-08-14 00:32:27.636
cmss7q6t000msv4fov3djqnkx	cmss7q6t000mhv4focggy6tc5	11	cmsh1b3wp000cv45k0eshx54k	통신비	1129	2026-08-14 00:32:27.636
cmss7q6t000mtv4foh09howhk	cmss7q6t000mhv4focggy6tc5	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	45819	2026-08-14 00:32:27.636
cmss7q6t000muv4fod1i0oq8c	cmss7q6t000mhv4focggy6tc5	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	8663	2026-08-14 00:32:27.636
cmss7q6t000mvv4fo11h10dzl	cmss7q6t000mhv4focggy6tc5	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	7372	2026-08-14 00:32:27.636
cmss7q6t000mwv4fo0byr2cdp	cmss7q6t000mhv4focggy6tc5	15	cmsh1b3zn000ev45ke50rracp	국외출장비	54710	2026-08-14 00:32:27.636
cmss7q6t000mxv4fox3xs9n1b	cmss7q6t000mhv4focggy6tc5	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	824683	2026-08-14 00:32:27.636
cmss7q6t000myv4fo3ff9czf4	cmss7q6t000mhv4focggy6tc5	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	14716	2026-08-14 00:32:27.636
cmss7q6t000mzv4fo270azl5q	cmss7q6t000mhv4focggy6tc5	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	270753	2026-08-14 00:32:27.636
cmss7q6t000n0v4fofn3qhf9x	cmss7q6t000mhv4focggy6tc5	19	cmsh1b3iy0003v45kozth7aas	건강보험	44508	2026-08-14 00:32:27.636
cmss7q6wb00nmv4foe90dutan	cmss7q6wb00nlv4fooaw12npc	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:27.755
cmss7q6wb00nnv4fo6pm1j2jg	cmss7q6wb00nlv4fooaw12npc	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	7213	2026-08-14 00:32:27.755
cmss7q6wb00nov4fo50p2zg95	cmss7q6wb00nlv4fooaw12npc	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	17022	2026-08-14 00:32:27.755
cmss7q6wb00npv4fo0xusvjsk	cmss7q6wb00nlv4fooaw12npc	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	1912	2026-08-14 00:32:27.755
cmss7q6wb00nqv4foidbv4fxt	cmss7q6wb00nlv4fooaw12npc	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	1030	2026-08-14 00:32:27.755
cmss7q6wb00nrv4fonrou7mgj	cmss7q6wb00nlv4fooaw12npc	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	43	2026-08-14 00:32:27.755
cmss7q6wb00nsv4fooekushqc	cmss7q6wb00nlv4fooaw12npc	7	cmsh1b3kc0004v45kv13t1190	국민연금	41445	2026-08-14 00:32:27.755
cmss7q6wb00ntv4fof5lrq1px	cmss7q6wb00nlv4fooaw12npc	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	18790	2026-08-14 00:32:27.755
cmss7q6wb00nuv4foowz2e892	cmss7q6wb00nlv4fooaw12npc	9	cmsh1b3qm0008v45krlvaq333	업무추진비	20429	2026-08-14 00:32:27.755
cmss7q6wb00nvv4foh7o9o2w4	cmss7q6wb00nlv4fooaw12npc	10	cmsh1b42x000gv45kutf85p3y	차량관리비	1981	2026-08-14 00:32:27.755
cmss7q6wb00nwv4fol9zeucix	cmss7q6wb00nlv4fooaw12npc	11	cmsh1b3wp000cv45k0eshx54k	통신비	1007	2026-08-14 00:32:27.755
cmss7q6wb00nxv4foxm9gtxs7	cmss7q6wb00nlv4fooaw12npc	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	40876	2026-08-14 00:32:27.755
cmss7q6wb00nyv4fow76wd0rc	cmss7q6wb00nlv4fooaw12npc	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	7729	2026-08-14 00:32:27.755
cmss7q6wb00nzv4fors3dmam3	cmss7q6wb00nlv4fooaw12npc	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	6577	2026-08-14 00:32:27.755
cmss7q6wb00o0v4fobwe27bmp	cmss7q6wb00nlv4fooaw12npc	15	cmsh1b3zn000ev45ke50rracp	국외출장비	48808	2026-08-14 00:32:27.755
cmss7q6wb00o1v4fo34uw4c0i	cmss7q6wb00nlv4fooaw12npc	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	735715	2026-08-14 00:32:27.755
cmss7q6wb00o2v4foh1sx76nj	cmss7q6wb00nlv4fooaw12npc	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	13128	2026-08-14 00:32:27.755
cmss7q6wb00o3v4fol01lc3q4	cmss7q6wb00nlv4fooaw12npc	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	241544	2026-08-14 00:32:27.755
cmss7q6wb00o4v4fo7ykmlwl6	cmss7q6wb00nlv4fooaw12npc	19	cmsh1b3iy0003v45kozth7aas	건강보험	39706	2026-08-14 00:32:27.755
cmss7q6zv00oqv4fo81xa64of	cmss7q6zv00opv4foumpw9xux	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:27.883
cmss7q6zv00orv4fo78kten6x	cmss7q6zv00opv4foumpw9xux	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	7023	2026-08-14 00:32:27.883
cmss7q6zv00osv4fotuldvs8y	cmss7q6zv00opv4foumpw9xux	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	16576	2026-08-14 00:32:27.883
cmss7q6zv00otv4fosvxhulol	cmss7q6zv00opv4foumpw9xux	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	1861	2026-08-14 00:32:27.883
cmss7q6zv00ouv4fof9rfdx16	cmss7q6zv00opv4foumpw9xux	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	1003	2026-08-14 00:32:27.883
cmss7q6zv00ovv4foe0grfq8h	cmss7q6zv00opv4foumpw9xux	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	42	2026-08-14 00:32:27.883
cmss7q6zv00owv4focl7h6qrs	cmss7q6zv00opv4foumpw9xux	7	cmsh1b3kc0004v45kv13t1190	국민연금	40359	2026-08-14 00:32:27.883
cmss7q6zv00oxv4focol2287v	cmss7q6zv00opv4foumpw9xux	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	18298	2026-08-14 00:32:27.883
cmss7q6zv00oyv4fonrnex5rb	cmss7q6zv00opv4foumpw9xux	9	cmsh1b3qm0008v45krlvaq333	업무추진비	19894	2026-08-14 00:32:27.883
cmss7q6zv00ozv4fo2sth2l99	cmss7q6zv00opv4foumpw9xux	10	cmsh1b42x000gv45kutf85p3y	차량관리비	1929	2026-08-14 00:32:27.883
cmss7q6zv00p0v4foi6ubg5jh	cmss7q6zv00opv4foumpw9xux	11	cmsh1b3wp000cv45k0eshx54k	통신비	981	2026-08-14 00:32:27.883
cmss7q6zv00p1v4fo42lu83xh	cmss7q6zv00opv4foumpw9xux	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	39804	2026-08-14 00:32:27.883
cmss7q6zv00p2v4fodly63qvu	cmss7q6zv00opv4foumpw9xux	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	7526	2026-08-14 00:32:27.883
cmss7q6zv00p3v4fok17h1fes	cmss7q6zv00opv4foumpw9xux	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	6404	2026-08-14 00:32:27.883
cmss7q6zv00p4v4foj171xpc6	cmss7q6zv00opv4foumpw9xux	15	cmsh1b3zn000ev45ke50rracp	국외출장비	47529	2026-08-14 00:32:27.883
cmss7q6zv00p5v4fo97u4s059	cmss7q6zv00opv4foumpw9xux	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	716428	2026-08-14 00:32:27.883
cmss7q6zv00p6v4foscu59hbu	cmss7q6zv00opv4foumpw9xux	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	12784	2026-08-14 00:32:27.883
cmss7q6zv00p7v4fo4orw4fx5	cmss7q6zv00opv4foumpw9xux	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	235211	2026-08-14 00:32:27.883
cmss7q6zv00p8v4fo5ubvy0gh	cmss7q6zv00opv4foumpw9xux	19	cmsh1b3iy0003v45kozth7aas	건강보험	38666	2026-08-14 00:32:27.883
cmss7q73400puv4foxpuizncr	cmss7q73300ptv4fojnvckumz	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:28
cmss7q73400pvv4fovdfb0l7e	cmss7q73300ptv4fojnvckumz	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	6326	2026-08-14 00:32:28
cmss7q73400pwv4fokc0v0ng2	cmss7q73300ptv4fojnvckumz	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	14931	2026-08-14 00:32:28
cmss7q73400pxv4fogro0xijh	cmss7q73300ptv4fojnvckumz	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	1677	2026-08-14 00:32:28
cmss7q73400pyv4fonnbf5pgt	cmss7q73300ptv4fojnvckumz	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	904	2026-08-14 00:32:28
cmss7q73400pzv4fo148jmjof	cmss7q73300ptv4fojnvckumz	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	37	2026-08-14 00:32:28
cmss7q73400q0v4fo1uz8ximf	cmss7q73300ptv4fojnvckumz	7	cmsh1b3kc0004v45kv13t1190	국민연금	36353	2026-08-14 00:32:28
cmss7q73400q1v4fokgs7ezpb	cmss7q73300ptv4fojnvckumz	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	16482	2026-08-14 00:32:28
cmss7q73400q2v4foiqcr4uz3	cmss7q73300ptv4fojnvckumz	9	cmsh1b3qm0008v45krlvaq333	업무추진비	17919	2026-08-14 00:32:28
cmss7q73400q3v4fo9uxcaygr	cmss7q73300ptv4fojnvckumz	10	cmsh1b42x000gv45kutf85p3y	차량관리비	1738	2026-08-14 00:32:28
cmss7q73400q4v4fota0dv4im	cmss7q73300ptv4fojnvckumz	11	cmsh1b3wp000cv45k0eshx54k	통신비	883	2026-08-14 00:32:28
cmss7q73400q5v4forqlx8lej	cmss7q73300ptv4fojnvckumz	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	35853	2026-08-14 00:32:28
cmss7q73400q6v4fopw1jdtl9	cmss7q73300ptv4fojnvckumz	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	6779	2026-08-14 00:32:28
cmss7q73400q7v4fo8pxoj6sj	cmss7q73300ptv4fojnvckumz	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	5769	2026-08-14 00:32:28
cmss7q73400q8v4fopj1p3uo3	cmss7q73300ptv4fojnvckumz	15	cmsh1b3zn000ev45ke50rracp	국외출장비	42811	2026-08-14 00:32:28
cmss7q73400q9v4foa4ivjyo4	cmss7q73300ptv4fojnvckumz	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	645316	2026-08-14 00:32:28
cmss7q73400qav4fodg95ep3r	cmss7q73300ptv4fojnvckumz	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	11515	2026-08-14 00:32:28
cmss7q73400qbv4fo53xy2scg	cmss7q73300ptv4fojnvckumz	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	211864	2026-08-14 00:32:28
cmss7q73400qcv4for3fim5en	cmss7q73300ptv4fojnvckumz	19	cmsh1b3iy0003v45kozth7aas	건강보험	34828	2026-08-14 00:32:28
cmss7q76e00qyv4foprcsj45z	cmss7q76e00qxv4fo04jk3d64	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:28.118
cmss7q76e00qzv4foclrgb632	cmss7q76e00qxv4fo04jk3d64	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	5954	2026-08-14 00:32:28.118
cmss7q76e00r0v4fo862y61ov	cmss7q76e00qxv4fo04jk3d64	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	14052	2026-08-14 00:32:28.118
cmss7q76e00r1v4foh9devfny	cmss7q76e00qxv4fo04jk3d64	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	1578	2026-08-14 00:32:28.118
cmss7q76e00r2v4fo5iz37a8l	cmss7q76e00qxv4fo04jk3d64	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	851	2026-08-14 00:32:28.118
cmss7q76e00r3v4for9r5pdnv	cmss7q76e00qxv4fo04jk3d64	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	35	2026-08-14 00:32:28.118
cmss7q76e00r4v4fo2tdr03ux	cmss7q76e00qxv4fo04jk3d64	7	cmsh1b3kc0004v45kv13t1190	국민연금	34213	2026-08-14 00:32:28.118
cmss7q76e00r5v4fokaosp1he	cmss7q76e00qxv4fo04jk3d64	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	15511	2026-08-14 00:32:28.118
cmss7q76e00r6v4fowijt1utp	cmss7q76e00qxv4fo04jk3d64	9	cmsh1b3qm0008v45krlvaq333	업무추진비	16864	2026-08-14 00:32:28.118
cmss7q76e00r7v4foobvsqybn	cmss7q76e00qxv4fo04jk3d64	10	cmsh1b42x000gv45kutf85p3y	차량관리비	1636	2026-08-14 00:32:28.118
cmss7q76e00r8v4foass15wuj	cmss7q76e00qxv4fo04jk3d64	11	cmsh1b3wp000cv45k0eshx54k	통신비	831	2026-08-14 00:32:28.118
cmss7q76e00r9v4folb3l4cs1	cmss7q76e00qxv4fo04jk3d64	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	33743	2026-08-14 00:32:28.118
cmss7q76e00rav4fof4wfqnfq	cmss7q76e00qxv4fo04jk3d64	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	6380	2026-08-14 00:32:28.118
cmss7q76e00rbv4foxt45lqna	cmss7q76e00qxv4fo04jk3d64	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	5429	2026-08-14 00:32:28.118
cmss7q76e00rcv4fo11nfyigq	cmss7q76e00qxv4fo04jk3d64	15	cmsh1b3zn000ev45ke50rracp	국외출장비	40291	2026-08-14 00:32:28.118
cmss7q76e00rdv4fo96kyjgnn	cmss7q76e00qxv4fo04jk3d64	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	607326	2026-08-14 00:32:28.118
cmss7q76e00rev4fo7u9vq22l	cmss7q76e00qxv4fo04jk3d64	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	10837	2026-08-14 00:32:28.118
cmss7q76e00rfv4fogc65l363	cmss7q76e00qxv4fo04jk3d64	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	199392	2026-08-14 00:32:28.118
cmss7q76e00rgv4fo7iqx0rk9	cmss7q76e00qxv4fo04jk3d64	19	cmsh1b3iy0003v45kozth7aas	건강보험	32777	2026-08-14 00:32:28.118
cmss7q79p00s2v4fovdtgzv4s	cmss7q79p00s1v4foixmh7olm	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:28.237
cmss7q79p00s3v4foal8tor3r	cmss7q79p00s1v4foixmh7olm	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	5387	2026-08-14 00:32:28.237
cmss7q79p00s4v4fojxitzcab	cmss7q79p00s1v4foixmh7olm	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	12715	2026-08-14 00:32:28.237
cmss7q79p00s5v4foyph050gj	cmss7q79p00s1v4foixmh7olm	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	1428	2026-08-14 00:32:28.237
cmss7q79p00s6v4fo9jty8o4g	cmss7q79p00s1v4foixmh7olm	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	770	2026-08-14 00:32:28.237
cmss7q79p00s7v4fociuet1v5	cmss7q79p00s1v4foixmh7olm	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	32	2026-08-14 00:32:28.237
cmss7q79p00s8v4foi97txht9	cmss7q79p00s1v4foixmh7olm	7	cmsh1b3kc0004v45kv13t1190	국민연금	30958	2026-08-14 00:32:28.237
cmss7q79p00s9v4for8sm245x	cmss7q79p00s1v4foixmh7olm	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	14036	2026-08-14 00:32:28.237
cmss7q79p00sav4fo17x06dzp	cmss7q79p00s1v4foixmh7olm	9	cmsh1b3qm0008v45krlvaq333	업무추진비	15260	2026-08-14 00:32:28.237
cmss7q79p00sbv4fop59pi0xm	cmss7q79p00s1v4foixmh7olm	10	cmsh1b42x000gv45kutf85p3y	차량관리비	1480	2026-08-14 00:32:28.237
cmss7q79p00scv4foo0ujjp11	cmss7q79p00s1v4foixmh7olm	11	cmsh1b3wp000cv45k0eshx54k	통신비	752	2026-08-14 00:32:28.237
cmss7q79p00sdv4foh6a0iebx	cmss7q79p00s1v4foixmh7olm	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	30533	2026-08-14 00:32:28.237
cmss7q79p00sev4fo8bx9aj5z	cmss7q79p00s1v4foixmh7olm	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	5773	2026-08-14 00:32:28.237
cmss7q79p00sfv4folnk0o20y	cmss7q79p00s1v4foixmh7olm	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	4913	2026-08-14 00:32:28.237
cmss7q79p00sgv4foe6uykjus	cmss7q79p00s1v4foixmh7olm	15	cmsh1b3zn000ev45ke50rracp	국외출장비	36458	2026-08-14 00:32:28.237
cmss7q79p00shv4foig64wav3	cmss7q79p00s1v4foixmh7olm	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	549560	2026-08-14 00:32:28.237
cmss7q79p00siv4foz48087f6	cmss7q79p00s1v4foixmh7olm	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	9806	2026-08-14 00:32:28.237
cmss7q79p00sjv4foj6b6u789	cmss7q79p00s1v4foixmh7olm	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	180427	2026-08-14 00:32:28.237
cmss7q79p00skv4fod5qxmzli	cmss7q79p00s1v4foixmh7olm	19	cmsh1b3iy0003v45kozth7aas	건강보험	29660	2026-08-14 00:32:28.237
cmss7q7d100t6v4foplrii3od	cmss7q7d100t5v4fom8yoq6vc	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:28.357
cmss7q7d100t7v4foyv2sqrb6	cmss7q7d100t5v4fom8yoq6vc	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	4363	2026-08-14 00:32:28.357
cmss7q7d100t8v4foov75429n	cmss7q7d100t5v4fom8yoq6vc	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	10298	2026-08-14 00:32:28.357
cmss7q7d100t9v4fokv15h24s	cmss7q7d100t5v4fom8yoq6vc	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	1156	2026-08-14 00:32:28.357
cmss7q7d100tav4fozb7b8f3j	cmss7q7d100t5v4fom8yoq6vc	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	623	2026-08-14 00:32:28.357
cmss7q7d100tbv4foi2ljo7cu	cmss7q7d100t5v4fom8yoq6vc	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	26	2026-08-14 00:32:28.357
cmss7q7d100tcv4foil6zdh0u	cmss7q7d100t5v4fom8yoq6vc	7	cmsh1b3kc0004v45kv13t1190	국민연금	25073	2026-08-14 00:32:28.357
cmss7q7d100tdv4fokd347c0x	cmss7q7d100t5v4fom8yoq6vc	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	11367	2026-08-14 00:32:28.357
cmss7q7d100tev4fo0cekn8tx	cmss7q7d100t5v4fom8yoq6vc	9	cmsh1b3qm0008v45krlvaq333	업무추진비	12359	2026-08-14 00:32:28.357
cmss7q7d100tfv4foqozkprcx	cmss7q7d100t5v4fom8yoq6vc	10	cmsh1b42x000gv45kutf85p3y	차량관리비	1198	2026-08-14 00:32:28.357
cmss7q7d100tgv4foymyw3c6y	cmss7q7d100t5v4fom8yoq6vc	11	cmsh1b3wp000cv45k0eshx54k	통신비	609	2026-08-14 00:32:28.357
cmss7q7d100thv4foeutocwzh	cmss7q7d100t5v4fom8yoq6vc	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	24728	2026-08-14 00:32:28.357
cmss7q7d100tiv4fo7cykytpq	cmss7q7d100t5v4fom8yoq6vc	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	4675	2026-08-14 00:32:28.357
cmss7q7d100tjv4foxj6rd9ra	cmss7q7d100t5v4fom8yoq6vc	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	3978	2026-08-14 00:32:28.357
cmss7q7d100tkv4fo9dmz97r0	cmss7q7d100t5v4fom8yoq6vc	15	cmsh1b3zn000ev45ke50rracp	국외출장비	29527	2026-08-14 00:32:28.357
cmss7q7d100tlv4foladfb45d	cmss7q7d100t5v4fom8yoq6vc	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	445077	2026-08-14 00:32:28.357
cmss7q7d100tmv4fodgo2oqro	cmss7q7d100t5v4fom8yoq6vc	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	7942	2026-08-14 00:32:28.357
cmss7q7d100tnv4fonp7c85h5	cmss7q7d100t5v4fom8yoq6vc	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	146124	2026-08-14 00:32:28.357
cmss7q7d100tov4fouwok6iiy	cmss7q7d100t5v4fom8yoq6vc	19	cmsh1b3iy0003v45kozth7aas	건강보험	24021	2026-08-14 00:32:28.357
cmss7q7gi00uav4fo5eogw6ko	cmss7q7gi00u9v4fo32r1iffz	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:28.482
cmss7q7gi00ubv4fow4qzouyz	cmss7q7gi00u9v4fo32r1iffz	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	2088	2026-08-14 00:32:28.482
cmss7q7gi00ucv4fohaohvpk6	cmss7q7gi00u9v4fo32r1iffz	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	4927	2026-08-14 00:32:28.482
cmss7q7gi00udv4fo9leumbdm	cmss7q7gi00u9v4fo32r1iffz	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	553	2026-08-14 00:32:28.482
cmss7q7gi00uev4fo7hjc1ees	cmss7q7gi00u9v4fo32r1iffz	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	298	2026-08-14 00:32:28.482
cmss7q7gi00ufv4fo9vf9nrwj	cmss7q7gi00u9v4fo32r1iffz	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	12	2026-08-14 00:32:28.482
cmss7q7gi00ugv4fopt9exf06	cmss7q7gi00u9v4fo32r1iffz	7	cmsh1b3kc0004v45kv13t1190	국민연금	11997	2026-08-14 00:32:28.482
cmss7q7gi00uhv4fow5bv3g9j	cmss7q7gi00u9v4fo32r1iffz	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	5439	2026-08-14 00:32:28.482
cmss7q7gi00uiv4foj85r1vhh	cmss7q7gi00u9v4fo32r1iffz	9	cmsh1b3qm0008v45krlvaq333	업무추진비	5913	2026-08-14 00:32:28.482
cmss7q7gi00ujv4foyjmane5k	cmss7q7gi00u9v4fo32r1iffz	10	cmsh1b42x000gv45kutf85p3y	차량관리비	573	2026-08-14 00:32:28.482
cmss7q7gi00ukv4foxi1skr66	cmss7q7gi00u9v4fo32r1iffz	11	cmsh1b3wp000cv45k0eshx54k	통신비	291	2026-08-14 00:32:28.482
cmss7q7gi00ulv4fok6hnuvup	cmss7q7gi00u9v4fo32r1iffz	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	11832	2026-08-14 00:32:28.482
cmss7q7gi00umv4fowb9xso07	cmss7q7gi00u9v4fo32r1iffz	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	2237	2026-08-14 00:32:28.482
cmss7q7gi00unv4fobfmwvtvc	cmss7q7gi00u9v4fo32r1iffz	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	1903	2026-08-14 00:32:28.482
cmss7q7gi00uov4foix18sea9	cmss7q7gi00u9v4fo32r1iffz	15	cmsh1b3zn000ev45ke50rracp	국외출장비	14129	2026-08-14 00:32:28.482
cmss7q7gi00upv4fo93g10ett	cmss7q7gi00u9v4fo32r1iffz	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	212974	2026-08-14 00:32:28.482
cmss7q7gi00uqv4foulx8kdeb	cmss7q7gi00u9v4fo32r1iffz	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	3800	2026-08-14 00:32:28.482
cmss7q7gi00urv4fowb6z7b52	cmss7q7gi00u9v4fo32r1iffz	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	69921	2026-08-14 00:32:28.482
cmss7q7gi00usv4folcnp5ag3	cmss7q7gi00u9v4fo32r1iffz	19	cmsh1b3iy0003v45kozth7aas	건강보험	11494	2026-08-14 00:32:28.482
cmss7q7jq00vev4fox57dve6l	cmss7q7jq00vdv4fogpnwb7w3	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:28.598
cmss7q7jq00vfv4fo3yc9dgzb	cmss7q7jq00vdv4fogpnwb7w3	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	2060	2026-08-14 00:32:28.598
cmss7q7jq00vgv4foiaphtxc8	cmss7q7jq00vdv4fogpnwb7w3	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	4863	2026-08-14 00:32:28.598
cmss7q7jq00vhv4foldnhux87	cmss7q7jq00vdv4fogpnwb7w3	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	546	2026-08-14 00:32:28.598
cmss7q7jq00viv4fofyuhamkg	cmss7q7jq00vdv4fogpnwb7w3	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	294	2026-08-14 00:32:28.598
cmss7q7jq00vjv4fod4tcerpr	cmss7q7jq00vdv4fogpnwb7w3	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	12	2026-08-14 00:32:28.598
cmss7q7jq00vkv4fo1bmqtequ	cmss7q7jq00vdv4fogpnwb7w3	7	cmsh1b3kc0004v45kv13t1190	국민연금	11841	2026-08-14 00:32:28.598
cmss7q7jq00vlv4focve6bnn1	cmss7q7jq00vdv4fogpnwb7w3	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	5368	2026-08-14 00:32:28.598
cmss7q7jq00vmv4foa4xpcpak	cmss7q7jq00vdv4fogpnwb7w3	9	cmsh1b3qm0008v45krlvaq333	업무추진비	5836	2026-08-14 00:32:28.598
cmss7q7jq00vnv4foixz38acc	cmss7q7jq00vdv4fogpnwb7w3	10	cmsh1b42x000gv45kutf85p3y	차량관리비	566	2026-08-14 00:32:28.598
cmss7q7jq00vov4fo7sy8svow	cmss7q7jq00vdv4fogpnwb7w3	11	cmsh1b3wp000cv45k0eshx54k	통신비	287	2026-08-14 00:32:28.598
cmss7q7jq00vpv4fob16om01n	cmss7q7jq00vdv4fogpnwb7w3	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	11678	2026-08-14 00:32:28.598
cmss7q7jq00vqv4fobdqvhgnd	cmss7q7jq00vdv4fogpnwb7w3	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	2208	2026-08-14 00:32:28.598
cmss7q7jq00vrv4fosf9y19mx	cmss7q7jq00vdv4fogpnwb7w3	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	1879	2026-08-14 00:32:28.598
cmss7q7jq00vsv4foa2xh3mos	cmss7q7jq00vdv4fogpnwb7w3	15	cmsh1b3zn000ev45ke50rracp	국외출장비	13944	2026-08-14 00:32:28.598
cmss7q7jq00vtv4fovtla17xz	cmss7q7jq00vdv4fogpnwb7w3	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	210197	2026-08-14 00:32:28.598
cmss7q7jq00vuv4fonatv5g1c	cmss7q7jq00vdv4fogpnwb7w3	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	3750	2026-08-14 00:32:28.598
cmss7q7jq00vvv4foqsy2zjxq	cmss7q7jq00vdv4fogpnwb7w3	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	69010	2026-08-14 00:32:28.598
cmss7q7jq00vwv4focle0mkmq	cmss7q7jq00vdv4fogpnwb7w3	19	cmsh1b3iy0003v45kozth7aas	건강보험	11344	2026-08-14 00:32:28.598
cmss7q7mw00wiv4foaoktwdbv	cmss7q7mw00whv4fo80vmluu2	1	cmsh1b44c000hv45k8wyhshmu	기타지급	0	2026-08-14 00:32:28.713
cmss7q7mw00wjv4foxlgx7iut	cmss7q7mw00whv4fo80vmluu2	2	cmsh1b3v5000bv45kkg5k7jdr	지급수수료	1045	2026-08-14 00:32:28.713
cmss7q7mx00wkv4fodv5fkgq0	cmss7q7mw00whv4fo80vmluu2	3	cmsh1b3tj000av45kp4w6n24d	국내출장비	2466	2026-08-14 00:32:28.713
cmss7q7mx00wlv4fo399wljpc	cmss7q7mw00whv4fo80vmluu2	4	cmsh1b41f000fv45k4qgcw4ac	감가상각비(차량)	277	2026-08-14 00:32:28.713
cmss7q7mx00wmv4foutjejs7n	cmss7q7mw00whv4fo80vmluu2	5	cmsh1b45p000iv45krmpx8fmv	지급수수료(일반)	149	2026-08-14 00:32:28.713
cmss7q7mx00wnv4fo2ncigd3b	cmss7q7mw00whv4fo80vmluu2	6	cmsh1b3y6000dv45k9tvmq64r	도서인쇄비	6	2026-08-14 00:32:28.713
cmss7q7mx00wov4foq93hkltf	cmss7q7mw00whv4fo80vmluu2	7	cmsh1b3kc0004v45kv13t1190	국민연금	6006	2026-08-14 00:32:28.713
cmss7q7mx00wpv4fomid8pk6q	cmss7q7mw00whv4fo80vmluu2	8	cmsh1b3ow0007v45kegisx5jd	식대(식권)	2723	2026-08-14 00:32:28.713
cmss7q7mx00wqv4fo6atf2fyi	cmss7q7mw00whv4fo80vmluu2	9	cmsh1b3qm0008v45krlvaq333	업무추진비	2960	2026-08-14 00:32:28.713
cmss7q7mx00wrv4focu3gooj5	cmss7q7mw00whv4fo80vmluu2	10	cmsh1b42x000gv45kutf85p3y	차량관리비	287	2026-08-14 00:32:28.713
cmss7q7mx00wsv4foqndi4ika	cmss7q7mw00whv4fo80vmluu2	11	cmsh1b3wp000cv45k0eshx54k	통신비	146	2026-08-14 00:32:28.713
cmss7q7mx00wtv4fokpb2kg1g	cmss7q7mw00whv4fo80vmluu2	12	cmsh1b3rx0009v45kvzp0f6by	소모품비	5923	2026-08-14 00:32:28.713
cmss7q7mx00wuv4fo4hcco2gn	cmss7q7mw00whv4fo80vmluu2	13	cmsh1b3lv0005v45k1i15ud1r	산재보험	1120	2026-08-14 00:32:28.713
cmss7q7mx00wvv4fo4e73y223	cmss7q7mw00whv4fo80vmluu2	14	cmsh1b3hc0002v45kkzg3z9wd	복리후생비(기타)	953	2026-08-14 00:32:28.713
cmss7q7mx00wwv4foqrnth8vg	cmss7q7mw00whv4fo80vmluu2	15	cmsh1b3zn000ev45ke50rracp	국외출장비	7073	2026-08-14 00:32:28.713
cmss7q7mx00wxv4foi7tqtzcn	cmss7q7mw00whv4fo80vmluu2	16	cmsh1b3cp0000v45kdnl2mv4k	급료와임금	106617	2026-08-14 00:32:28.713
cmss7q7mx00wyv4fod1v6h9ur	cmss7q7mw00whv4fo80vmluu2	17	cmsh1b3ne0006v45ka0wrz3cs	고용보험	1902	2026-08-14 00:32:28.713
cmss7q7mx00wzv4fozm0wd6h1	cmss7q7mw00whv4fo80vmluu2	18	cmsh1b3fq0001v45k1k7ywxzg	상여금	35003	2026-08-14 00:32:28.713
cmss7q7mx00x0v4fowsjhq1bl	cmss7q7mw00whv4fo80vmluu2	19	cmsh1b3iy0003v45kozth7aas	건강보험	5754	2026-08-14 00:32:28.713
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.invoices (id, run_id, company_id, invoice_number, invoice_type, status, issue_date, period_label, subtotal, markup_amount, total_amount, billing_address, notes, created_at, updated_at) FROM stdin;
cmss7q4vc0009v4fo1h5w8ckt	cmsh7rit90009v4jw0wy1a0dv	cmsh1b47a000jv45kt8g2btbf	\N	DOMESTIC	DRAFT	\N	2026 H1	115940420	0	115940420	\N	\N	2026-08-14 00:32:25.128	2026-08-14 00:32:25.128
cmss7q4z6001dv4foh7r998kj	cmsh7rit90009v4jw0wy1a0dv	cmsh1b48y000kv45kqdgbm8j3	\N	DOMESTIC	DRAFT	\N	2026 H1	76385390	0	76385390	\N	\N	2026-08-14 00:32:25.266	2026-08-14 00:32:25.266
cmss7q52m002hv4fok3pltxka	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ae000lv45kgcv15flb	\N	DOMESTIC	DRAFT	\N	2026 H1	43217290	0	43217290	\N	\N	2026-08-14 00:32:25.391	2026-08-14 00:32:25.391
cmss7q564003lv4fosq2qz1c8	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4bt000mv45km6tt3ls4	\N	OVERSEAS	DRAFT	\N	2026 H1	42103970	2105190	44209160	{"city": null, "line1": "Industriestrasse 6, 63607 Wächtersbach, Germany", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:25.516	2026-08-14 00:32:25.516
cmss7q59h004pv4fozy8ghusb	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4en000nv45k8o15vdeq	\N	DOMESTIC	DRAFT	\N	2026 H1	29644920	0	29644920	\N	\N	2026-08-14 00:32:25.637	2026-08-14 00:32:25.637
cmss7q5cs005tv4foahi0s8ab	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4g2000ov45ko6r97c9s	\N	DOMESTIC	DRAFT	\N	2026 H1	27456820	0	27456820	\N	\N	2026-08-14 00:32:25.756	2026-08-14 00:32:25.756
cmss7q5g8006xv4foar6v7dv7	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4hk000pv45kwzbq77t0	\N	DOMESTIC	DRAFT	\N	2026 H1	12938300	0	12938300	\N	\N	2026-08-14 00:32:25.88	2026-08-14 00:32:25.88
cmss7q5jj0081v4foae13ugo6	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4ja000qv45k2n1ynwji	\N	OVERSEAS	DRAFT	\N	2026 H1	8388460	419420	8807880	{"city": null, "line1": "Land No. 1, Bahya, Ajman, United Arab Emirates", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:26	2026-08-14 00:32:26
cmss7q5mz0095v4fok1ww2i69	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4m4000rv45kwto42p9x	\N	OVERSEAS	DRAFT	\N	2026 H1	4649420	232470	4881890	{"city": null, "line1": "OFFICE 105, Al Qasba, Al Khan, Sharjah, UAE", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:26.124	2026-08-14 00:32:26.124
cmss7q5qb00a9v4fodpgf0f12	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4os000sv45kzco6xvgf	\N	DOMESTIC	DRAFT	\N	2026 H1	12720020	0	12720020	\N	\N	2026-08-14 00:32:26.244	2026-08-14 00:32:26.244
cmss7q5u200bdv4foqgdgbf69	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4q4000tv45kyya9ob77	\N	OVERSEAS	DRAFT	\N	2026 H1	9940930	497040	10437970	{"city": null, "line1": "1255 Avenida del Parque, Colonia Otra No Especificada en el Catálogo,\\nPesquería, Pesquería Municipality,\\nNuevo León 66650,\\nMexico", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:26.378	2026-08-14 00:32:26.378
cmss7q5xg00chv4fo3x6n4dza	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4sp000uv45krukvxdaz	\N	OVERSEAS	DRAFT	\N	2026 H1	9300490	465020	9765510	{"city": null, "line1": "Plot 1, Khai Quang Industrial Zone, Vinh Phuc Ward, Phu Tho Province, Vietnam", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:26.5	2026-08-14 00:32:26.5
cmss7q60r00dlv4foiei1vhxd	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4vb000vv45k58zhvwf2	\N	DOMESTIC	DRAFT	\N	2026 H1	8633550	0	8633550	\N	\N	2026-08-14 00:32:26.619	2026-08-14 00:32:26.619
cmss7q64z00epv4foq50zqsav	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4wm000wv45k8lzp87ri	\N	DOMESTIC	DRAFT	\N	2026 H1	8312620	0	8312620	\N	\N	2026-08-14 00:32:26.771	2026-08-14 00:32:26.771
cmss7q68b00ftv4fox8895mcw	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4xx000xv45kg9lrhu6l	\N	DOMESTIC	DRAFT	\N	2026 H1	8240220	0	8240220	\N	\N	2026-08-14 00:32:26.892	2026-08-14 00:32:26.892
cmss7q6bi00gxv4fos6bkbsnq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b4z9000yv45kfk582b97	\N	OVERSEAS	DRAFT	\N	2026 H1	7947870	397390	8345260	{"city": null, "line1": "No. 65, Huangshan South Road,\\nYancheng Economic Development Zone,\\nYancheng, Jiangsu, China", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:27.006	2026-08-14 00:32:27.006
cmss7q6f300i1v4foiyafg9wh	cmsh7rit90009v4jw0wy1a0dv	cmsh1b51t000zv45k9adb5siw	\N	DOMESTIC	DRAFT	\N	2026 H1	7477120	0	7477120	\N	\N	2026-08-14 00:32:27.135	2026-08-14 00:32:27.135
cmss7q6ih00j5v4fo2w1i59pr	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5340010v45kazu0fg9d	\N	DOMESTIC	DRAFT	\N	2026 H1	5423120	0	5423120	\N	\N	2026-08-14 00:32:27.257	2026-08-14 00:32:27.257
cmss7q6m200k9v4fo8twb4qjc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b54g0011v45kev87ke0m	\N	DOMESTIC	DRAFT	\N	2026 H1	4045090	0	4045090	\N	\N	2026-08-14 00:32:27.386	2026-08-14 00:32:27.386
cmss7q6po00ldv4fowwtscdjq	cmsh7rit90009v4jw0wy1a0dv	cmsh1b55v0012v45k9b9yxq0s	\N	OVERSEAS	DRAFT	\N	2026 H1	2971070	148550	3119620	{"city": null, "line1": "No. 679, Kottaiyur Village, Kannur Post, Thiruvallur, Thiruvallur, Tamil Nadu, India, 602108", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:27.516	2026-08-14 00:32:27.516
cmss7q6t000mhv4focggy6tc5	cmsh7rit90009v4jw0wy1a0dv	cmsh1b58h0013v45knn7t3ki3	\N	DOMESTIC	DRAFT	\N	2026 H1	1395500	0	1395500	\N	\N	2026-08-14 00:32:27.636	2026-08-14 00:32:27.636
cmss7q6wb00nlv4fooaw12npc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b59s0014v45k3thfg7eo	\N	DOMESTIC	DRAFT	\N	2026 H1	1244950	0	1244950	\N	\N	2026-08-14 00:32:27.755	2026-08-14 00:32:27.755
cmss7q6zv00opv4foumpw9xux	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5b40015v45k8mcig9nr	\N	DOMESTIC	DRAFT	\N	2026 H1	1212310	0	1212310	\N	\N	2026-08-14 00:32:27.883	2026-08-14 00:32:27.883
cmss7q73300ptv4fojnvckumz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ci0016v45kk7vqptov	\N	OVERSEAS	DRAFT	\N	2026 H1	1091980	54590	1146570	{"city": null, "line1": "9-9 Yotsuya-Sakamachi, Shinjuku-ku, Tokyo, Japan", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:28	2026-08-14 00:32:28
cmss7q76e00qxv4fo04jk3d64	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5fb0017v45kavuhad0r	\N	OVERSEAS	DRAFT	\N	2026 H1	1027700	51380	1079080	{"city": null, "line1": "9-6 Imado 2-chome, Taito-ku, Tokyo, Japan", "line2": null, "country": "OVERSEAS"}	\N	2026-08-14 00:32:28.118	2026-08-14 00:32:28.118
cmss7q79p00s1v4foixmh7olm	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5ip0018v45kvj32jt75	\N	DOMESTIC	DRAFT	\N	2026 H1	929940	0	929940	\N	\N	2026-08-14 00:32:28.237	2026-08-14 00:32:28.237
cmss7q7d100t5v4fom8yoq6vc	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5k40019v45ku5nghgym	\N	DOMESTIC	DRAFT	\N	2026 H1	753140	0	753140	\N	\N	2026-08-14 00:32:28.357	2026-08-14 00:32:28.357
cmss7q7gi00u9v4fo32r1iffz	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5le001av45kliboorof	\N	DOMESTIC	DRAFT	\N	2026 H1	360380	0	360380	\N	\N	2026-08-14 00:32:28.482	2026-08-14 00:32:28.482
cmss7q7jq00vdv4fogpnwb7w3	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5mu001bv45kjxfmgyyz	\N	DOMESTIC	DRAFT	\N	2026 H1	355680	0	355680	\N	\N	2026-08-14 00:32:28.598	2026-08-14 00:32:28.598
cmss7q7mw00whv4fo80vmluu2	cmsh7rit90009v4jw0wy1a0dv	cmsh1b5oa001cv45kedokcq0k	\N	DOMESTIC	DRAFT	\N	2026 H1	180410	0	180410	\N	\N	2026-08-14 00:32:28.713	2026-08-14 00:32:28.713
\.


--
-- Data for Name: monthly_costs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.monthly_costs (id, project_id, cost_account_id, month, amount, status, version, created_at, updated_at, created_by_id) FROM stdin;
cmss9jcd9000wv4koza35isdr	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2hw000kv4z4f8g8xs9o	1	8500000	DRAFT	1	2026-08-14 01:23:07.485	2026-08-14 01:23:07.485	cmsgzh1nn0007v4z4im98e204
cmss9jce1000yv4koozy52z1d	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2hw000kv4z4f8g8xs9o	2	8500000	DRAFT	1	2026-08-14 01:23:07.513	2026-08-14 01:23:07.513	cmsgzh1nn0007v4z4im98e204
cmss9jcef0010v4kok4yehhy7	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2hw000kv4z4f8g8xs9o	3	8500000	DRAFT	1	2026-08-14 01:23:07.527	2026-08-14 01:23:07.527	cmsgzh1nn0007v4z4im98e204
cmss9jceq0012v4ko48y1nd0w	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2hw000kv4z4f8g8xs9o	4	8500000	DRAFT	1	2026-08-14 01:23:07.538	2026-08-14 01:23:07.538	cmsgzh1nn0007v4z4im98e204
cmss9jcf20014v4komfjl9vxh	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2hw000kv4z4f8g8xs9o	5	8500000	DRAFT	1	2026-08-14 01:23:07.55	2026-08-14 01:23:07.55	cmsgzh1nn0007v4z4im98e204
cmss9jcfb0016v4kopjgak2k7	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2hw000kv4z4f8g8xs9o	6	8500000	DRAFT	1	2026-08-14 01:23:07.56	2026-08-14 01:23:07.56	cmsgzh1nn0007v4z4im98e204
cmss9jcfl0018v4ko80865zn6	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2kb000lv4z45i7fszvy	1	1200000	DRAFT	1	2026-08-14 01:23:07.57	2026-08-14 01:23:07.57	cmsgzh1nn0007v4z4im98e204
cmss9jcfy001av4kor5i6nl84	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2kb000lv4z45i7fszvy	2	1150000	DRAFT	1	2026-08-14 01:23:07.582	2026-08-14 01:23:07.582	cmsgzh1nn0007v4z4im98e204
cmss9jcg8001cv4kog5pbubja	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2kb000lv4z45i7fszvy	3	1180000	DRAFT	1	2026-08-14 01:23:07.592	2026-08-14 01:23:07.592	cmsgzh1nn0007v4z4im98e204
cmss9jcgi001ev4kozpr4bwpz	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2kb000lv4z45i7fszvy	4	1220000	DRAFT	1	2026-08-14 01:23:07.602	2026-08-14 01:23:07.602	cmsgzh1nn0007v4z4im98e204
cmss9jcgu001gv4kokmss6q7y	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2kb000lv4z45i7fszvy	5	1190000	DRAFT	1	2026-08-14 01:23:07.615	2026-08-14 01:23:07.615	cmsgzh1nn0007v4z4im98e204
cmss9jch5001iv4koeamjukjw	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2kb000lv4z45i7fszvy	6	1210000	DRAFT	1	2026-08-14 01:23:07.625	2026-08-14 01:23:07.625	cmsgzh1nn0007v4z4im98e204
cmss9jchf001kv4kocdzwtyfy	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2mg000mv4z4tiforuzt	1	980000	DRAFT	1	2026-08-14 01:23:07.636	2026-08-14 01:23:07.636	cmsgzh1nn0007v4z4im98e204
cmss9jchp001mv4kohr728y8i	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2mg000mv4z4tiforuzt	2	920000	DRAFT	1	2026-08-14 01:23:07.645	2026-08-14 01:23:07.645	cmsgzh1nn0007v4z4im98e204
cmss9jchz001ov4ko93wjf2h7	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2mg000mv4z4tiforuzt	3	1050000	DRAFT	1	2026-08-14 01:23:07.655	2026-08-14 01:23:07.655	cmsgzh1nn0007v4z4im98e204
cmss9jcia001qv4ko475kvfkj	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2mg000mv4z4tiforuzt	4	1100000	DRAFT	1	2026-08-14 01:23:07.666	2026-08-14 01:23:07.666	cmsgzh1nn0007v4z4im98e204
cmss9jcik001sv4ko1f2a3aca	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2mg000mv4z4tiforuzt	5	990000	DRAFT	1	2026-08-14 01:23:07.676	2026-08-14 01:23:07.676	cmsgzh1nn0007v4z4im98e204
cmss9jciw001uv4koelvwo9fz	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2mg000mv4z4tiforuzt	6	1010000	DRAFT	1	2026-08-14 01:23:07.688	2026-08-14 01:23:07.688	cmsgzh1nn0007v4z4im98e204
cmss9jcj8001wv4konwnkyye6	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2om000nv4z4n0q3kl9g	1	500000	DRAFT	1	2026-08-14 01:23:07.7	2026-08-14 01:23:07.7	cmsgzh1nn0007v4z4im98e204
cmss9jcjh001yv4koi8do94av	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2om000nv4z4n0q3kl9g	2	500000	DRAFT	1	2026-08-14 01:23:07.71	2026-08-14 01:23:07.71	cmsgzh1nn0007v4z4im98e204
cmss9jcjs0020v4koeixaslpl	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2om000nv4z4n0q3kl9g	3	500000	DRAFT	1	2026-08-14 01:23:07.72	2026-08-14 01:23:07.72	cmsgzh1nn0007v4z4im98e204
cmss9jck30022v4ko0y5hvsw8	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2om000nv4z4n0q3kl9g	4	500000	DRAFT	1	2026-08-14 01:23:07.731	2026-08-14 01:23:07.731	cmsgzh1nn0007v4z4im98e204
cmss9jckd0024v4koeobylw3d	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2om000nv4z4n0q3kl9g	5	500000	DRAFT	1	2026-08-14 01:23:07.741	2026-08-14 01:23:07.741	cmsgzh1nn0007v4z4im98e204
cmss9jcko0026v4ko05gjnj5a	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2om000nv4z4n0q3kl9g	6	500000	DRAFT	1	2026-08-14 01:23:07.753	2026-08-14 01:23:07.753	cmsgzh1nn0007v4z4im98e204
cmss9jcky0028v4ko95b1oi32	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2qs000ov4z4irmuzkh0	1	3200000	DRAFT	1	2026-08-14 01:23:07.762	2026-08-14 01:23:07.762	cmsgzh1nn0007v4z4im98e204
cmss9jcl8002av4ko52dhx1y8	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2qs000ov4z4irmuzkh0	2	3200000	DRAFT	1	2026-08-14 01:23:07.772	2026-08-14 01:23:07.772	cmsgzh1nn0007v4z4im98e204
cmss9jcm2002cv4ko7o8ohea3	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2qs000ov4z4irmuzkh0	3	3200000	DRAFT	1	2026-08-14 01:23:07.802	2026-08-14 01:23:07.802	cmsgzh1nn0007v4z4im98e204
cmss9jcmc002ev4koucv7uaoz	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2qs000ov4z4irmuzkh0	4	3200000	DRAFT	1	2026-08-14 01:23:07.813	2026-08-14 01:23:07.813	cmsgzh1nn0007v4z4im98e204
cmss9jcmn002gv4ko7wijnuux	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2qs000ov4z4irmuzkh0	5	3200000	DRAFT	1	2026-08-14 01:23:07.823	2026-08-14 01:23:07.823	cmsgzh1nn0007v4z4im98e204
cmss9jcmy002iv4kohg3b4vyw	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2qs000ov4z4irmuzkh0	6	3200000	DRAFT	1	2026-08-14 01:23:07.834	2026-08-14 01:23:07.834	cmsgzh1nn0007v4z4im98e204
cmss9jcn7002kv4kor75hgvxp	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2sx000pv4z4ugxp12nb	1	450000	DRAFT	1	2026-08-14 01:23:07.844	2026-08-14 01:23:07.844	cmsgzh1nn0007v4z4im98e204
cmss9jcnk002mv4kox7zpj81w	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2sx000pv4z4ugxp12nb	2	380000	DRAFT	1	2026-08-14 01:23:07.856	2026-08-14 01:23:07.856	cmsgzh1nn0007v4z4im98e204
cmss9jcnv002ov4kodxed410v	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2sx000pv4z4ugxp12nb	3	520000	DRAFT	1	2026-08-14 01:23:07.867	2026-08-14 01:23:07.867	cmsgzh1nn0007v4z4im98e204
cmss9jco5002qv4kouw97khtw	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2sx000pv4z4ugxp12nb	4	410000	DRAFT	1	2026-08-14 01:23:07.878	2026-08-14 01:23:07.878	cmsgzh1nn0007v4z4im98e204
cmss9jcof002sv4kohozkxruq	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2sx000pv4z4ugxp12nb	5	390000	DRAFT	1	2026-08-14 01:23:07.888	2026-08-14 01:23:07.888	cmsgzh1nn0007v4z4im98e204
cmss9jcos002uv4ko7yktmdyt	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2sx000pv4z4ugxp12nb	6	470000	DRAFT	1	2026-08-14 01:23:07.9	2026-08-14 01:23:07.9	cmsgzh1nn0007v4z4im98e204
cmss9jcpa002wv4koehsbikmh	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2v8000qv4z4jby0vwu0	1	780000	DRAFT	1	2026-08-14 01:23:07.918	2026-08-14 01:23:07.918	cmsgzh1nn0007v4z4im98e204
cmss9jcpm002yv4ko7ibzo8wf	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2v8000qv4z4jby0vwu0	2	780000	DRAFT	1	2026-08-14 01:23:07.93	2026-08-14 01:23:07.93	cmsgzh1nn0007v4z4im98e204
cmss9jcpy0030v4kov0j7ebnx	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2v8000qv4z4jby0vwu0	3	780000	DRAFT	1	2026-08-14 01:23:07.942	2026-08-14 01:23:07.942	cmsgzh1nn0007v4z4im98e204
cmss9jcq90032v4kohwllovsm	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2v8000qv4z4jby0vwu0	4	780000	DRAFT	1	2026-08-14 01:23:07.953	2026-08-14 01:23:07.953	cmsgzh1nn0007v4z4im98e204
cmss9jcqk0034v4koooc9m3mp	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2v8000qv4z4jby0vwu0	5	780000	DRAFT	1	2026-08-14 01:23:07.964	2026-08-14 01:23:07.964	cmsgzh1nn0007v4z4im98e204
cmss9jcrx0036v4kor3qsoj8h	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2v8000qv4z4jby0vwu0	6	780000	DRAFT	1	2026-08-14 01:23:08.013	2026-08-14 01:23:08.013	cmsgzh1nn0007v4z4im98e204
cmss9jcsc0038v4ko08e90x2d	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2xd000rv4z4w3b9gj2f	1	650000	DRAFT	1	2026-08-14 01:23:08.028	2026-08-14 01:23:08.028	cmsgzh1nn0007v4z4im98e204
cmss9jcsm003av4kom96b98zp	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2xd000rv4z4w3b9gj2f	2	720000	DRAFT	1	2026-08-14 01:23:08.038	2026-08-14 01:23:08.038	cmsgzh1nn0007v4z4im98e204
cmss9jcu0003cv4kojz3fu41u	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2xd000rv4z4w3b9gj2f	3	680000	DRAFT	1	2026-08-14 01:23:08.088	2026-08-14 01:23:08.088	cmsgzh1nn0007v4z4im98e204
cmss9jcuj003ev4kobdnwnlmz	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2xd000rv4z4w3b9gj2f	4	710000	DRAFT	1	2026-08-14 01:23:08.107	2026-08-14 01:23:08.107	cmsgzh1nn0007v4z4im98e204
cmss9jcux003gv4kogddj1nx7	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2xd000rv4z4w3b9gj2f	5	690000	DRAFT	1	2026-08-14 01:23:08.121	2026-08-14 01:23:08.121	cmsgzh1nn0007v4z4im98e204
cmss9jcvb003iv4kool3wg542	cmsgzh31v000uv4z40z4iq9r4	cmsgzh2xd000rv4z4w3b9gj2f	6	700000	DRAFT	1	2026-08-14 01:23:08.135	2026-08-14 01:23:08.135	cmsgzh1nn0007v4z4im98e204
cmsh1b5yi001hv45k1togdtr7	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3cp0000v45kdnl2mv4k	1	39839844	CONFIRMED	1	2026-08-06 04:47:21.066	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b602001jv45ktf31m64g	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3fq0001v45k1k7ywxzg	1	16245277	CONFIRMED	1	2026-08-06 04:47:21.122	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b61m001lv45kx46z6khf	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3hc0002v45kkzg3z9wd	1	0	CONFIRMED	1	2026-08-06 04:47:21.178	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b62z001nv45klqyuhrwr	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3iy0003v45kozth7aas	1	1990530	CONFIRMED	1	2026-08-06 04:47:21.227	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b64j001pv45kafx0iaei	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3kc0004v45kv13t1190	1	2277610	CONFIRMED	1	2026-08-06 04:47:21.283	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b667001rv45k178eyez4	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3lv0005v45k1i15ud1r	1	389530	CONFIRMED	1	2026-08-06 04:47:21.343	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b67p001tv45kkxmgppoy	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ne0006v45ka0wrz3cs	1	660680	CONFIRMED	1	2026-08-06 04:47:21.398	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b696001vv45kcc0w3my4	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ow0007v45kegisx5jd	1	54000	CONFIRMED	1	2026-08-06 04:47:21.45	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6ap001xv45ke0aq7ul7	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3qm0008v45krlvaq333	1	588600	CONFIRMED	1	2026-08-06 04:47:21.506	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6c6001zv45khbb3391z	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3rx0009v45kvzp0f6by	1	115000	CONFIRMED	1	2026-08-06 04:47:21.559	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6dk0021v45kqbysge9o	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3tj000av45kp4w6n24d	1	484695	CONFIRMED	1	2026-08-06 04:47:21.608	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6ew0023v45krxh05tmm	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3v5000bv45kkg5k7jdr	1	63329	CONFIRMED	1	2026-08-06 04:47:21.657	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6gb0025v45k1xbr9upr	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3wp000cv45k0eshx54k	1	60380	CONFIRMED	1	2026-08-06 04:47:21.707	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6hp0027v45k42oil7nh	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3y6000dv45k9tvmq64r	1	0	CONFIRMED	1	2026-08-06 04:47:21.758	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6iz0029v45kyi8hy5nu	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3zn000ev45ke50rracp	1	0	CONFIRMED	1	2026-08-06 04:47:21.804	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6kc002bv45kg3scsgtk	cmsgzh31v000uv4z40z4iq9r4	cmsh1b41f000fv45k4qgcw4ac	1	0	CONFIRMED	1	2026-08-06 04:47:21.852	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6lk002dv45kuie3lgw7	cmsgzh31v000uv4z40z4iq9r4	cmsh1b42x000gv45kutf85p3y	1	0	CONFIRMED	1	2026-08-06 04:47:21.896	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6ms002fv45ki310dgq0	cmsgzh31v000uv4z40z4iq9r4	cmsh1b44c000hv45k8wyhshmu	1	0	CONFIRMED	1	2026-08-06 04:47:21.94	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6o7002hv45kl5icx44q	cmsgzh31v000uv4z40z4iq9r4	cmsh1b45p000iv45krmpx8fmv	1	62700	CONFIRMED	1	2026-08-06 04:47:21.991	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6pm002jv45kgv9a3b39	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3cp0000v45kdnl2mv4k	2	35298898	CONFIRMED	1	2026-08-06 04:47:22.042	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6r3002lv45kvjfdv0gh	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3fq0001v45k1k7ywxzg	2	15184447	CONFIRMED	1	2026-08-06 04:47:22.095	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6so002nv45kj7go11kl	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3hc0002v45kkzg3z9wd	2	1800000	CONFIRMED	1	2026-08-06 04:47:22.152	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6ty002pv45k4hgjqhb7	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3iy0003v45kozth7aas	2	1990530	CONFIRMED	1	2026-08-06 04:47:22.199	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6va002rv45kyl5swjls	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3kc0004v45kv13t1190	2	2277610	CONFIRMED	1	2026-08-06 04:47:22.246	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6wm002tv45kbdz33esk	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3lv0005v45k1i15ud1r	2	389530	CONFIRMED	1	2026-08-06 04:47:22.294	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6xu002vv45kvowpuu6v	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ne0006v45ka0wrz3cs	2	660680	CONFIRMED	1	2026-08-06 04:47:22.338	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b6z4002xv45kulzqu036	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ow0007v45kegisx5jd	2	850500	CONFIRMED	1	2026-08-06 04:47:22.385	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b70f002zv45kc7clixzu	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3qm0008v45krlvaq333	2	1094460	CONFIRMED	1	2026-08-06 04:47:22.432	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b71q0031v45k8xl0kbx9	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3rx0009v45kvzp0f6by	2	46000	CONFIRMED	1	2026-08-06 04:47:22.478	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7320033v45kx8f7zgtm	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3tj000av45kp4w6n24d	2	753740	CONFIRMED	1	2026-08-06 04:47:22.526	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b74d0035v45k6hkc7dbt	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3v5000bv45kkg5k7jdr	2	44414	CONFIRMED	1	2026-08-06 04:47:22.574	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b75p0037v45kfyva2cmx	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3wp000cv45k0eshx54k	2	8440	CONFIRMED	1	2026-08-06 04:47:22.622	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7710039v45kzuo1nzzm	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3y6000dv45k9tvmq64r	2	0	CONFIRMED	1	2026-08-06 04:47:22.669	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b78d003bv45kpv49lcln	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3zn000ev45ke50rracp	2	0	CONFIRMED	1	2026-08-06 04:47:22.718	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b79n003dv45kjg67xdl9	cmsgzh31v000uv4z40z4iq9r4	cmsh1b41f000fv45k4qgcw4ac	2	0	CONFIRMED	1	2026-08-06 04:47:22.763	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7az003fv45k7t64r28t	cmsgzh31v000uv4z40z4iq9r4	cmsh1b42x000gv45kutf85p3y	2	0	CONFIRMED	1	2026-08-06 04:47:22.811	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7c9003hv45krxgawmj3	cmsgzh31v000uv4z40z4iq9r4	cmsh1b44c000hv45k8wyhshmu	2	0	CONFIRMED	1	2026-08-06 04:47:22.858	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7dm003jv45k9tv6cy0k	cmsgzh31v000uv4z40z4iq9r4	cmsh1b45p000iv45krmpx8fmv	2	62700	CONFIRMED	1	2026-08-06 04:47:22.906	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7ew003lv45kn9ht7j09	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3cp0000v45kdnl2mv4k	3	40277010	CONFIRMED	1	2026-08-06 04:47:22.952	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7g9003nv45kme5bsnxy	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3fq0001v45k1k7ywxzg	3	15184447	CONFIRMED	1	2026-08-06 04:47:23.001	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7hh003pv45k2lt2bf7o	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3hc0002v45kkzg3z9wd	3	0	CONFIRMED	1	2026-08-06 04:47:23.045	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7ir003rv45ks0pti6u2	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3iy0003v45kozth7aas	3	2030620	CONFIRMED	1	2026-08-06 04:47:23.091	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7k3003tv45kk34x5ufx	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3kc0004v45kv13t1190	3	2277610	CONFIRMED	1	2026-08-06 04:47:23.139	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7lf003vv45kixby6bbf	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3lv0005v45k1i15ud1r	3	389530	CONFIRMED	1	2026-08-06 04:47:23.187	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7mx003xv45k8387wzno	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ne0006v45ka0wrz3cs	3	660680	CONFIRMED	1	2026-08-06 04:47:23.241	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7oc003zv45kxx199uu6	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ow0007v45kegisx5jd	3	1035027	CONFIRMED	1	2026-08-06 04:47:23.292	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7pm0041v45kgekk755x	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3qm0008v45krlvaq333	3	436100	CONFIRMED	1	2026-08-06 04:47:23.339	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7qx0043v45kejgjzjhs	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3rx0009v45kvzp0f6by	3	14205709	CONFIRMED	1	2026-08-06 04:47:23.385	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7sb0045v45k4ws8cmbp	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3tj000av45kp4w6n24d	3	840354	CONFIRMED	1	2026-08-06 04:47:23.435	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7tm0047v45k4gmmt4f4	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3v5000bv45kkg5k7jdr	3	96173	CONFIRMED	1	2026-08-06 04:47:23.483	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7v00049v45k0p29ycgb	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3wp000cv45k0eshx54k	3	38760	CONFIRMED	1	2026-08-06 04:47:23.532	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7wi004bv45k7cnrhcg1	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3y6000dv45k9tvmq64r	3	0	CONFIRMED	1	2026-08-06 04:47:23.586	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7xt004dv45kvcpgtofb	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3zn000ev45ke50rracp	3	351321	CONFIRMED	1	2026-08-06 04:47:23.633	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b7za004fv45k6jjtbw67	cmsgzh31v000uv4z40z4iq9r4	cmsh1b41f000fv45k4qgcw4ac	3	0	CONFIRMED	1	2026-08-06 04:47:23.686	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b80q004hv45k81soij2d	cmsgzh31v000uv4z40z4iq9r4	cmsh1b42x000gv45kutf85p3y	3	0	CONFIRMED	1	2026-08-06 04:47:23.738	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b827004jv45ktbjp8d8o	cmsgzh31v000uv4z40z4iq9r4	cmsh1b44c000hv45k8wyhshmu	3	0	CONFIRMED	1	2026-08-06 04:47:23.792	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b83r004lv45k6ra3sl3x	cmsgzh31v000uv4z40z4iq9r4	cmsh1b45p000iv45krmpx8fmv	3	62700	CONFIRMED	1	2026-08-06 04:47:23.847	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b857004nv45kpe4cpdty	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3cp0000v45kdnl2mv4k	4	50625770	CONFIRMED	1	2026-08-06 04:47:23.899	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b872004pv45kb5cylt05	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3fq0001v45k1k7ywxzg	4	13841404	CONFIRMED	1	2026-08-06 04:47:23.966	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b88m004rv45kqy33v2oe	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3hc0002v45kkzg3z9wd	4	0	CONFIRMED	1	2026-08-06 04:47:24.023	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8a2004tv45kmzrwx0as	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3iy0003v45kozth7aas	4	3174720	CONFIRMED	1	2026-08-06 04:47:24.074	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8bg004vv45kzg0sfamt	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3kc0004v45kv13t1190	4	2763530	CONFIRMED	1	2026-08-06 04:47:24.124	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8cr004xv45kvc4kyx6d	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3lv0005v45k1i15ud1r	4	625860	CONFIRMED	1	2026-08-06 04:47:24.171	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8e4004zv45kp47bio83	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ne0006v45ka0wrz3cs	4	1068640	CONFIRMED	1	2026-08-06 04:47:24.22	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8fp0051v45kax7b9nze	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ow0007v45kegisx5jd	4	1639066	CONFIRMED	1	2026-08-06 04:47:24.277	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8hh0053v45ki3ys860y	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3qm0008v45krlvaq333	4	1120200	CONFIRMED	1	2026-08-06 04:47:24.341	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8kp0055v45kq18xhmq6	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3rx0009v45kvzp0f6by	4	221904	CONFIRMED	1	2026-08-06 04:47:24.457	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8mr0057v45kfmzruwid	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3tj000av45kp4w6n24d	4	1880341	CONFIRMED	1	2026-08-06 04:47:24.531	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8oj0059v45kbm7969v4	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3v5000bv45kkg5k7jdr	4	1815246	CONFIRMED	1	2026-08-06 04:47:24.595	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8q6005bv45kglmsk2u5	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3wp000cv45k0eshx54k	4	29170	CONFIRMED	1	2026-08-06 04:47:24.654	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8rt005dv45klig4go8g	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3y6000dv45k9tvmq64r	4	15750	CONFIRMED	1	2026-08-06 04:47:24.713	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8tc005fv45k0dfu7u22	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3zn000ev45ke50rracp	4	2985855	CONFIRMED	1	2026-08-06 04:47:24.768	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8uv005hv45kj7kwmfqx	cmsgzh31v000uv4z40z4iq9r4	cmsh1b41f000fv45k4qgcw4ac	4	0	CONFIRMED	1	2026-08-06 04:47:24.823	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8w7005jv45kmsj1n16e	cmsgzh31v000uv4z40z4iq9r4	cmsh1b42x000gv45kutf85p3y	4	0	CONFIRMED	1	2026-08-06 04:47:24.871	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8xj005lv45k22yoa566	cmsgzh31v000uv4z40z4iq9r4	cmsh1b44c000hv45k8wyhshmu	4	0	CONFIRMED	1	2026-08-06 04:47:24.919	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b8zd005nv45k2k8wbr34	cmsgzh31v000uv4z40z4iq9r4	cmsh1b45p000iv45krmpx8fmv	4	62700	CONFIRMED	1	2026-08-06 04:47:24.985	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b90u005pv45kw1s6v36l	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3cp0000v45kdnl2mv4k	5	50269318	CONFIRMED	1	2026-08-06 04:47:25.038	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b92i005rv45kypuarvqt	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3fq0001v45k1k7ywxzg	5	13841404	CONFIRMED	1	2026-08-06 04:47:25.099	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b940005tv45kjghxrkaq	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3hc0002v45kkzg3z9wd	5	600000	CONFIRMED	1	2026-08-06 04:47:25.152	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b95z005vv45kfijjzl3g	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3iy0003v45kozth7aas	5	2651250	CONFIRMED	1	2026-08-06 04:47:25.223	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b97i005xv45kjk68cjp3	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3kc0004v45kv13t1190	5	2763530	CONFIRMED	1	2026-08-06 04:47:25.278	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b98x005zv45kiw4c1co3	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3lv0005v45k1i15ud1r	5	512940	CONFIRMED	1	2026-08-06 04:47:25.329	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9ai0061v45ksxlregwb	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ne0006v45ka0wrz3cs	5	869980	CONFIRMED	1	2026-08-06 04:47:25.386	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9bx0063v45k38ga96ml	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ow0007v45kegisx5jd	5	1639066	CONFIRMED	1	2026-08-06 04:47:25.437	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9do0065v45kuemi0tyn	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3qm0008v45krlvaq333	5	2583080	CONFIRMED	1	2026-08-06 04:47:25.5	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9f80067v45k6y47txkh	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3rx0009v45kvzp0f6by	5	120482	CONFIRMED	1	2026-08-06 04:47:25.556	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9gj0069v45krfxfbwfd	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3tj000av45kp4w6n24d	5	1216176	CONFIRMED	1	2026-08-06 04:47:25.603	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9i2006bv45kjsg5qdfo	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3v5000bv45kkg5k7jdr	5	158523	CONFIRMED	1	2026-08-06 04:47:25.658	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9je006dv45kjcq1ekt2	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3wp000cv45k0eshx54k	5	123640	CONFIRMED	1	2026-08-06 04:47:25.706	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9kr006fv45kfkz62qna	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3y6000dv45k9tvmq64r	5	0	CONFIRMED	1	2026-08-06 04:47:25.755	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9mk006hv45kj5oyyd5p	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3zn000ev45ke50rracp	5	12060931	CONFIRMED	1	2026-08-06 04:47:25.82	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9o5006jv45k0kp0o4vp	cmsgzh31v000uv4z40z4iq9r4	cmsh1b41f000fv45k4qgcw4ac	5	348863	CONFIRMED	1	2026-08-06 04:47:25.877	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9pf006lv45ket0xpwfv	cmsgzh31v000uv4z40z4iq9r4	cmsh1b42x000gv45kutf85p3y	5	357000	CONFIRMED	1	2026-08-06 04:47:25.923	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9qu006nv45kkhm3t118	cmsgzh31v000uv4z40z4iq9r4	cmsh1b44c000hv45k8wyhshmu	5	0	CONFIRMED	1	2026-08-06 04:47:25.974	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9sh006pv45kynhqlhuh	cmsgzh31v000uv4z40z4iq9r4	cmsh1b45p000iv45krmpx8fmv	5	62700	CONFIRMED	1	2026-08-06 04:47:26.034	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9tt006rv45k9lxsf918	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3cp0000v45kdnl2mv4k	6	52148662	CONFIRMED	1	2026-08-06 04:47:26.081	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9va006tv45k8d3n43jv	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3fq0001v45k1k7ywxzg	6	13841404	CONFIRMED	1	2026-08-06 04:47:26.135	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9wm006vv45kvrl6oh98	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3hc0002v45kkzg3z9wd	6	0	CONFIRMED	1	2026-08-06 04:47:26.182	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9y4006xv45ky5q60gi7	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3iy0003v45kozth7aas	6	2651250	CONFIRMED	1	2026-08-06 04:47:26.236	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1b9zn006zv45ksh6ko4cd	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3kc0004v45kv13t1190	6	2763530	CONFIRMED	1	2026-08-06 04:47:26.291	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1ba120071v45kc2hc7cgv	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3lv0005v45k1i15ud1r	6	512940	CONFIRMED	1	2026-08-06 04:47:26.342	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1ba2m0073v45k8ctjb71v	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ne0006v45ka0wrz3cs	6	869980	CONFIRMED	1	2026-08-06 04:47:26.399	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1ba440075v45k73nv7s2w	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3ow0007v45kegisx5jd	6	1639066	CONFIRMED	1	2026-08-06 04:47:26.452	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1ba5i0077v45kf9wmfabs	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3qm0008v45krlvaq333	6	1632290	CONFIRMED	1	2026-08-06 04:47:26.503	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1ba7b0079v45k7ya78xsi	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3rx0009v45kvzp0f6by	6	206565	CONFIRMED	1	2026-08-06 04:47:26.567	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1ba8t007bv45kwbd28m78	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3tj000av45kp4w6n24d	6	1036243	CONFIRMED	1	2026-08-06 04:47:26.621	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1baac007dv45krdua3cp2	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3v5000bv45kkg5k7jdr	6	454333	CONFIRMED	1	2026-08-06 04:47:26.676	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1babo007fv45kkhcwbrof	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3wp000cv45k0eshx54k	6	107280	CONFIRMED	1	2026-08-06 04:47:26.724	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1badb007hv45kzhe78p49	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3y6000dv45k9tvmq64r	6	0	CONFIRMED	1	2026-08-06 04:47:26.783	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1baer007jv45k9c9fy85k	cmsgzh31v000uv4z40z4iq9r4	cmsh1b3zn000ev45ke50rracp	6	2411960	CONFIRMED	1	2026-08-06 04:47:26.835	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1bag2007lv45k0h8kxcea	cmsgzh31v000uv4z40z4iq9r4	cmsh1b41f000fv45k4qgcw4ac	6	348863	CONFIRMED	1	2026-08-06 04:47:26.882	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1bahk007nv45kxwhpg94l	cmsgzh31v000uv4z40z4iq9r4	cmsh1b42x000gv45kutf85p3y	6	366205	CONFIRMED	1	2026-08-06 04:47:26.936	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1baj1007pv45kwdvollig	cmsgzh31v000uv4z40z4iq9r4	cmsh1b44c000hv45k8wyhshmu	6	0	CONFIRMED	1	2026-08-06 04:47:26.989	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
cmsh1bakf007rv45k2jne8hfd	cmsgzh31v000uv4z40z4iq9r4	cmsh1b45p000iv45krmpx8fmv	6	62700	CONFIRMED	1	2026-08-06 04:47:27.039	2026-08-06 07:45:20.29	cmsgzh1nn0007v4z4im98e204
\.


--
-- Data for Name: reconciliation_results; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.reconciliation_results (id, run_id, total_source_cost, total_account_allocated, account_rounding_diff, total_company_allocated, company_rounding_diff, total_markup, total_billing, is_balanced, details, created_at) FROM stdin;
cmss7ps280003v4fonqyf1q26	cmsh7rit90009v4jw0wy1a0dv	454282475	454289224	-6749	454289080	144	4371050	458660130	t	[{"code": "ACC-18", "name": "기타지급", "sourceTotal": "0", "allocatedSum": "0", "roundingDiff": "0", "costAccountId": "cmsh1b44c000hv45k8wyhshmu"}, {"code": "ACC-12", "name": "지급수수료", "sourceTotal": "2632018", "allocatedSum": "2632044", "roundingDiff": "-26", "costAccountId": "cmsh1b3v5000bv45kkg5k7jdr"}, {"code": "ACC-11", "name": "국내출장비", "sourceTotal": "6211549", "allocatedSum": "6211630", "roundingDiff": "-81", "costAccountId": "cmsh1b3tj000av45kp4w6n24d"}, {"code": "ACC-16", "name": "감가상각비(차량)", "sourceTotal": "697726", "allocatedSum": "697725", "roundingDiff": "1", "costAccountId": "cmsh1b41f000fv45k4qgcw4ac"}, {"code": "ACC-19", "name": "지급수수료(일반)", "sourceTotal": "376200", "allocatedSum": "376190", "roundingDiff": "10", "costAccountId": "cmsh1b45p000iv45krmpx8fmv"}, {"code": "ACC-14", "name": "도서인쇄비", "sourceTotal": "15750", "allocatedSum": "15738", "roundingDiff": "12", "costAccountId": "cmsh1b3y6000dv45k9tvmq64r"}, {"code": "ACC-05", "name": "국민연금", "sourceTotal": "15123420", "allocatedSum": "15123638", "roundingDiff": "-218", "costAccountId": "cmsh1b3kc0004v45kv13t1190"}, {"code": "ACC-08", "name": "식대(식권)", "sourceTotal": "6856725", "allocatedSum": "6856817", "roundingDiff": "-92", "costAccountId": "cmsh1b3ow0007v45kegisx5jd"}, {"code": "ACC-09", "name": "업무추진비", "sourceTotal": "7454730", "allocatedSum": "7454828", "roundingDiff": "-98", "costAccountId": "cmsh1b3qm0008v45krlvaq333"}, {"code": "ACC-17", "name": "차량관리비", "sourceTotal": "723205", "allocatedSum": "723199", "roundingDiff": "6", "costAccountId": "cmsh1b42x000gv45kutf85p3y"}, {"code": "ACC-13", "name": "통신비", "sourceTotal": "367670", "allocatedSum": "367658", "roundingDiff": "12", "costAccountId": "cmsh1b3wp000cv45k0eshx54k"}, {"code": "ACC-10", "name": "소모품비", "sourceTotal": "14915660", "allocatedSum": "14915876", "roundingDiff": "-216", "costAccountId": "cmsh1b3rx0009v45kvzp0f6by"}, {"code": "ACC-06", "name": "산재보험", "sourceTotal": "2820330", "allocatedSum": "2820359", "roundingDiff": "-29", "costAccountId": "cmsh1b3lv0005v45k1i15ud1r"}, {"code": "ACC-03", "name": "복리후생비(기타)", "sourceTotal": "2400000", "allocatedSum": "2400023", "roundingDiff": "-23", "costAccountId": "cmsh1b3hc0002v45kkzg3z9wd"}, {"code": "ACC-15", "name": "국외출장비", "sourceTotal": "17810067", "allocatedSum": "17810328", "roundingDiff": "-261", "costAccountId": "cmsh1b3zn000ev45ke50rracp"}, {"code": "ACC-01", "name": "급료와임금", "sourceTotal": "268459502", "allocatedSum": "268463633", "roundingDiff": "-4131", "costAccountId": "cmsh1b3cp0000v45kdnl2mv4k"}, {"code": "ACC-07", "name": "고용보험", "sourceTotal": "4790640", "allocatedSum": "4790696", "roundingDiff": "-56", "costAccountId": "cmsh1b3ne0006v45ka0wrz3cs"}, {"code": "ACC-02", "name": "상여금", "sourceTotal": "88138383", "allocatedSum": "88139730", "roundingDiff": "-1347", "costAccountId": "cmsh1b3fq0001v45k1k7ywxzg"}, {"code": "ACC-04", "name": "건강보험", "sourceTotal": "14488900", "allocatedSum": "14489112", "roundingDiff": "-212", "costAccountId": "cmsh1b3iy0003v45kozth7aas"}]	2026-08-14 00:32:08.527
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.roles (id, name, description, created_at, updated_at) FROM stdin;
cmsgzh1100000v4z4fq1auug9	Admin	Admin role	2026-08-06 03:55:55.38	2026-08-06 03:55:55.38
cmsgzh13e0001v4z489whfhg7	CostManager	CostManager role	2026-08-06 03:55:55.466	2026-08-06 03:55:55.466
cmsgzh15o0002v4z46oto38j4	AllocationManager	AllocationManager role	2026-08-06 03:55:55.548	2026-08-06 03:55:55.548
cmsgzh17v0003v4z4lw456g5q	Approver	Approver role	2026-08-06 03:55:55.627	2026-08-06 03:55:55.627
cmsgzh1a90004v4z44nyo65ah	BillingManager	BillingManager role	2026-08-06 03:55:55.713	2026-08-06 03:55:55.713
cmsgzh1cj0005v4z4r6eeu5rb	Auditor	Auditor role	2026-08-06 03:55:55.795	2026-08-06 03:55:55.795
cmsgzh1et0006v4z4awe2rwlj	Viewer	Viewer role	2026-08-06 03:55:55.878	2026-08-06 03:55:55.878
\.


--
-- Data for Name: system_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.system_settings (id, key, value, description, created_at, updated_at) FROM stdin;
cmsgzh5ht003sv4z4vn7ei6f5	default_markup_rate	0.05	해외법인 Mark-up 기본 비율 (향후 설정 확장)	2026-08-06 03:56:01.169	2026-08-06 03:56:01.169
cmsgzh5km003tv4z4uv7i8320	vat_enabled	false	부가세 계산 (MVP 비활성)	2026-08-06 03:56:01.271	2026-08-06 03:56:01.271
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_roles (id, user_id, role_id, created_at) FROM stdin;
cmsgzh1nn0009v4z4wugltraa	cmsgzh1nn0007v4z4im98e204	cmsgzh1100000v4z4fq1auug9	2026-08-06 03:55:56.195
cmsgzh1nn000av4z48umnpqim	cmsgzh1nn0007v4z4im98e204	cmsgzh13e0001v4z489whfhg7	2026-08-06 03:55:56.195
cmsgzh1nn000bv4z43youwk7x	cmsgzh1nn0007v4z4im98e204	cmsgzh15o0002v4z46oto38j4	2026-08-06 03:55:56.195
cmsgzh1nn000cv4z4bkb6ea1g	cmsgzh1nn0007v4z4im98e204	cmsgzh17v0003v4z4lw456g5q	2026-08-06 03:55:56.195
cmsgzh1nn000dv4z43qkitwsc	cmsgzh1nn0007v4z4im98e204	cmsgzh1a90004v4z44nyo65ah	2026-08-06 03:55:56.195
cmsh72gew0002v4fcvt3r9oi2	cmsh72get0000v4fcr7uaqxdq	cmsgzh1100000v4z4fq1auug9	2026-08-06 07:28:32.403
cmsh72gew0003v4fc956ntvls	cmsh72get0000v4fcr7uaqxdq	cmsgzh13e0001v4z489whfhg7	2026-08-06 07:28:32.403
cmsh72gew0004v4fc9ojayn50	cmsh72get0000v4fcr7uaqxdq	cmsgzh15o0002v4z46oto38j4	2026-08-06 07:28:32.403
cmsh72gew0005v4fc67vjxwji	cmsh72get0000v4fcr7uaqxdq	cmsgzh17v0003v4z4lw456g5q	2026-08-06 07:28:32.403
cmsh72gew0006v4fc63a0181b	cmsh72get0000v4fcr7uaqxdq	cmsgzh1a90004v4z44nyo65ah	2026-08-06 07:28:32.403
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, supabase_id, email, name, password_hash, is_active, created_at, updated_at, deleted_at) FROM stdin;
cmsgzh1nn0007v4z4im98e204	648a43af-19bf-41fd-a187-3446e0ccaaed	admin@kbi.local	시스템 관리자	$2b$12$nABBs82W/CUO7XOnlHiEBOOt9iV4JExAKdt3CNHIWVmUrjYLv6j.O	t	2026-08-06 03:55:56.195	2026-08-14 01:23:06.254	\N
cmsh72get0000v4fcr7uaqxdq	33c4216e-e9df-48e7-b177-9a06f04ac0ac	jaeyong.lee@kbigrp.com	이재용	$2b$12$pu5ozzAcFG7DnoM9XreH2uMDb9y5lKFsxqzNVypz/nGlxX0/krFhS	t	2026-08-06 07:28:32.403	2026-08-14 01:28:44.582	\N
\.


--
-- Name: accounting_periods accounting_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_periods
    ADD CONSTRAINT accounting_periods_pkey PRIMARY KEY (id);


--
-- Name: allocation_details allocation_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_details
    ADD CONSTRAINT allocation_details_pkey PRIMARY KEY (id);


--
-- Name: allocation_projects allocation_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_projects
    ADD CONSTRAINT allocation_projects_pkey PRIMARY KEY (id);


--
-- Name: allocation_rate_versions allocation_rate_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rate_versions
    ADD CONSTRAINT allocation_rate_versions_pkey PRIMARY KEY (id);


--
-- Name: allocation_rates allocation_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rates
    ADD CONSTRAINT allocation_rates_pkey PRIMARY KEY (id);


--
-- Name: allocation_runs allocation_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_runs
    ADD CONSTRAINT allocation_runs_pkey PRIMARY KEY (id);


--
-- Name: approval_actions approval_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_actions
    ADD CONSTRAINT approval_actions_pkey PRIMARY KEY (id);


--
-- Name: approval_requests approval_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_pkey PRIMARY KEY (id);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_addresses company_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_addresses
    ADD CONSTRAINT company_addresses_pkey PRIMARY KEY (id);


--
-- Name: company_allocation_summaries company_allocation_summaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_allocation_summaries
    ADD CONSTRAINT company_allocation_summaries_pkey PRIMARY KEY (id);


--
-- Name: cost_accounts cost_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_accounts
    ADD CONSTRAINT cost_accounts_pkey PRIMARY KEY (id);


--
-- Name: invoice_lines invoice_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_lines
    ADD CONSTRAINT invoice_lines_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: monthly_costs monthly_costs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monthly_costs
    ADD CONSTRAINT monthly_costs_pkey PRIMARY KEY (id);


--
-- Name: reconciliation_results reconciliation_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_results
    ADD CONSTRAINT reconciliation_results_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: system_settings system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: accounting_periods_year_half_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX accounting_periods_year_half_key ON public.accounting_periods USING btree (year, half);


--
-- Name: allocation_details_run_id_company_id_cost_account_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX allocation_details_run_id_company_id_cost_account_id_key ON public.allocation_details USING btree (run_id, company_id, cost_account_id);


--
-- Name: allocation_projects_period_id_version_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX allocation_projects_period_id_version_key ON public.allocation_projects USING btree (period_id, version);


--
-- Name: allocation_rate_versions_project_id_version_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX allocation_rate_versions_project_id_version_key ON public.allocation_rate_versions USING btree (project_id, version);


--
-- Name: allocation_rates_rate_version_id_company_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX allocation_rates_rate_version_id_company_id_key ON public.allocation_rates USING btree (rate_version_id, company_id);


--
-- Name: allocation_runs_project_id_rate_version_id_run_number_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX allocation_runs_project_id_rate_version_id_run_number_key ON public.allocation_runs USING btree (project_id, rate_version_id, run_number);


--
-- Name: allocation_runs_project_id_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX allocation_runs_project_id_status_idx ON public.allocation_runs USING btree (project_id, status);


--
-- Name: approval_requests_entity_type_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_requests_entity_type_entity_id_idx ON public.approval_requests USING btree (entity_type, entity_id);


--
-- Name: approval_requests_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX approval_requests_status_idx ON public.approval_requests USING btree (status);


--
-- Name: attachments_entity_type_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attachments_entity_type_entity_id_idx ON public.attachments USING btree (entity_type, entity_id);


--
-- Name: audit_logs_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_created_at_idx ON public.audit_logs USING btree (created_at);


--
-- Name: audit_logs_entity_type_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_entity_type_entity_id_idx ON public.audit_logs USING btree (entity_type, entity_id);


--
-- Name: audit_logs_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_user_id_idx ON public.audit_logs USING btree (user_id);


--
-- Name: companies_code_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX companies_code_key ON public.companies USING btree (code);


--
-- Name: company_allocation_summaries_run_id_company_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX company_allocation_summaries_run_id_company_id_key ON public.company_allocation_summaries USING btree (run_id, company_id);


--
-- Name: cost_accounts_code_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cost_accounts_code_key ON public.cost_accounts USING btree (code);


--
-- Name: invoice_lines_invoice_id_line_number_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX invoice_lines_invoice_id_line_number_key ON public.invoice_lines USING btree (invoice_id, line_number);


--
-- Name: invoices_invoice_number_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX invoices_invoice_number_key ON public.invoices USING btree (invoice_number);


--
-- Name: invoices_run_id_company_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX invoices_run_id_company_id_key ON public.invoices USING btree (run_id, company_id);


--
-- Name: invoices_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX invoices_status_idx ON public.invoices USING btree (status);


--
-- Name: monthly_costs_project_id_cost_account_id_month_version_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX monthly_costs_project_id_cost_account_id_month_version_key ON public.monthly_costs USING btree (project_id, cost_account_id, month, version);


--
-- Name: monthly_costs_project_id_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX monthly_costs_project_id_status_idx ON public.monthly_costs USING btree (project_id, status);


--
-- Name: reconciliation_results_run_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX reconciliation_results_run_id_key ON public.reconciliation_results USING btree (run_id);


--
-- Name: roles_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX roles_name_key ON public.roles USING btree (name);


--
-- Name: system_settings_key_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX system_settings_key_key ON public.system_settings USING btree (key);


--
-- Name: user_roles_user_id_role_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_roles_user_id_role_id_key ON public.user_roles USING btree (user_id, role_id);


--
-- Name: users_email_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_key ON public.users USING btree (email);


--
-- Name: users_supabase_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_supabase_id_key ON public.users USING btree (supabase_id);


--
-- Name: allocation_details allocation_details_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_details
    ADD CONSTRAINT allocation_details_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_details allocation_details_cost_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_details
    ADD CONSTRAINT allocation_details_cost_account_id_fkey FOREIGN KEY (cost_account_id) REFERENCES public.cost_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_details allocation_details_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_details
    ADD CONSTRAINT allocation_details_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.allocation_runs(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: allocation_projects allocation_projects_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_projects
    ADD CONSTRAINT allocation_projects_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_projects allocation_projects_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_projects
    ADD CONSTRAINT allocation_projects_period_id_fkey FOREIGN KEY (period_id) REFERENCES public.accounting_periods(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_rate_versions allocation_rate_versions_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rate_versions
    ADD CONSTRAINT allocation_rate_versions_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_rate_versions allocation_rate_versions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rate_versions
    ADD CONSTRAINT allocation_rate_versions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.allocation_projects(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_rates allocation_rates_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rates
    ADD CONSTRAINT allocation_rates_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_rates allocation_rates_rate_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_rates
    ADD CONSTRAINT allocation_rates_rate_version_id_fkey FOREIGN KEY (rate_version_id) REFERENCES public.allocation_rate_versions(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_runs allocation_runs_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_runs
    ADD CONSTRAINT allocation_runs_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_runs allocation_runs_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_runs
    ADD CONSTRAINT allocation_runs_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.allocation_projects(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: allocation_runs allocation_runs_rate_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_runs
    ADD CONSTRAINT allocation_runs_rate_version_id_fkey FOREIGN KEY (rate_version_id) REFERENCES public.allocation_rate_versions(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: approval_actions approval_actions_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_actions
    ADD CONSTRAINT approval_actions_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.approval_requests(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: approval_actions approval_actions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_actions
    ADD CONSTRAINT approval_actions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: attachments attachments_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: company_addresses company_addresses_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_addresses
    ADD CONSTRAINT company_addresses_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: company_allocation_summaries company_allocation_summaries_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_allocation_summaries
    ADD CONSTRAINT company_allocation_summaries_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: company_allocation_summaries company_allocation_summaries_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_allocation_summaries
    ADD CONSTRAINT company_allocation_summaries_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.allocation_runs(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: invoice_lines invoice_lines_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_lines
    ADD CONSTRAINT invoice_lines_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: invoices invoices_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: invoices invoices_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.allocation_runs(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: monthly_costs monthly_costs_cost_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monthly_costs
    ADD CONSTRAINT monthly_costs_cost_account_id_fkey FOREIGN KEY (cost_account_id) REFERENCES public.cost_accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: monthly_costs monthly_costs_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monthly_costs
    ADD CONSTRAINT monthly_costs_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: monthly_costs monthly_costs_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monthly_costs
    ADD CONSTRAINT monthly_costs_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.allocation_projects(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: reconciliation_results reconciliation_results_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reconciliation_results
    ADD CONSTRAINT reconciliation_results_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.allocation_runs(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict Wb1oWT0QR8NITaXtpuNgNrvLOASt39s9DAfXlGhg4FdaOqryXgWVratoTqe3Bde

