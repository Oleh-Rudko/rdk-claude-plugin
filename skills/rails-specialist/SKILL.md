---
name: rails-specialist
description: >
  Rails backend specialist for Acuity PPM. Use when working with rails_api/:
  controllers, models, services, migrations, blueprinters, specs. Knows real project
  patterns: ApiController + Secured, Blueprinter, Assignment-based roles, N+1 prevention,
  multi-tenant through Company → Organization → Portfolio/ProposalPortfolio.
---

# Rails Specialist — Acuity PPM

Rails 7.2 API-only, PostgreSQL, Blueprinter, Lambdakiq (AWS Lambda + SQS), RSpec + FactoryBot.

---

## ‼️ ARCHITECTURE SPLIT: Rails vs Hasura

**Rails handles Create / Update / Delete** (with Audits).
**Hasura handles ~97% of GET/Read** (GraphQL queries from frontend).

```
Frontend → GraphQL (Hasura) → PostgreSQL     ← READ (queries, subscriptions)
Frontend → REST (Rails API) → PostgreSQL     ← CREATE / UPDATE / DELETE (with audit trail)
```

**Do NOT create Rails GET endpoints** unless:
- Data requires complex business logic that Hasura can't do
- Endpoint returns CSV/Excel export
- Integration API (Open API /v1)
- Snapshot API (/snapshot)

For new read operations → add Hasura permissions + frontend GraphQL query.
For new write operations → add Rails controller action.

---

## NAMING CONVENTIONS

Rails uses Zeitwerk autoloader: file path maps to class/module name via `camelize`.
**This is mandatory** — wrong naming = class not found at runtime.

| Layer | File path | Class/Module name |
|-------|-----------|-------------------|
| Model | `app/models/project_resource.rb` | `class ProjectResource < ApplicationRecord` |
| Controller | `app/controllers/projects_controller.rb` | `class ProjectsController < ApiController` |
| Service | `app/services/excel_export_service.rb` | `class ExcelExportService` |
| Blueprint | `app/blueprints/project_blueprint.rb` | `class ProjectBlueprint < Blueprinter::Base` |
| Job | `app/jobs/notification_email_job.rb` | `class NotificationEmailJob < ApplicationJob` |
| Concern | `app/models/concerns/site_color.rb` | `module SiteColor` |
| Migration | `db/migrate/20260219_add_field_to_projects.rb` | `class AddFieldToProjects < ActiveRecord::Migration[7.2]` |
| Spec | `spec/models/project_resource_spec.rb` | `RSpec.describe ProjectResource` |
| Request spec | `spec/requests/projects_spec.rb` | `RSpec.describe ProjectsController, type: :request` |
| Factory | `spec/factories/project_resources.rb` | `FactoryBot.define { factory :project_resource }` |

**Key rules:**
1. **Pluralization matters**: model = singular (`Project`), controller = plural (`ProjectsController`), table = plural (`projects`)
2. **Suffix = type**: `*Controller`, `*Service`, `*Blueprint`, `*Job` — always add the suffix
3. **File = class**: `project_resource.rb` → `ProjectResource` (Zeitwerk resolves automatically)
4. **Nesting = module**: `app/services/notification_sender/proposal_created.rb` → `NotificationSender::ProposalCreated`

---

## DATA ARCHITECTURE

```
Company
├── Organizations (has_many, through: :organizations)
│   ├── Portfolios (has_many)
│   │   ├── Projects (has_many, project_type: 'project')
│   │   │   ├── StatusReports, Issues, Risks, Milestones, ProjectTasks
│   │   │   ├── ProjectBenefits, ProjectDecisions, ProjectLearnedLessons
│   │   │   ├── ProjectResourceAssignments → CompanyProjectResources
│   │   │   ├── ProjectCustomFields, ProjectScoringCriteriaValues
│   │   │   ├── CommunicationPlans → CommunicationPlansPhases
│   │   │   └── Financials: CapEx/OpEx/Rev/Dep OptionAssignments → OpDetails
│   │   └── PortfoliosGroupsMemberships → AccessGroups
│   │
│   └── ProposalPortfolios (has_many)
│       ├── Projects (has_many, project_type: 'proposal')
│       └── ProposalPortfoliosGroupsMemberships → AccessGroups
│
├── Assignments (has_many) → Users (roles: superadmin, admin, writer, reader, integration)
├── AccessGroups (has_many) → UsersGroupsMemberships → Users
├── TeamMembers, Categories, Departments, Lifecycles, StrategicObjectives
├── CompanyProjectResources, CompanyResourceTeams, CompanyResourceRoles
├── ScoringCriteria, ScoringCriterionOptions
├── CompanyConfigurations, CompanyCustomFields
└── MilestonePerformances, ProjectPriorities, DependencyTypes
```

