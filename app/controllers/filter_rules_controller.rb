class ::DiscourseGitter::FilterRulesController < ::ApplicationController
  requires_plugin DiscourseGitter::PLUGIN_NAME

  def create
    filter_params = params.permit(:category_id, :room, :filter, tags: [])
    DiscourseGitter::Gitter.set_filter(filter_params[:category_id], filter_params[:room],
                                       filter_params[:filter], filter_params[:tags])

    render json: success_json
  end

  def delete
    filter_params = params.permit(:category_id, :room, :filter, tags: [])

    DiscourseGitter::Gitter.delete_filter(filter_params[:category_id], filter_params[:room],
                                          filter_params[:filter], filter_params[:tags])

    render json: success_json
  end

  private

  def category_filters_row_key(category_id)
    "category_#{category_id.present? ? category_id : '*'}"
  end
end
