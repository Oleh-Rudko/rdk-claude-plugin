---
name: typescript-react
description: >
  TypeScript/React frontend specialist for Acuity PPM. Use when working with client/.
  Knows real patterns: useQueryGraphql/useMutationGraphql wrappers, useGet/usePost/usePut
  REST hooks, snake_case from Hasura, Permission hooks, AG Grid + MUI7, Redux + Immutable.js.
---

# TypeScript/React Specialist — Acuity PPM

React 18, TypeScript, Apollo Client 3 (GraphQL → Hasura), custom REST hooks (→ Rails API),
Redux + Immutable.js, MUI 7 (migration in progress from v5), AG Grid, Bryntum Gantt 7,
Tiptap 3 (rich text editor), Formik (adopting), Zod (validation), moment.js (dates),
flag (feature flags), React Router 5, Jest + RTL.

---

## ‼️ ARCHITECTURE SPLIT

```
Frontend → GraphQL (Hasura) → PostgreSQL     ← READ (~97% of data fetching)
Frontend → REST (Rails API) → PostgreSQL     ← CREATE / UPDATE / DELETE (with audit trail)
```

**For new features:**
- Need to display data? → GraphQL query via `useQueryGraphql`
- Need to create/update/delete? → REST call via `usePost`/`usePut`/`useDelete`
- Do NOT use `useGet` for data that Hasura already provides

---

## FRONTEND ARCHITECTURE

```
client/src/
├── hooks/
│   ├── serverHooksForGraphqlTS/    ← MAIN GraphQL hooks (typed)
│   │   ├── useQueryGraphql.ts      ← wrapper useQuery (fetchPolicy: 'network-only')
│   │   ├── useMutationGraphql.ts   ← wrapper useMutation
│   │   ├── useLazyQueryGraphql.ts
│   │   ├── useSubscriptionGraphql.ts
│   │   └── useSelectUpsertRemoveAdapterForGraphGql.ts
│   ├── serverHooksForRestTS/       ← REST API hooks (typed)
│   │   ├── useRest.ts              ← useGet, usePost, usePut, useDelete
│   │   └── restService.ts
│   ├── serverHooksForGraphql/      ← ⚠️ LEGACY JS hooks — do NOT use, migrate to TS
│   ├── Permissions/                ← permission checks
│   ├── api/                        ← shared query/CRUD hooks used across 2+ pages
│   ├── useProjects/                ← feature-specific hooks
│   ├── usePortfolio/
│   ├── useCompany/
│   ├── useLanguage/                ← i18n wrapper (t + safeT)
│   └── ... (30+ feature hooks)
├── contexts/                       ← React Context providers
│   └── ViewManagement/             ← view state management
├── translations/                   ← i18n JSON files (en, es, company-specific)
├── components/                     ← 150+ components
│   ├── AcuityAgGrid/               ← AG Grid wrappers
│   ├── common/                     ← reusable Acuity components (modal, tooltip, button)
│   ├── Dashboard*/                 ← dashboard components
│   ├── Project*/                   ← project feature pages
│   ├── Proposal*/                  ← proposal feature pages
│   └── Settings*/                  ← settings pages
├── global/                         ← app-wide: ContentRoutes, layout, providers
├── actions/                        ← Redux actions
├── reducers/                       ← Redux reducers (Immutable.js)
├── selectors.js / selectorsTS.ts   ← Redux selectors
├── utilsTS.ts                      ← shared utility functions
├── AgGridServices/                 ← AG Grid services and helpers
└── constants.ts
```

**Where to put new hooks:**
- Hook used by **1 page only** → keep in that page's directory or `hooks/useFeatureName/`
- Hook used by **2+ pages** → put in `hooks/api/`

---

## DATA FETCHING PATTERNS (REAL)

### GraphQL (Hasura) — PRIMARY

```typescript
import { gql, useQueryGraphql } from '../serverHooksForGraphqlTS';

// Types
export type Project = {
  id: number;
  portfolio_id: number;
  name: string;
  description: string | null;
  state: number | null;           // ← enum as number from Hasura
  health_status: number | null;
  start_date: string | null;      // ← ISO date string
  cost: number | null;            // ← in cents (bigint)
  // ...
};

type TVariables = {
  portfolioState: number[];       // ← array of portfolio IDs
};
type TData = {
  projects: Project[];
};

// Hook
export const useProjects = () => {
  const { portfolioState } = usePortfolio();

  const { loading, error, data } = useQueryGraphql<TData, TVariables>(
    gql`
      query useProjects($portfolioState: [bigint!]!) {
        projects(where: { portfolio_id: { _in: $portfolioState } }) {
          id
          portfolio_id
          name
          state
          health_status
          cost
          start_date
          end_date
        }
      }
    `,
    { variables: { portfolioState } },
  );

  return {
    loading,
    error,
    projects: data?.projects || [],
  };
};
```

