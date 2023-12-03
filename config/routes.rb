# frozen_string_literal: true

Rails.application.routes.draw do
  resource :presence, only: :show, controller: :presence

  namespace :api, defaults: { route_viewmodel: nil } do
    arvm_resources :users

    resources :types, only: [:index, :show], controller: :'types/enums', constraints: { id: /.+/ }
    resources :schemas, only: [:index, :show], controller: :'schemas/schemas', constraints: { id: /.+/ }
  end
end
