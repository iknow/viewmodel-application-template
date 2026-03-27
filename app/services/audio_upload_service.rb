# frozen_string_literal: true

class AudioUploadService < MediaUploadService
  HEADER_SIZE = 100 * 1024
  ID3V1_SIZE = 128

  class ParseError < MediaUploadService::ParseError
    def initialize(content_type, reason = nil)
      message = "Could not parse uploaded file as #{content_type}"
      message = "#{message}: #{reason}" if reason
      super(message)
    end
  end

  def characterize_media(upload)
    provided_content_type = upload.content_type

    case provided_content_type
    when 'audio/mpeg', 'audio/mp3'
      characterize_mp3(upload, provided_content_type)
    when 'audio/webm;codecs=opus'
      characterize_with_ffmpeg(upload,
                               provided_content_type:,
                               expected_inferred_type: 'video/webm',
                               required_format: 'webm',
                               required_codec: 'opus')
    when 'audio/mp4;codecs=opus'
      characterize_with_ffmpeg(upload,
                               provided_content_type:,
                               expected_inferred_type: 'video/mp4',
                               required_format: 'mp4',
                               required_codec: 'opus')
    else
      raise MediaUploadService::ParseError.new("Specified content type is not supported for audio upload: #{provided_content_type}")
    end
  end

  def characterize_mp3(upload, provided_content_type)
    io = get_measurable_io(upload, with_padding: true)

    inferred_content_type = infer_content_type(io, provided_content_type)

    unless inferred_content_type == 'audio/mpeg'
      raise ParseError.new(provided_content_type)
    end

    info =
      begin
        Mp3Info.open(io)
      rescue Mp3InfoError
        raise ParseError.new(provided_content_type, 'could not parse file details')
      ensure
        io.rewind
      end

    duration = info.length.seconds

    { content_type: inferred_content_type, duration: }
  end

  def characterize_with_ffmpeg(upload,
                               provided_content_type:,
                               expected_inferred_type:,
                               required_format:,
                               required_codec:)
    io = get_measurable_io(upload, with_padding: false)

    # libmagic can't differentiate the contents of a webm or mp4 container,
    # so doesn't distinguish audio and video: there exists only video/webm
    # or video/mp4
    inferred_content_type = infer_content_type(io, expected_inferred_type)

    unless inferred_content_type == expected_inferred_type
      raise ParseError.new(provided_content_type)
    end

    info =
      begin
        FfmpegWrapper.new.ffprobe(io)
      rescue FfmpegWrapper::FfmpegError
        raise ParseError.new(provided_content_type, 'could not parse file details')
      ensure
        io.rewind unless io.closed?
      end

    format_names = info.dig('format', 'format_name')&.split(',')

    unless format_names&.include?(required_format)
      raise ParseError.new(provided_content_type, "container is not #{required_format}")
    end

    streams = info['streams']
    unless streams && streams.length == 1
      raise ParseError.new(provided_content_type, 'must not contain multiple streams')
    end

    stream = streams.first
    unless stream['codec_type'] == 'audio'
      raise ParseError.new(provided_content_type, 'must contain an audio stream')
    end

    unless stream['codec_name'] == required_codec
      raise ParseError.new(provided_content_type, "must contain only #{required_codec} streams")
    end

    duration =
      begin
        Float(info.dig('format', 'duration'))
      rescue TypeError
        raise ParseError.new(provided_content_type, 'must contain an indexed duration')
      end

    { content_type: provided_content_type, duration: }
  end

  def infer_content_type(io, provided_content_type)
    header = io.read(HEADER_SIZE)
    FileIdentificationService.new.identify(header, provided_content_type)
  rescue ArgumentError => e
    raise ParseError.new(e.message)
  ensure
    io.rewind
  end

  # Obtain an IO representing enough of the file to determine the duration,
  # including in the case of a MP3. This io may be the actual backing file for
  # the upload, and so it must be rewound before returning.
  def get_measurable_io(upload, with_padding:)
    case upload
    when Upload::S3Temporary
      # We can fetch just the beginning and end of the file, and then pad out
      # the middle with blanks to the content length. This allows mp3info to
      # parse the header and tags, and then use the content length to infer
      # duration for CBR mp3s. Because the underlying file might be very large,
      # we use a (sparse) tempfile to represent it.
      #
      # Note that this will result in incorrect durations for CBR MP3s where the
      # ID3v2 tag is longer than the header we fetch, as mp3info will start
      # estimating length from the end of the parsed header. This is unlikely to
      # be the case for media we upload.
      content_length = upload.content_length
      header = upload.peek_range(0, HEADER_SIZE)

      tempfile = Tempfile.new
      tempfile.binmode
      tempfile.unlink
      tempfile.write(header)

      if with_padding && content_length > header.bytesize
        potential_tag = upload.peek_range(content_length - ID3V1_SIZE, ID3V1_SIZE)
        tempfile.seek(content_length - ID3V1_SIZE)
        tempfile.write(potential_tag)
      end

      tempfile.rewind
      tempfile.to_io
    else
      stream = upload.stream
      # mp3info doesn't handle e.g. Tempfiles, despite that they behave like IOs
      stream = stream.to_io if stream.respond_to?(:to_io)
      stream
    end
  end
end
