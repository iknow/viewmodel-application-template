# frozen_string_literal: true

##
# Adds automatic pagination to controller methods with a `scope:` parameter.
#
# ActiveRecord::ViewModel::Controller generated controllers provide an optional
# `scope:` keyword argument for `index` and `show`, which constrain entity
# lookup to the provided ActiveRecord scope. This concern uses that
# functionality to provide pagination. It can also be used on any custom
# controller method, providing that the same `scope:` behaviour is implemented.
#
# Paginated controller methods take the additional four URL parameters `:start`,
# `:page_size`, `:order` and `:direction`. Pagination is performed if any of the
# four parameters are provided. Paginated responses are annotated with a metadata
# structure `{ start: , page_size: , order:, direction: }` at the additional key
# `pagination` in the top level response hash.
#
# Pagination orders for automatic pagination wrappers are defined by
# ActiveRecord scopes, and installed with `add_pagination_order(name, &block)`,
# where `block` takes a single parameter `direction` and must return an
# appropriate AR scope.
#
# A default ordering `:id` based on the model id is provided. For other
# controllers, all orderings must be manually defined and a default set with
# `#default_pagination_order=`.

module Pagination
  extend ActiveSupport::Concern

  class_methods do
    def pagination_config
      @pagination_config ||= PaginationConfig.new(model_class)
    end

    def pagination_order(name, default_direction: PaginationConfig::DEFAULT_DIRECTION, &block)
      pagination_config.add_pagination_order(name, default_direction:, &block)
    end

    def default_page_size(size)
      pagination_config.default_page_size = size
    end

    def max_page_size(size)
      pagination_config.max_page_size = size
    end

    def default_pagination_order(name)
      pagination_config.default_pagination_order = name
    end
  end

  protected

  def current_page
    @current_page ||= parse_pagination
  end

  def search_action?(action_name)
    action_name == 'search'
  end

  # PaginationConfigs define a default pagination order that is used for all
  # non-search actions. (Search actions always have default order :relevance)
  def default_pagination_order
    if search_action?(self.action_name)
      :relevance
    else
      self.class.pagination_config.default_pagination_order
    end
  end

  private

  # Parse pagination specified in params
  def parse_pagination
    config = self.class.pagination_config

    start      = parse_param(:start, default: 0, with: ParamSerializers::SignedInteger.new(negative: false))
    page_size  = parse_param(:page_size, default: config.default_page_size, with: ParamSerializers::SignedInteger.new(negative: false))
    order_name = parse_string_param(:order, default: default_pagination_order)
    direction  = parse_param(:direction, with: ParamSerializers::SearchDirection, default: nil)

    pagination_order = config.pagination_order(order_name.to_sym)
    direction ||= pagination_order.default_direction

    config.new_page(order_name, pagination_order, direction, start, page_size)
  end
end
