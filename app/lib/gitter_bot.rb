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
          client.subscribe("/api/v1/rooms/#{room_id}/chatMessages") { |m| handle_message(m) } if room_id.present?
        end
      end
    end
  end

  def self.handle_message(message)
    puts 'NEW MESSAGE'
    puts message.inspect
  end

  def self.subscribe_room(room)
    room_id = fetch_room_id(room)
    @faye_thread[:faye_client].subscribe("/api/v1/rooms/#{room_id}/chatMessages") { |m| handle_message(m) } if room_id.present?
  end

  def self.unsubscribe_room(room)
    room_id = fetch_room_id(room)
    @faye_thread[:faye_client].unsubscribe("/api/v1/rooms/#{room_id}/chatMessages") if room_id.present?
  end

  def self.fetch_room_id(room)
    @rooms ||= {}
    unless @rooms.key? room
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
end
