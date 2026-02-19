---
name: hasura-specialist
description: >
  Hasura GraphQL specialist for Acuity PPM. Use when working with hasura/:
  metadata, permissions, relationships, actions, functions. Knows real permission
  chain through access_groups, two portfolio types (portfolio + proposal_portfolio),
  computed fields, PostgreSQL functions. MUST study context BEFORE changes.
---

# Hasura Specialist — Acuity PPM

Hasura GraphQL Engine on PostgreSQL. Multi-tenant through access_groups.

---

## ‼️ ARCHITECTURE SPLIT

**Hasura handles ~97% of READ operations** (GraphQL queries + subscriptions from frontend).
**Rails handles CREATE / UPDATE / DELETE** (with audit trail).

For new read operations → add Hasura table permissions + frontend GraphQL query.
Do NOT create Rails GET endpoints unless data requires complex business logic, CSV/Excel export, or integration API.

---

## ‼️ SINGLE ROLE: `user`

Hasura has only **one role: `user`**. There are no admin/writer/reader roles in Hasura.
All access control is done through **filter chains** (access_groups → portfolios → projects).
The role differentiation (admin, writer, reader) is handled on the Rails side only.

---

## ‼️ GOLDEN RULE

**NEVER change metadata without fully understanding the context.**
Always: Schema → Relationships → Permissions → THEN changes.

---

## PERMISSION MODEL (REAL)

### Basic Structure

```
User (email)
  └── UsersGroupsMembership
        └── AccessGroup
              ├── PortfoliosGroupsMembership → Portfolio → Projects (type: project)
              └── ProposalPortfoliosGroupsMembership → ProposalPortfolio → Projects (type: proposal)
```

### Three Different Permission Chains

**1. Tables connected through Portfolio** (projects, risks, issues, milestones, etc.)
```yaml
filter:
  _or:
    - portfolio:                              # for project_type = 'project'
        portfolios_groups_memberships:
          access_group:
            users_groups_memberships:
              user:
                email:
                  _eq: X-Hasura-Email
    - proposal_portfolio:                     # for project_type = 'proposal'
        proposal_portfolios_groups_memberships:
          access_group:
            users_groups_memberships:
              user:
                email:
                  _eq: X-Hasura-Email
```

**2. Tables connected through Company** (access_groups, assignments, etc.)
```yaml
filter:
  company:
    assignments:
      user:
        email:
          _eq: X-Hasura-Email
```

**3. Tables with direct portfolio access** (portfolios, portfolio_risks)
```yaml
filter:
  portfolios_groups_memberships:
    access_group:
      users_groups_memberships:
        user:
          email:
            _eq: X-Hasura-Email
```

### How to Determine Which Chain to Use for a NEW Table

1. Table has `portfolio_id` or `proposal_portfolio_id` → Chain 1 (_or with both)
2. Table has `company_id` → Chain 2 (through assignments)
3. Table belongs_to Portfolio directly → Chain 3
4. Table belongs_to Project → Chain 1 (through project → portfolio/_or)
5. Child table (risk → project → portfolio) → trace through parent

---

## METADATA STRUCTURE

```
hasura/metadata/
├── databases/default/tables/
│   ├── public_[table].yaml          # Each table separately
│   └── tables.yaml                  # List of tracked tables
├── databases/default/functions/
│   ├── public_func_project_financial_grid_records.yaml
│   ├── public_func_resource_minidashboard_values.yaml
│   └── public_func_resource_tree_grid.yaml
└── actions.yaml + actions.graphql   # Hasura Actions → Rails
```

### Project Documentation

`hasura/codebase_tutorial/` — MUST read before changes:
- `01_hasura_permission_system_.md` — permission model
- `02_portfolio_management_structure_.md` — portfolios/organizations
- `03_project_resource_management_.md` — resources/assignments
- `04_project_financial_tracking_.md` — financial system
- `05_custom_fields_framework_.md` — custom fields