### Key Models

**Project** — central model. Has two types:
- `project_type: 'project'` → belongs_to :portfolio
- `project_type: 'proposal'` → belongs_to :proposal_portfolio

Enums (with prefix): state, funding, financial_class, health_status, schedule_status,
budget_status, quality_status, scope/risk/resource/benefits_stoplight_status, proposal_state

Currency fields (stored in cents): cost, cost_actual, financial_benefits,
financial_benefits_actual, operational_expenses, capital_expenses + actual variants

Custom type `app/types/currency_type.rb`:
```ruby
class CurrencyType < ActiveRecord::Type::BigInteger
  # Casts dollar input → BigDecimal → stored as bigint (cents) in DB
end

# Usage in models:
attribute :cost, :currency, default: 0
attribute :financial_benefits, :currency, default: 0
```
`:currency` is NOT a standard Rails type — it's project-specific. Registered via `app/types/`.

**Company** — tenant root. Everything starts from Company.
- `company.users` — through assignments
- `company.projects` — through organizations → portfolios
- `company.portfolios` — through organizations

**AccessGroup** — key to Hasura permissions:
- Company has_many access_groups
- AccessGroup → UsersGroupsMemberships → Users
- Portfolio → PortfoliosGroupsMemberships → AccessGroups
- ProposalPortfolio → ProposalPortfoliosGroupsMemberships → AccessGroups

---

## AUTH PATTERN

```ruby
# All controllers inherit from ApiController
class ApiController < ActionController::API
  include Secured  # JWT auth → current_user via email
  before_action :restrict_access_for_integration
end

# Secured concern:
# - JWT token from header Authorization → decode → email
# - FindsUserByEmail.new(current_email).find → @_user
# - Integration auth: api-auth + api-token + api-secret headers
```

`current_user` — available in every controller.
`current_email` — email from JWT.

Roles through Assignment model:
- `Assignment::SUPERADMIN`, `Assignment::ADMIN`, `Assignment::WRITER`,
  `Assignment::READER`, `Assignment::INTEGRATION`

Role check:
```ruby
assignment_in_company(user: current_user, company: company)
admin_in_company?(user: current_user, company: company)
```

---

## CONTROLLER PATTERNS

Controllers are NOT namespaced by api/v1. Located directly in `app/controllers/`.

```ruby
class ProjectsController < ApiController
  before_action :set_project, only: [:update, :destroy]

  def index
    # Filter by portfolio (tenant scope)
    projects = current_user.projects.where(portfolio: params[:portfolio_id])
    # Respond with Blueprinter or CSV
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      render json: @project, status: :created
    else
      render json: @project.errors, status: :unprocessable_entity
    end
  end

  def update
    # Pattern: store old values → update → trigger side effects → save
    store_old_values
    prepare_project_attributes
    update_custom_fields
    trigger_financial_updates
    if @project.save
      send_notifications
      render json: @project
    end
  end

  private
  def set_project
    @project = Project.find(params[:id])
  end
end
```

Specifics:
- Some controllers return CSV (not JSON)
- Notifications sent after save (NotificationSender)
- Import controllers are separate (*_imports_controller.rb)
- Integration controllers are separate (*_integration_controller.rb)

---

## BLUEPRINTER

Located in `rails_api/app/blueprints/`. Used for snapshot/export.

```ruby
class ProjectBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :state, :health_status, :start_date, :end_date, :cost
  # ...nested associations with other blueprints
end
```

NOT all endpoints use Blueprinter — some return raw JSON or CSV.

---

## BUSINESS LOGIC LOCATIONS

Two directories for business logic (legacy split):

### `app/lib/` — older code, VerbNoun naming (no suffix)
```ruby
# imports_projects.rb
class ImportsProjects
  def initialize(csv, user, filename:, company_id:); end
  def successfully?; end
  def projects; end
  def errors; end
end

# calculates_priority_score.rb
class CalculatesPriorityScore
  def initialize(project:, category:); end
  def result; end
end

# finds_user_by_email.rb
class FindsUserByEmail
  def initialize(email); end
  def find; end
end
```

