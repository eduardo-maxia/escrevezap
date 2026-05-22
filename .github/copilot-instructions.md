# Copilot Instructions — Cobrança em Dia

Automated WhatsApp billing reminders SaaS for small businesses. Companies connect a WhatsApp number (via Waha), register clients, and the platform sends payment reminders automatically.

---

## Stack

| Layer | Tech |
|---|---|
| **Framework** | Rails 8.1.3, Ruby 3.4.7 |
| **Database** | PostgreSQL — use `jsonb` (not `json`) for JSON columns |
| **Asset pipeline** | Propshaft (NOT Sprockets — never reference Sprockets APIs) |
| **JS bundling** | jsbundling-rails |
| **CSS bundling** | cssbundling-rails |
| **CSS framework** | Tailwind v4 |
| **Frontend** | Hotwire: Turbo + Stimulus |
| **Auth** | Devise 5 |
| **Background jobs** | SolidQueue |
| **Action Cable** | SolidCable |
| **Cache** | SolidCache |
| **File uploads** | Active Storage + image_processing |
| **Pagination** | Pagy 9 — `@pagy, @records = pagy(scope)` |
| **Search** | pg_search |
| **Email (dev)** | letter_opener |
| **Email (prod)** | Resend via SMTP (`smtp.resend.com:587`) |
| **Deployment** | Kamal + Docker |
| **Networking** | Tailscale sidecar in production |

---

## CSS & Tailwind v4

**Always use CSS variable utilities:**

```html
✅ text-(--color-brand)        bg-(--color-surface)       border-(--color-border)
❌ text-[#0D2E67]              bg-[--color-surface]        text-blue-900
```

**All CSS variables (defined in `app/assets/stylesheets/application.tailwind.css`):**

```
Brand:   --color-brand #0D2E67 | --color-brand-dark #0A224E | --color-brand-light #DCE8F8 | --color-brand-subtle #F4F8FD
Accent:  --color-accent #C88437 | --color-accent-dark #A86A25 | --color-accent-light #F4E3D0 | --color-accent-subtle #FBF6F0
Surface: --color-surface #FFF | --color-surface-muted #F8FAFC | --color-surface-raised #EEF2F7
Border:  --color-border #E2E8F0 | --color-border-strong #CBD5E1
Text:    --color-text #111827 | --color-text-muted #64748B | --color-text-subtle #94A3B8 | --color-text-inverse #FFF
Status:  --color-danger #DC2626 | --color-danger-light #FEE2E2
         --color-warning #D97706 | --color-warning-light #FEF3C7
         --color-success (see CSS file) | --color-success-light
Sidebar: --color-sidebar-bg | --color-sidebar-border | --color-sidebar-text | --color-sidebar-text-hover | --color-sidebar-item-hover
```

---

## Icons

Phosphor Icons via CDN (`@phosphor-icons/web@2.1.1`). Always use the `ph` class prefix.

```html
<i class="ph ph-icon-name"></i>          <!-- outlined -->
<i class="ph-fill ph-icon-name"></i>     <!-- filled -->
```

