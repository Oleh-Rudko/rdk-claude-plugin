---
name: quality-checklists
description: >
  Quality checklists for each Acuity PPM layer. Used by the orchestrator
  after each Story and by the code-reviewer. Specific to real project patterns:
  ApiController auth, access_groups permissions, snake_case types, serverHooksForGraphqlTS.
---

# Quality Checklists — Acuity PPM

---

## Rails (rails_api/)

### Critical
- [ ] **Auth**: Controller extends `ApiController` (includes Secured → JWT auth)
- [ ] **N+1**: `.each`/`.map` with associations has `includes`/`preload`/`eager_load`
- [ ] **Multi-tenant**: data scoped through `current_user` or portfolio/company membership
- [ ] **SQL injection**: no raw SQL without parameterization
- [ ] **Roles**: assignment role check where needed (admin_in_company?)

### Important
- [ ] **Naming**: follows Rails/Zeitwerk conventions (see rails-specialist SKILL.md)
- [ ] **Strong params**: new fields in `permit()`
- [ ] **Validations**: new fields on model have validations
- [ ] **Blueprinter**: serializer updated (if endpoint uses it)
- [ ] **Currency**: bigint in cents, `attribute :field, :currency, default: 0`
- [ ] **Enums**: with `prefix: true` to avoid name collision
- [ ] **Callbacks**: minimal; complex logic → service object
- [ ] **Background jobs**: use Lambdakiq (NOT Sidekiq), include `Lambdakiq::Worker`
- [ ] **Audited**: new models with important data have `audited`
- [ ] **RSpec**: model + request specs, multi-tenant isolation test
- [ ] **Architecture split**: no new GET endpoints unless complex logic — use Hasura for reads

### Migrations
- [ ] Reversible (`change` method)
- [ ] Index on every foreign key (`add_reference` with `index: true`)
- [ ] Default value where needed
- [ ] `null: false` where needed
- [ ] Data migration — separate migration, not in structural

### Run
```bash
cd rails_api && bundle exec rspec
```

---

## Hasura (hasura/)

### Critical
- [ ] **Context studied**: read codebase_tutorial/ relevant section
- [ ] **Schema studied**: read DB schema in schema.rb BEFORE changes
- [ ] **Relationships studied**: read yaml BEFORE changes
- [ ] **Permissions studied**: read for `user` role BEFORE changes (only role in Hasura)
- [ ] **Permission filter**: correct chain:
  - Through portfolio: `_or` with portfolio + proposal_portfolio → access_groups → users → email
  - Through company: company → assignments → user → email
  - Direct portfolio: portfolios_groups_memberships → access_groups → users → email
- [ ] **New columns**: added to select_permissions.columns for `user` role

### Important
- [ ] **Update permissions**: only needed columns, with correct filter
- [ ] **Relationships**: object/array match DB foreign keys
- [ ] **Manual config**: where FK naming is non-standard (project_manager_id → team_members)
- [ ] **Computed fields**: if human-readable enum names are needed

### Run
```bash
cd hasura && hasura metadata apply
cd hasura && hasura metadata inconsistency list
```

---

## TypeScript (client/)

### Critical
- [ ] **No `any`**: zero new `any` types
- [ ] **Prefer `type` over `interface`**: use `type` for new type definitions
- [ ] **Types match backend**: types correspond to Hasura response / Rails Blueprinter
- [ ] **snake_case fields**: types use snake_case like Hasura AND REST (portfolio_id, NOT portfolioId)
- [ ] **GraphQL types**: query/mutation typed via generics `<TData, TVariables>`

### Important
- [ ] **Existing types**: checked hooks/ before creating new ones (no types/ directory)
- [ ] **Enum handling**: Hasura returns numbers for enums (state: 0 = active)
- [ ] **Currency**: values in cents (bigint) — conversion on display
- [ ] **Nullable**: `| null` for nullable DB columns, `?` for optional params

---

## React (client/)

### Critical
- [ ] **Imports**: `gql`, `useQueryGraphql`, `useMutationGraphql` from `serverHooksForGraphqlTS`
- [ ] **Tenant scope**: `portfolioState` from `usePortfolio()` for data queries
- [ ] **useEffect deps**: all dependencies specified
- [ ] **Error handling**: loading + error + empty states

### Important
- [ ] **Existing hooks**: checked hooks/ (30+ feature hooks already exist)
- [ ] **Permissions**: `canUser(userRole, ProjectPermissions.xxx)` or `PortfolioPermissions.xxx` — almost every page/grid needs `permissionToWrite` to control editing, add/delete buttons visibility
- [ ] **i18n**: all user-facing strings via `t()` — no hardcoded text
- [ ] **AG Grid**: `GridWithToolbar.Basic` for display, `GridWithToolbar.EditPopup.Primary` for editing (NOT `AgGridWithCrudFunctionality`)
- [ ] **MUI only**: no new react-bootstrap imports — use MUI 7 components
- [ ] **MUI theme**: theme tokens (p, color, bgcolor), not hardcoded
- [ ] **Forms**: Formik + Zod + MUI for new code (no react-bootstrap)
- [ ] **Memoization**: useMemo/useCallback where needed
- [ ] **Apollo cache**: refetchQueries for mutations (network-only policy)
- [ ] **Selectors**: use `selectorsTS.ts` (typed), not `selectors.js` (legacy)
- [ ] **Tests**: Jest + RTL for new components

### Hook file structure
- [ ] `hooks/useFeatureName/useFeatureName.ts` — hook file
- [ ] `hooks/useFeatureName/index.ts` — re-export

### Run
```bash
cd client && yarn prettier --write src/path/to/file.tsx
cd client && yarn tsc --noEmit                          # whole project, no file args
cd client && yarn lint src/path/to/file.tsx
cd client && yarn jest --findRelatedTests src/path/to/file.tsx
```

---

## Cross-cutting

- [ ] Changes consistent: API field → Blueprinter → Hasura permission → TS type → React component
- [ ] **Architecture split respected**: Rails = CUD, Hasura = Read (~97%)
- [ ] **Multi-region**: changes work across US, EU, UAE (especially Lambda/SQS/email/AWS services)
- [ ] No debug: `console.log`, `binding.pry`, `debugger`, `byebug`
- [ ] No commented-out code
- [ ] No secrets/credentials
- [ ] New dependencies (gems/packages) — only with human approval
- [ ] Hasura metadata + Rails migration aligned (both run, schema matches)
