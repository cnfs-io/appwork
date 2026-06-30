Chorus::Engine.routes.draw do
  resources :organizations
  resources :strategies
  resources :goals
  resources :roles
  resources :agents
  resources :workspaces
  resources :projects
  resources :artifacts
  resources :issues

  root to: "organizations#index"
end
