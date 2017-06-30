module DiscourseGitter
  class Gitter
    def self.notify(post_id)
      post = Post.find_by(id: post_id)
      return if post.blank? || post.post_type != Post.types[:regular] || !guardian.can_see?(post)

      topic = post.topic
      return if topic.blank? || topic.archetype == Archetype.private_message

      precedence = { 'mute' => 0, 'watch' => 1, 'follow' => 1 }

      uniq_func = proc { |item| item.values_at(:room, :tags) }
      sort_func = proc { |item| precedence[item[:filter]] }

      filters = get_filters(topic.category_id) | get_filters

      responses = []

      filters.sort_by(&sort_func).uniq(&uniq_func).each do |filter|
        topic_tags = SiteSetting.tagging_enabled? && topic.tags.present? ? topic.tags.pluck(:name) : []

        next if SiteSetting.tagging_enabled? && filter[:tags].present? && (topic_tags & filter[:tags]).count.zero?
        next if (filter[:filter] == 'mute') || (!post.is_first_post? && filter[:filter] == 'follow')

        room = get_room(filter[:room])
        uri = URI.parse(room[:webhook])
        responses << Net::HTTP.post_form(uri, message: gitter_message(post))
      end
      responses
    end

    def self.get_filters(category_id = nil)
      PluginStore.get(::Gitter::PLUGIN_NAME, category_filters_row_key(category_id)) || []
    end

    def self.category_filters_row_key(category_id)
      "category_#{category_id.present? ? category_id : '*'}"
    end

    def self.get_room(room_uri)
      @rooms ||= {}
      @rooms[room_uri] ||= PluginStore.get(::Gitter::PLUGIN_NAME, "integration_#{room_uri}")
    end

    def self.gitter_message(post)
      display_name = post.user.username
      topic = post.topic
      parent_category = topic.category.parent_category
      category_name = parent_category ? "[#{parent_category.name}/#{topic.category.name}]" : "[#{topic.category.name}]"

      "[__#{display_name}__ - #{topic.title} - #{category_name}](#{post.full_url})"
    end

    def self.guardian
      Guardian.new(User.find_by(username: 'system'))
    end
  end
end
