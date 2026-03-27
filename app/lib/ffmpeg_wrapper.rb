# frozen_string_literal: true

# Based extremely loosely around a cut-down https://github.com/streamio/streamio-ffmpeg.
# We run ffmpeg in a tight system-call sandbox without access to fstat or fopen, so
# input data can only come via inherited file descriptors.
class FfmpegWrapper
  # We expect ffmpeg to be provided on the path by Nix
  FFMPEG_BINARY = 'ffmpeg'
  FFPROBE_BINARY = 'ffprobe'

  MP3_OUTPUT_OPTIONS = {
    'f'   => 'mp3',
    'b:a' => '64k', # CBR 64kbps
    'ac'  => '1',   # mono
    'max_muxing_queue_size' => '9999', # Workaround for https://trac.ffmpeg.org/ticket/6375
  }.freeze

  H264_OUTPUT_OPTIONS = {
    'movflags' => '+frag_keyframe', #+empty_moov+rtphint+separate_moof',
    'c:v' => 'libx264',
    'c:a' => 'aac',
    'b:a' => '64k',
    'ac' => '1', # mono
    'preset' => 'superfast',
    'crf' => '30',
    'f' => 'mp4', # fragmented mp4 that allows streaming output
    'max_muxing_queue_size' => '9999',
  }.freeze

  enum :TranscodeFormat do
    include LowercaseRenum
    MP3('audio/mpeg', 'mp3', false, MP3_OUTPUT_OPTIONS)
    MP4('video/mp4',  'mp4', true,  H264_OUTPUT_OPTIONS)

    attr_reader :content_type, :video, :extension, :transcode_options
    alias video? video

    def init(content_type, extension, video, transcode_options)
      @content_type      = content_type
      @extension         = extension
      @video             = video
      @transcode_options = transcode_options
    end

    def audio?
      !video?
    end
  end

  BUFFER_SIZE = 131072

  class FfmpegError < ServiceError
    status 502
    code 'VideoTranscode.ServiceError'
    detail 'An error occurred during video transcoding'

    def initialize(ffmpeg_command, exit_status, ffmpeg_stderr, input_errors)
      super()
      @ffmpeg_command = ffmpeg_command
      @exit_status = exit_status
      @ffmpeg_stderr = ffmpeg_stderr
      @input_errors = input_errors
    end

    def to_honeybadger_context
      {
        ffmpeg_command: @ffmpeg_command,
        ffmpeg_exit_status: @exit_status,
        ffmpeg_stderr: @ffmpeg_stderr.split("\n"),
        input_errors: @input_errors.map { |e|
          { class: e.class.name, message: e.message, backtrace: e.backtrace }
        },
      }
    end
  end

  ConfiguredInput = Struct.new(:configuration, :input)
  LiteralInput = Struct.new(:value)

  class LavfiInput < ConfiguredInput
    def initialize(filter)
      super({ 'f' => 'lavfi' }, LiteralInput.new(filter))
    end
  end

  def ffprobe(input)
    redirections, pipes, ffmpeg_inputs, async_input_threads = build_inputs([input])

    command = [{}, FFPROBE_BINARY, *ffmpeg_inputs, '-print_format', 'json', '-show_format', '-show_streams', '-show_error']
    options = { unsetenv_others: true }.merge(redirections)

    invoke_ffmpeg(command:, pipes:, async_input_threads:, options:) do |stdout|
      result = stdout.read
      JSON.parse(result)
    rescue JSON::ParserError
      raise FfmpegError.new(command, 0, result, [])
    end
  end

  def streaming_transcode(*inputs, input_options: {}, output_options:, &)
    iopts = flatten_configuration_map(input_options)
    oopts = flatten_configuration_map(output_options)

    redirections, pipes, ffmpeg_inputs, async_input_threads = build_inputs(inputs)

    command = [{}, FFMPEG_BINARY, '-y', *iopts, *ffmpeg_inputs, *oopts, 'pipe:1']
    options = { unsetenv_others: true }.merge(redirections)

    invoke_ffmpeg(command:, pipes:, async_input_threads:, options:) do |stdout|
      # Synchronously consume stdout in the main thread, yielding BUFFER_SIZE
      # chunks to the caller. The buffer is not reused, as the caller may hand
      # the value to another thread without duplicating it.
      while (buf = stdout.read(BUFFER_SIZE))
        yield(buf)
      end
    end
  end

  private

  # Each input may be a single IO, or an array of IOs representing file
  # chunks that need to be concatenated before feeding them to ffmpeg.
  def build_inputs(inputs)
    redirections = {}
    pipes = []
    ffmpeg_inputs = []
    async_input_threads = []

    inputs.each do |input|
      if input.is_a?(ConfiguredInput)
        ffmpeg_inputs.concat(flatten_configuration_map(input.configuration))
        input = input.input
      end

      input = input.to_io if input.respond_to?(:to_io)

      if input.is_a?(LiteralInput)
        ffmpeg_inputs << '-i' << input.value
      elsif input.is_a?(IO) && input.fileno
        redirections[input.fileno] = input.fileno
        ffmpeg_inputs << '-i' << "pipe:#{input.fileno}"
      else
        rd, wr = IO.pipe
        pipes << [rd, wr]
        wr.binmode

        inputs = Array.wrap(input).map do |i|
          i = i.to_io if i.respond_to?(:to_io)
          raise ArgumentError.new("Invalid input (not IO): #{i.inspect}") unless i.is_a?(IO) || i.is_a?(StringIO)

          i
        end

        async_input_threads << async_fill_pipe(*inputs, wr)
        redirections[rd.fileno] = rd.fileno
        ffmpeg_inputs << '-i' << "pipe:#{rd.fileno}"
      end
    end

    [redirections, pipes, ffmpeg_inputs, async_input_threads]
  end

  def invoke_ffmpeg(command:, pipes:, async_input_threads:, options:)
    Rails.logger.debug { "Launching ffmpeg process with: #{command.inspect}" }
    Open3.popen3(*command, options) do |_stdin, stdout, stderr, wait_thr|
      pipes.each { |rd, _wr| rd.close }

      # Asynchronously consume stderr
      stderr_thread = async_consume(stderr)

      # Synchronously consume stdout in the main thread
      result = yield(stdout)

      # Wait for the error output then the status, and if failed, raise the
      # error, stashing the error details in Honeybadger context.
      error_output = stderr_thread.value
      status = wait_thr.value

      # Check for any errors in the async feeding threads, because if there were
      # any it would signify truncated input
      input_errors = async_input_threads.map do |t|
        t.value
        nil
      rescue StandardError => e
        e
      end.compact

      unless status.success? && input_errors.empty?
        raise FfmpegError.new(command, status.exitstatus, error_output, input_errors)
      end

      result
    end
  ensure
    pipes&.each do |rd, wr|
      rd.close
      wr.close
    end
  end

  def async_fill_pipe(*inputs, pipe)
    Thread.new do
      Thread.current.report_on_exception = false
      inputs.each do |input|
        buf = String.new(capacity: BUFFER_SIZE)
        while input.read(BUFFER_SIZE, buf)
          pipe.write(buf)
        end
      end
    ensure
      pipe.close
    end
  end

  def async_consume(pipe)
    Thread.new do
      buf = StringIO.new
      while (line = pipe.gets)
        Rails.logger.debug { line.rstrip }
        buf.puts(line)
      end
      buf.string
    end
  end

  def flatten_configuration_map(config)
    args = []

    config.each do |k, v|
      flag = "-#{k}"
      case v
      when nil
        args << flag
      when Array
        v.each { |vi| args << flag << vi.to_s }
      else
        args << flag << v.to_s
      end
    end

    args
  end
end
