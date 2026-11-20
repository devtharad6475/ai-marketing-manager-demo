# AI Marketing Manager - Implementation Blueprint v1.0
**Prepared:** 31 October 2026 | **Project state:** DESIGN PACK COMPLETE; NO LIVE SYSTEM DEPLOYED

## Executive decision
Build a business-specific AI Marketing Manager using a **Master AI Controller** as the human-facing command interface, with eight specialist roles. Use **OpenAI Agents SDK (Python)** for the first version, **Supabase/Postgres** for structured records and time-aware memory, **Google Drive** for original product documents, and **OmniSocials** for approved social posting and supported analytics/inbox interactions. Use a persistent scheduled backend; do **not** rely on chat-summary rereading as the operating system. Consider LangGraph only if workflow complexity merits its additional orchestration and persistence.

This pack is a **design and implementation starter**, not an operational AI service. No account connection, API call, database migration, social-media post, charge, or deployment has been executed.

## 1. Architecture and separation of responsibilities

```text
USER / CHATGPT CONTROL INTERFACE
              |
      MASTER AI CONTROLLER
   (intent + planning + authorization)
              |
      JOB ORCHESTRATOR / QUEUE  <---- SCHEDULED JOBS + INCOMING EVENTS
              |
  +-----------+-----------+-------------+---------------------------+
  |           |           |             |                           |
PRODUCT     MARKET      FESTIVAL      CAMPAIGN                   CREATIVE
INTEL       RESEARCH    INTEL         STRATEGY                   STUDIO
  +-----------+-----------+-------------+---------------------------+
              |
    QUALITY + PUBLISHING GATE  ----> HUMAN APPROVAL WHEN REQUIRED
              |
           OMNISOCIALS -----> SOCIAL PLATFORMS
              |
          POST METRICS + INBOX + CAMPAIGN LEADS
              |
     ANALYTICS ----> LEARNING & OPTIMIZATION ----> NEXT PLANNING CYCLE
              |
        SUPABASE TIME-AWARE MEMORY + AUDIT LOG
              |
        DRIVE: SOURCE PRODUCT FILES + LICENSED CREATIVES
```

**Design principle:** Specialists propose; deterministic application code validates, authorizes and executes side effects. The model **never** receives unrestricted database administration, spending or publishing credentials. The backend enforces permissions independently of prompts.

### Runtime design
- **Interactive:** User speaks in ChatGPT or later a controlled web dashboard. Master Controller parses intent and identifies the exact campaign/objective/state/asset before acting.
- **Scheduled:** cron/job scheduler starts recurring research, content planning, metrics sync and reviews. A cron tick triggers a run; it is not a permanently executing model.
- **Event-driven:** OmniSocials post events via HMAC-verified webhooks; inbound social conversations through permitted inbox read/sync where supported.
- **Persistence:** All job states, agent outputs, versioned strategies, approvals, publishing IDs and metrics snapshots live in a database. Failed jobs can retry without double-posting.
- **Tool access:** Google Drive read-only ingestion; research search; Supabase scoped data operations; OmniSocials restricted publishing/analytics scopes; optional CRM/ERP leads and sales; ads integrations only when separately approved.

## 2. Nine logical agent roles (one director + eight specialists)

| Agent | Responsibility | Memory scope (read/write) | Key output | Allowed tools |
|---|---|---|---|---|
| 0. Master AI Controller | Understand requests, dispatch, coordinate, request approval, report changes | Shared objectives/policies, job state, decisions, audit | `ActionPlan` + `ActionResult` | Query specialists, scoped job controls, approval requests |
| 1. Product Intelligence | Parse catalogue, classify product uses/specs, identify missing information | Product master, versioned source links, usage assumptions | `ProductProfile` | Drive read, catalogue read/write through validation |
| 2. State/Market Research | Find geography-industry fit, alternatives, competitors, customer segments | Evidence records by product/state/customer type, freshness and confidence | `MarketFinding` | Search/research, evidence store |
| 3. Festival & Demand Calendar | Regional festivals, lead time, buying windows | Calendar, historical windows, verified dates and sources | `SeasonalOpportunity` | Date/calendar research, calendar store |
| 4. Campaign Strategist | Objectives, audiences, channels, budget recommendation, experiments | Campaign history, learnings, spend caps, leads | `CampaignPlan` | Campaign store, source citations, forecast calculator |
| 5. Creative Studio | Variant copy, poster briefs, localization, CTA | Brand voice, templates, licensed images, prior wins | `CreativeVariant` | Asset retrieval, image creation, content store |
| 6. QA & Publishing | Brand/spec checks, claims validation, safety, final approvals and scheduled dispatch | Policies, approval status, provider post IDs | `PublicationRequest` or `Rejection` | Read-only QA + approved OmniSocials publishing endpoint |
| 7. Analytics | Import provider snapshots, classify inquiries and compare cohorts | Post metrics over time, campaign attribution, qualified leads | `PerformanceAssessment` | OmniSocials analytics/inbox read, lead aggregates |
| 8. Learning & Optimization | Compare experiments; preserve/retire hypotheses; propose safe changes | Versioned lessons, confidence, counterevidence | `LearningProposal` | Analytics/experiments read, learning store |