### `app/services/` — newer code, NounService naming (with suffix)
```ruby
# excel_export_service.rb
class ExcelExportService
  def initialize(company:, portfolio:); end
  def export; end
end

# csv_processor_service.rb
class CsvProcessorService
  def initialize(file, options = {}); end
  def process; end
end
```

**For new code**: use `app/services/` with `*Service` suffix.

### `app/notifications/` — notification module
```ruby
# notification_sender.rb → module, not class
module NotificationSender
  # Subclasses in notification_sender/ directory
end
```

---

## AUDITED (Audit Trail)

72 models use the `audited` gem — nearly every model in the project.
This is why Rails handles writes: every create/update/delete is automatically audit-logged.

```ruby
# Simple — audit all changes
class Project < ApplicationRecord
  audited
end

# With association — audit links to parent
class ProjectResourceAssignment < ApplicationRecord
  audited associated_with: :project
end

# Exclude noisy fields
class User < ApplicationRecord
  audited except: [:logged_in_at]
end
```

**For new models**: always add `audited` (or `audited associated_with: :parent`).
Audit records stored in `audits` table — accessible via `record.audits`.

---

## N+1 QUERIES — CRITICAL

Project model has ~30 associations. N+1 is the MOST COMMON problem.

```ruby
# ❌ N+1 — each project.portfolio — separate query
projects.each { |p| p.portfolio.name }

# ✅ Eager load
projects = Project.where(...).includes(:portfolio, :category, :department)

# For snapshot — see Company.create_snapshots for FULL includes chain
```

Blueprinter nested associations = controller MUST eager load.

---

## MIGRATIONS

```ruby
class AddFieldToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :new_field, :string, null: false, default: ''
    add_reference :projects, :new_relation, foreign_key: true, index: true
    # Currency → :bigint (stored in cents)
    add_column :projects, :new_amount, :bigint, default: 0
  end
end
```

After migration:
1. `bundle exec rake db:migrate`
2. Hasura sees new schema automatically
3. May need hasura metadata apply for permissions

---

## RSPEC

```ruby
RSpec.describe ProjectsController, type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let!(:assignment) { create(:assignment, user: user, company: company, role: 'admin') }

  describe "POST /projects" do
    it "creates project" do
      # Block-based auth helper — mocks current_user for the block
      as_authenticated_user(user) do
        post "/projects", params: { project: valid_params }
        expect(response).to have_http_status(:created)
      end
    end
  end
end
```

`as_authenticated_user(user, &block)` — defined in `spec/support/request_spec_helper.rb`.
Mocks `authenticate_request!` and `current_user` on `ApiController`.
**No headers needed** — auth is stubbed, not sent via HTTP.

Test:
- Auth: without `as_authenticated_user` block → 401
- Roles: reader cannot create
- Multi-tenant: other company data NOT returned
- Validations: invalid params → 422 with errors

---

## BACKGROUND JOBS

**NOT Sidekiq.** Uses **Lambdakiq** — ActiveJob adapter for AWS Lambda + SQS.

```ruby
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  include Lambdakiq::Worker
  queue_as ENV['JOBS_QUEUE_NAME'] || 'default'
end
```

- Production/staging: `config.active_job.queue_adapter = :lambdakiq`
- Development: default `:async` adapter (in-process, no SQS)
- Gems: `lambdakiq ~> 2.2`, `aws-sdk-sqs ~> 1.80`

### ActiveJob jobs (`app/jobs/`) — async via SQS → Lambda
```ruby
class NotificationEmailJob < ApplicationJob
  queue_as ENV['JOBS_QUEUE_NAME'] || 'default'

  def perform(notification_id)
    # ...
  end
end
```

Existing:
- `NotificationEmailJob`, `TeamsNotificationJob`, `WelcomeEmailJob` — email/messaging
- `ConvertProposalJob`, `ConvertRiskToIssueJob` — state transitions
- `MppImportJob` — Microsoft Project import
- `CompanyReportsResourcesSnapshotJob` — scheduled snapshots
- `EnableNotificationSubscriptionsJob` — notification setup

### Daily jobs (`app/jobs/daily/`) — NOT ActiveJob, plain Ruby classes

Orchestrated by `DailyJobsRunner` service (called by external Lambda cron).

```ruby
# Pattern for daily jobs:
class Daily::LateMilestonesJob
  def self.should_run?(context); end  # check if job is needed
  def initialize(context); end        # receives CompanyDataContext
  def process; end                    # returns { emails_sent:, notifications_sent: }
end
```

