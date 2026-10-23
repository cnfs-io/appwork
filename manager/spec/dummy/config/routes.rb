Rails.application.routes.draw do
  mount Appwork::Manager::Engine => "/manager"
end