The eight specialists are **roles**, not necessarily eight concurrent model processes. Start with a manager + 3 to 4 callable tools/roles; split them as accuracy and complexity justify.

## 3. Three-tier memory

**A. Working memory (per run):** Current user task, relevant retrieved facts, planned tool calls and run checkpoints. Expires or is summarized when the task ends; do not store private raw reasoning.

**B. Agent-specific domain memory:** Product profiles, market findings, event calendars, content versions, approval outcomes, analytics summaries and tested hypotheses. Each record is identified, typed, attributed to source, dated, versioned and linked to owner/company.

**C. Shared operational memory:** Company goals and product taxonomy, brand guidelines, allowed channels, authorization policy, current campaigns, event queue, global audit trail and learning records. All agents access this through narrowly scoped retrieval; there is **no global uncontrolled write access**.

### Time-aware evidence schema
Every market assertion should include `product_id`, `market_id`, `segment`, `claim`, `evidence_url`, `source_type`, `observed_at`, `valid_until`, `confidence`, `verification_status` and `supersedes_finding_id` (when replaced). Old findings stay stored for trend analysis, but outdated findings are not treated as current facts. An inference is labeled separately from observed customer demand.

## 4. Database schema: logical modules

See `database_schema.sql` for the proposed Postgres tables, indexes and privacy defaults. Main modules:
1. **Company & Policy:** organizations, marketing_policies, source profiles.
2. **Products & Media:** products, product_assets.
3. **Geographic Intelligence:** markets, market_findings, seasonal_events.
4. **Strategy:** campaigns, campaign_targets, experiments.
5. **Content & Approval:** content_variants, approvals, publications.
6. **Measurement:** metric_snapshots, lead_events, learning_records.
7. **Operations:** agent_jobs, audit_events.

Use **Google Drive for original photos/catalogue documents** and the DB for metadata/verified extracts; do not make Drive the transactional database. Store third-party access tokens only in a secrets manager / controlled server environment. Keep direct Data API access closed until role-based access/RLS is designed and tested.

## 5. Closed-loop adaptive marketing (not model-weight training)

**Loop:** observe -> normalize -> compare -> form hypothesis -> test within rules -> measure -> update versioned learning -> propose next action.

- **Observe:** OmniSocials reported impressions, reach, reactions, comments, saves, shares, account-level stats and any supported inbox data; collect campaign-tagged inbound leads and completed orders from separate CRM/ERP if integrated.
- **Normalize:** Deduplicate platform event/post IDs; timestamp snapshots; distinguish missing metrics from zero; map to state and customer segment only where the targeting/lead source supports that attribution.
- **Measure:** Prefer *cost per qualified lead*, lead-to-order rate and attributable revenue when available. Otherwise label reach/engagement as proxy outcomes, not proven sales demand.
- **Compare:** Use baselines and matched audiences when possible. Flag small sample sizes, seasonality, algorithm shifts and paid-versus-organic differences.
- **Learn:** Save evidence, sample size, confidence, counterevidence, experiment and recommended change. No self-modification of system prompt, allowed tools, budget caps or security policies.
- **Act:** Research/copy variants can auto-run. Publishing follows the active approval policy. Paid advertising and customer-facing replies start as mandatory approval.

