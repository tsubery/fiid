class MediaItemsController < ApplicationController
  before_action :set_media_item
  before_action :set_video, only: %i[audio video]
  include ActionController::Live

  def article
    render :article, layout: false
  end

  def audio
    stream(audio: true)
  end

  def video
    stream(audio: false)
  end

  private

  def stream(audio:)
    response.headers['Content-Type'] = audio ? 'audio/mp4' : 'video/mp4'
    begin
      @video.each_chunk(audio: audio, &response.stream.method(:write))
    rescue => e
      response.headers['Content-Type'] = 'text/plain'
      render plain: e.inspect, status: :internal_server_error
    ensure
      response.stream.close
    end
  end

  def set_media_item
    @media_item = MediaItem.find(params[:id] || params[:media_item_id])
  end

  def set_video
    @video = Youtube::Video.new(@media_item.url)

    if @video.nil?
      render plain: :unknown_video, status: :unprocessable_entity
    end
  end
end
