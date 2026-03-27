# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UrlPathGenerator do
  subject { UrlPathGenerator.build(path_base, query_params, url_params) }

  let(:path_base)    { '/base/:id/resource/edit' }
  let(:query_params) { { baz: 'wow', faz: 'sass' } }
  let(:url_params)   { { id: '44' } }

  it 'produces paths' do
    expect(subject).to eq '/base/44/resource/edit?baz=wow&faz=sass'
  end

  context 'with one query param' do
    let(:query_params) { { baz: 'wow' } }

    it 'produces the right query string' do
      expect(subject).to eq '/base/44/resource/edit?baz=wow'
    end
  end

  context 'with zero query params' do
    let(:query_params) { {} }

    it 'produces the right query string' do
      expect(subject).to eq '/base/44/resource/edit'
    end
  end

  context 'without url params' do
    let(:path_base) { '/resource/edit' }
    let(:url_params) { {} }

    it 'produces paths' do
      expect(subject).to eq '/resource/edit?baz=wow&faz=sass'
    end
  end

  context 'with two url params' do
    let(:path_base) { '/base/:base_id/child/:child_id/resource/edit' }
    let(:url_params) { { base_id: '44', child_id: '66' } }

    it 'produces paths' do
      expect(subject).to eq '/base/44/child/66/resource/edit?baz=wow&faz=sass'
    end
  end

  context 'with special characters' do
    context 'with spaces' do
      let(:query_params) { { foo: 'such bar' } }
      let(:url_params)   { { id: 'such id' } }

      it 'escapes its parameters' do
        expect(subject)
          .to eq '/base/such+id/resource/edit?foo=such+bar'
      end
    end

    context 'with slashes' do
      let(:query_params) { { foo: 'such/bar' } }
      let(:url_params)   { { id: 'such/id' } }

      it 'escapes its parameters' do
        expect(subject)
          .to eq '/base/such%2Fid/resource/edit?foo=such%2Fbar'
      end
    end

    context 'with url params missing' do
      let(:url_params) { {} }

      it 'throws an error' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end

    context 'with extra URL parameters' do
      let(:url_params) { { id: 4, no: 'no' } }
      it 'throws an error' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end
end
