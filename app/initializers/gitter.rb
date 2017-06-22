require_dependency 'application_controller'

module ::Gitter
  PLUGIN_NAME ||= 'discourse-chat-gitter'.freeze

  class Engine < ::Rails::Engine
    engine_name Gitter::PLUGIN_NAME
    isolate_namespace Gitter
  end
end
