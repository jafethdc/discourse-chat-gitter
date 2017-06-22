class ::Gitter::FilterRulesController < ::ApplicationController
  requires_plugin Gitter::PLUGIN_NAME

  def create
    filter_params = params.permit(:category_id, :room, :filter, tags: [])
    category_filters_row_key = category_filters_row_key(filter_params[:category_id])
    category_filters = PluginStore.get(Gitter::PLUGIN_NAME, category_filters_row_key) || []
    tags = Tag.where(name: filter_params[:tags]).pluck(:name)

    category_filters.push(filter: filter_params[:filter], room: filter_params[:room], tags: tags)
    PluginStore.set(Gitter::PLUGIN_NAME, category_filters_row_key, category_filters)

    render json: success_json
  end

  def delete
    filter_params = params.permit(:category_id, :room, :filter, tags: [])
    filter_params[:tags] ||= []
    category_filters_row_key = category_filters_row_key(filter_params[:category_id])
    category_filters = PluginStore.get(Gitter::PLUGIN_NAME, category_filters_row_key) || []
    category_filters.delete_at(category_filters.index(filter_params.except(:category_id).stringify_keys))
    PluginStore.set(Gitter::PLUGIN_NAME, category_filters_row_key, category_filters)
    render json: success_json
  end

  private

  def category_filters_row_key(category_id)
    "category_#{category_id.present? ? category_id : '*'}"
  end
end
