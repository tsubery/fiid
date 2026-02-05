require "test_helper"

class LibrariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("HOSTNAME")
  end

  test "podcast returns RSS XML for valid library" do
    library = libraries(:one)

    get "/podcasts/#{library.id}"

    assert_response :success
    assert_equal "application/rss+xml; charset=utf-8", response.content_type
  end

  test "podcast returns 404 for non-existent library" do
    get "/podcasts/999999"

    assert_response :not_found
  end

  test "podcast XML contains library metadata" do
    library = libraries(:one)

    get "/podcasts/#{library.id}"

    assert_response :success
    assert_includes response.body, "<title>#{library.title}</title>"
    assert_includes response.body, "<description>#{library.description}</description>"
    assert_includes response.body, "<author>#{library.author}</author>"
  end

  test "podcast XML contains proper RSS structure" do
    library = libraries(:one)

    get "/podcasts/#{library.id}"

    assert_response :success
    assert_includes response.body, '<?xml version="1.0" encoding="UTF-8"?>'
    assert_includes response.body, '<rss'
    assert_includes response.body, 'xmlns:itunes='
    assert_includes response.body, '<channel>'
  end

  test "podcast includes media items with sufficient duration" do
    library = libraries(:one)
    library.media_items.clear

    media_item = MediaItem.create!(
      url: "http://test.local/podcast-episode",
      guid: "http://test.local/podcast-episode",
      title: "Test Episode Title",
      description: "Test episode description",
      author: "Test Author",
      thumbnail_url: "http://test.local/thumb.jpg",
      duration_seconds: 300,
      feed: feeds(:one),
      reachable: true
    )
    library.media_items << media_item
    library.update!(audio: true)

    get "/podcasts/#{library.id}"

    assert_response :success
    assert_includes response.body, "Test Episode Title"
  end

  test "podcast excludes media items with short duration" do
    library = libraries(:one)
    library.media_items.clear

    short_item = MediaItem.create!(
      url: "http://test.local/short-episode",
      guid: "http://test.local/short-episode",
      title: "Short Episode Should Not Appear",
      description: "Too short",
      author: "Author",
      thumbnail_url: "http://test.local/thumb.jpg",
      duration_seconds: 60,
      feed: feeds(:one),
      reachable: true
    )
    library.media_items << short_item
    library.update!(audio: true)

    get "/podcasts/#{library.id}"

    assert_response :success
    assert_not_includes response.body, "Short Episode Should Not Appear"
  end

  test "podcast respects episode_count limit" do
    library = libraries(:one)
    library.media_items.clear
    library.update!(audio: true, episode_count: 2)

    base_time = Time.utc(2024, 1, 15, 12, 0, 0)
    travel_to base_time do
      5.times do |i|
        item = MediaItem.create!(
          url: "http://test.local/episode-#{i}",
          guid: "http://test.local/episode-#{i}",
          title: "Episode Number #{i}",
          description: "Description #{i}",
          author: "Author",
          thumbnail_url: "http://test.local/thumb.jpg",
          duration_seconds: 300,
          updated_at: base_time - i.hours,
          feed: feeds(:one),
          reachable: true
        )
        library.media_items << item
      end

      get "/podcasts/#{library.id}"

      assert_response :success
      # Should only have the 2 most recent episodes
      assert_includes response.body, "Episode Number 0"
      assert_includes response.body, "Episode Number 1"
      assert_not_includes response.body, "Episode Number 2"
    end
  end

  test "podcast uses request URL as link" do
    library = libraries(:one)
    hostname = ENV.fetch("HOSTNAME")

    get "/podcasts/#{library.id}"

    assert_response :success
    assert_includes response.body, "<link>http://#{hostname}/podcasts/#{library.id}</link>"
  end
end
