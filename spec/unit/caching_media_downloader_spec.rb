# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CachingMediaDownloader do
  subject { CachingMediaDownloader.new }

  let(:access_url) { 'https://example.com/media.png' }
  let(:expected_url) { access_url }
  let(:expected_filename) { "#{Digest::SHA256.hexdigest(access_url)}.png" }

  let!(:tempdir) { Dir.mktmpdir('media-download') }

  let!(:download_tempdir) do
    File.join(tempdir, 'download').tap { |d| Dir.mkdir(d) }
  end

  before(:each) do
    stub_const('CachingMediaDownloader::MEDIA_PATH', tempdir)
    stub_const('CachingMediaDownloader::DOWNLOAD_PATH', download_tempdir)
  end

  after(:each) do
    FileUtils.remove_dir(tempdir)
  end

  before(:each) do
    stub_request(:get, expected_url).to_return(status: 200, body: example_media_data)
  end

  let(:download_args) { {} }

  shared_examples 'downloads the media to a file' do
    it 'downloads the media to a file' do
      result = subject.download_static_url(access_url, **download_args)
      expect(WebMock).to have_requested(:get, expected_url)

      expect(File.basename(result)).to eq(expected_filename)
      expect(File.binread(result)).to eq(example_media_data)
    end
  end

  include_examples 'downloads the media to a file'

  it 'downloads the media only once' do
    subject.download_static_url(access_url)
    expect(WebMock).to have_requested(:get, expected_url)

    result = subject.download_static_url(access_url)
    expect(WebMock).to have_requested(:get, expected_url).once

    expect(File.basename(result)).to eq(expected_filename)
    expect(File.binread(result)).to eq(example_media_data)
  end

  context 'with a missing remote resource' do
    before(:each) do
      stub_request(:get, access_url).to_return(status: 404)
    end

    it 'raises an error' do
      expect { subject.download_static_url(access_url) }.to raise_error(CachingMediaDownloader::MediaDownloadError)
    end
  end

  context 'when transcoding' do
    let(:width) { 20 }
    let(:height) { 10 }

    let!(:expected_url) do
      URI.join(TranscoderConfig.transcoder_url,
               "/image/fetch/f_png,c_pad,h_#{height},w_#{width}/#{access_url}")
    end

    let(:expected_filename) do
      digest = Digest::SHA256.hexdigest(access_url)
      "#{digest}_#{width}x#{height}_pad.png"
    end

    let(:download_args) { { width:, height: } }

    include_examples 'downloads the media to a file'

    context 'with only one constrained size' do
      let(:width) { nil }
      let!(:expected_url) do
        URI.join(TranscoderConfig.transcoder_url,
                 "/image/fetch/f_png,c_pad,h_#{height}/#{access_url}")
      end

      include_examples 'downloads the media to a file'
    end
  end
end
