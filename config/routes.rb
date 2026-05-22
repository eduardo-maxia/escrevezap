Rails.application.routes.draw do
  root "pages#home"
  get "up" => "rails/health#show", as: :rails_health_check
  
  mount SolidQueueDashboard::Engine, at: "/jobs"

  scope "/app" do
    devise_for :users

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
      post "skip",     to: "onboarding#skip",         as: :skip_onboarding
      post "complete", to: "onboarding#complete",     as: :complete_onboarding
    end

    resources :users, only: [:index, :new, :create, :destroy], path: "membros"

    get   "settings",          to: "settings#show",          as: :settings
    get   "settings/empresa",  to: "settings#empresa",       as: :settings_empresa
    patch "settings/empresa",  to: "settings#update_empresa"
    get   "settings/perfil",   to: "settings#perfil",        as: :settings_perfil
    patch "settings/perfil",   to: "settings#update_perfil"
    get   "settings/senha",    to: "settings#senha",         as: :settings_senha
    patch "settings/senha",    to: "settings#update_senha"
    get   "settings/cobranca", to: "settings#cobranca",      as: :settings_cobranca
    patch "settings/cobranca", to: "settings#update_cobranca"

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

    resources :campaigns, except: [:edit] do
      resources :campaign_clients, only: [:show, :create, :update, :destroy], shallow: true
    end
  end

  namespace :webhook do
    resource :waha, only: [:create], controller: :waha
  end
end
