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
  resources :children, only: %i[ index new create edit update ]
  resources :daycares, only: %i[ index show ]
end
