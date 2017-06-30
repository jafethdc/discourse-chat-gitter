# name: discourse-chat-gitter
# about: Gitter integration for Discourse
# version: 0.1
# authors: Jafeth Diaz
# url: https://github.com/JafethDC/discourse-chat-gitter

enabled_site_setting :gitter_enabled

add_admin_route 'gitter.title', 'gitter'

register_asset 'stylesheets/gitter-admin.scss'

def gitter_require(path)
  require Rails.root.join('plugins', 'discourse-chat-gitter', 'app', path).to_s
end

after_initialize do
  gitter_require 'initializers/gitter'
  gitter_require 'routes/gitter'
  gitter_require 'routes/discourse'
  gitter_require 'controllers/filter_rules_controller'
  gitter_require 'controllers/integrations_controller'
  gitter_require 'lib/gitter'
  gitter_require 'jobs/regular/notify_gitter'

  DiscourseEvent.on(:post_created) do |post|
    if SiteSetting.gitter_enabled?
      Jobs.enqueue_in(1, :notify_gitter, post_id: post.id)
    end
  end
end

