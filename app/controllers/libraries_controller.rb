class LibrariesController < ApplicationController
  def podcast
    @library = Library.find(params["id"])
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
