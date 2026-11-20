-- AI Marketing Manager: proposed Supabase/Postgres schema v1.0
-- DESIGN ONLY; not executed or integration-tested against user's Supabase instance.
-- Private schema, no direct Data API access. Implement granular backend role model before production.
CREATE SCHEMA IF NOT EXISTS marketing;
REVOKE ALL ON SCHEMA marketing FROM PUBLIC;
REVOKE ALL ON SCHEMA marketing FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS marketing.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_name text NOT NULL,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata',
  brand_guidelines jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS marketing.marketing_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  name text NOT NULL,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  rules jsonb NOT NULL,
  approved_by text,
  approved_at timestamptz,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, name, version)
);
CREATE TABLE IF NOT EXISTS marketing.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  sku text NOT NULL,
  product_name text NOT NULL,
  category text,
  specifications jsonb NOT NULL DEFAULT '{}'::jsonb,
  verified_applications jsonb NOT NULL DEFAULT '[]'::jsonb,
  availability_status text NOT NULL DEFAULT 'unknown',
  price_note text,
  source_updated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, sku)
);
CREATE TABLE IF NOT EXISTS marketing.product_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  product_id uuid REFERENCES marketing.products(id),
  drive_file_id text,
  asset_uri text NOT NULL,
  asset_type text NOT NULL,
  rights_status text NOT NULL DEFAULT 'unverified',
  checksum text,
  source_verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS marketing.markets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  country_code text NOT NULL DEFAULT 'IN',
  state text NOT NULL,
  city text NOT NULL DEFAULT '',
  customer_segment text NOT NULL,
  industry text NOT NULL DEFAULT '',
  UNIQUE (organization_id, country_code, state, city, customer_segment, industry)
);
CREATE TABLE IF NOT EXISTS marketing.market_findings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  product_id uuid NOT NULL REFERENCES marketing.products(id),
  market_id uuid NOT NULL REFERENCES marketing.markets(id),
  claim text NOT NULL,
  evidence_url text,
  source_type text,
  is_inference boolean NOT NULL DEFAULT true,
  confidence numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
  verification_status text NOT NULL DEFAULT 'unverified',
  observed_at timestamptz NOT NULL DEFAULT now(),
  valid_until timestamptz,
  supersedes_finding_id uuid REFERENCES marketing.market_findings(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS marketing.seasonal_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  name text NOT NULL,
  region text NOT NULL,
  event_date date NOT NULL,
  buying_lead_days integer CHECK (buying_lead_days >= 0),
  source_url text,
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, name, region, event_date)
);
CREATE TABLE IF NOT EXISTS marketing.campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  name text NOT NULL,
  objective text NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','planned','in_review','active','paused','completed','cancelled')),
  currency_code text NOT NULL DEFAULT 'INR',
  proposed_budget numeric(14,2) CHECK (proposed_budget IS NULL OR proposed_budget >= 0),
  approved_budget numeric(14,2) CHECK (approved_budget IS NULL OR approved_budget >= 0),
  start_at timestamptz,
  end_at timestamptz,
  assumptions jsonb NOT NULL DEFAULT '[]'::jsonb,
  owner_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS marketing.campaign_targets (
  campaign_id uuid NOT NULL REFERENCES marketing.campaigns(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES marketing.products(id),
  market_id uuid NOT NULL REFERENCES marketing.markets(id),
  rationale text,
  PRIMARY KEY(campaign_id, product_id, market_id)
);
CREATE TABLE IF NOT EXISTS marketing.content_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  campaign_id uuid NOT NULL REFERENCES marketing.campaigns(id),
  platform text NOT NULL,
  creative_format text NOT NULL,
  caption text NOT NULL DEFAULT '',
  asset_uris jsonb NOT NULL DEFAULT '[]'::jsonb,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  content_hash text NOT NULL,
  qa_status text NOT NULL DEFAULT 'pending',
  supersedes_variant_id uuid REFERENCES marketing.content_variants(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, platform, content_hash)
);
CREATE TABLE IF NOT EXISTS marketing.approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  content_variant_id uuid NOT NULL REFERENCES marketing.content_variants(id),
  content_hash text NOT NULL,
  policy_id uuid REFERENCES marketing.marketing_policies(id),
  actor_identifier text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('approved','rejected','revoked')),
  allowed_account_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  schedule_start timestamptz,
  schedule_end timestamptz,
  decided_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS marketing.publications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  content_variant_id uuid NOT NULL REFERENCES marketing.content_variants(id),
  approval_id uuid NOT NULL REFERENCES marketing.approvals(id),
  social_account_id text NOT NULL,
  idempotency_key text NOT NULL UNIQUE,
  provider_post_id text,
  status text NOT NULL DEFAULT 'pending',
  scheduled_at timestamptz,
  published_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (social_account_id, provider_post_id)
);
CREATE TABLE IF NOT EXISTS marketing.metric_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  publication_id uuid NOT NULL REFERENCES marketing.publications(id),
  collected_at timestamptz NOT NULL,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  source_provider text NOT NULL DEFAULT 'omnisocials',
  UNIQUE (publication_id, collected_at)
);
CREATE TABLE IF NOT EXISTS marketing.lead_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  publication_id uuid REFERENCES marketing.publications(id),
  campaign_id uuid REFERENCES marketing.campaigns(id),
  event_type text NOT NULL CHECK(event_type IN ('inquiry','qualified_lead','quotation','order')),
  state text,
  segment text,
  attributable_revenue numeric(14,2),
  source_event_key text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, source_event_key)
);
CREATE TABLE IF NOT EXISTS marketing.experiments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  campaign_id uuid REFERENCES marketing.campaigns(id),
  hypothesis text NOT NULL,
  success_metric text NOT NULL,
  comparison_plan jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'proposed',
  results jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  ended_at timestamptz
);
CREATE TABLE IF NOT EXISTS marketing.learning_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  experiment_id uuid REFERENCES marketing.experiments(id),
  claim text NOT NULL,
  evidence jsonb NOT NULL DEFAULT '[]'::jsonb,
  counterevidence jsonb NOT NULL DEFAULT '[]'::jsonb,
  confidence numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
  recommendation text NOT NULL,
  status text NOT NULL DEFAULT 'proposed',
  supersedes_learning_id uuid REFERENCES marketing.learning_records(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS marketing.agent_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  agent_name text NOT NULL,
  job_key text NOT NULL,
  status text NOT NULL DEFAULT 'queued',
  input_ref jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_ref jsonb,
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  error_summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  finished_at timestamptz,
  UNIQUE (organization_id, job_key)
);
CREATE TABLE IF NOT EXISTS marketing.audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES marketing.organizations(id),
  actor_type text NOT NULL,
  actor_id text,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id text,
  change_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  event_time timestamptz NOT NULL DEFAULT now()
);