**Illustrative example:** Gujarat post reaches 20k, 5 qualified leads. UP post reaches 15k, 25 qualified leads. Do not conclude UP is inherently the better market until costs, channel mix, product fit and cohort definitions are comparable. Create a controlled follow-up test; retain the result and its limitations.

## 6. Master Controller - decision protocol

Use the full copy-paste instructions in `MASTER_AI_HARNESS.md`. The controller follows:

1. **UNDERSTAND:** Identify task type, product, target market, objective, relevant user policy and intended external side effects.
2. **RETRIEVE:** Query authoritative catalogue, latest verified market findings, active campaigns and applicable brand/permission rules.
3. **PLAN:** Write a structured action plan identifying specialist agents/tools, required evidence, risks and approval requirement.
4. **DELEGATE:** Use only scoped specialist tools; never invent source URLs, demand data, prices or available stock.
5. **VALIDATE:** Check product claims, freshness, channel format, policy, audience relevance and duplicate-post risk.
6. **AUTHORIZE:** Obtain explicit approval for a specific immutable version or act only under an existing grant. A conversational 'yes' cannot override a separate platform approval requirement.
7. **EXECUTE:** Backend records an idempotency key, calls the approved tool, records external ID/receipt, handles retries.
8. **REPORT:** Give concise outcomes, exact changes, timestamps, links/IDs, failed steps and next action.
9. **LEARN:** Append observed facts and candidate lessons; do not rewrite history or silently change authority.

## 7. Permission and change-control rules

| Action | Default authority | Controls |
|---|---|---|
| Read products / analyze public markets | Automatic | Access-scoped, provenance required |
| Draft campaigns, generate creatives | Automatic | Brand/spec verification, version record |
| Suggest schedule/audience update | Automatic proposal | Show impact and rationale |
| Publish organic post | Human approval until an explicit bounded policy is configured | Content-version hash, account list, scheduled date, receipt |
| Edit an already approved or scheduled post | Reapproval on substantive change | Invalidate old approval, keep revision history |
| Respond to customer DMs/comments | Human review initially | No cold outreach, no promises on prices or timelines |
| Spend money / change advertising budgets | Human approval | Platform spend caps and backend authorization |
| Change company rules, delete data, rotate tokens | Admin-only | Hard non-model privilege boundary |

For production, whitelist exact tool names, require credentials via a secrets manager, verify inbound webhook signatures, use least-privilege OmniSocials key scopes, enforce organization isolation, log write actions and add a kill switch/pause-all queue.

## 8. Proposed recurring jobs (IST; defaults to approve later)

These are **proposed schedules, not tasks that have been created**.

| Cadence | Routine | Agent chain | Artifact |
|---|---|---|---|
| Daily, business morning | Monitor festivals, upcoming posts, new campaigns, inbox queue | Calendar -> Manager -> QA | Prioritized action queue |
| Daily, end of day | Fetch post/inbox metrics, alerts and failures | Analytics -> Learning | Metric snapshot + exception list |
| Weekly | Update state-product opportunities, detect evidence drift | Market -> Strategist | Ranked opportunities + sources |
| Weekly | Generate content calendar for approved campaigns | Strategist -> Creative -> QA | Approval-ready content package |
| Monthly | Compare results against business objectives; recommend experiments | Analytics -> Learning -> Manager | Strategy review |
| Event-triggered | Receive post published/failed/approved/rejected event | Webhook verifier -> Publisher -> Audit | Durable state update |

Implementation scheduler may be Supabase Cron for lightweight triggers and a persistent Python worker for longer agent runs, with retry and dead-letter handling. ChatGPT Tasks can provide conversational reminders/summaries, but are not assumed to host the complete multi-agent service.

## 9. Key data contracts

Each agent response must be **validated JSON**, not unstructured persuasive prose. Minimum contracts:

- `MarketFinding`: `claim`, `evidence[]`, `confidence`, `observed_at`, `expires_at`, `is_inference`, `affected_products`, `affected_regions`.
- `CampaignPlan`: `campaign_id`, `objective`, `product_ids`, `markets`, `segment`, `message`, `channels`, `proposed_budget`, `schedule`, `success_metric`, `assumptions`.
- `CreativeVariant`: `content_id`, `version`, `platform`, `asset_references`, `caption`, `claims_to_verify`, `cta`, `brand_check`.
- `PublicationRequest`: `content_id`, `content_hash`, `platform_account_ids`, `scheduled_at`, `approval_id`, `idempotency_key`.
- `LearningProposal`: `hypothesis`, `baseline`, `treatment`, `metrics`, `evidence_quality`, `recommended_change`, `approval_required`.

