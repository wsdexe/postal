# frozen_string_literal: true

Rails.application.routes.draw do
  # Legacy API Routes
  match "/api/v1/send/message" => "legacy_api/send#message", via: [:get, :post, :patch, :put]
  match "/api/v1/send/raw" => "legacy_api/send#raw", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/message" => "legacy_api/messages#message", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/deliveries" => "legacy_api/messages#deliveries", via: [:get, :post, :patch, :put]

  # Management API v2 Routes
  namespace :management_api, path: "api/v2" do
    # System endpoints
    get "system/info" => "system#info"
    get "system/health" => "system#health"
    get "system/stats" => "system#stats"
    get "system/ip_pools" => "system#ip_pools"
    post "system/ip_pools" => "system#create_ip_pool"
    delete "system/ip_pools/:id" => "system#destroy_ip_pool"
    post "system/ip_pools/:id/ip_addresses" => "system#create_ip_address"
    delete "system/ip_addresses/:id" => "system#destroy_ip_address"
    post "system/ip_addresses/:id/verify" => "system#verify_ip_address"

    # Users (global)
    resources :users do
      member do
        post :make_admin
        post :revoke_admin
      end
    end

    # Servers (global list)
    get "servers" => "servers#index_all"

    # Organizations
    resources :organizations do
      member do
        post :suspend
        post :unsuspend
      end

      # Organization users
      resources :users, controller: "organization_users", only: [:index, :show, :create, :update, :destroy]
      post "transfer_ownership" => "organization_users#transfer_ownership"

      # Organization domains
      resources :domains, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :verify
          post :check_dns
        end
      end

      # Servers within organization
      resources :servers do
        member do
          post :suspend
          post :unsuspend
          get :stats
        end

        # Server domains
        resources :domains, only: [:index, :show, :create, :update, :destroy] do
          member do
            post :verify
            post :check_dns
          end
        end

        # Credentials
        resources :credentials

        # Routes
        resources :routes

        # Webhooks
        resources :webhooks

        # Endpoints
        get "endpoints" => "endpoints#index"
        post "endpoints/http" => "endpoints#create_http"
        patch "endpoints/http/:id" => "endpoints#update_http"
        delete "endpoints/http/:id" => "endpoints#destroy_http"
        post "endpoints/smtp" => "endpoints#create_smtp"
        patch "endpoints/smtp/:id" => "endpoints#update_smtp"
        delete "endpoints/smtp/:id" => "endpoints#destroy_smtp"
        post "endpoints/address" => "endpoints#create_address"
        patch "endpoints/address/:id" => "endpoints#update_address"
        delete "endpoints/address/:id" => "endpoints#destroy_address"
      end
    end
  end

  scope "org/:org_permalink", as: "organization" do
    resources :domains, only: [:index, :new, :create, :destroy] do
      match :verify, on: :member, via: [:get, :post]
      get :setup, on: :member
      post :check, on: :member
    end
    resources :servers, except: [:index] do
      resources :domains, only: [:index, :new, :create, :destroy] do
        match :verify, on: :member, via: [:get, :post]
        get :setup, on: :member
        post :check, on: :member
      end
      resources :track_domains do
        post :toggle_ssl, on: :member
        post :check, on: :member
      end
      resources :credentials
      resources :routes
      resources :http_endpoints
      resources :smtp_endpoints
      resources :address_endpoints
      resources :ip_pool_rules
      resources :messages do
        get :incoming, on: :collection
        get :outgoing, on: :collection
        get :held, on: :collection
        get :activity, on: :member
        get :plain, on: :member
        get :html, on: :member
        get :html_raw, on: :member
        get :attachments, on: :member
        get :headers, on: :member
        get :attachment, on: :member
        get :download, on: :member
        get :spam_checks, on: :member
        post :retry, on: :member
        post :cancel_hold, on: :member
        get :suppressions, on: :collection
        delete :remove_from_queue, on: :member
        get :deliveries, on: :member
      end
      resources :webhooks do
        get :history, on: :collection
        get "history/:uuid", on: :collection, action: "history_request", as: "history_request"
      end
      get :limits, on: :member
      get :retention, on: :member
      get :queue, on: :member
      get :spam, on: :member
      get :delete, on: :member
      get "help/outgoing" => "help#outgoing"
      get "help/incoming" => "help#incoming"
      get :advanced, on: :member
      post :suspend, on: :member
      post :unsuspend, on: :member
    end

    resources :ip_pool_rules
    resources :ip_pools, controller: "organization_ip_pools" do
      put :assignments, on: :collection
    end
    root "servers#index"
    get "settings" => "organizations#edit"
    patch "settings" => "organizations#update"
    get "delete" => "organizations#delete"
    delete "delete" => "organizations#destroy"
  end

  resources :organizations, except: [:index]
  resources :users
  resources :ip_pools do
    resources :ip_addresses do
      post :verify, on: :member
    end
  end

  get "settings" => "user#edit"
  patch "settings" => "user#update"
  post "persist" => "sessions#persist"

  get "login" => "sessions#new"
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy"
  match "login/reset" => "sessions#begin_password_reset", :via => [:get, :post]
  match "login/reset/:token" => "sessions#finish_password_reset", :via => [:get, :post]

  if Postal::Config.oidc.enabled?
    get "auth/oidc/callback", to: "sessions#create_from_oidc"
  end

  get ".well-known/jwks.json" => "well_known#jwks"

  get "ip" => "sessions#ip"

  root "organizations#index"
end