**Key points:**
- `useQueryGraphql` — wrapper with `fetchPolicy: 'network-only'` (no cache!)
- `gql` — re-exported from `@apollo/client` via `serverHooksForGraphqlTS/index.ts`. Always import from `serverHooksForGraphqlTS`, not directly from `@apollo/client`
- Hasura returns **snake_case** (portfolio_id, health_status)
- Enums returned as **numbers** (state: 0 = active, 1 = hold, etc.)
- Currency in **cents** as bigint
- Variables type Hasura: `bigint!` for IDs, `[bigint!]!` for arrays
- `portfolioState` — array of portfolio IDs (from usePortfolio hook)

### REST (Rails API)

```typescript
import { useGet, usePost, usePut, useDelete } from '../serverHooksForRestTS';

// GET
const { data, loading, error } = useGet<ProjectResponse>('/projects?portfolio_id=1');

// POST
const { mutateAsync, loading } = usePost<CreateProjectInput, ProjectResponse>('/projects');
await mutateAsync({ name: 'New Project', portfolio_id: 1 });

// PUT
const { mutateAsync } = usePut<UpdateProjectInput, ProjectResponse>('/projects/1');
await mutateAsync({ name: 'Updated Name' });

// DELETE
const { mutateAsync } = useDelete<void, void>('/projects/1');
await mutateAsync({});
```

### Mutations (GraphQL) — ONLY for config/JSON data

`useMutationGraphql` is used almost exclusively for **configuration data** (user/company configs
stored as JSON in Hasura). Regular table CRUD (projects, resources, etc.) goes through **REST**.

```typescript
import { gql, useMutationGraphql } from '../serverHooksForGraphqlTS';

// Example: saving user view configuration (JSON)
const [updateConfig] = useMutationGraphql<TData, TVariables>(
  gql`
    mutation updateUserConfig($id: bigint!, $set: user_configs_set_input!) {
      update_user_configs_by_pk(pk_columns: { id: $id }, _set: $set) {
        id
        config
      }
    }
  `,
  {
    refetchQueries: ['useUserConfigs'],  // ← refetch by query name
  }
);
```

---

## TYPESCRIPT RULES

### No `any`

```typescript
// ❌ NEVER (even wrapper hooks have any — that's legacy, don't add new ones)
const data: any = response;

// ✅ Specific types
const data: Project[] = response.data?.projects || [];

// ✅ unknown for unknowns
function parseResponse(data: unknown): Project { }
```

### Prefer `type` over `interface`

```typescript
// ✅ Preferred — use type
export type Project = {
  id: number;
  name: string;
  portfolio_id: number;
};

// ❌ Avoid — don't use interface
export interface Project {
  id: number;
  name: string;
  portfolio_id: number;
}
```

### Where to Find Existing Types

1. **In hooks themselves** — `hooks/useProjects/useProjects.ts` → `export type Project = {...}`
2. **In components** — some types defined inline
3. **selectorsTS.ts** — typed selectors
4. **constants.ts** — shared constants
5. **Permissions/types.ts** — permission types

### Naming: snake_case everywhere

Both **Hasura AND REST API (Blueprinter)** return **snake_case**. No camelCase transform exists.
TypeScript types must use **snake_case** fields to match:
```typescript
type Project = {
  portfolio_id: number;    // NOT portfolioId — matches both Hasura AND REST response
  health_status: number;
  start_date: string | null;
};
```

This differs from "standard" camelCase convention, but it's the project's pattern — one format
for both data sources.

### Validation with Zod

Zod (v3) is available and recommended for runtime validation, especially for forms and API inputs:
```typescript
import { z } from 'zod';

const ProjectFormSchema = z.object({
  name: z.string().min(1),
  portfolio_id: z.number(),       // snake_case
  start_date: z.string().nullable(),
});

type ProjectFormValues = z.infer<typeof ProjectFormSchema>;
```
Not yet used everywhere — adopt incrementally for new features.

---

## REACT PATTERNS

### Hook structure (feature hook)

