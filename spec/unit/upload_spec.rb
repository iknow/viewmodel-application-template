# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Upload do
  context 'with local upload data' do
    let(:upload) { Upload.build(example_media_data_url, {}) }

    describe 'filename selection' do
      it 'picks the same basename given the same content' do
        basename2 = Upload::Stream.new(StringIO.new(example_media_data), example_media_content_type).basename_from_contents
        expect(upload.basename_from_contents).to eq(basename2)
      end

      it 'picks a different basename given different content' do
        basename2 = Upload::Stream.new(StringIO.new(example_media_data + 'x'), example_media_content_type).basename_from_contents
        expect(upload.basename_from_contents).not_to eq(basename2)
      end
    end
  end

  describe 'parse_data_url' do
    context 'with a complete image url' do
      let(:url) { 'data:image/png;base64,aGVsbG8=' }
      it 'parses' do
        data, content_type = Upload.parse_data_url(url)
        expect(data).to eq('hello')
        expect(content_type).to eq('image/png')
        expect(data.encoding).to eq(Encoding::ASCII_8BIT)
      end
    end

    # Examples from MDN
    # https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/Data_URIs

    context 'with literal data' do
      let(:url) { 'data:,Hello%2C%20World!' }
      it 'parses' do
        data, content_type = Upload.parse_data_url(url)
        expect(data).to eq('Hello, World!')
        expect(content_type).to eq('text/plain')
        expect(data.encoding).to eq(Encoding::US_ASCII)
      end
    end

    context 'with literal data and content type' do
      let(:url) { 'data:text/html,%3Ch1%3EHello%2C%20World!%3C%2Fh1%3E' }
      it 'parses' do
        data, content_type = Upload.parse_data_url(url)
        expect(data.encoding).to eq(Encoding::ASCII_8BIT)
        expect(data).to eq('<h1>Hello, World!</h1>')
        expect(content_type).to eq('text/html')
      end
    end

    context 'with literal data, content type and charset' do
      let(:url) { 'data:text/html;charset=utf-8,%3Ch1%3EHello%2C%20World!%3C%2Fh1%3E' }
      it 'parses' do
        data, content_type = Upload.parse_data_url(url)
        expect(data.encoding).to eq(Encoding::UTF_8)
        expect(data).to eq('<h1>Hello, World!</h1>')
        expect(content_type).to eq('text/html')
      end
    end

    context 'with literal data and charset but no content type' do
      let(:url) { 'data:;charset=utf-8,%E9%AC%B1' }
      it 'parses' do
        data, content_type = Upload.parse_data_url(url)
        expect(data.encoding).to eq(Encoding::UTF_8)
        expect(data).to eq('鬱')
        expect(content_type).to eq('text/plain')
      end
    end

    # Examples from RFC2397 (and errata id 2009)
    # https://tools.ietf.org/html/rfc2397
    # https://www.rfc-editor.org/errata/eid2009

    context 'with a charset' do
      let(:url) { 'data:text/plain;charset=iso-8859-7,%be%d3%be' }
      it 'parses' do
        data, content_type = Upload.parse_data_url(url)
        expect(data.encoding).to eq(Encoding::ISO_8859_7)
        expect(data.encode(Encoding::UTF_8)).to eq('ΎΣΎ')
        expect(content_type).to eq('text/plain')
      end
    end
  end
end
