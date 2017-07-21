module DiscourseGitter
  class Gitter
    def self.set_rule(category_id, room, filter, tags = [])
      category_rules = get_rules(category_id)
      tag_names = Tag.where(name: tags).pluck(:name)

      to_delete = []
      index = category_rules.index do |rule|
        if rule['tags'].blank?
          tag_names.blank? && rule[:room] == room
        else
          next if tag_names.blank?
          if (rule['tags'] - tag_names).blank?
            if rule[:room] == room
              to_delete << rule
              next
            end
          else
            if (tag_names - rule['tags']).blank?
              rule[:room] == room ? return : next
            else
              next
            end
          end
        end
      end

      category_rules -= to_delete

      if index
        category_rules[index]['filter'] = filter
        category_rules[index]['tags'] = category_rules[index]['tags'].concat(tag_names).uniq
      else
        category_rules.push(room: room, filter: filter, tags: tag_names)
      end

      PluginStore.set(DiscourseGitter::PLUGIN_NAME, category_filters_row_key(category_id), category_rules)
    end

    def self.delete_rule(category_id, room, filter, tags)
      category_filters = get_rules(category_id)
      category_filters.delete_at(category_filters.index({ room: room, filter: filter, tags: tags || [] }.stringify_keys))
      PluginStore.set(DiscourseGitter::PLUGIN_NAME, category_filters_row_key(category_id), category_filters)
    end

    # Handle repeated notifications
    def self.notify(post_id)
      post = Post.find_by(id: post_id)
      return if post.blank? || post.post_type != Post.types[:regular] || !guardian.can_see?(post)

      topic = post.topic
      return if topic.blank? || topic.archetype == Archetype.private_message

      rules = get_rules(topic.category_id) | get_rules

      integrations = {}
      notified_rooms = []

      rules.each do |rule|
        topic_tags = SiteSetting.tagging_enabled? && topic.tags.pluck(:name)

        next if SiteSetting.tagging_enabled? && rule[:tags].present? && (topic_tags & rule[:tags]).count.zero?
        next if (rule[:filter] == 'mute') || (!post.is_first_post? && rule[:filter] == 'follow')

        integration = integrations[rule[:room]] ||= get_integration(rule[:room])
        uri = URI.parse(integration[:webhook])

        begin
          response = Net::HTTP.post_form(uri, message: gitter_message(post))
          notified_rooms << rule[:room] if response.body == 'OK'
        rescue TypeError
          # ignored
        end
      end
      notified_rooms
    end

    def self.get_rules(category_id = nil)
      PluginStore.get(DiscourseGitter::PLUGIN_NAME, category_filters_row_key(category_id)) || []
    end

    def self.get_room_rules(room)
      rules = []
      PluginStoreRow.where(plugin_name: DiscourseGitter::PLUGIN_NAME).where('key LIKE ?', 'category_%').each do |row|
        PluginStore.cast_value(row.type_name, row.value).each do |rule|
          category_id = row.key == 'category_*' ? nil : row.key.gsub('category_', '')
          rules << rule.merge(category_id: category_id) if rule[:room] == room
        end
      end
      rules
    end

    def self.category_filters_row_key(category_id)
      "category_#{category_id.present? ? category_id : '*'}"
    end

    def self.get_integration(room_uri)
      PluginStore.get(DiscourseGitter::PLUGIN_NAME, "integration_#{room_uri}")
    end

    def self.gitter_message(post)
      display_name = post.user.username
      topic = post.topic
      parent_category = topic.category.try :parent_category
      category_name = parent_category ? "[#{parent_category.name}/#{topic.category.name}]" : "[#{topic.category.name}]"

      "[__#{display_name}__ - #{topic.title} - #{category_name}](#{post.full_url})"
    end

    def self.guardian
      Guardian.new(User.find_by(username: 'system'))
    end

    def self.set_integration(room, room_id, webhook)
      integration = { room: room, room_id: room_id, webhook: webhook }
      saved = PluginStore.set(DiscourseGitter::PLUGIN_NAME, "integration_#{integration[:room]}", integration.slice(:room_id, :webhook))
      saved ? integration : nil
    end

    def self.delete_integration(room)
      PluginStore.remove(DiscourseGitter::PLUGIN_NAME, "integration_#{room}")
      PluginStoreRow.where(plugin_name: DiscourseGitter::PLUGIN_NAME).where('key LIKE ?', 'category_%').each do |row|
        cleared_rules = PluginStore.cast_value(row.type_name, row.value).reject { |rule| rule[:room] == room }
        row.update(value: cleared_rules.to_json)
      end
    end

    def self.test_notification(room)
      integration = PluginStore.get(DiscourseGitter::PLUGIN_NAME, "integration_#{room}")

      uri = URI.parse(integration[:webhook])
      message = "This is a test notification from __#{SiteSetting.title}__!"

      begin
        response = Net::HTTP.post_form(uri, message: message)
        response.body == 'OK'
      rescue TypeError
        false
      end
    end
  end
end
