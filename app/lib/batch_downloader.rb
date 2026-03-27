# frozen_string_literal: true

class BatchDownloader
  DOWNLOAD_CONCURRENCY = 20

  class DownloadError < RuntimeError
    attr_reader :errors

    def initialize(errors)
      super('Error in batch downloading')
      @errors = errors
    end

    def to_honeybadger_context
      ViewModelLogging.filter_error_context({ errors: })
    end
  end

  # Provided a map of key to list of urls, returns a map of that key to list of
  # open File descriptors to unlinked downloaded tempfiles. If a URL appears
  # twice or more, each instance will be mapped to a separately-opened File
  # descriptor on the same file.
  def batch_download(spec)
    urls = spec.values.flatten.uniq

    # Allocate temporary files to download each video chunk
    tempfiles = urls.index_with do
      result_file = Tempfile.new('batch-download')
      result_file.binmode
      result_file
    end

    # Download the chunks in parallel, bailing if we encounter an error in any
    # of them
    hydra = Typhoeus::Hydra.new(max_concurrency: DOWNLOAD_CONCURRENCY)
    any_failures = false

    requests = tempfiles.map do |url, tempfile|
      request = Typhoeus::Request.new(url)

      request.on_headers do |response|
        next :abort if any_failures

        if response.code != 200
          any_failures = true
          next :abort
        end
      end

      request.on_body do |chunk|
        next :abort if any_failures

        tempfile.write(chunk)
      end

      request.on_failure do
        any_failures = true
      end

      request.on_complete do
        tempfile.rewind
      end

      hydra.queue(request)

      request
    end

    hydra.run

    # Check for and collect errors
    errored_requests = requests.reject do |request|
      request.response.success? && request.response.code == 200
    end

    if errored_requests.present?
      error_details = errored_requests.map do |request|
        {
          path:   request&.base_url,
          status: request&.response&.code,
          body:   request&.response&.body,
        }
      end
      raise DownloadError.new(error_details)
    end

    # We need a unique file descriptor per file
    seen_tempfiles = Set.new

    spec_files = spec.transform_values do |spec_urls|
      spec_urls.map do |url|
        tempfile = tempfiles.fetch(url)
        if seen_tempfiles.add?(tempfile)
          io = tempfile.to_io
          # We want to return proper IO objects for everything. We also don't
          # want to discard the reference to the tempfile, because otherwise
          # this fd will be closed when it's garbage-collected.
          io.instance_variable_set(:@__parent_tempfile_ref, tempfile)
          io
        else
          File.open(tempfile.path, 'rb')
        end
      end
    end

    # unlink the tempfiles now that we've opened as many open file descriptors
    # as needed
    tempfiles.each_value(&:unlink)

    spec_files
  rescue StandardError
    tempfiles&.each_value { |file| file.close rescue nil }
    raise
  end
end