- `Daily::LateMilestonesJob`, `Daily::LateTasksJob`, `Daily::DueTasksJob`
- `DailyJobsRunner` iterates all companies, checks `CompanyDataContext`, runs applicable jobs
- New daily jobs: add class to `DailyJobsRunner#jobs_registry` array

---

## ‼️ MULTI-REGION DEPLOYMENT

The app runs across **multiple regions**: US, EU, UAE (AU coming soon).
Each region has its own infrastructure (Lambda, SQS, DB, etc.).

**ALWAYS remember**: changes that touch AWS infrastructure, messaging, notifications,
Lambda jobs, SQS queues, or external service integrations — **must work in ALL regions**.

Common mistake: implement and test in US → deploy → breaks in EU/UAE because of
different protocols, endpoints, region-specific configs, or service availability.

**Checklist for infra-touching changes:**
- [ ] Works in US region
- [ ] Works in EU region
- [ ] Works in UAE region
- [ ] Region-specific configs updated in ALL environment files

There are 13 deployed environments: 11 customer instances + staging + review.
Each major customer has an isolated instance. Per-customer env files are in
`rails_api/config/environments/`.

---

## RAKE TASKS

Located in `rails_api/lib/tasks/`.

| Task | Purpose |
|------|---------|
| `daily_jobs:run[timezone]` | Run daily notification jobs (via DailyJobsRunner) |
| `udfs` | Manage PostgreSQL user-defined functions |
| `import` | Data import operations |
| `database` | DB maintenance utilities |
| `one_offs` | One-time data migrations/fixes |
| `repair` | Data repair operations |
| `audit_backfill` | Backfill audit records |
| `auth0` | Auth0 management tasks |
| `login_tracker` | Login tracking utilities |

---

## ACTIVE ADMIN (Super Admin Panel)

Located in `rails_api/app/admin/`. 28 resources. NOT part of the public API.
Used by the customer (not end users) to manage features that should not be accessible from the frontend.

**Typical use cases:**
- Toggle company feature flags (`financial_enabled`, `bryntum_project_scheduler_enabled`, `advanced_permissions`, `resource_planning`, `work_intake`, etc.)
- Manage integrations (create API keys, assign integration users)
- Manage users, assignments, companies, portfolios
- Run data migrations or one-off admin operations
- Manage licensing (`licenses`, `team_member_licenses`, `resource_manager_licenses`)

```ruby
# app/admin/companies.rb
ActiveAdmin.register Company do
  permit_params :name, :financial_enabled, :integration_enabled, ...

  form do |f|
    inputs do
      input :name
      input :financial_enabled
      # ...
    end
    f.actions
  end
end
```

**Key pattern**: Integration form restricts user selection to `Assignment::INTEGRATION` role only.

---

## INTEGRATION API (Open API)

Public API for external systems. Uses API key auth (not JWT).

### Auth — three headers
```
api-auth:   <integration.auth_token>
api-token:  <integration.company_api_token>
api-secret: <integration.auth_secret>
```

Credentials stored in `Integration` model (created by Super Admin only).
Integration users have `Assignment::INTEGRATION` role — restricted to whitelist of endpoints.

### Routes (`/v1` scope)
```
GET/POST/PUT  /v1/project            — project CRUD
PUT           /v1/project/timeline   — update project timeline
GET/POST/PUT  /v1/project/task       — task CRUD
GET/POST/PUT  /v1/project/status-report — status report CRUD
GET/POST/PUT  /v1/proposal           — proposal CRUD
PUT           /v1/proposal/timeline  — update proposal timeline
GET/POST/PUT  /v1/milestones         — milestone CRUD
POST/DELETE   /v1/webhook            — webhook subscriptions
GET           /v1/check-auth         — verify credentials
```

### Snapshot API (`/snapshot` scope) — read-only
```
GET /snapshot/projects               — full project data
GET /snapshot/projects/risks|issues|reports|benefits|lessons|decisions|resources|tasks
GET /snapshot/proposals              — full proposals data
```

### Controllers
Integration endpoints use separate controllers: `*_integration_controller.rb`
Access restricted via `allowed_action_for_integration?` whitelist in `ApiController`.

Full documentation: `docs/API/`

---

## QUALITY CHECKS

See `quality-checklists` skill for the full verification checklist.
Run after changes: `cd rails_api && bundle exec rspec`