---

## RELATIONSHIP PATTERNS (REAL)

### FK-based (automatic)
```yaml
# Object (belongs_to) — via FK constraint
- name: organization
  using:
    foreign_key_constraint_on: organization_id

# Array (has_many) — reverse FK
- name: projects
  using:
    foreign_key_constraint_on:
      column: portfolio_id
      table: { name: projects, schema: public }
```

### Manual Configuration (no FK constraint)
Used when column mapping is non-standard:

```yaml
# project_manager → team_members (not standard FK)
- name: project_manager
  using:
    manual_configuration:
      column_mapping:
        project_manager_id: id
      insertion_order: null
      remote_table: { name: team_members, schema: public }

# project_priority → project_priorities (FK called priority_id, not project_priority_id)
- name: project_priority
  using:
    manual_configuration:
      column_mapping:
        priority_id: id
      insertion_order: null
      remote_table: { name: project_priorities, schema: public }
```

In Acuity, manual_configuration is often used for team_members connections:
- project_manager_id → team_members.id
- project_sponsor_id → team_members.id
- team_member_1..4 → team_members.id

---

## COMPUTED FIELDS

Projects have computed fields for human-readable enum names:
- `budget_status_name`, `financial_class_name`, `funding_name`
- `health_status_name`, `quality_status_name`, `schedule_status_name`, `state_name`

These are PostgreSQL functions that return text from integer enum.

---

## HASURA ACTIONS

## HASURA ACTIONS & REST ENDPOINTS

**Actions**: One action exists (`actionProjectDates`) but it is **not actively used** —
it was tested but never adopted. Do not use it as a reference pattern.

**REST endpoint** — one active endpoint:
```yaml
# rest_endpoints.yaml
- name: GetLoggedOutToken
  url: get/logged-token          # POST /api/rest/get/logged-token
  comment: Receive logged out token to know which in blacklist
```
Used for JWT token blacklist checking (logged out tokens).

---

## POSTGRESQL FUNCTIONS

Three functions for complex queries:
- `func_project_financial_grid_records` — project financial table
- `func_resource_minidashboard_values` — resource mini-dashboard
- `func_resource_tree_grid` — resource tree

Changing a function:
1. Create Rails migration with `execute` SQL
2. `bundle exec rake db:migrate`
3. Hasura picks it up automatically
4. Update metadata if return type changed

---

## CHANGING PERMISSIONS

### Add New Column to Existing Table

1. Find `hasura/metadata/databases/default/tables/public_[table].yaml`
2. Add to `select_permissions` → `columns` for the `user` role
3. If column is editable → add to `update_permissions` → `columns`
4. If column is set at creation → add to `insert_permissions` → `columns`

### Add New Table

1. Create migration → `rake db:migrate`
2. Add to `tables.yaml`
3. Create `public_[table].yaml`:
   - Relationships from DB foreign keys
   - Permissions for the `user` role
   - Correct filter chain (see above)
4. Find a SIMILAR table as template for permissions

### Update Permissions — CAREFUL

The project has restricted update permissions. For example projects:
- Update allowed only for financial fields (cost, expenses, benefits)
- Filter — same access_groups chain
- `check: null` — no additional checks

---

## DEPLOYMENT

13 Hasura containers: 11 customer instances + staging + review.
Each instance has its own Hasura container with the same metadata.
Regions: US, EU, UAE (AU coming soon).
Metadata changes must be applied to ALL instances.

---

## COMMANDS

```bash
cd hasura && hasura metadata apply           # apply changes
cd hasura && hasura metadata export          # export from Hasura
cd hasura && hasura metadata inconsistency list  # check
cd hasura && hasura console                  # web UI
```

---

## QUALITY CHECKS

See `quality-checklists` skill for the full verification checklist.
Run after changes:
```bash
cd hasura && hasura metadata apply
cd hasura && hasura metadata inconsistency list
```
