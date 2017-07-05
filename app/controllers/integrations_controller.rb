class ::DiscourseGitter::IntegrationsController < ::ApplicationController
  requires_plugin DiscourseGitter::PLUGIN_NAME

  def index
    integrations = {}
    PluginStoreRow.where(plugin_name: DiscourseGitter::PLUGIN_NAME).where('key LIKE ?', 'integration_%').each do |row|
      integration = PluginStore.cast_value(row.type_name, row.value)
      room = row.key.gsub('integration_', '')
      integrations[room] = {
        room: room,
        room_id: integration[:room_id],
        webhook: integration[:webhook],
        filters: []
      }
    end

    PluginStoreRow.where(plugin_name: DiscourseGitter::PLUGIN_NAME).where('key LIKE ?', 'category_%').each do |row|
      PluginStore.cast_value(row.type_name, row.value).each do |filter|
        category_id = row.key == 'category_*' ? nil : row.key.gsub('category_', '')
        integrations[filter[:room]][:filters] << {
          category_id: category_id,
          room: filter[:room],
          filter: filter[:filter],
          tags: filter[:tags]
        }
      end
    end

    render json: integrations.values
  end

  def create
    integration_params = params.permit(:room, :room_id, :webhook)
    DiscourseGitter::Gitter.set_integration(integration_params[:room], integration_params[:room_id], integration_params[:webhook])
    render json: success_json
  end

  def delete
    DiscourseGitter::Gitter.delete_integration(params[:room])
    render json: success_json
  end
end