-- Default-deny for client roles; all accesses through a properly authorized private backend.
-- Service-role/DB-admin bypass requires server-only secret handling; never ship it to browsers.
DO $$ DECLARE t record; BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='marketing' LOOP
   EXECUTE format('ALTER TABLE marketing.%I ENABLE ROW LEVEL SECURITY', t.tablename);
 END LOOP;
END $$;
REVOKE ALL ON ALL TABLES IN SCHEMA marketing FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA marketing FROM PUBLIC, anon, authenticated;

CREATE INDEX IF NOT EXISTS idx_products_org ON marketing.products(organization_id);
CREATE INDEX IF NOT EXISTS idx_findings_lookup ON marketing.market_findings(organization_id, product_id, market_id, observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_due ON marketing.seasonal_events(organization_id, event_date);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON marketing.campaigns(organization_id, status);
CREATE INDEX IF NOT EXISTS idx_approvals_variant ON marketing.approvals(content_variant_id, decided_at DESC);
CREATE INDEX IF NOT EXISTS idx_pubs_status ON marketing.publications(organization_id, status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_metrics_post ON marketing.metric_snapshots(publication_id, collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_campaign ON marketing.lead_events(organization_id, campaign_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON marketing.agent_jobs(organization_id, status, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_org_time ON marketing.audit_events(organization_id, event_time DESC);

-- Required before production:
-- 1) add foreign-key org-scope consistency checks/authorizing query layer;
-- 2) configure server/database role and connection pooling, RLS policies if clients exposed;
-- 3) add approval verification transaction and replay-safe publication worker;
-- 4) monitor migrations/rollback/restore and formal data retention rules.