Browse icons at [phosphoricons.com](https://phosphoricons.com). Never use Heroicons, FontAwesome, or inline SVGs.

---

## Routing

All authenticated app routes live under the `/app` scope:

```ruby
scope "/app" do
  authenticated :user { root "dashboard#index", as: :authenticated_root }
  resources :campaigns
  resources :clients
  resources :chips
  # etc.
end
```

- Public root: `pages#home` (layout: `landing`)
- Authenticated root: `dashboard#index` at `/app` (layout: `authenticated`)
- Devise routes: also under `/app` scope

---

## Layouts

| Layout | Used by |
|---|---|
| `landing` | `PagesController` — public marketing pages |
| `authenticated` | All app controllers — sidebar + main content |

---

## Modals

Standard pattern across the whole app: native `<dialog>` inside a shared `turbo-frame#modal`, opened via Turbo link with `data-turbo-frame="modal"`. On mobile it's a **bottom sheet sliding up**; on desktop it's a centered card fading in. Both behaviors are baked into the `.app-modal` class in `application.tailwind.css` — never roll your own positioning/animation.

**Standard skeleton for any new modal view:**

```erb
<turbo-frame id="modal">
  <dialog data-controller="modal" class="app-modal md:max-w-md">
    <div class="app-modal-handle"></div>

    <%# Header %>
    <div class="flex items-start justify-between gap-4 px-6 py-5 border-b border-(--color-border) flex-shrink-0">
      <h2 class="text-base font-bold text-(--color-text)">Título</h2>
      <button type="button" data-action="click->modal#close"
              class="p-1.5 rounded-lg text-(--color-text-muted) hover:bg-(--color-surface-raised)">
        <i class="ph ph-x text-sm"></i>
      </button>
    </div>

    <%# Body — scrollable on mobile (max-height: 92vh applied by .app-modal) %>
    <div class="px-6 py-5 overflow-y-auto">
      <%# ... form / content ... %>
    </div>
  </dialog>
</turbo-frame>
```

Rules:
- Always include `.app-modal-handle` — invisible on desktop, shows the drag-bar affordance on mobile.
- Width override: use `md:max-w-*` utility on the `<dialog>` (e.g. `md:max-w-lg`); mobile is always full-width.
- Open with: `<%= link_to "Edit", edit_path(record), data: { turbo_frame: "modal" } %>`
- Forms inside modal that should navigate after submit must use `data: { turbo_frame: "_top" }`.
- The `modal` Stimulus controller (`modal_controller.js`) auto-calls `showModal()`, handles backdrop click, ESC, and clears the frame on close.

---

## Auth Guards (ApplicationController)

Use these `before_action` helpers in controllers:

```ruby
authenticate_user!      # Devise — redirect to login
ensure_company!         # Redirect to onboarding if no company
require_owner!          # Only role: :owner can proceed
require_campaigns!      # Only if company.feature_campanhas? — see Feature Flags
```

---

## Key Models

```
User          belongs_to :company (optional)
              enum :role — owner | admin | member
              Devise (email + password)
              scope :onboarding_completed? (boolean column)

Company       has_many :users, :chips, :campaigns, :clients
              has_one_attached :profile_picture
              boolean :feature_campanhas (feature flag — see below)

Chip          belongs_to :company
              enum :waha_status — pending | stopped | starting | scan_qr_code | working | failed
              chip.working? → true when connected

Campaign      belongs_to :company, :chip
              enum :status — draft | active | paused | finished
              enum :recurrence_pattern — monthly
              jsonb :template → { "body" => "Olá {{nome}}! ..." }

CampaignClient  belongs_to :campaign, :client
                decimal :amount; date :next_due_date; datetime :inactivated_at
                soft_delete! method sets inactivated_at

Client        belongs_to :company
              string :name, :phone_number

Installment   belongs_to :campaign_client
              decimal :amount; date :due_date; string :status

Notification  polymorphic :sender (Chip)
              belongs_to :campaign_client; belongs_to :installment (optional)
```

---

## Feature Flags

There is one feature flag: `company.feature_campanhas?` (boolean column `feature_campanhas`, default: `false`).

**When `feature_campanhas` is `false` (default):**
- Campaigns, CampaignClients, and Chips routes are blocked by `require_campaigns!`
- Nav hides "Campanhas" and "Chips" items
- Settings shows "Cobrança" subitem (`settings_cobranca_path`) for simpler billing config

**When `feature_campanhas` is `true`:**
- Full campaigns/chips UI is available
- "Cobrança" settings subitem is hidden (campaigns handle it)

---

## WhatsApp Integration (Waha)

Waha is a self-hosted WhatsApp API. Use the `Waha::Client` service:

```ruby
waha = Waha::Client.new(session: chip.waha_session)

waha.sessions.me              # → { "id" => "5511...@c.us", "pushName" => "..." }
waha.sessions.start(...)      # Start/create a session
waha.contacts.profile_picture(contact_id: chat_id)  # → { "profilePictureURL" => "..." }
waha.messages.send_text(...)  # Send a message
```

`ApiRequest#get` returns a parsed Hash for JSON responses. No need to call `JSON.parse`.

Webhook endpoint: `POST /webhook/waha` → `Webhook::WahaController#create`

---

## Phone Number Inputs

Library: `intl-tel-input@28.1.0` via CDN (not imported from npm). Load on any page that uses it:

```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/intl-tel-input@28.1.0/dist/css/intlTelInput.css">
<script src="https://cdn.jsdelivr.net/npm/intl-tel-input@28.1.0/dist/js/intlTelInputWithUtils.min.js"></script>
```

Stimulus controller: `phone-input` (`phone_input_controller.js`). Always use a visible + hidden pair:

```html
<%# Visible display input — NOT submitted %>
<input type="tel" data-phone-input-target="input" ...>

<%# Hidden input — submitted to controller, always E.164 (e.g. +5511999999999) %>
<%= f.hidden_field :phone_number, data: { "phone-input-target": "hidden" } %>
```

Config: `initialCountry: "br"`, `strictMode: true`. The hidden input is synced on every keystroke and country change. Submit buttons should fire `phone-input#syncHidden` for a final safety sync.

The `add_client_controller.js` has its own inline `#initPhoneInput()` method that follows the same pattern — no need to nest `phone-input` inside `add-client`.

---

## Amount / Currency Inputs

No external library — custom Stimulus controller `amount-input` (`amount_input_controller.js`). Always use a display + hidden pair:

```html
<%# Visible input — NOT submitted. User types digits only; last 2 = decimal places. %>
<input type="text" inputmode="numeric" data-amount-input-target="display"
       data-action="input->amount-input#format" placeholder="0,00">

<%# Hidden input — submitted. Stores decimal value in reais (e.g. "150.00"). %>
<input type="hidden" data-amount-input-target="hidden" name="campaign_client[amount]">
```

How it works: user types `15000` → display shows `150,00` → hidden sends `150.00`. The model column is `decimal` storing reais (e.g. `150.00`), not integer cents. Do NOT store amounts as integer cents.

---

## Background Jobs

All jobs inherit `ApplicationJob` and use `queue_as :default`:

```ruby
class MyJob < ApplicationJob
  queue_as :default
  def perform(arg)
    # ...
  end
end
```

Existing jobs: `ChipDisconnectCheckJob`, `FetchChipProfilePictureJob`.

---

## Email

```ruby
# Mailer default (application_mailer.rb)
default from: "Cobrança em Dia <no-reply@cobrancaemdia.com.br>"

# Dev: opens in browser via letter_opener
# Prod: Resend SMTP — credentials.dig(:resend, :api_key)
```

All mailer views use the shared layout `app/views/layouts/mailer.html.erb` (navy header, white card, grey footer).

---

## Real-time (ActionCable)

Broadcast from model callbacks:

```ruby
after_update_commit :broadcast_waha_status_change, if: :saved_change_to_waha_status?

def broadcast_waha_status_change
  ActionCable.server.broadcast("chip_status_#{id}", { status: waha_status })
end
```

---

## Onboarding Flow

Three steps, enforced by `check_onboarding` in `ApplicationController`:
1. `onboarding#step1` — create Company
2. `onboarding#step2` — connect WhatsApp chip (Waha QR / pairing code)
3. `onboarding#step3` — invite first client

`user.onboarding_completed?` gates all authenticated pages.

---

## Production

- Domain: `cobrancaemdia.com.br`
- Deployment: Kamal (`config/deploy.yml`)
- Docker: `web`, `worker`, `waha` services share Tailscale network (`network_mode: service:tailscale`)
- OG image: `public/og-image.png` (1200×630px) — always reference with hardcoded production URL in meta tags, never `request.base_url`

---

## Code Style

- No over-engineering. Only add what's needed.
- Don't add docstrings or comments to code you didn't change.
- Don't add error handling for impossible scenarios.
- Use Rails conventions: scopes, enums, callbacks, concerns.
- Prefer `redirect_to ..., alert:` over raising exceptions for auth failures.
- All strings facing users are in **Portuguese (pt-BR)**.
