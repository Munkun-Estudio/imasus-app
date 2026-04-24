Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#index"

  resources :materials, only: [ :index, :show ], param: :slug do
    member do
      get :preview
    end
  end
  resources :training, only: :index
  get "training/:slug/:section", to: "training#show", as: :training_show,
      constraints: { slug: /[a-z0-9-]+/, section: /[a-z0-9-]+/ }
  resources :workshops, only: [ :index, :show ], param: :slug do
    member do
      get :agenda
    end
    resources :invitations, only: [ :new, :create ], controller: "workshop_invitations"
  end
  resources :glossary_terms, path: "glossary", param: :slug do
    member do
      get :delete_confirmation
      get :popover
    end
  end
  resources :challenges, only: [ :index, :edit, :update ], param: :code do
    member do
      get :preview
    end
  end

  resources :projects do
    resources :memberships, only: [ :new, :create, :destroy ], controller: "project_memberships"
    resources :log_entries, only: [ :index, :new, :create, :destroy ] do
      member { get :delete_confirmation }
    end
  end

  resource :session, only: [ :new, :create, :destroy ]

  get   "password_reset/new",  to: "password_resets#new",    as: :new_password_reset
  post  "password_reset",      to: "password_resets#create", as: :password_resets
  get   "password_resets/:token/edit", to: "password_resets#edit",   as: :edit_password_reset
  patch "password_resets/:token",      to: "password_resets#update", as: :password_reset

  namespace :admin do
    root to: "dashboard#index"
    resources :facilitators, only: [ :index, :new, :create ]
  end

  get   "facilitator_invitations/:token/edit", to: "facilitator_invitations#edit",   as: :edit_facilitator_invitation
  patch "facilitator_invitations/:token",      to: "facilitator_invitations#update", as: :facilitator_invitation

  get   "participant_invitations/:token/edit", to: "participant_invitations#edit",   as: :edit_participant_invitation
  patch "participant_invitations/:token",      to: "participant_invitations#update", as: :participant_invitation
end
