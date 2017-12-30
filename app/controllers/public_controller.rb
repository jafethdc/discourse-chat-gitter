class ::DiscourseGitter::PublicController < ::ApplicationController
  requires_plugin DiscourseGitter::PLUGIN_NAME

  def post_transcript
    params.require(:secret)

    redis_key = 'gitter_integration:transcript:' + params[:secret]
    content = $redis.get(redis_key)

    byebug
    if content
      render json: { content: content }
      return
    end

    raise Discourse::NotFound
  end
end
