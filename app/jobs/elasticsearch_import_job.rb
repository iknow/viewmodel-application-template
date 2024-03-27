# frozen_string_literal: true

class ElasticsearchImportJob < ApplicationJob
  queue_as :default

  retry_on(
    Faraday::TimeoutError,
    Faraday::ConnectionFailed,
    Elasticsearch::Transport::Transport::ServerError,
    wait: :exponentially_longer,
    attempts: 50,
  ) do |job, err|
    job.final_error_handler(err)
  end

  NOTIFY_AFTER_RETRIES = 3

  def perform(index_class_name, model_ids)
    index_class = index_class_name.constantize
    index_class.import_with_lock(*model_ids)
  rescue StandardError => e
    if executions > NOTIFY_AFTER_RETRIES
      report_error(e)
    end
    raise
  end
end
