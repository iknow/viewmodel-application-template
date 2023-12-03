# frozen_string_literal: true

class Api::ViewModelController < Api::ApplicationController
  include ViewModel::ActiveRecord::Controller

  enum :LookupStrategy do
    include LowercaseRenum

    Either(true, true)
    Search(true, false)
    Scope(false, true)

    def init(search, scope)
      @search = search
      @scope  = scope
    end

    def can_search?
      @search
    end

    def can_scope?
      @scope
    end
  end

  class LookupStrategy::Serializer < ParamSerializers::LowercaseRenum
    def initialize
      super(LookupStrategy)
    end

    def load(str)
      str = str.capitalize if str.respond_to?(:capitalize)
      super(str)
    end

    set_singleton!
  end

  def create(serialize_context: new_serialize_context, **args)
    super(serialize_context:, **args) do |view|
      load_context_data(Array.wrap(view), context: serialize_context)
      view = yield(view) if block_given?
      view
    end
  end

  def show(viewmodel_class: self.viewmodel_class, scope: nil, serialize_context: new_serialize_context(viewmodel_class:), prerenderer: nil)
    view = nil
    pre_rendered = viewmodel_class.transaction do
      view = viewmodel_class.find(viewmodel_id, scope:, eager_include: false)

      load_context_data([view], context: serialize_context)

      view = yield(view) if block_given?

      if prerenderer
        prerenderer.call(view, serialize_context:)
      else
        ViewModel.preload_for_serialization(view)
        prerender_viewmodel(view, serialize_context:)
      end
    end
    render_json_string(pre_rendered)
    view
  end

  def index(viewmodel_class: self.viewmodel_class, scope: nil, serialize_context: new_serialize_context(viewmodel_class:), prerenderer: nil)
    pre_rendered = viewmodel_class.transaction do
      strategy = parse_param(:resolution_strategy, with: LookupStrategy::Serializer, default: default_resolution_strategy)

      views = resolve_views(scope, current_filters, current_page, viewmodel_class:, serialize_context:, strategy:)

      load_context_data(views, context: serialize_context)

      views = yield(views) if block_given?

      if prerenderer
        prerenderer.call(views, serialize_context:)
      else
        ViewModel.preload_for_serialization(views)
        prerender_viewmodel(views, serialize_context:)
      end
    end

    render_json_string(pre_rendered)
  end

  # Handle pagination/filtering for nested controllers: to be compatible with
  # the superclass implementation only scoped lookup is possible
  def index_associated(scope: nil, serialize_context: new_serialize_context)
    validate_lookup_strategy!(scope, current_filters, current_page,
                              strategy: LookupStrategy::Scope)
    scope = merge_scopes(scope,
                         current_filters.scope,
                         current_page&.scope(current_filters))

    super(scope:, serialize_context:) do |views|
      record_pagination!(views, current_page) if current_page
      load_context_data(views, context: serialize_context)
      views = yield(views) if block_given?
      views
    end
  end

  def show_associated(serialize_context: new_serialize_context, **args)
    super(serialize_context:, **args) do |v|
      load_context_data(Array.wrap(v), context: serialize_context)
      v = yield(v) if block_given?
      v
    end
  end

  def append(serialize_context: new_serialize_context, **args)
    super(serialize_context:, **args) do |v|
      load_context_data(Array.wrap(v), context: serialize_context)
      v = yield(v) if block_given?
      v
    end
  end

  def replace(serialize_context: new_serialize_context, **args)
    super(serialize_context:, **args) do |v|
      load_context_data(Array.wrap(v), context: serialize_context)
      v = yield(v) if block_given?
      v
    end
  end

  def search(viewmodel_class: self.viewmodel_class, serialize_context: new_serialize_context(viewmodel_class:), prerenderer: nil)
    search_class = self.search_class
    query = parse_string_param(:query)
    translation_language = parse_param(:translation_language,
                                       with: ParamSerializers::Language::Insensitive,
                                       default: nil)

    validate_lookup_strategy!(nil, current_filters, current_page,
                              strategy: LookupStrategy::Search)

    pre_rendered = viewmodel_class.transaction do
      models = perform_search(query,
                              with: search_class,
                              page: current_page,
                              translation_language:,
                              filters: current_filters)

      views = models.map { |model| viewmodel_class.new(model) }

      load_context_data(views, context: serialize_context)

      views = yield(views) if block_given?

      if prerenderer
        prerenderer.call(views, serialize_context:)
      else
        ViewModel.preload_for_serialization(views)
        prerender_viewmodel(views, serialize_context:)
      end
    end

    render_json_string(pre_rendered)
  end

  protected

  def new_deserialize_context(access_control: new_access_control, **args)
    super(request_context:, access_control:, **args)
  end

  def new_serialize_context(access_control: new_access_control, **args)
    super(request_context:, access_control:, **args)
  end

  def new_access_control
    self.access_control.new
  end

  def search_class
    self.class.default_search_class
  end

  def default_resolution_strategy
    if self.class.searchable?
      LookupStrategy::Either
    else
      LookupStrategy::Scope
    end
  end

  # Allow individual routes to override the viewmodel class used by the controller.
  def viewmodel_class
    if (viewmodel_name = params[:route_viewmodel])
      ViewModel::Registry.for_view_name(viewmodel_name)
    else
      super
    end
  end

  # Use scope (filtered database lookup) or search (full-text search) to resolve
  # views matching the provided filters, optionally paginated by the provided
  # page
  def resolve_views(scope, filters, page, viewmodel_class:, serialize_context:, strategy:)
    resolved_strategy = validate_lookup_strategy!(scope, filters, page, strategy:)

    case resolved_strategy
    when LookupStrategy::Scope
      # resolve views from database
      scope = merge_scopes(scope, filters.scope)
      scope = merge_scopes(scope, page.scope(filters)) if page

      views = viewmodel_class.load(scope:, eager_include: false)
      record_pagination!(views, page) if page

      views

    when LookupStrategy::Search
      search_class = self.search_class
      models = perform_search(nil, with: search_class, page:, filters:, filter_only: true)

      models.map { |model| viewmodel_class.new(model) }
    else
      raise ArgumentError.new("Unexpected resolved lookup strategy: #{resolved_strategy}")
    end
  end

  # Return the specific strategy most appropriate to the filtered/paginated
  # request, optionally constrained to the `strategy` parameter, or raises
  # IncompatibleParameters.
  def validate_lookup_strategy!(scope, filters, page, strategy: LookupStrategy::Either)
    resolved_strategy = resolve_lookup_strategy(scope, filters, page, strategy:)
    if resolved_strategy.nil?
      raise IncompatibleParameters.new(filters: current_filters,
                                       page: current_page,
                                       with_scope: scope.present?,
                                       strategy: strategy.name)
    end
    resolved_strategy
  end

  # Return the specific strategy most appropriate to the filtered/paginated
  # request, optionally constrained to the `strategy` parameter. Returns nil if
  # no matching strategy could be identified.
  def resolve_lookup_strategy(scope, filters, page, strategy:  LookupStrategy::Either)
    if strategy.can_scope? && filters.can_scope? && (page.nil? || page.can_scope?)
      LookupStrategy::Scope
    elsif strategy.can_search? && scope.nil? && filters.can_search? && (page.nil? || page.can_search?)
      LookupStrategy::Search
    else
      nil
    end
  end

  def record_pagination!(results, page)
    last_page = !page.size_limit? || results.count <= page.page_size

    # The page's scope asks for one more result than requested to check whether
    # we're on the last page: if we're not, then drop it.
    results.pop unless last_page

    pagination_view = PaginationView.new(page, last_page:)
    add_response_metadata(:pagination, pagination_view)
  end

  def load_context_data(views, context:)
    if viewmodel_class.const_defined?(:ContextData)
      viewmodel_class::ContextData.load(views, context:)
    end
  end
end
