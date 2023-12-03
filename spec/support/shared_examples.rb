# frozen_string_literal: true

RSpec.shared_examples 'rejects the request' do |status:, code:|
  it "rejects the request -> #{status}: #{code}" do
    make_request
    expect(response).to be_json_error_response(status, code)
    additional_expectations
  end
end

RSpec.shared_examples 'rejects the request with validation error' do |attribute:, error:|
  it "rejects the request with validation error '#{error}' for attribute '#{attribute}'" do
    make_request
    expect(response).to be_json_error_response(400, 'DeserializationError.Validation')
    expect(response_error).to be_validation_error(attribute, error)
    additional_expectations
  end
end

RSpec.shared_examples 'responds successfully' do |status: 200|
  it 'responds successfully' do
    expect(self.respond_to?(:expected_result)).to be(false)
    make_request
    expect(response).to be_json_success_response(status)
    additional_expectations
  end
end

RSpec.shared_examples 'responds successfully with no body' do |status: 204|
  it 'responds successfully' do
    make_request
    expect(response).to be_response_with_status(status)
    additional_expectations
  end
end

RSpec.shared_examples 'responds successfully with result' do |status: 200|
  it 'responds successfully with result' do
    make_request
    expect(response).to be_json_success_response(status)
    expect(response_data).to expected_result
    additional_expectations
  end
end

RSpec.shared_examples 'requires login' do |code: 'Auth.NotLoggedIn', status: 401|
  context 'when not logged in' do
    let(:request_headers) { super().except('Authorization') }
    include_examples 'rejects the request', status:, code:
  end
end

RSpec.shared_examples 'rejects unprivileged auth' do |status: default_rejection_status, code: default_rejection_code|
  context 'with a new unprivileged user' do
    let(:request_headers) { new_auth_without_abilities(create(:user)) }
    include_examples 'rejects the request', status:, code:
  end
end

# Shared examples testing admin access to a resource. Relies on a conventional
# context:
# * the resource is restricted to the `organization` and `brand` inherited from
#   the environment.
# * there is an `admin` and `global_admin` in the environment, with the
#  appropriate ability to use the resource specified in `admin_abilities`

RSpec.shared_examples 'responds successfully with admin auth' do |abilities: nil|
  let(:request_headers) { new_auth_with_abilities(admin) }
  let(:admin_abilities) { abilities } if abilities

  include_examples 'responds successfully with result'
end

RSpec.shared_examples 'rejects admin auth' do |status: default_rejection_status, code: default_rejection_code, abilities: nil|
  let(:request_headers) { new_auth_with_abilities(admin) }
  let(:admin_abilities) { abilities } if abilities

  include_examples 'rejects the request', status:, code:
end
