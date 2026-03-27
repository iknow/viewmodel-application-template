# frozen_string_literal: true

class PaginationConfig
  DEFAULT_DIRECTION = 'asc'
  DEFAULT_PAGE_SIZE = 100
  # For now, we don't impose a max foreground-rendered page size limit for most
  # controllers. We'll set one once the client has been updated to no longer
  # request unlimited results.
  DEFAULT_MAX_PAGE_SIZE = nil
  DEFAULT_MAX_BACKGROUND_PAGE_SIZE = 50000

  attr_accessor :default_page_size, :max_page_size, :max_background_page_size

  def initialize(model_class)
    @default_page_size = DEFAULT_PAGE_SIZE
    @max_page_size     = DEFAULT_MAX_PAGE_SIZE
    @max_background_page_size = DEFAULT_MAX_BACKGROUND_PAGE_SIZE
    @pagination_orders = {}
    # All types can be sorted by id and none, searchable types can be sorted by relevance.
    add_pagination_order(:id) do
      scope  { |dir| model_class.reorder(id: dir) }
      search { |dir| { id: { order: dir } } }
    end

    add_pagination_order(:none) do
      scope { |_| model_class.reorder(nil) }
      search { |_| {} }
    end

    add_pagination_order(:relevance, default_direction: 'desc') do
      scope nil
      search { |direction| { '_score' => { order: direction } } }
    end
  end

  def add_pagination_order(name, default_direction: DEFAULT_DIRECTION, &block)
    order = PaginationOrder.build!(name:, default_direction:, &block)

    order.names.each do |n|
      if @pagination_orders.has_key?(n)
        raise ArgumentError.new("Pagination order '#{n}' already defined")
      end

      @pagination_orders[n] = order
    end
  end

  def pagination_order(name)
    @pagination_orders.fetch(name) do
      raise ViewModel::SerializationError.new("No pagination order '#{name}' defined")
    end
  end

  def default_pagination_order
    @default_pagination_order || @pagination_orders.keys.first
  end

  def default_pagination_order=(name)
    unless @pagination_orders.has_key?(name)
      raise ArgumentError.new("Cannot set default pagination order to undefined order '#{name}'")
    end

    @default_pagination_order = name
  end

  def new_page(name, order, direction, start, page_size, compute_total_count, background: false)
    max_size = background ? max_background_page_size : max_page_size

    if max_size.present? && (page_size.zero? || page_size > max_size)
      raise PageSizeLimitExceeded.new(page_size, max_size, background:)
    end

    Page.new(name, order, direction, start, page_size, compute_total_count)
  end
end
