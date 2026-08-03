require "test_helper"

class LibraryTest < ActiveSupport::TestCase
  # Validations
  test "validates episode_count is greater than or equal to zero" do
    library = libraries(:one)
    library.episode_count = -1
    assert_not library.valid?
    assert_includes library.errors[:episode_count], "must be greater than or equal to 0"
  end

  test "allows episode_count of zero" do
    library = libraries(:one)
    library.episode_count = 0
    assert library.valid?
  end

  test "allows positive episode_count" do
    library = libraries(:one)
    library.episode_count = 100
    assert library.valid?
  end

  # Associations
  test "has many media_items" do
    library = libraries(:one)
    assert_respond_to library, :media_items
  end

  test "has many feeds" do
    library = libraries(:one)
    assert_respond_to library, :feeds
  end

  # add_media_item method
  test "add_media_item adds a media item to the library" do
    library = libraries(:one)
    library.media_items.clear
    media_item = media_items(:one)

    assert_difference -> { library.media_items.count }, 1 do
      library.add_media_item(media_item)
    end

    assert_includes library.media_items, media_item
  end

  # Constants
  test "has correct default language" do
    assert_equal 'en', Library::DEFAULT_LANGUAGE
  end

  test "has correct default episode count" do
    assert_equal 200, Library::DEFAULT_EPISODE_COUNT
  end

  test "has correct minimum duration seconds" do
    assert_equal 120, Library::MIN_DURATION_SECONDS
  end

  # generate_podcast tests
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

  test "generates podcast with media items" do
    library = libraries(:one)
    library.update!(audio: true, video: false)

    media_item = MediaItem.create!(
      url: "http://test.local/video1",
      guid: "http://test.local/video1",
      title: "Test Video",
      description: "A test video description",
      author: "Test Author",
      thumbnail_url: "http://test.local/thumb.jpg",
      duration_seconds: 300,
      updated_at: Time.current,
      feed: feeds(:one),
      reachable: true
    )
    library.media_items = [media_item]

    link = "https://test.local/mypodcast"
    podcast_xml = library.generate_podcast(
      link,
      audio_url: ->(id) { "audio://#{id}" },
      video_url: ->(id) { "video://#{id}" }
    ).to_xml

    assert_includes podcast_xml, "<title>Test Video</title>"
    assert_includes podcast_xml, "<description>A test video description</description>"
    assert_includes podcast_xml, "<itunes:author>Test Author</itunes:author>"
    assert_includes podcast_xml, "audio://#{media_item.id}"
  end

  test "filters out media items shorter than MIN_DURATION_SECONDS" do
    library = libraries(:one)
    library.update!(audio: true, video: false)

    short_item = MediaItem.create!(
      url: "http://test.local/short",
      guid: "http://test.local/short",
      title: "Short Video",
      description: "Too short",
      author: "Author",
      thumbnail_url: "http://test.local/thumb.jpg",
      duration_seconds: 60,
      feed: feeds(:one),
      reachable: true
    )

    long_item = MediaItem.create!(
      url: "http://test.local/long",
      guid: "http://test.local/long",
      title: "Long Video",
      description: "Long enough",
      author: "Author",
      thumbnail_url: "http://test.local/thumb.jpg",
      duration_seconds: 300,
      feed: feeds(:one),
      reachable: true
    )

    library.media_items = [short_item, long_item]

    link = "https://test.local/mypodcast"
    podcast_xml = library.generate_podcast(
      link,
      audio_url: ->(id) { "audio://#{id}" },
      video_url: ->(id) { "video://#{id}" }
    ).to_xml

    assert_not_includes podcast_xml, "Short Video"
    assert_includes podcast_xml, "Long Video"
  end

  test "limits media items to episode_count" do
    library = libraries(:one)
    library.update!(audio: true, video: false, episode_count: 2)

    items = 5.times.map do |i|
      MediaItem.create!(
        url: "http://test.local/video#{i}",
        guid: "http://test.local/video#{i}",
        title: "Video #{i}",
        description: "Description #{i}",
        author: "Author",
        thumbnail_url: "http://test.local/thumb.jpg",
        duration_seconds: 300,
        updated_at: Time.current - i.days,
        feed: feeds(:one),
        reachable: true
      )
    end

    library.media_items = items

    link = "https://test.local/mypodcast"
    podcast_xml = library.generate_podcast(
      link,
      audio_url: ->(id) { "audio://#{id}" },
      video_url: ->(id) { "video://#{id}" }
    ).to_xml

    # Should only include the 2 most recent items (episode_count: 2)
    assert_includes podcast_xml, "Video 0"
    assert_includes podcast_xml, "Video 1"
    assert_not_includes podcast_xml, "Video 2"
    assert_not_includes podcast_xml, "Video 3"
    assert_not_includes podcast_xml, "Video 4"
  end

  test "generates both audio and video items when both enabled" do
    library = libraries(:one)
    library.update!(audio: true, video: true)

    media_item = MediaItem.create!(
      url: "http://test.local/media",
      guid: "http://test.local/media",
      title: "Test Media",
      description: "A test description",
      author: "Author",
      thumbnail_url: "http://test.local/thumb.jpg",
      duration_seconds: 300,
      feed: feeds(:one),
      reachable: true
    )
    library.media_items = [media_item]

    link = "https://test.local/mypodcast"
    podcast_xml = library.generate_podcast(
      link,
      audio_url: ->(id) { "audio://#{id}" },
      video_url: ->(id) { "video://#{id}" }
    ).to_xml

    assert_includes podcast_xml, "audio://#{media_item.id}"
    assert_includes podcast_xml, "video://#{media_item.id}"
  end

  test "excludes items with nil duration_seconds due to has_all_details check" do
    library = libraries(:one)
    library.update!(audio: true, video: false)

    item_with_nil_duration = MediaItem.create!(
      url: "http://test.local/nil-duration",
      guid: "http://test.local/nil-duration",
      title: "Nil Duration Video",
      description: "Has nil duration",
      author: "Author",
      thumbnail_url: "http://test.local/thumb.jpg",
      duration_seconds: nil,
      feed: feeds(:one),
      reachable: true
    )

    library.media_items = [item_with_nil_duration]

    link = "https://test.local/mypodcast"
    podcast_xml = library.generate_podcast(
      link,
      audio_url: ->(id) { "audio://#{id}" },
      video_url: ->(id) { "video://#{id}" }
    ).to_xml

    # Items pass the WHERE clause but fail has_all_details? since duration_seconds is required
    assert_not_includes podcast_xml, "Nil Duration Video"
  end
end
