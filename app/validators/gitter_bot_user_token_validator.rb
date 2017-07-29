class GitterBotUserTokenValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return false if val.blank?
    return false unless gitter_token_valid?(val)
    GitterBot.stop
    GitterBot.init
    true
  end

  def error_message
    I18n.t('site_settings.errors.gitter_bot_user_nonexistent')
  end

  private

  def gitter_token_valid?(token)
    url = URI.parse('https://api.gitter.im/v1/user')
    req = Net::HTTP::Get.new(url.path)
    req['Accept'] = 'application/json'
    req['Authorization'] = "Bearer #{token}"
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    response = http.request(req)
    response.code == '200'
  end
end
