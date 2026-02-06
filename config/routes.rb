Rails.application.routes.draw do
  constraints subdomain: 'admin' do
    ActiveAdmin.routes(self)
    get "/login", to: "sessions#new" # , constraints: { subdomain: :admin }
    post "/login", to: "sessions#create" # , constraints: { subdomain: :admin }

    post "/passkeys/create_options", to: "passkeys#create_options"
    post "/passkeys/create", to: "passkeys#create"
    delete "/passkeys/:id", to: "passkeys#destroy", as: :passkey
  end

  post "/passkeys/authenticate_options", to: "passkeys#authenticate_options"
  post "/passkeys/authenticate", to: "passkeys#authenticate"

  get "podcasts/:id", to: "libraries#podcast", as: :podcasts
  resources :media_items, only: [] do
    get '/video', action: "video"
    get '/audio', action: "audio"
    #get '/article', action: "article"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
