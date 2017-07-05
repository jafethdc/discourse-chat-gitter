require_dependency 'application_controller'

module ::DiscourseGitter
  PLUGIN_NAME ||= 'discourse-chat-gitter'.freeze

  class Engine < ::Rails::Engine
    engine_name DiscourseGitter::PLUGIN_NAME
    isolate_namespace DiscourseGitter
  end
end
