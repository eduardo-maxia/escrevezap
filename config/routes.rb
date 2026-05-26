Rails.application.routes.draw do
  root "pages#home"
  get "privacidade", to: "pages#privacidade", as: :privacidade
  get "termos",      to: "pages#termos",      as: :termos
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "manifest"       => "rails/pwa#manifest",     as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "offline"        => "pwa#offline",             as: :pwa_offline
  
  mount SolidQueueDashboard::Engine, at: "/jobs"

  scope "/app" do
    devise_for :users,
               controllers: {
                 sessions:            "users/sessions",
                 omniauth_callbacks:  "users/omniauth_callbacks"
               },
               skip: [:passwords, :registrations]

    devise_scope :user do
      get  "users/verify",  to: "users/sessions#verify",  as: :verify_otp
      post "users/verify",  to: "users/sessions#confirm", as: :confirm_otp
      post "users/resend",  to: "users/sessions#resend",  as: :resend_otp
    end

    authenticated :user do
      root "dashboard#index", as: :authenticated_root
    end

    scope :onboarding do
      get  "step1",    to: "onboarding#step1",        as: :onboarding_step1
      post "step1",    to: "onboarding#create_step1"
      get  "step2",    to: "onboarding#step2",        as: :onboarding_step2
      post "step2",    to: "onboarding#create_step2"
      post "step2/start_session",        to: "onboarding#start_waha_session",        as: :onboarding_start_waha_session
      post "step2/request_pairing_code", to: "onboarding#request_waha_pairing_code", as: :onboarding_request_waha_pairing_code
      get  "step2/qr",                   to: "onboarding#waha_qr_code",              as: :onboarding_waha_qr_code
      get  "step2/chip_status",          to: "onboarding#chip_status",               as: :onboarding_chip_status
      get  "step3",    to: "onboarding#step3",        as: :onboarding_step3
      post "step3",    to: "onboarding#create_step3"
      get  "step3/check_whatsapp",       to: "onboarding#check_whatsapp_exists",     as: :onboarding_check_whatsapp
      get  "step4",    to: "onboarding#step4",        as: :onboarding_step4
      post "skip",     to: "onboarding#skip",         as: :skip_onboarding
      post "complete", to: "onboarding#complete",     as: :complete_onboarding
    end

    resources :users, only: [:index, :new, :create, :destroy], path: "membros" do
      member { post :resend_invite }
    end

    get   "settings",          to: "settings#show",          as: :settings
    get   "settings/empresa",  to: "settings#empresa",       as: :settings_empresa
    patch "settings/empresa",  to: "settings#update_empresa"
    get   "settings/perfil",              to: "settings#perfil",              as: :settings_perfil
    patch "settings/perfil",              to: "settings#update_perfil"
    post  "settings/perfil/verify_email", to: "settings#verify_email_change",  as: :settings_verify_email_change
    post  "settings/perfil/resend_email", to: "settings#resend_email_change",  as: :settings_resend_email_change
    post  "settings/perfil/cancel_email", to: "settings#cancel_email_change",  as: :settings_cancel_email_change
    get   "settings/senha",    to: "settings#senha",         as: :settings_senha
    patch "settings/senha",    to: "settings#update_senha"
    get   "settings/cobranca", to: "settings#cobranca",      as: :settings_cobranca
    patch "settings/cobranca", to: "settings#update_cobranca"
    get   "settings/notifications", to: "settings#notifications", as: :settings_notifications
    patch "settings/notifications", to: "settings#update_notifications"

    post   "push_subscriptions",          to: "push_subscriptions#create",  as: :push_subscriptions
    delete "push_subscriptions",          to: "push_subscriptions#destroy"

    resources :chips, only: [:index, :new, :create, :show, :destroy] do
      member do
        post :start_session
        post :request_pairing_code
        get  :qr_code
        get  :status
        post :disconnect
      end
    end

    resources :clients, except: [:edit] do
      collection { get :search }
    end

    resources :installments, only: [:edit, :update]

    get  "share-receipt",        to: "share_receipts#new",     as: :share_receipt
    post "share-receipt",        to: "share_receipts#receive"
    post "share-receipt/attach", to: "share_receipts#attach",  as: :attach_share_receipt

    resources :campaigns, except: [:edit] do
      resources :campaign_clients, only: [:show, :create, :update, :destroy], shallow: true
    end
  end

  namespace :webhook do
    resource :waha, only: [:create], controller: :waha
  end

  # Catch-all — redirects any unknown path to a sensible page instead of 404.
  # Must be the LAST route declaration.
  # Exclude /rails/* so Active Storage, health check, etc. are not swallowed.
  match "*unmatched", to: "application#route_not_found", via: :all,
        constraints: ->(req) { !req.path.start_with?("/rails/") }
end
