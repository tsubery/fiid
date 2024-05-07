require_relative 'deps'
require 'sinatra'

class App < Sinatra::Base
  def base_url(request, path)
    (request.url.split('/').first(3) + [path]).join('/')
  end

  get '/feeds/videos.xml' do
    podcast = youtube
              .get
              &.parse
              &.generate_podcast(
                request.url,
                episode_base_url,
                params.fetch("filter", {})
              )&.to_xml

    content_type youtube.content_type
    status youtube.code
    podcast || youtube.body
  end

  get '/listen' do
    video = Cache.find_or_create_video(params[:v])
    if video.audio_path
      content_type video.audio_mime_type

      stream do |body|
        video.each_audio_chunk { |c| body << c }
      end
    else
      status 500
      content_type "text/plain"
      video.download_log
    end
  end
end
