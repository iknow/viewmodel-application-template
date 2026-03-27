# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FrontendRoutes do
  let(:base_url) { 'http://baseurl.com' }

  subject { FrontendRoutes.new(base_url) }

  context 'with a dummy route' do
    before(:context) do
      FrontendRoutes.route :test_route, '/users/:user_id/widgets/:widget_id',
                           query_params: [:token, :magic],
                           required_params: [:token]
    end

    let(:user) { double('user', id: 5, to_param: '5') }
    let(:widget) { double('widget', id: 10, to_param: '10') }
    let(:token) { 'abad1dea' }
    let(:magic) { 'magic' }

    describe 'test_route_url' do
      it 'returns a full URL with the provided parameters' do
        expect(subject.test_route_url(user, widget, token:, magic:))
          .to eq("#{base_url}/users/#{user.id}/widgets/#{widget.id}?magic=#{magic}&token=#{token}")
      end

      it 'raises an exception when required params are missing' do
        expect { subject.test_route_url(user) }
          .to raise_error(ArgumentError)

        expect { subject.test_route_url(user, widget) }
          .to raise_error(ArgumentError)

        expect { subject.test_route_url(user, widget, magic: 'foo') }
          .to raise_error(ArgumentError)
      end

      it 'raises an exception when unknown params are provided' do
        expect { subject.test_route_url(user, widget, token:, unknown: 'foo') }
          .to raise_error(ArgumentError)
      end

      context 'with non-standard base URL' do
        subject {}

        it 'strips a trailing / in the base_url' do
          expect(FrontendRoutes.new('http://baseurl.com/').test_route_url(user, widget, token:))
            .to eq "#{base_url}/users/#{user.id}/widgets/#{widget.id}?token=#{token}"
        end

        it 'rejects non-HTTP(S) schemes' do
          expect { FrontendRoutes.new('ftp://example.com') }
            .to raise_error(ArgumentError)
          expect { FrontendRoutes.new('example.com') }
            .to raise_error(ArgumentError)
        end
      end
    end

    describe 'test_route_path' do
      it 'works like the URL' do
        expect(subject.test_route_path(user, widget, token:))
          .to eq "/users/#{user.id}/widgets/#{widget.id}?token=#{token}"
      end
    end
  end
end
