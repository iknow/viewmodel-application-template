# frozen_string_literal: true

module MailHelper
  DownloadedAsset = Struct.new(:filename, :contents, :height, :width)

  def add_inline_asset(asset, name)
    basename = File.basename(name, '.*')
    extension = File.extname(asset.filename)
    filename = "#{basename}#{extension}"
    unless attachments.inline[filename]
      attachments.inline[filename] = asset.contents
    end
    attachments[filename]
  end

  def downloaded_asset(model, height: nil, width: nil)
    raise ArgumentError.new('unconstrained size') unless height || width

    file = CachingMediaDownloader.new.download_media(model, height:, width:)
    filename = File.basename(file)
    contents = File.read(file)

    unless height && width
      width, height = FastImage.size(StringIO.new(contents))
    end

    DownloadedAsset.new(filename, contents, height, width)
  end

  def l_time_for_user(time, format: :long)
    l(time.in_time_zone(@user.effective_timezone), format:)
  end

  def frontend_routes
    @frontend_routes ||= FrontendRoutes.new(frontend_base_url)
  end

  def frontend_base_url
    'example.com'
  end

  # Helper for creating a link with a localized key and our link styles
  def t_link(key, url, **params)
    link_to(t(key, **params), url)
  end

  # Helper for rendering a single localized key with multiple links inside.
  #
  # For each link, the key and url should be given in the form i18n_key: url
  # and the url keys should have a corresponding "<key>_text" i18n key for the text
  # associated with that link.
  # If there isn't an associated "<key>_text" entry for a key, it will be treated
  # as a standard text substitution, allowing normal keys to be mixed with link keys.
  #
  # Example Call
  # <%= t_with_links('some-t-key', user_name: "foo", link1: "https://example.com/link1") %>
  #
  # In en.yml:
  # some-t-key: 'some text %{user_name} more text %{link1}'
  # link1_text: 'Click here'
  def t_with_links(key, scope: nil, text_only: false, **inline_urls)
    link_bodies = inline_urls.each_with_object({}) do |(link_key, url_or_text), h|
      # The link text key is expected to be a sibling to the key
      link_text_key = key.start_with?('.') ? ".#{link_key}_text" : "#{link_key}_text"

      # Because the result will be HTML with links, we need to pre-escape the input.
      url_or_text = ERB::Util.html_escape(url_or_text)

      h[link_key] =
        if t(link_text_key, default: '', scope:).empty?
          url_or_text
        elsif text_only
          t(link_text_key, scope:) + " (#{url_or_text})"
        else
          t_link(link_text_key, url_or_text, scope:)
        end
    end
    raw(t(key, scope:, **link_bodies))
  end
end
