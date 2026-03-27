# frozen_string_literal: true

class ImageUploadService < MediaUploadService
  attr_reader :maximum_dimensions

  def initialize(maximum_dimensions: nil, **rest)
    super(**rest)
    @maximum_dimensions = maximum_dimensions
  end

  # Ignore the content type provided by the user-agent in favour of
  # detecting it with FastImage. Additionally extract dimensions.
  def characterize_media(upload)
    # Trust FastImage's characterization of the file over the user-agent provided type.
    file_header = upload.peek_range(0, 102400)

    parsed_filetype = parse_type(StringIO.new(file_header))
    content_type = fast_image_content_type(parsed_filetype)

    x, y = parse_size(StringIO.new(file_header))

    {
      content_type:,
      dimensions: ActiveRecord::Point.new(x, y),
    }
  rescue FastImage::UnknownImageType, FastImage::ImageFetchFailure, FastImage::CannotParseImage
    raise ParseError.new('Could not parse type of uploaded image')
  rescue FastImage::SizeNotFound
    raise ParseError.new('Could not parse dimensions from uploaded image')
  end

  def validate_characteristics!(upload, characteristics)
    super

    if maximum_dimensions
      dims = characteristics[:dimensions]
      if dims.x > maximum_dimensions.x || dims.y > maximum_dimensions.y
        raise ParseError.new(
                "Invalid size for uploaded media: #{dims.x}x#{dims.y} " \
                "must not exceed #{maximum_dimensions.x}x#{maximum_dimensions.y}")
      end
    end
  end

  private

  # Use FastImage to identify the type of the image, specified by the expected
  # file extension
  def parse_type(image_io)
    parsed_type = FastImage.type(image_io, raise_on_failure: true).to_s

    unless parsed_type
      raise ParseError.new('Could not parse type of uploaded image')
    end

    parsed_type
  end

  def parse_size(image_io)
    FastImage.size(image_io, raise_on_failure: true)
  end

  # Selected MIME type for each FastImage-identified file extension. Since some
  # formats have multiple MIME types, this cannot be canonical.
  FAST_IMAGE_TYPES = {
    'bmp'  => 'image/bmp',
    'gif'  => 'image/gif',
    'jpeg' => 'image/jpeg',
    'png'  => 'image/png',
    'tiff' => 'image/tiff',
    'psd'  => 'image/vnd.adobe.photoshop',
    'ico'  => 'image/x-icon',
    'cur'  => 'image/x-win-bitmap',
    'webp' => 'image/webp',
    'svg'  => 'image/svg+xml',
  }.freeze

  def fast_image_content_type(type)
    FAST_IMAGE_TYPES.fetch(type.to_s) do
      raise ParseError.new("Uploaded media parsed to unrecognized type '#{type}'")
    end
  end
end
