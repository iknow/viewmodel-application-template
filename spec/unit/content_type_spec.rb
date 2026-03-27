# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContentType do
  describe '.parse' do
    shared_examples 'parses successfully' do |content_type, media_type, subtype, params|
      let(:content_type) { content_type }
      let(:media_type) { media_type }
      let(:subtype) { subtype }
      let(:params) { params }

      it "parses #{content_type} successfully" do
        ct = ContentType.parse(content_type)
        expect(ct.media_type).to eq(media_type)
        expect(ct.subtype).to eq(subtype)
        expect(ct.params).to eq(params)
      end
    end

    shared_examples 'rejects parsing' do |content_type|
      let(:content_type) { content_type }

      it "rejects parsing #{content_type}" do
        expect {
          ContentType.parse(content_type)
        }.to raise_error(ContentType::InvalidContentType)
      end
    end

    it_behaves_like 'parses successfully', 'text/plain', 'text', 'plain', {}
    it_behaves_like 'parses successfully', 'teXt/plAin', 'text', 'plain', {}
    it_behaves_like 'parses successfully', 'text/plain;charset=utf-8', 'text', 'plain', { 'charset' => 'utf-8' }
    it_behaves_like 'parses successfully', 'text/plain ; charset=utf-8', 'text', 'plain', { 'charset' => 'utf-8' }
    it_behaves_like 'parses successfully', 'text/plain;Charset=utf-8', 'text', 'plain', { 'charset' => 'utf-8' }
    it_behaves_like 'parses successfully', 'text/plain;charset=UTF-8', 'text', 'plain', { 'charset' => 'UTF-8' }
    it_behaves_like 'parses successfully', 'text/plain;charset="something \"with\" quotes"', 'text', 'plain', { 'charset' => 'something "with" quotes' }
    it_behaves_like 'parses successfully', 'text/plain;charset="esc\\ape"', 'text', 'plain', { 'charset' => 'escape' }
    it_behaves_like 'parses successfully', 'text/plain;charset="back\\\\slash"', 'text', 'plain', { 'charset' => 'back\\slash' }
    it_behaves_like 'parses successfully', 'text/plain;charset=utf-8; extra=value', 'text', 'plain', { 'charset' => 'utf-8', 'extra' => 'value' }

    it_behaves_like 'rejects parsing', 'text'
    it_behaves_like 'rejects parsing', 'text/'
    it_behaves_like 'rejects parsing', ' text/plain'
    it_behaves_like 'rejects parsing', 'text/plain '
    it_behaves_like 'rejects parsing', 'text /plain'
    it_behaves_like 'rejects parsing', 'text/plain;'
    it_behaves_like 'rejects parsing', 'text/plain;key'
    it_behaves_like 'rejects parsing', 'text/plain;key='
    it_behaves_like 'rejects parsing', 'text/plain;key="value'
    it_behaves_like 'rejects parsing', 'text/plain;key="value\\'
    it_behaves_like 'rejects parsing', 'text/plain;key="value\\"'
    it_behaves_like 'rejects parsing', 'text/plain;key=value;'
  end

  describe '#to_s' do
    shared_examples 'renders' do |content_type, string|
      let(:content_type) { content_type }
      let(:expected_string) { string }

      it "renders as #{string}" do
        expect(content_type.to_s).to eq(expected_string)
      end
    end

    it_behaves_like 'renders', ContentType.new('text', 'plain', {}), 'text/plain'
    it_behaves_like 'renders', ContentType.new('text', 'plain', { 'key' => 'value' }), 'text/plain;key=value'
    it_behaves_like 'renders', ContentType.new('text', 'plain', { 'key' => 'value', 'key2' => 'value2' }), 'text/plain;key=value;key2=value2'
    it_behaves_like 'renders', ContentType.new('text', 'plain', { 'key' => 'multi word value' }), 'text/plain;key="multi word value"'
    it_behaves_like 'renders', ContentType.new('text', 'plain', { 'key' => 'quo"te' }), 'text/plain;key="quo\"te"'
    it_behaves_like 'renders', ContentType.new('text', 'plain', { 'key' => 'back\\slash' }), 'text/plain;key="back\\\\slash"'
  end
end
