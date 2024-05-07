require "test_helper"

class LibraryTest < ActiveSupport::TestCase
  test "generates empty podcast" do
    library = libraries(:one)
    library.update!(media_items: [])
    link = "https://test.local/mypodcast"
    podcast_xml = library.generate_podcast(
      link,
      audio_url: ->(url) { "audio://#{url}" },
      video_url: ->(url) { "audio://#{url}" }
    ).to_xml
    expected = <<~EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:googleplay="https://www.google.com/schemas/play-podcasts/1.0/" version="2.0">
        <channel>
          <link>#{link}</link>
          <language>en</language>
          <title>#{library.title}</title>
          <description>#{library.description}</description>
          <author>#{library.author}</author>
          <image>
            <url>#{library.thumbnail_url}</url>
            <title>#{library.title}</title>
            <link>#{link}</link>
          </image>
          <googleplay:author>#{library.author}</googleplay:author>
          <googleplay:image href="#{library.thumbnail_url}"/>
          <itunes:author>#{library.author}</itunes:author>
          <itunes:owner>#{library.author}</itunes:owner>
          <itunes:title>#{library.title}</itunes:title>
          <itunes:link>#{link}</itunes:link>
          <itunes:explicit>no</itunes:explicit>
        </channel>
      </rss>
    EOF
    assert_equal expected.lines, podcast_xml.lines
  end

  test "generates podcast with one episode" do
    library = libraries(:one)
    short_video = media_items(:short_video)
    assert short_video.valid? # loads description from youtube
    library.update!(media_items: [short_video])
    podcast_xml = library.generate_podcast(
      "https://test.local",
      audio_url: ->(url) { "audio://#{url}" },
      video_url: ->(url) { "audio://#{url}" }
    ).to_xml
    podcast = Nokogiri::XML.parse(podcast_xml)
    xml_lines = podcast.at_css('item').to_s.lines
    expected_item = <<~EOF
      <item>
            <link>audio://#{short_video.id}</link>
            <title>#{short_video.title}</title>
            <description>#{short_video.description}</description>
            <guid>#{short_video.url}</guid>
            <pubDate>#{short_video.created_at.rfc822}</pubDate>
            <enclosure url="audio://#{short_video.id}" type="audio/mpeg" length="#{short_video.duration_seconds * 1000}"/>
            <itunes:image>#{short_video.thumbnail_url}</itunes:image>
            <itunes:duration>00:00:#{short_video.duration_seconds}</itunes:duration>
            <itunes:title>#{short_video.title}</itunes:title>
            <itunes:author>#{short_video.author}</itunes:author>
          </item>
    EOF
    expected_item.chomp.lines.each.with_index.each do |expected_line, i|
      assert_equal expected_line, xml_lines[i],
                   "Expected lines #{i} to be equal:\n#{expected_line.inspect}\n#{xml_lines[i].inspect}"
    end
  end
end
