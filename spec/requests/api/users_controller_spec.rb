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

  RSpec.shared_examples 'with admin auth' do |abilities|
    let_factory(:admin, :user)
    let(:request_headers) { new_auth_with_abilities(admin) }
    include_examples 'with admin abilities', abilities
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

  CSV_ABILITIES = [
    Ability::VIEW_USERS, Ability::EDIT_USERS,
    Ability::DOWNLOAD_CSV, Ability::MAKE_BACKGROUND_REQUEST,
  ].freeze

  describe 'GET /api/users/csv' do
    include CsvHelper

    let(:request_url) { csv_api_users_url }

    context 'as an admin' do
      include_examples 'with admin auth', CSV_ABILITIES

      let(:request_params) { { timezone: } }
      let(:timezone) { 'America/Los_Angeles' }

      let(:expected_truncated) { false }
      let(:expected_count) { 2 }
      let(:expected_rows) do
        all(include('id' => kind_of(String)))
      end

      it_behaves_like 'responds successfully with CSV result'

      context 'with a limit' do
        let(:request_params) { super().merge(page_size: 1) }
        let(:expected_count) { 1 }
        let(:expected_truncated) { true }
        it_behaves_like 'responds successfully with CSV result'
      end

      context 'with a request filter' do
        let(:target) { user }
        let(:request_params) { super().merge(id: target.id) }
        let(:expected_count) { 1 }
        let(:expected_rows) do
          contain_exactly(include('id' => target.id))
        end
        it_behaves_like 'responds successfully with CSV result'
      end

      context 'with custom columns' do
        let(:columns) { ['email', 'id'] }
        let(:request_params) { super().merge(columns:) }

        let(:expected_rows) do
          all(have_attributes(keys: columns))
        end

        it_behaves_like 'responds successfully with CSV result'
      end
    end
  end

  describe 'POST /api/users/csv' do
    include CsvHelper

    let(:request_url) { csv_api_users_url }

    context 'as an admin' do
      include_examples 'with admin auth', CSV_ABILITIES

      let(:request_method) { :post }
      let(:request_params) { { timezone:, csv: upload_csv } }
      # prevent the request params from being json'd
      let(:request_encoding) { nil }

      let(:timezone) { 'America/Los_Angeles' }
      let(:upload_data) { {} }

      let(:upload_csv) do
        hashes = Array.wrap(upload_data)
        csvfile = Tempfile.new

        headers = hashes.first.keys
        csv = CSV.new(csvfile.to_io, headers:, write_headers: true)

        hashes.each do |hash|
          expect(hash.keys).to eq(headers)
          csv << hash.values
        end
        csvfile.rewind

        Rack::Test::UploadedFile.new(
          csvfile, 'text/csv', original_filename: 'upload.csv')
      end

      context 'modifying a user' do
        let(:membership) { user }
        let(:new_name) { 'User' }
        let(:upload_data) do
          { id: user.id, name: new_name }
        end

        let(:expected_truncated) { false }
        let(:expected_count) { 1 }
        let(:expected_rows) do
          contain_exactly(include('id' => user.id, 'name' => new_name))
        end

        it_behaves_like 'responds successfully with CSV result' do
          local_expectations do
            expect(user.reload.name).to eq(new_name)
          end
        end

        context 'with invalid data' do
          let(:new_name) { 'x' * 21 }
          include_examples 'rejects the request', status: 400, code: 'CSV.Invalid'
        end

        context 'backgrounding' do
          # Mock passing the upload to the job via s3
          around(:each) do |example|
            stub_aws(simulated_uploads_aws_responses) do
              example.run
            end
          end

          context 'successfully' do
            include_examples 'with stubbed csv upload'

            let(:expected_result) do
              be_a_viewmodel_response_of(CsvResultView, id: nil, rows: expected_count, truncated: expected_truncated, url: stub_url)
            end

            include_examples 'runs the request successfully in the background with result'
          end

          context 'with invalid data' do
            let(:new_name) { 'y' * 21 }
            include_examples 'runs the request in the background with error', status: 400, code: 'CSV.Invalid'
          end
        end

        context 'forcing a column' do
          let(:upload_data) { super().except(:interface_language) }
          let(:request_params) { super().merge(forced_columns: { 'interface_language' => Language::IT.enum_constant }) }

          it_behaves_like 'responds successfully with CSV result' do
            local_expectations do
              expect(user.reload.interface_language).to eq(Language::IT)
            end
          end
        end
      end
    end
  end

  describe 'GET /api/users/csv_template' do
    include CsvHelper

    let(:request_url) { csv_template_api_users_url }

    context 'as an admin' do
      include_examples 'with admin auth', CSV_ABILITIES

      it 'returns a csv template' do
        make_request
        expect(response).to be_successful
        expect(response.content_type).to eq('text/csv')
        body = response.body
        consume_string_bom!(body)
        csv = CSV.new(body, headers: true, skip_lines: /^"?#/)
        expect(csv.count).to eq(0)
        expect(csv.headers).to eq(UserCsv.new.default_template_columns(request_filters: nil))
      end

      context 'with custom columns' do
        let(:columns) { ['name', 'id'] }
        let(:request_params) { { columns: } }

        it 'returns those columns in that order' do
          make_request
          expect(response).to be_successful
          body = response.body
          consume_string_bom!(body)
          csv = CSV.new(body, headers: true, skip_lines: /^"?#/)
          expect(csv.count).to eq(0)
          expect(csv.headers).to eq(columns)
        end
      end
    end
  end
end
