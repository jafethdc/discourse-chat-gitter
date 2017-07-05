module DiscourseGitter
  class Gitter
    def self.set_filter(category_id, room, filter, tags = [])
      category_filters = get_filters(category_id)
      tag_names = Tag.where(name: tags).pluck(:name)

      index = category_filters.index do |rule|
        rule['room'] == room && (rule['tags'] - tag_names).blank?
      end

      if index
        category_filters[index]['filter'] = filter
        category_filters[index]['tags'] = category_filters[index]['tags'].concat(tags).uniq
      else
        category_filters.push(room: room, filter: filter, tags: tags)
      end

      PluginStore.set(DiscourseGitter::PLUGIN_NAME, category_filters_row_key(category_id), category_filters)
    end

    def self.delete_filter(category_id, room, filter, tags = [])
      category_filters = get_filters(category_id)
      category_filters.delete_at(category_filters.index({ room: room, filter: filter, tags: tags }.stringify_keys))
      PluginStore.set(DiscourseGitter::PLUGIN_NAME, category_filters_row_key(category_id), category_filters)
    end

    # Handle repeated notifications
    def self.notify(post_id)
      post = Post.find_by(id: post_id)
      return if post.blank? || post.post_type != Post.types[:regular] || !guardian.can_see?(post)

      topic = post.topic
      return if topic.blank? || topic.archetype == Archetype.private_message

      filters = get_filters(topic.category_id) | get_filters

      notified_rooms = []

      filters.each do |filter|
        topic_tags = SiteSetting.tagging_enabled? && topic.tags.pluck(:name)

        next if SiteSetting.tagging_enabled? && filter[:tags].present? && (topic_tags & filter[:tags]).count.zero?
        next if (filter[:filter] == 'mute') || (!post.is_first_post? && filter[:filter] == 'follow')

        uri = URI.parse(get_room(filter[:room])[:webhook])

        begin
          response = Net::HTTP.post_form(uri, message: gitter_message(post))
          notified_rooms << filter[:room] if response.body == 'OK'
        rescue TypeError
          # ignored
        end
      end
      notified_rooms
    end

    def self.get_filters(category_id = nil)
      PluginStore.get(DiscourseGitter::PLUGIN_NAME, category_filters_row_key(category_id)) || []
    end

    def self.category_filters_row_key(category_id)
      "category_#{category_id.present? ? category_id : '*'}"
    end

    def self.get_room(room_uri)
      @rooms ||= {}
      @rooms[room_uri] ||= PluginStore.get(DiscourseGitter::PLUGIN_NAME, "integration_#{room_uri}")
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
        cleared_filters = PluginStore.cast_value(row.type_name, row.value).reject { |rule| rule[:room] == room }
        row.update(value: cleared_filters.to_json)
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
