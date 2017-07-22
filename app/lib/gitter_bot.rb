require 'json'

class GitterBot
  GITTER_API_TOKEN = SiteSetting.gitter_bot_user_token
  class ClientAuth
    def outgoing(message, callback)
      if message['channel'] == '/meta/handshake'
        message['ext'] ||= {}
        message['ext']['token'] = GITTER_API_TOKEN
      end
      callback.call(message)
    end
  end

  def self.init
    @faye_thread = Thread.new do
      return if SiteSetting.gitter_bot_user_token.blank?
      EM.run do
        client = Faye::Client.new('https://ws.gitter.im/faye', timeout: 60, retry: 5, interval: 1)
        client.add_extension(ClientAuth.new)

        Thread.current[:faye_client] = client

        rooms = PluginStoreRow.where(plugin_name: DiscourseGitter::PLUGIN_NAME).where('key LIKE ?', 'integration_%').map do |row|
          row.key.gsub('integration_', '')
        end

        rooms.each do |room|
          room_id = fetch_room_id(room)
          client.subscribe("/api/v1/rooms/#{room_id}/chatMessages") { |m| handle_message(m, room, room_id) } if room_id.present?
        end
      end
    end
  end

  def self.handle_message(message, room, room_id)
    puts message.inspect
    tokens = message.dig('model', 'text').split
    is_discourse_command = tokens.first == '/discourse'
    if is_discourse_command
      user = message.dig('model', 'fromUser', 'username')
      is_user_permitted = permitted_users.include? user
      if is_user_permitted
        case tokens.second.try(:downcase)
        when 'status'
          send_message(room_id, status_message(room))
        when 'remove'
          handle_remove_rule(room, room_id, tokens.third)
        else
          send_message(room_id, I18n.t('gitter.bot.nonexistent_command'))
        end
      else
        send_message(room_id, I18n.t('gitter.bot.unauthorized_user', user: user))
      end
    end
  end

  def self.subscribe_room(room)
    room_id = fetch_room_id(room)
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
    req['Authorization'] = "Bearer #{GITTER_API_TOKEN}"
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    response = http.request(req)
    JSON.parse(response.body)
  end

  def self.permitted_users
    SiteSetting.gitter_command_users.split(',').map(&:strip)
  end

  def self.send_message(room_id, text)
    url = URI.parse("https://api.gitter.im/v1/rooms/#{room_id}/chatMessages")
    req = Net::HTTP::Post.new(url.path)
    req['Accept'] = 'application/json'
    req['Authorization'] = "Bearer #{GITTER_API_TOKEN}"
    req['Content-Type'] = 'application/json'
    req.body = { text: text }.to_json
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    response = http.request(req)
    JSON.parse(response.body)
  end

  def self.status_message(room)
    rules = DiscourseGitter::Gitter.get_room_rules(room)
    message = "__#{I18n.t('gitter.bot.status_title')}__\n"
    rules.each_with_index do |rule, i|
      filter = I18n.t("gitter.bot.filters.#{rule[:filter]}")
      category = Category.find_by(id: rule[:category_id]).try(:name) || I18n.t('gitter.bot.all_categories')
      tags = Tag.where(name: rule[:tags]).map(&:name)
      with_tags = tags.present? ? I18n.t('gitter.bot.with_tags', tags: tags) : ''
      message += I18n.t('gitter.bot.filter', index: i + 1, filter: filter, category: category, with_tags: with_tags)
    end
    "> #{message}"
  end

  def self.handle_remove_rule(room, room_id, index)
    rules = DiscourseGitter::Gitter.get_room_rules(room)
    if (index.to_i - 1) < rules.length
      rule = rules.at(index.to_i - 1)
      DiscourseGitter::Gitter.delete_rule(rule[:category_id], rule[:room], rule[:filter], rule[:tags])
      send_message(room_id, status_message(room))
    else
      send_message(room_id, I18n.t('gitter.bot.nonexistent_rule'))
    end
  end
end
