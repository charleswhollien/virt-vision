Rails.application.routes.draw do
  # Authentication
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Dashboard (root)
  root "dashboard#show"

  # Resources
  resources :hosts do
    member do
      post :sync
      get :test_connection
    end
  end

  resources :vms do
    member do
      post :start
      post :shutdown
      post :reboot
      post :pause
      post :resume
      post :destroy
      get :console
    end
  end

  resources :alerts do
    member do
      post :toggle
    end
  end

  # User management
  resources :users

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
