class LibrariesController < ApplicationController
  def podcast
    @library = Library.find(params["id"])
    stale_feed_ids = @library.feeds
      .where(type: YoutubeChannelFeed.name)
      .where("last_sync IS NULL or last_sync < ?", 30.minutes.ago)
      .pluck(:id)
    # Runs on the request thread's connection; a thread per feed would take a
    # pool connection each.
    RetrieveFeedsJob.perform_now(stale_feed_ids)

      podcast = @library.generate_podcast(
        request.url,
        video_url: method(:media_item_video_url)
      )
      if Nokogiri::XML::Builder === podcast
        render xml: podcast, content_type: 'application/rss+xml'
      else
        # must be an exception
        render plain: podcast.inspect
      end
  end
end
