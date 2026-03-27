# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JSON encoding' do

  context 'precompiled terminals' do
    let(:terminal) { { 'a' => 100 } }

    let(:encoded_terminal) do
      ViewModel::Controller::CompiledJson.new(JSON.dump(terminal))
    end

    let(:expected_dump) { dump({ 'x' => terminal }) }
    let(:computed_dump) { dump({ 'x' => encoded_terminal }) }

    shared_examples 'it correctly dumps' do
      it 'correctly dumps' do
        expect(computed_dump).to eq(expected_dump)
      end
    end

    context 'with Api::ApplicationController' do
      def dump(value)
        Api::ApplicationController.new.send(:encode_jbuilder) do |json|
          json.merge!(value)
        end
      end
      include_examples 'it correctly dumps'
    end

    context 'with ViewModel encode_json' do
      def dump(value)
        ViewModel.encode_json(value)
      end
      include_examples 'it correctly dumps'
    end

    context 'with OJ compatibility mode' do
      def dump(value)
        Oj.dump(value, mode: :compat)
      end
      include_examples 'it correctly dumps'
    end
  end
end
