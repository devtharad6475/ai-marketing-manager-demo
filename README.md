# AI Marketing Manager — design and interactive prototype

**Live demo:** https://devtharad6475.github.io/ai-marketing-manager-demo/

A multi-agent marketing system designed for a B2B manufacturer: one **Master AI Controller** plans
work and delegates to 8 specialist agents (product intelligence, market research, festival timing,
campaign strategy, creative, QA & publishing, analytics, learning), with human approval before
anything is published or any money is spent.

The demo page simulates the agents in the browser so the decision protocol, approval gate and
safety checks can be tried without accounts or API keys. The company ("Demo Zari Co.") and all
figures are invented. Nothing is posted anywhere.

## What is in `design/`
- `AI_Marketing_Manager_Blueprint_v1.md` — architecture, memory model, learning loop, permissions, delivery gates
- `MASTER_AI_HARNESS.md` — controller instructions: trust order, command protocol, failure handling
- `agent_roles.yaml` — agent roles, scoped memory, tools and default approval policy
- `database_schema.sql` — proposed Postgres schema (18 tables)
- `evaluation_cases.json` — 12 acceptance scenarios (unsupported claims, missing approval, prompt injection, budget caps…)

## Planned stack for the live build
OpenAI Agents SDK (Python), Supabase/Postgres, Google Drive (read-only sources), a social publishing
adapter with idempotency keys and signed webhooks, cron plus a persistent worker.

Status: design complete, prototype demo live, production system not yet built.
