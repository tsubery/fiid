class LibrariesController < ApplicationController
  def podcast
    @library = Library.find(params["id"])
    @library.feeds
      .where(type: YoutubeChannelFeed.name)
      .where(
        "last_sync IS NULL or last_sync < ?", 30.minutes.ago
      ).pluck(:id).map do |feed_id|
        Thread.new { RetrieveFeedsJob.new.perform(feed_id) }
      end.each(&:join)

      podcast = @library.generate_podcast(
        request.url,
        video_url: method(:media_item_video_url),
        audio_url: method(:media_item_audio_url)
      )
      if Nokogiri::XML::Builder === podcast
        render xml: podcast, content_type: 'application/rss+xml'
      else
        # must be an exception
        render plain: podcast.inspect
      end
  end
end
