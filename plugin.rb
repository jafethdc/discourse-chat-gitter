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

gem 'cookiejar', '0.3.2', require: false
gem 'eventmachine', '1.2.0.1', require: false
gem 'em-socksify', '0.3.1', require: false
gem 'http_parser.rb', '0.6.0', require: false
gem 'em-http-request', '1.1.5', require: false
gem 'websocket-extensions', '0.1.2', require: false
gem 'websocket-driver', '0.6.5', require: false
gem 'faye-websocket', '0.10.7', require: false
gem 'faye', '1.2.4', require: false

require 'eventmachine'
require 'faye'

gitter_require 'validators/gitter_bot_enabled_validator'
gitter_require 'validators/gitter_bot_user_token_validator'

after_initialize do
  gitter_require 'initializers/gitter'
  gitter_require 'lib/gitter'
  gitter_require 'routes/gitter'
  gitter_require 'routes/discourse'
  gitter_require 'controllers/filter_rules_controller'
  gitter_require 'controllers/integrations_controller'
  gitter_require 'jobs/regular/notify_gitter'
  gitter_require 'lib/gitter_bot'

  GitterBot.init unless Sidekiq.server? || Rails.env.test?

  DiscourseEvent.on(:post_created) do |post|
    if SiteSetting.gitter_enabled?
      Jobs.enqueue_in(SiteSetting.gitter_notification_delay, :notify_gitter, post_id: post.id)
    end
  end
end

