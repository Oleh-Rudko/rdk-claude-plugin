---
name: rails-core
description: >
  Universal Rails 7 API patterns NOT specific to Acuity. Use as a companion to project-specific
  skills (rails-specialist). Covers Zeitwerk naming, migrations, RSpec + FactoryBot, Blueprinter
  basics, the `audited` gem, and N+1 prevention. A non-Acuity Rails project can use this skill
  alone; Acuity overlays additional patterns on top.
---

# Rails Core — Universal Rails 7 Patterns

Rails 7.x API-only, PostgreSQL, Blueprinter (optional), RSpec + FactoryBot, `audited` gem.

This skill is the **universal** layer. Project-specific patterns (auth, tenancy, background
job adapter, multi-region) live in the project overlay skill.

---

## NAMING CONVENTIONS (Zeitwerk)

Rails uses the Zeitwerk autoloader: file path maps to class/module name via `camelize`.
**Wrong naming = class not found at runtime.**

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
| Factory | `spec/factories/project_resources.rb` | `FactoryBot.define { factory :project_resource }` |

**Key rules:**
1. **Pluralization matters**: model = singular, controller = plural, table = plural
2. **Suffix = type**: `*Controller`, `*Service`, `*Blueprint`, `*Job` — always add the suffix
3. **File = class**: Zeitwerk resolves automatically
4. **Nesting = module**: `app/services/foo/bar.rb` → `Foo::Bar`

---

## MIGRATIONS

```ruby
class AddFieldToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :new_field, :string, null: false, default: ''
    add_reference :projects, :new_relation, foreign_key: true, index: true
  end
end
```

**Rules:**
- Always reversible — use `change` method, not `up` / `down` unless truly irreversible
- Every foreign key gets an index (`add_reference` with `index: true` does this automatically)
- `null: false` + `default:` when adding required columns to existing tables
- Data migrations (backfill, transform) go in a **separate** migration, NOT mixed with schema changes
- Large backfills belong in a rake task or async job, not a migration

---

## BLUEPRINTER (SERIALIZATION)

```ruby
class ProjectBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :state, :start_date, :end_date

  view :extended do
    association :portfolio, blueprint: PortfolioBlueprint
    field :cost
  end
end
```

**Rules:**
- `identifier :id` on every blueprint
- Use `view :xxx` blocks for different serialization shapes — do NOT create multiple blueprints for the same model
- `association` with an explicit blueprint — never nest raw models

---

## N+1 QUERIES

The single most common performance bug in Rails. Prevent with eager loading.

```ruby
# ❌ N+1 — one query per project for .portfolio
projects.each { |p| p.portfolio.name }

# ✅ Eager load
Project.where(...).includes(:portfolio, :category).each { |p| p.portfolio.name }
```

**Rule:** if a controller returns a collection AND the serializer references an association,
the controller MUST eager load that association. The `bullet` gem in development catches this.

---

## AUDITED (AUDIT TRAIL)

The `audited` gem records create/update/delete history on model records.

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

**Rules:**
- Audits live in the `audits` table — accessible via `record.audits`
- For new models holding business data: add `audited` (or `audited associated_with: :parent`)
- Do not audit high-churn fields (timestamps, session data) — use `except:`

---

## RSPEC + FACTORYBOT

**Model spec:**
```ruby
RSpec.describe Project, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to belong_to(:portfolio) }
  it { is_expected.to have_many(:milestones).dependent(:destroy) }

  describe '#display_name' do
    it 'returns the formatted name' do
      project = build(:project, name: 'Test')
      expect(project.display_name).to eq('Test')
    end
  end
end
```

**Request spec** (auth stubbing is project-specific — see project overlay skill):
```ruby
RSpec.describe ProjectsController, type: :request do
  let(:user) { create(:user) }

  describe 'POST /projects' do
    it 'creates a project' do
      # Auth helper is project-specific
      sign_in_as(user) do
        post '/projects', params: { project: { name: 'X' } }
        expect(response).to have_http_status(:created)
      end
    end
  end
end
```

**Rules:**
- Model specs: validations + associations + public methods
- Request specs: happy path + auth required + validation failure
- Avoid fixture sharing across specs — FactoryBot builds fresh data per test
- Use `build` (no DB write) for unit tests, `create` (writes to DB) for integration tests

---

## CONTROLLERS (BASIC PATTERN)

```ruby
class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :update, :destroy]

  def index
    render json: Project.all
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      render json: @project, status: :created
    else
      render json: @project.errors, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
```

**Rules:**
- Strong params on every write action
- Return standard HTTP statuses: 201 Created, 204 No Content, 422 Unprocessable, 404 Not Found
- Use `before_action :set_record` to avoid duplicate `find` calls
- Keep controllers thin — business logic belongs in services

---

## BUSINESS LOGIC: SERVICES

```ruby
# app/services/send_welcome_email_service.rb
class SendWelcomeEmailService
  def initialize(user:)
    @user = user
  end

  def call
    # Business logic here
    # Return a meaningful result or raise a specific error
  end

  private

  attr_reader :user
end
```

**Rules:**
- Services have a clear name: `VerbNounService` or `NounService`
- Single public method (`call`, `perform`, `result`) — services are one-trick objects
- Dependencies via `initialize` — no hidden globals
- Return values are meaningful (not just `true` / `false` unless that's literally what's being asked)

---

## RUN TESTS

```bash
bundle exec rspec                              # Full suite
bundle exec rspec spec/models/                 # Models only
bundle exec rspec spec/requests/projects_spec.rb  # One file
bundle exec rspec --fail-fast                  # Stop on first failure
```
