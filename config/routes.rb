Rails.application.routes.draw do
  root "pages#home"
  get  "precos",             to: "pages#pricing",        as: :pricing
  get  "privacidade",        to: "pages#privacidade",    as: :privacidade
  get  "termos",             to: "pages#termos",         as: :termos
  post "testar-transcricao", to: "pages#try_transcribe", as: :try_transcribe

  # ── SEO ────────────────────────────────────────────────────────────
  # Dynamic robots.txt + sitemap.xml + programmatic SEO landings.
  get "robots.txt",  to: "seo#robots",  defaults: { format: "text" }
  get "sitemap.xml", to: "seo#sitemap", defaults: { format: "xml" }

  # Programmatic SEO landings — slug must exist in SeoPagesController::PAGES.
  # Regex kept inline to avoid autoload coupling at route-load time.
  get "/:slug", to: "seo_pages#show", as: :seo_page,
                constraints: { slug: /transcrever-audio-whatsapp|converter-audio-em-texto|responder-audio-whatsapp|audio-whatsapp-texto/ }

  get  "up"             => "rails/health#show",        as: :rails_health_check
  get  "manifest"       => "rails/pwa#manifest",       as: :pwa_manifest
  get  "service-worker" => "pwa#service_worker", as: :pwa_service_worker
  get  "offline"        => "pwa#offline",               as: :pwa_offline

  authenticate :user, ->(u) { u.admin? } do
    mount SolidQueueDashboard::Engine, at: "/jobs"
  end

  scope "/app" do
    devise_for :users,
               controllers: {
                 sessions:           "users/sessions",
                 omniauth_callbacks: "users/omniauth_callbacks"
               },
               skip: [:passwords, :registrations]

    devise_scope :user do
      get    "entrar",                    to: "users/sessions#new",        as: :new_user_session
      post   "entrar",                    to: "users/sessions#create"
      delete "sair",                      to: "users/sessions#destroy",    as: :destroy_user_session
      get    "entrar/verificar/:token",   to: "users/sessions#magic_link", as: :magic_link
      get    "entrar/confirmar",          to: "users/sessions#check_inbox", as: :check_inbox
    end

    authenticated :user do
      root "dashboard#index", as: :authenticated_root

      # Onboarding (first-time WhatsApp connection — auth layout, no app chrome)
      get  "conectar",          to: "onboarding#show",             as: :onboarding
      post "conectar/reconectar", to: "onboarding#reconnect",      as: :onboarding_reconnect
      post "conectar/pular",    to: "onboarding#skip_connection",  as: :onboarding_skip_connection

      # WhatsApp connection
      resource  :waha_session,        only: [:show, :create, :destroy], as: :app_waha_session do
        member do
          get  :qr
          get  :status
          post :pairing_code
          post :reconnect
        end
      end

      # Contacts to monitor for transcription
      resources :monitored_contacts, only: [:index, :new, :create, :edit, :update, :destroy] do
        collection do
          get  :whatsapp_contacts
          post :switch_mode
        end
      end

      # User profile
      resource  :profile, controller: "profile", only: [:show, :update] do
        patch :update_email, on: :member
      end


      # Billing / upgrade flow
      scope "/assinatura" do
        get    "",               to: "billing#show",         as: :billing
        post   "upgrade",        to: "billing#upgrade",       as: :billing_upgrade
        post   "trocar-plano",            to: "billing#change_plan",         as: :billing_change_plan
        get    "trocar-plano/confirmar",    to: "billing#change_plan_confirm",  as: :billing_change_plan_confirm
        get    "cancelar",                 to: "billing#cancel_confirm",       as: :billing_cancel_confirm
        delete "cancelar",       to: "billing#cancel",        as: :billing_cancel
        get    "obrigado",       to: "billing#success",       as: :billing_success
      end
    end
  end

  namespace :admin do
    root "dashboard#index"
    resources :users,                only: [:index, :show]
    resources :transcriptions,       only: [:index, :show]
    resources :transcription_errors, only: [:index]
    resources :waha_sessions,        only: [:edit, :update]
  end

  namespace :webhook do
    resource :waha,       only: [:create], controller: :waha
    resource :abacate_pay, only: [:create], controller: :abacate_pay
  end

  # Catch-all 404 — must be the LAST route.
  # Excludes /rails/*, /assets/*, and static files served by the web server.
  match "*unmatched", to: "errors#not_found", via: :all,
        constraints: ->(req) {
          !req.path.start_with?("/rails/") &&
          !req.path.start_with?("/assets/") &&
          !req.path.include?("/auth/") &&
          req.path !~ /\.(png|jpg|jpeg|gif|svg|ico|webp|css|js|map|woff2?|ttf|eot)(\z|\?)/i
        }
end
