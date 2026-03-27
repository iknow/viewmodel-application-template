# frozen_string_literal: true

# Utility for downloading S3 media to a persistent local cache.
class CachingMediaDownloader
  MEDIA_PATH    = Rails.root.join('tmp', 'cache', 'media')
  DOWNLOAD_PATH = File.join(MEDIA_PATH, 'download')

  class MediaDownloadError < RuntimeError
    attr_reader :status

    def initialize(message, status)
      @status = status
      super(message)
    end
  end

  class << self
    def initialize_directories
      unless @initialized_directories
        FileUtils.mkdir_p(MEDIA_PATH)
        FileUtils.mkdir_p(DOWNLOAD_PATH)
        @initialized_directories = true
      end
    end
  end

  # Relies on the URL containing a static resource; saves to a filename based on
  # the hash of the URL.
  def download_static_url(url, height: nil, width: nil, scaling_mode: :pad, format: :png)
    url = URI(url)
    filename = Digest::SHA256.hexdigest(url.to_s)
    extension = File.extname(url.path)
    filename += extension if extension

    if width || height
      url = transcode_url(url, width, height, scaling_mode, format)
      filename = transcode_filename(filename, width, height, scaling_mode, format)
    end

    download_path = cache_path(filename)

    with_flock(download_path) do
      unless File.exist?(download_path)
        download_file(url, download_path)
      end
    end

    download_path
  end

  private

  def transcode_url(media_url, width, height, scaling_mode, format)
    keys = [
      "f_#{format}",
      "c_#{scaling_mode}",
      ("h_#{height}" if height),
      ("w_#{width}" if width),
    ].compact

    path = "/image/fetch/#{keys.join(',')}/#{media_url}"

    URI.join(TranscoderConfig.transcoder_url, path)
  end

  def transcode_filename(filename, width, height, scaling_mode, format)
    basename = File.basename(filename, '.*')

    "#{basename}_#{width}x#{height}_#{scaling_mode}.#{format}"
  end

  def cache_path(filename)
    File.join(MEDIA_PATH, filename)
  end

  def with_flock(download_path)
    File.open("#{download_path}.flock", File::CREAT) do |f|
      f.flock(File::LOCK_EX)
      yield
    end
  end

  def download_file(uri, path)
    tempfile = Tempfile.new('download', DOWNLOAD_PATH)
    tempfile.binmode

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request) do |response|
        unless response.is_a?(Net::HTTPSuccess)
          raise MediaDownloadError.new("Media download failed with response code: #{response.code}", response.code.to_i)
        end

        response.read_body do |chunk|
          tempfile.write(chunk)
        end
      end
    end

    tempfile.close

    File.rename(tempfile, path)
  rescue MediaDownloadError
    raise
  rescue StandardError => e
    raise MediaDownloadError.new(e.message, 500)
  end
end
