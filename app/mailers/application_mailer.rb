# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  IMAGE_ASSET_DIR = 'app/assets/images/'

  default from: ->(_) { mail_sender },
          reply_to: ->(_) { mail_sender }

  class AbortDeliveryError < StandardError; end
  rescue_from AbortDeliveryError, with: -> {}

  layout 'mailer'
  helper MailHelper

  # we need to include the helper because mailers don't use them
  # https://github.com/rails/rails/pull/24866#issuecomment-217278494
  include MailHelper

  rescue_from Net::SMTPSyntaxError do |err|
    # Log and discard
    Rails.logger.warn("Discarded invalid #{self.class.name} message to #{recipient_id}: #{err.message}")
  end

  rescue_from Net::SMTPFatalError do |err|
    if err.message.start_with?('554 Transaction failed: Invalid domain name')
      Rails.logger.warn("Discarded invalid #{self.class.name} message to #{recipient_id}: #{err.message}")
    else
      raise err
    end
  end

  protected

  def default_translation_scope
    [mailer_name, action_name]
  end

  def default_subject
    I18n.t(
      :subject,
      scope: default_translation_scope,
      default: action_name.to_s.humanize)
  end

  def sender_name
    'FIXME'
  end

  def sender_email
    'fixme@example.com'
  end

  def mail_sender
    "#{sender_name} <#{sender_email}>"
  end

  # Include the action name and user and organization id as SES message tags
  def ses_message_tags
    mailer_name = self.class.name.underscore.delete_suffix('_mailer')
    {
      'action'       => "#{mailer_name}-#{action_name}",
      'recipient'    => @user.id,
      'organization' => @user.organization_id,
    }
  end

  def ses_message_tags_header
    {
      'X-SES-Message-Tags' => ses_message_tags.map { |k, v| "#{k}=#{v}" }.join(', '),
    }
  end
end