```typescript
// hooks/useFeature/useFeature.ts
export const useFeature = () => {
  const { portfolioState } = usePortfolio();  // ← tenant scope
  const { loading, error, data } = useQueryGraphql<TData, TVars>(
    GQL_QUERY,
    { variables: { portfolioState } },
  );
  return { loading, error, data: data?.feature || [] };
};

// hooks/useFeature/index.ts
export { useFeature } from './useFeature';
```

### Component structure

```typescript
// Hooks at the top
const { t } = useTranslation();
const { loading, error, projects } = useProjects();
const { permissions } = usePermission();

// Early returns
if (loading) return <LoadingIndicator />;
if (error) return <div>{t('common.error')}</div>;
if (!projects.length) return <div>{t('common.noData')}</div>;

// Main render
return <GridWithToolbar.Basic gridOptions={gridOptions} />;
```

### AG Grid pattern

Two main wrappers (NOT `AcuityAgGrid` — that's only services/renderers):
- `GridWithToolbar.Basic` — display grid (read-only or simple)
- `GridWithToolbar.EditPopup.Primary` — grid with editing via popup

Both accept `gridOptions` prop (AG Grid `GridOptions`), NOT `data` + `columns` separately.

```typescript
import { GridWithToolbar } from '../GridWithToolbar';
import { GridOptions } from 'ag-grid-community';

const { t } = useTranslation();

const gridOptions: GridOptions = useMemo(() => ({
  columnDefs: [
    { field: 'name', headerName: t('gridTable.projectName'), flex: 1 },
    { field: 'state_name', headerName: t('gridTable.status') },
    { field: 'health_status', headerName: t('gridTable.health'),
      cellRenderer: (params) => <StatusIndicator value={params.value} /> },
  ],
  rowData: projects,
}), [projects, t]);

return <GridWithToolbar.Basic gridOptions={gridOptions} />;
```

AG Grid services in `AcuityAgGrid/services/` — reusable cell renderers (HyperLinkCellRenderer).
AG Grid helpers in `AgGridServices/` — shared grid utilities.

### Permission check

Three permission patterns exist:

**1. `canUser` — MAIN pattern** (most pages/grids use this):
```typescript
import { canUser } from '../../utilsTS';
import { ProjectPermissions, PortfolioPermissions } from '../../constants';

// Almost every page/grid needs permissionToWrite
const permissionToWrite = canUser(userRole, ProjectPermissions.projectRisks);
// or for portfolio-level:
const permissionToWrite = canUser(userRole, PortfolioPermissions.projects);

// Controls editing, add/delete buttons visibility
{permissionToWrite && <Button>{t('buttons.add')}</Button>}
```

**2. `usePermission` hook** — feature-specific, service-based (Schedule, Baseline):
```typescript
import { usePermission } from '../../hooks/Permissions';

const canEditSchedule = usePermission('Schedule:CRUD', { project });
const canCreateBaseline = usePermission('Baseline:Create', { project });

{canEditSchedule && <Button>{t('buttons.editSchedule')}</Button>}
```

**3. `permissionProjectAndProposal`** — general project/proposal write check:
```typescript
import { permissionProjectAndProposal } from '../../utilsTS';

const permissionToWrite = useMemo(() =>
  permissionProjectAndProposal({
    userId, userRole, readers_can_edit_own_proposals,
    writers_can_edit_own_proposals, pathname, project, rolePermissions,
  }),
  [project],
);

{permissionToWrite && <Button>{t('buttons.save')}</Button>}
```

**4. Company-level permissions** — from Redux selector:
```typescript
const permissions = useSelector(selectors.getCompany);
// permissions?.work_intake, permissions?.scheduling, etc.
```

---

## i18n (TRANSLATIONS)

Uses `react-i18next`. **Never hardcode user-facing strings** — always use translation keys.

```typescript
// Standard import — use this for new code
import { useTranslation } from 'react-i18next';
const { t } = useTranslation();
```

### Safe translate (when key might not exist)

```typescript
// validateTranslate — MAIN pattern (67 occurrences, 26 files)
// Returns label if translation key not found
import { validateTranslate } from '../../utilsTS';
const text = validateTranslate({ t, label: 'Risk Score', tab: 'dashBoard' });
// tries t('dashBoard.riskScore'), returns 'Risk Score' if missing

// safeT — newer but rarely used (5 occurrences)
import { useLanguage } from '../../hooks/useLanguage';
const { t, safeT } = useLanguage();
// safeT returns '' if key is missing
```

### Translation files

Translation keys are **nested** in `client/src/translations/en.json`:
```json
{
  "header": { "newProject": "New Project", "toolbarOut": "Log Out" },
  "gridTable": { "save": "Save", "cancel": "Cancel" },
  "adminSettings": { "permissions": { "addUser": "Add User" } },
  "buttons": { "yes": "Yes", "no": "No" }
}
```

Usage: `t('adminSettings.permissions.addUser')` — dot-separated nested keys.

### Languages

Base languages:
- `en.json` — English (primary)
- `es.json` — Spanish

Company-specific overrides (partial — only override specific keys):
- `en_ocean_state_job_lot.json` — e.g. "Risk" → "Impact"
- `en_lely.json`, `en_shawmut.json`, `en_eml_enterprise_portfolio.json`, `pretium.json`

All stored in `client/src/translations/`.

---

## FORMS

**New forms:** Formik (v2.4.6) + Zod (v3) for validation + MUI components.
**Legacy forms:** controlled components with useState + react-bootstrap `<Form>`.
⚠️ **react-bootstrap is being removed** — new code must use MUI only. Do NOT add new bootstrap imports.

```typescript
// ✅ NEW — Formik + Zod + MUI
import { Formik, Form, Field } from 'formik';
import { toFormikValidationSchema } from 'zod-formik-adapter';
import { TextField, Button } from '@mui/material';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1),
  portfolio_id: z.number(),
});

<Formik
  initialValues={{ name: '', portfolio_id: 0 }}
  validationSchema={toFormikValidationSchema(schema)}
  onSubmit={handleSubmit}
>
  ...
</Formik>

// ❌ LEGACY — react-bootstrap (being removed)
import { Form, FormControl } from 'react-bootstrap';
```

- `react-select` for complex dropdowns (still used)

---

## ROUTING

React Router **v5** (not v6). Central routes in `client/src/global/ContentRoutes/ContentRoutes.tsx`.

Key patterns:
- **No lazy loading** — all 90+ components eagerly imported (except Sandbox)
- **Permission-based routes**: `{permissions?.work_intake && <Route ... />}`
- **Route enums**: paths built from enums in `assets` (`ESidebarRoute`, `ESettingsTabRoute`, etc.)
- **Prefetching wrappers**: `PrefetchingProjectNavigation`, `PrefetchingProposalNavigation` — wrap project/proposal sub-routes
- **Project/Proposal sub-routes**: `/project/:id/status-report`, `/project/:id/financials`, etc.
- **Nested route params with regex**: `/dashboard/:dashboardView(main|bubble-chart|insights)`
- New code should use `useHistory`, `useParams` (not `withRouter` HOC)

---

## REDUX + IMMUTABLE.JS

Legacy state management. Don't create new Redux actions/reducers without approval.

```typescript
// ✅ NEW — use typed selectors from selectorsTS.ts
import { selectorsTS } from '../../selectorsTS';
const companyId = useSelector(selectorsTS.getCompanyId);

// ❌ LEGACY — untyped JS selectors (64 files still use this)
const selectors = require('../../selectors');
const companyId = useSelector(selectors.getCompany)?.id;
```

Two selector files:
- `selectorsTS.ts` — **typed**, use for new code
- `selectors.js` — **legacy JS**, do not add new selectors here

---

## MUI 7 (migration from v5)

MUI 7 (`@mui/material ^7.3.7`). Migration from v5 in progress — some components may still
use v5 patterns. Date pickers: `@mui/x-date-pickers ^8.26.0`.

```typescript
// ✅ Theme tokens
<Box sx={{ p: 2, color: 'text.primary', bgcolor: 'background.paper' }}>
<Typography variant="h6">

// ❌ Hardcoded values
<Box sx={{ padding: '16px', color: '#333' }}>
```

---

## TESTING (Jest + RTL)

```typescript
describe('ProjectCard', () => {
  const mockProject: Project = {
    id: 1, name: 'Test', portfolio_id: 1,  // snake_case!
    state: 0, health_status: 0,
    // ... all required fields
  };

  it('renders project name', () => {
    render(<ProjectCard project={mockProject} />);
    expect(screen.getByText('Test')).toBeInTheDocument();
  });
});
```

---

## QUALITY CHECKS

See `quality-checklists` skill for the full verification checklist.
Run after changes:
```bash
cd client && yarn prettier --write src/path/to/file.tsx
cd client && yarn tsc --noEmit                          # whole project, no file args
cd client && yarn lint src/path/to/file.tsx
cd client && yarn jest --findRelatedTests src/path/to/file.tsx
```
