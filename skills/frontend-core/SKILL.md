---
name: frontend-core
description: >
  Universal React 18 + TypeScript patterns NOT specific to Acuity. Companion to
  typescript-react. Covers hook design, TS strictness rules, component structure,
  testing with Jest + RTL, form handling with Formik + Zod. A non-Acuity React project
  can use this skill alone.
---

# Frontend Core — Universal React 18 + TS Patterns

React 18, TypeScript strict, Jest + React Testing Library, Formik + Zod.

---

## TYPESCRIPT RULES

### No `any`

```typescript
// ❌ forbidden
const data: any = response;

// ✅ specific types
const data: Project[] = response.data?.projects ?? [];

// ✅ unknown with type guards when truly unknown
function parse(data: unknown): Project {
  if (!isProject(data)) throw new Error('Invalid project');
  return data;
}
```

### Prefer `type` over `interface`

```typescript
// ✅
export type Project = { id: number; name: string };

// ❌ reserve interface for library augmentation only
export interface Project { id: number; name: string }
```

Rationale: `type` is fully compositional (unions, mapped, conditional) and less error-prone.
`interface` is only strictly needed for declaration merging.

### Nullable vs optional

```typescript
type Project = {
  id: number;
  description: string | null;   // ← column is nullable in the DB
  notes?: string;               // ← field may be absent from the response entirely
};
```

Use `| null` for values that exist but may be empty. Use `?` for values that may be absent.
Conflating them leads to bugs (`data.notes?.trim()` vs `data.description?.trim()` differ in
runtime behavior).

---

## HOOK DESIGN

### Custom hook structure

```typescript
// useFeature.ts
export function useFeature(params: UseFeatureParams): UseFeatureResult {
  const { data, loading, error } = useQuery(QUERY, { variables: params });

  const actions = {
    refresh: () => { /* … */ },
    update: (id: number, patch: Partial<Feature>) => { /* … */ },
  };

  return { feature: data?.feature ?? null, loading, error, actions };
}
```

### Dependency arrays

```typescript
// ❌ missing dep — stale closure
useEffect(() => { fetchData(userId); }, []);

// ✅ complete deps
useEffect(() => { fetchData(userId); }, [userId]);

// ✅ stable callback via useCallback
const fetchData = useCallback((id: number) => { /* … */ }, []);
```

Use `eslint-plugin-react-hooks` + `react-hooks/exhaustive-deps`. Do not suppress warnings
with `// eslint-disable-next-line` without a written reason.

---

## COMPONENT STRUCTURE

```typescript
export function ProjectList() {
  // 1. Hooks at the top
  const { t } = useTranslation();
  const { loading, error, projects } = useProjects();

  // 2. Early returns for non-happy states
  if (loading) return <LoadingIndicator />;
  if (error) return <ErrorBanner error={error} />;
  if (!projects.length) return <EmptyState message={t('projects.empty')} />;

  // 3. Main render
  return (
    <List>
      {projects.map((p) => <ProjectRow key={p.id} project={p} />)}
    </List>
  );
}
```

Always handle **four states** for any data-fetching component: loading, error, empty, success.
Missing any one is a bug by default.

---

## FORMS (FORMIK + ZOD)

```typescript
import { Formik, Form, Field } from 'formik';
import { toFormikValidationSchema } from 'zod-formik-adapter';
import { z } from 'zod';
import { TextField, Button } from '@mui/material';

const schema = z.object({
  name: z.string().min(1, 'Required'),
  email: z.string().email(),
  age: z.number().int().positive().optional(),
});

type FormValues = z.infer<typeof schema>;

export function UserForm({ onSubmit }: Props) {
  return (
    <Formik<FormValues>
      initialValues={{ name: '', email: '' }}
      validationSchema={toFormikValidationSchema(schema)}
      onSubmit={onSubmit}
    >
      {({ errors, touched }) => (
        <Form>
          <Field as={TextField} name="name" label="Name" error={touched.name && !!errors.name} helperText={touched.name && errors.name} />
          <Field as={TextField} name="email" label="Email" />
          <Button type="submit">Save</Button>
        </Form>
      )}
    </Formik>
  );
}
```

Rules:
- One schema is the source of truth — infer `FormValues` from Zod, don't redeclare.
- Validate on blur, not on change (better UX).
- Never trust client-side validation as the only line of defense — server must re-validate.

---

## TESTING (JEST + RTL)

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ProjectCard } from './ProjectCard';

describe('ProjectCard', () => {
  const project = { id: 1, name: 'Test', description: null };

  it('renders the project name', () => {
    render(<ProjectCard project={project} />);
    expect(screen.getByText('Test')).toBeInTheDocument();
  });

  it('calls onSelect when clicked', async () => {
    const onSelect = jest.fn();
    render(<ProjectCard project={project} onSelect={onSelect} />);
    await userEvent.click(screen.getByRole('button'));
    expect(onSelect).toHaveBeenCalledWith(1);
  });

  it('shows placeholder when description is null', () => {
    render(<ProjectCard project={project} />);
    expect(screen.getByText(/no description/i)).toBeInTheDocument();
  });
});
```

Rules:
- Query by **role > label > text > testid** (in that order). `getByTestId` is last resort.
- Assert on user-visible behavior, not on implementation details (no snapshotting full trees).
- `userEvent` > `fireEvent` — simulates real user interaction (hover, focus, tab).
- One logical assertion per `it` — easier to debug failures.

---

## PERFORMANCE

```typescript
// Memoize expensive derived values
const sortedProjects = useMemo(
  () => [...projects].sort((a, b) => a.name.localeCompare(b.name)),
  [projects],
);

// Memoize callbacks passed to memoized children
const handleClick = useCallback((id: number) => { /* … */ }, []);

// Memoize pure components that re-render too often
export const ProjectRow = React.memo(ProjectRowImpl);
```

Rules:
- Do NOT memoize everything — `useMemo` and `useCallback` have overhead.
- Profile first (React DevTools Profiler) — only optimize verified hot paths.
- Virtualize long lists (> 50 items) with `react-window` or an equivalent.

---

## ACCESSIBILITY

- Every interactive element must have `aria-label` or visible text.
- Forms: every input must have an associated `<label>` (MUI `TextField` does this automatically).
- Keyboard navigation: tab order must be sensible; Esc closes modals; Enter submits forms.
- Color alone must never convey meaning — add icon / text.
