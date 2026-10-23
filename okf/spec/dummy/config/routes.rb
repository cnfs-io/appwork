Rails.application.routes.draw do
  mount Appwork::Okf::Engine => "/okf"
end
