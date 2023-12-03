# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::UsersController', type: :request do
  let_factory(:user)

  # The demo app doesn't meaningfully have user abilities
  RSpec.shared_examples 'with admin abilities' do |abilities|
    before do
      allow_any_instance_of(User).to receive(:effective_permissions) do |user|
        if user.id == admin.id
          abilities
        else
          []
        end
      end
    end
  end

  describe 'GET /api/users' do
    let(:request_method) { :get }
    let(:request_url) { api_users_url }

    let(:expected_result) { all(be_a_viewmodel_response_of(UserView)) }

    it_behaves_like 'requires login', status: 403, code: 'AccessControl.Forbidden'
    it_behaves_like 'rejects unprivileged auth', status: 403, code: 'AccessControl.Forbidden'

    context 'as an administrator' do
      let_factory(:admin, :user)
      include_examples 'with admin abilities', [Ability::VIEW_USERS]

      it_behaves_like 'responds successfully with admin auth'
    end
  end

  describe 'GET /api/user/:id' do
    let(:request_method) { :get }
    let(:request_url) { api_user_url(id: user.id) }

    let(:expected_result) { be_a_viewmodel_response_of(UserView) }

    it_behaves_like 'requires login', status: 403, code: 'AccessControl.Forbidden'
    it_behaves_like 'rejects unprivileged auth', status: 403, code: 'AccessControl.Forbidden'

    context 'as the same user' do
      let(:request_headers) { new_auth_with_abilities(user) }
      it_behaves_like 'responds successfully with result'
    end

    context 'as an admin' do
      let_factory(:admin, :user)
      include_examples 'with admin abilities', [Ability::VIEW_USERS]

      before do
        allow(user).to receive(:effective_permissions).and_return([Ability::VIEW_USERS])
      end

      it_behaves_like 'responds successfully with admin auth'
    end
  end
end
