class MediaItemsController < ApplicationController
  before_action :set_media_item
  before_action :set_video, only: %i[audio video]
  include ActionController::Live

  def article
    @html = @media_item.description.html_safe
    if @media_item.html?
      render html: @html
    else
      render :article, layout: false
    end
  end

  def audio
    stream(audio: true)
  end

  def video
    stream(audio: false)
  end

  private

  def stream(audio: )
    response.headers['Content-Type'] = audio ? 'audio/mp4' : 'video/mp4'
    begin
      @video.each_chunk(audio: audio, &response.stream.method(:write))
    rescue => e
      response.headers['Content-Type'] = 'text/plain'
      render plain: e.inspect, status: 500
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
      render plain: :unknown_video, status: 422
    end
  end
end