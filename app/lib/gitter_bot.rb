require 'json'

class GitterBot
  class ClientAuth
    def outgoing(message, callback)
      if message['channel'] == '/meta/handshake'
        message['ext'] ||= {}
        message['ext']['token'] = GitterBot.user_token
      end
      callback.call(message)
    end
  end

  def self.init(token = nil, force = false)
    return if @faye_thread.try(:alive?)
    return unless SiteSetting.gitter_bot_enabled || (force && SiteSetting.gitter_bot_user_token.present?)
    @user_token = token || SiteSetting.gitter_bot_user_token

    @faye_thread = Thread.new do
      EM.run do
        Thread.current[:faye_client] = Faye::Client.new('https://ws.gitter.im/faye', timeout: 60, retry: 5, interval: 1)
        Thread.current[:faye_client].add_extension(ClientAuth.new)

        rooms_names.each { |room| subscribe_room(room) }
        @running = true
      end
    end
  end

  def self.stop
    EM.stop_event_loop if @running
    @faye_thread.try(:kill)
    @running = false
    @rooms = {}
  end

  def self.running?
    @running ||= false
  end

  def self.subscribe_room(room)
    room_id = fetch_room_id(room)
    p "room for #{room} :  #{room_id} -"
    if room_id.present?
      @faye_thread[:faye_client].subscribe("/api/v1/rooms/#{room_id}/chatMessages") do |m|
        handle_message(m, room, room_id)
      end
    end
  end

  def self.unsubscribe_room(room)
    room_id = fetch_room_id(room)
    @faye_thread[:faye_client].unsubscribe("/api/v1/rooms/#{room_id}/chatMessages") if room_id.present?
  end

  def self.permitted_users
    SiteSetting.gitter_command_users.split(',').map(&:strip)
  end

  def self.user_token
    @user_token
  end

  def self.rooms_names
    PluginStoreRow.where(plugin_name: DiscourseGitter::PLUGIN_NAME).where('key LIKE ?', 'integration_%').map do |row|
      row.key.gsub('integration_', '')
    end
  end

  def self.handle_message(message, room, room_id)
    p 'GITTER MESSAGE'
    p message.inspect
    text = message.dig('model', 'text')
    return if text.nil?
    tokens = text.split
    if tokens.first == '/discourse'
      user = message.dig('model', 'fromUser', 'username')
      if permitted_users.include? user
        action = tokens.second.try(:downcase)
        case action
        when 'status'
          send_message(room_id, status_message(room))
        when 'remove'
          remove_rule(room, tokens.third)
        when 'watch', 'follow', 'mute'
          add_rule(room, action, tokens[2..-1].join)
        when 'help'
          send_message(room_id, I18n.t('gitter.bot.help'))
        else
          send_message(room_id, I18n.t('gitter.bot.nonexistent_command'))
        end
      else
        send_message(room_id, I18n.t('gitter.bot.unauthorized_user', user: user))
      end
    end
  rescue => e
    p e.message
    p e.backtrace
    @running = false
    SiteSetting.gitter_bot_enabled = false
  end

  def self.send_message(room_id, text)
    url = URI.parse("https://api.gitter.im/v1/rooms/#{room_id}/chatMessages")
    req = Net::HTTP::Post.new(url.path)
    req['Accept'] = 'application/json'
    req['Authorization'] = "Bearer #{user_token}"
    req['Content-Type'] = 'application/json'
    req.body = { text: text }.to_json
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    response = http.request(req)
    response.code == '200'
  end

  def self.remove_rule(room, index)
    room_id = fetch_room_id(room)
    rules = DiscourseGitter::Gitter.get_room_rules(room)
    # The indices shown in the chat begin in 1
    index = index.to_i - 1
    if index < rules.length
      rule = rules.at index
      DiscourseGitter::Gitter.delete_rule(rule[:category_id], rule[:room], rule[:filter], rule[:tags])
      send_message(room_id, status_message(room))
    else
      send_message(room_id, I18n.t('gitter.bot.nonexistent_rule'))
    end
  end

  def self.add_rule(room, filter, params)
    room_id = fetch_room_id(room)

    tags_index = params.index('tags:')
    tags = []
    if tags_index.present?
      tags_token = params[tags_index..-1]
      params.sub!(tags_token, '')
      tags_names = tags_token.sub('tags:', '').split(',').map(&:strip)
      tags = Tag.where(name: tags_names).pluck(:name)
      tags_diff = tags_names - tags
      if tags_diff.present?
        send_message(room_id, I18n.t('gitter.bot.nonexistent_tags', tags: tags_diff))
        return
      end
    end

    # if category present
    if params.present?
      category = Category.find_by(name: params.strip)
      if category
        category_id = category.id
      else
        send_message(room_id, I18n.t('gitter.bot.nonexistent_category', category: params.strip))
        return
      end
    elsif tags_index.present?
      category_id = nil
    else
      send_message(room_id, I18n.t('gitter.bot.no_new_rule_params'))
      return
    end

    DiscourseGitter::Gitter.set_rule(category_id, room, filter, tags)
    send_message(room_id, status_message(room))
  end

  def self.status_message(room)
    rules = DiscourseGitter::Gitter.get_room_rules(room)
    message = I18n.t('gitter.bot.status_title').dup
    rules.each_with_index do |rule, i|
      filter = I18n.t("gitter.bot.filters.#{rule[:filter]}")
      category = Category.find_by(id: rule[:category_id]).try(:name) || I18n.t('gitter.bot.all_categories')
      tags = Tag.where(name: rule[:tags]).map(&:name)
      with_tags = tags.present? ? I18n.t('gitter.bot.with_tags', tags: tags) : ''
      message << I18n.t('gitter.bot.filter', index: i + 1, filter: filter, category: category, with_tags: with_tags)
    end
    message
  end

  def self.fetch_room_id(room)
    @rooms ||= {}
    unless @rooms.key?(room)
      @rooms = fetch_rooms.map { |r| [r['name'], r['id']] }.to_h
    end
    @rooms[room]
  end

  def self.fetch_rooms
    url = URI.parse('https://api.gitter.im/v1/rooms')
    req = Net::HTTP::Get.new(url.path)
    req['Accept'] = 'application/json'
    req['Authorization'] = "Bearer #{user_token}"
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    response = http.request(req)
    JSON.parse(response.body)
  end
end
