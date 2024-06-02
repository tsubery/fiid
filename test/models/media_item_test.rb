require "test_helper"

class MediaItemTest < ActiveSupport::TestCase
  test "creating a youtube video fills missing info" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: media_items(:youtube_video).url)
    assert_equal "Joseph Wang - YouTube - Markets Weekly May 4, 2024", yt.title
    assert_equal "Joseph Wang", yt.author
    assert_equal Date.parse("2024-05-04"), yt.published_at
    assert_equal 1045, yt.duration_seconds
    assert_equal yt.description,
                 "Original Video: https://www.youtube.com/watch?v=2gqjFoVkHbo\nPublished At: 2024-05-04 00:00:00 UTC\n #federalreserve   #marketsanalysis \nUS Labor Market Softening\r\nQRA Debrief\r\nJapan Finally Intervenes (twice!)\n\n00:00 - Intro \n1:10 - US Labor Market Softening\n4:49 - QRA Debrief\n10:25 - Japan Finally Intervenes (twice!)\n\n\nFor my latest thoughts:\nwww.fedguy.com\n\nFor macro courses:\nwww.centralbanking101.com\n\nMy best seller on monetary policy:\nhttps://www.amazon.com/Central-Banking-101-Joseph-Wang/dp/0999136747"
    assert_equal "https://i.ytimg.com/vi_webp/2gqjFoVkHbo/maxresdefault.webp", yt.thumbnail_url
  end

  test "creating a private youtube video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: "https://www.youtube.com/watch?v=zOIOsej4xE8")
    assert_not yt.reachable
  end

  test "embedding images and resolving links" do
    original_html = File.read("test/fixtures/articles/substack_email.html")
    VCR.use_cassette("embedded-images-test", record: :new_episodes) do
      feed = MediaItem.create(description: original_html)
      feed.embed_images_and_resolve_links
      # File.write("test/fixtures/articles/substack_email.embedded.html", feed.description)
      assert_not feed.description.match?(%r{ href="https://substack\.com/redirect/})
      assert_equal File.read("test/fixtures/articles/substack_email.embedded.html"), feed.description
    end
  end

  test "private video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: "https://www.youtube.com/watch?v=YfWG3g3RRVU")

    assert_equal "Joseph Wang - YouTube - Private video. Sign in if you've been granted access to this video", yt.title
    assert_equal "unknown", yt.author
    assert_equal Date.parse("1970-01-01"), yt.published_at
    assert_equal 0, yt.duration_seconds
    assert_equal "Original Video: https://www.youtube.com/watch?v=YfWG3g3RRVU\nPublished At: 1970-01-01 00:00:00 UTC\n ERROR: [youtube] YfWG3g3RRVU: Private video. Sign in if you've been granted access to this video\n", yt.description
    assert_equal "", yt.thumbnail_url
  end

  test "truncated video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: "https://www.youtube.com/watch?v=YfWG3g3RR")

    assert_equal yt.title, "Joseph Wang - YouTube - //www.youtube.com/watch?v=YfWG3g3RR looks truncated."
    assert_equal "unknown", yt.author
    assert_equal  Date.parse("1970-01-01"), yt.published_at
    assert_equal 0, yt.duration_seconds
    assert_equal "Original Video: https://www.youtube.com/watch?v=YfWG3g3RR\nPublished At: 1970-01-01 00:00:00 UTC\n ERROR: [youtube:truncated_id] YfWG3g3RR: Incomplete YouTube ID YfWG3g3RR. URL https://www.youtube.com/watch?v=YfWG3g3RR looks truncated.\n", yt.description
    assert_equal "", yt.thumbnail_url
  end

  test "missing video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: "https://www.youtube.com/watch?v=YfWG3g3RRaa")

    assert_equal  "Joseph Wang - YouTube - Video unavailable", yt.title
    assert_equal  "unknown", yt.author
    assert_equal  Date.parse("1970-01-01"), yt.published_at
    assert_equal  0, yt.duration_seconds
    assert_equal "Original Video: https://www.youtube.com/watch?v=YfWG3g3RRaa\nPublished At: 1970-01-01 00:00:00 UTC\n ERROR: [youtube] YfWG3g3RRaa: Video unavailable\n", yt.description
    assert_equal "", yt.thumbnail_url
  end

  test "url validations" do
    mi = media_items(:one)
    assert mi.valid?

    mi.url = "'http://asdf.com"
    assert_not mi.valid?

    mi.url = "http://asd'f.com"
    assert_not mi.valid?
  end
end
