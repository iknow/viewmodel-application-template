# frozen_string_literal: true

# Service using libmagic to to identify types of uploaded files. Because we
# can't trust libmagic entirely, we attempt to unify the user-agent provided
# content_type with libmagic's inferred result, and only positively identify
# when they can be matched.
class FileIdentificationService
  # Many commonly used content types are not valid MIME types (as understood
  # by MIME::Types): first resolve the uploaded type from a local set of
  # aliases.
  CONTENT_TYPE_ALIASES = {
    'audio/mp3'  => 'audio/mpeg',
    'audio/wav'  => 'audio/x-wav',
    'audio/wave' => 'audio/x-wav',
  }.freeze

  # Returns inferred content type for bytes.
  def identify(bytes, provided_content_type)
    raise ArgumentError.new('Cannot identify nil file content') if bytes.nil?

    inferred_content_type = FileMagic.new(:mime_type).buffer(bytes)
    inferred_content_type = CONTENT_TYPE_ALIASES.fetch(inferred_content_type) { inferred_content_type }
    inferred_mime_type    = MIME::Types[inferred_content_type].first

    if provided_content_type
      provided_content_type = CONTENT_TYPE_ALIASES.fetch(provided_content_type) { provided_content_type }
      provided_mime_type    = MIME::Types[provided_content_type].first

      # Try to unify the provided and inferred types. If only one is understood,
      # return the other. Otherwise, if they can be reasonably matched using
      # #like?, return the inferred type. Otherwise consider them incompatible and
      # raise a parse error.
      if inferred_content_type.nil? || inferred_content_type == 'application/octet-stream'
        provided_content_type
      elsif provided_content_type.nil? || provided_content_type == 'application/octet-stream'
        inferred_content_type
      elsif mime_types_equivalent?(provided_mime_type, inferred_mime_type)
        inferred_content_type
      else
        raise ArgumentError.new(
                "Inferred media content type '#{inferred_content_type}' "\
                "is not compatible with supplied type '#{provided_content_type}'")
      end
    else
      inferred_content_type
    end
  end

  private

  # Use MIME::Types information to infer whether a pair of mime types are
  # talking about the same format.
  def mime_types_equivalent?(a, b)
    return false if a.nil? || b.nil?

    a == b ||
      a.like?(b) ||
      a.xrefs['template']&.any? { |t| b == t } ||
      b.xrefs['template']&.any? { |t| a == t }
  end
end
