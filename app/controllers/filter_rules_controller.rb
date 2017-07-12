class ::DiscourseGitter::FilterRulesController < ::ApplicationController
  requires_plugin DiscourseGitter::PLUGIN_NAME

  def create
    rule_params = params.permit(:category_id, :room, :filter, tags: [])
    DiscourseGitter::Gitter.set_rule(rule_params[:category_id], rule_params[:room],
                                     rule_params[:filter], rule_params[:tags])

    render json: success_json
  end

  def delete
    rule_params = params.permit(:category_id, :room, :filter, tags: [])

    DiscourseGitter::Gitter.delete_rule(rule_params[:category_id], rule_params[:room],
                                        rule_params[:filter], rule_params[:tags])

    render json: success_json
  end
end
