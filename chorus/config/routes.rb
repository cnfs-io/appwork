Chorus::Engine.routes.draw do
  resources :strategies
  resources :goals
  resources :roles
  resources :agents
  resources :workspaces
  resources :projects
  resources :artifacts
  resources :issues

  root to: "strategies#index"
end
