# frozen_string_literal: true

Rails.application.routes.draw do
  resource :presence, only: :show, controller: :presence

  namespace :api, defaults: { route_viewmodel: nil } do
    arvm_resources :users do
      collection do
        get 'csv', action: :csv_index
        get 'csv/template', action: :csv_template
        post 'csv', action: :csv_update
      end
    end

    arvm_resources :background_job_progresses, only: :show

    resources :types, only: [:index, :show], controller: :'types/enums', constraints: { id: /.+/ }
    resources :schemas, only: [:index, :show], controller: :'schemas/schemas', constraints: { id: /.+/ }
  end
end
