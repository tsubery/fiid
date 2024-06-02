class YoutubePlaylistFeed < YoutubeFeed
  def normalized_url
    html_url
  end

  def html_url
    "https://www.youtube.com/playlist?list=#{youtube_id}"
  end

  def self.parse_id(url)
    if %r{\Ahttps://(www\.)?youtube.com/playlist} =~ url
      parsed_query = Rack::Utils.parse_nested_query(URI.parse(url).query)
      parsed_query["playlist_id"] || parsed_query["list"]
    end
  end

  DAY_SECONDS = 60 * 60 * 24
  def recent_media_items(*)
    response = Youtube::CLI.get_playlist_information(youtube_id)
    @episodes = response.lines.map do |line|
      parsed = JSON.parse(line)
      video = Youtube::Video.from_id(parsed.fetch("id"))
      media_items.find_by(guid: video.guid) ||
        media_items.find_by(url: video.url) ||
        media_items.new(
          author: parsed["uploader"] || '',
          description: parsed["description"] || '',
          duration_seconds: parsed["duration"],
          guid: video.guid,
          title: [title, parsed["title"]].compact.join(" - "),
          url: video.url
        )
    end
  end
end
