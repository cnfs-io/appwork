Rails.application.routes.draw do
  mount Chatter::Engine => "/chatter"
end