Use strict typed schemas, validation against active policies, and unit/integration tests. Never let text from Google Drive, web pages, customer comments or messages modify system instructions or tool permissions.

## 10. Readiness / acceptance tests

| Test | Passing behavior |
|---|---|
| Unknown product application | Ask for spec or label uncertainty; don't fabricate use cases |
| Stale market research | Search/refresh or explicitly mark as outdated |
| High engagement, poor qualified leads | Optimize toward business KPI; no unwarranted market conclusion |
| Invalid proof of demand | Reject unverified market claim or label as hypothesis |
| Missing approval | Prevent publish/API write, even if model says 'approved' |
| Duplicate job retry | Only one external post per content/account/slot |
| Changed approved creative | Approval invalidated; show diff; request renewed approval |
| Invalid webhook signature | Ignore, log security event |
| Account credentials in logs | Secret redaction check passes |
| No CRM/ERP connection | Do not claim revenue/ROI, only available proxies |
| Hindi/Hinglish user instruction | Normalize meaning but preserve target customer language preference |
| Model outage / rate limit | Retry/backoff, never blind repost, alert responsible person |

## 11. Delivery sequence and gates

**Gate A - Design (completed in this pack):** Agent matrix, memory model, architecture, decision protocol, proposed schema, permissions, evaluation criteria, data needs.

**Gate B - Inputs / access (blocked):** Company and logo, products/images/specifications, marketing objective/KPIs, target markets, existing social accounts, consented Drive folder, connected Supabase and OmniSocials, OpenAI API billing, hosting budget. No secret keys in chat.

**Gate C - One-product proof of concept (not started):** Ingest one product, source 3-5 candidate markets, draft 2 channel-specific creatives, validate, get approval, dry-run publish; compare with expert review.

**Gate D - Live MVP (not started):** Set up database, worker, real access-controlled publishing, analytics ingestion, dashboards, audit and error paths; publish one reviewed post end-to-end.

**Gate E - Adaptive operations (not started):** Add calendar/market refresh, controlled experiments, feedback loop, bounded auto-actions after explicit authorization, KPI review.

**Gate F - Expansion (future):** Additional products, regions, platforms, and CRM/ERP attribution; consider LangGraph for more advanced state graphs, branching or resumption.

## 12. Decisions and unresolved inputs

**Designed decisions** (not yet business-owner-approved):
- One Master AI Controller as the only high-level conversational control point.
- Eight specialist roles, but phased implementation instead of nine always-on workers.
- OpenAI Agents SDK first; LangGraph optional later.
- Supabase as system of record; Google Drive as source document repository.
- OmniSocials for supported publishing/organic analytics/inbox; ads campaigns need separate Ads APIs.
- Organic posts require specific approval by default; automatic drafting/research allowed.
- Measured business KPI should prioritize qualified B2B inquiries over likes where sales growth is the objective.

**Still needed from user:** brand name/logo, product catalogue, initial target audience, priority states, B2B lead generation vs awareness weighting, social media handles/accounts, available budget, approval delegations, preferred schedule, historical leads/ERP data (optional).

## 13. Verification sources reviewed 31 October 2026

- OmniSocials developer API & channel coverage: https://docs.omnisocials.com/api
- OmniSocials analytics snapshots: https://docs.omnisocials.com/api/analytics
- OmniSocials inbox scope & platform limitations: https://docs.omnisocials.com/api/inbox
- OpenAI Agents SDK agent/handoffs/guardrails: https://openai.github.io/openai-agents-python/
- OpenAI Agents SDK tracing: https://openai.github.io/openai-agents-python/tracing/
- Supabase Cron (lightweight recurring jobs): https://supabase.com/docs/guides/cron
- Supabase row-level security: https://supabase.com/docs/guides/database/postgres/row-level-security

> **Status:** The architecture/specification work is complete for v1.0. The project is **not built/deployed**; live tests and connected-account implementation remain after the user supplies access and product data. API features and pricing can change; revalidate before enabling live automation.
