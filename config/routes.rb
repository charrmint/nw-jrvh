Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "pages#welcome"

  # Authentication (existing)
  get "sign-up", to: "registrations#new", as: :sign_up
  resources :registrations, only: :create

  get "login", to: "sessions#new", as: :login
  resource :session, only: %i[ create destroy ]

  resources :passwords, param: :token, only: %i[ new create edit update ]

  # Backend resources
  resources :children, only: %i[ index new create edit update ] do
    # Reusable child profile screens (ProfilesController)
    resource :profile, only: %i[ show edit update ]
  end
  resources :general_applications, only: %i[ index new create edit update ]
  resource :ymca_connection, only: %i[ create update destroy ]
  get "gmail/connect", to: "gmail_connections#new", as: :connect_gmail
  get "gmail/oauth/callback", to: "gmail_connections#create", as: :gmail_oauth_callback
  delete "gmail/connection", to: "gmail_connections#destroy", as: :gmail_connection
  resources :daycares, only: %i[ index show ]
  resources :daycares, only: [] do
    resource :browser_application, only: :create
    resource :ymca_experiment, only: :create
    resource :beyond_care_experiment, only: :create
    resource :parkcrest_application, only: :create
  end

  # Front-end-only screens
  get "home", to: "home#show", as: :home
  get "settings", to: "settings#show", as: :settings
  resources :daycare_applications, path: "applications", only: %i[ index show ]
end
