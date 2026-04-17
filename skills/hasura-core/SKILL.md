---
name: hasura-core
description: >
  Universal Hasura GraphQL Engine patterns NOT specific to Acuity. Companion to
  hasura-specialist. Covers metadata structure, relationship types (FK + manual),
  permission model basics, computed fields, actions, functions, the metadata CLI workflow.
  A non-Acuity Hasura project can use this skill alone.
---

# Hasura Core — Universal Patterns

Hasura GraphQL Engine on PostgreSQL.

---

## METADATA STRUCTURE

```
hasura/metadata/
├── databases/default/
│   ├── tables/
│   │   ├── public_[table].yaml   ← one file per tracked table
│   │   └── tables.yaml           ← list of tracked tables
│   └── functions/
│       └── public_[fn].yaml      ← one file per tracked SQL function
├── actions.yaml + actions.graphql  ← Hasura Actions (custom resolvers)
├── rest_endpoints.yaml           ← REST wrappers over GraphQL queries
└── query_collections.yaml        ← allow-listed query collections
```

---

## RELATIONSHIP TYPES

### FK-based (automatic)

```yaml
# Object (belongs_to) — via FK constraint
- name: organization
  using:
    foreign_key_constraint_on: organization_id

# Array (has_many) — reverse FK on a remote table
- name: projects
  using:
    foreign_key_constraint_on:
      column: portfolio_id
      table: { name: projects, schema: public }
```

Use this whenever a DB foreign key already exists. Cheapest, clearest, no maintenance.

### Manual configuration (no FK constraint)

Use when column naming is non-standard or the relation crosses schemas:

```yaml
- name: project_manager
  using:
    manual_configuration:
      column_mapping:
        project_manager_id: id        # local column → remote column
      insertion_order: null
      remote_table: { name: team_members, schema: public }
```

Rules:
- Prefer FK-based whenever possible — document WHY manual configuration is used.
- `insertion_order: null` for read-only relations.
- Keep `column_mapping` minimal (usually a single pair).

---

## PERMISSION MODEL (UNIVERSAL)

Every tracked table has four permission types, each scoped to a role:

| Operation | What it controls |
|---|---|
| `select_permissions` | Which rows a role can read + which columns are visible |
| `insert_permissions` | Which rows a role can create + which columns accept input + `check` predicate |
| `update_permissions` | Which rows a role can modify (`filter`) + which columns are writable + `check` predicate |
| `delete_permissions` | Which rows a role can delete (`filter`) |

**Filter** = WHERE clause applied to every query. Uses session variables
(`X-Hasura-User-Id`, custom headers) to restrict rows per authenticated user.

**Check** = INSERT/UPDATE guard — rejects writes that would violate the predicate.
Often `check: null` (no additional guard) when `filter` is already tight.

**Column permissions** — the set of columns a role can see (select) or set (insert/update).
Narrow columns aggressively — exposing an email column by default is a common security
leak.

---

## COMPUTED FIELDS

Exposed PostgreSQL functions that appear as virtual columns on a table:

```yaml
computed_fields:
  - name: full_name
    definition:
      function:
        schema: public
        name: users_full_name
    comment: concat first_name || ' ' || last_name
```

Use for:
- Denormalizing enum integers into human-readable text
- Cheap aggregations
- Server-computed values that must match DB truth

Rules:
- The SQL function takes one argument of the row type (`users`) and returns a scalar.
- Add an index if the function is used in filters.
- Keep them pure / deterministic — Hasura caches plan, not per-row results.

---

## ACTIONS

Custom GraphQL resolvers backed by an external HTTP endpoint (usually your Rails/Node API).

```graphql
# actions.graphql
type Mutation {
  createProjectWithDefaults(input: CreateProjectInput!): CreateProjectOutput
}
```

```yaml
# actions.yaml
actions:
  - name: createProjectWithDefaults
    definition:
      kind: synchronous
      handler: '{{API_BASE_URL}}/hasura/actions/create_project'
      forward_client_headers: true
      headers:
        - name: X-Hasura-Action-Secret
          value_from_env: HASURA_ACTION_SECRET
```

Use when:
- You need server-side business logic that Hasura can't express
- You need to call a third-party API as part of a mutation
- You need a write path with audit logging

Do NOT use for simple CRUD — that's what `insert/update/delete` mutations are for.

---

## POSTGRESQL FUNCTIONS

Track a function to expose it as a GraphQL query or mutation:

```yaml
# functions/public_my_fn.yaml
function:
  schema: public
  name: my_fn
configuration:
  session_argument: hasura_session
```

Workflow to change a tracked function:
1. Write a migration with `execute "CREATE OR REPLACE FUNCTION …"`
2. Run migration
3. Hasura picks up the new definition automatically
4. If return type changed — update metadata (`hasura metadata export` → commit)

---

## METADATA CLI COMMANDS

```bash
cd hasura
hasura metadata apply                    # push local metadata to the server
hasura metadata export                   # pull server metadata into local files
hasura metadata inconsistency list       # check for broken refs (missing tables, bad FKs)
hasura metadata reload                   # force Hasura to reread DB schema
hasura console                           # open the web UI (runs proxied; edits go into your files)
```

Rules:
- `hasura metadata apply` is idempotent — safe to rerun.
- `hasura metadata inconsistency list` should always return empty before merge. CI enforces this.
- `hasura console` edits ARE persisted back to your local YAML — do not edit the production console.

---

## MULTI-INSTANCE DEPLOYMENT

If the project runs multiple Hasura instances (per customer, per region), metadata must be
applied to each instance. Treat instance-specific config via environment variables
(`{{API_BASE_URL}}`, `{{HASURA_ACTION_SECRET}}`) — never hardcode URLs in `actions.yaml`.
