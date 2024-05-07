require "test_helper"

class MediaItemTest < ActiveSupport::TestCase
  test "creating a youtube video fills missing info" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: media_items(:youtube_video).url)
    assert_equal yt.title, "Markets Weekly May 4, 2024"
    assert_equal yt.author, "Joseph Wang"
    assert_equal yt.published_at, Date.parse("2024-05-04")
    assert_equal yt.duration_seconds, 1045
    assert_equal yt.description,
                 "Original Video: https://www.youtube.com/watch?v=2gqjFoVkHbo\nPublished At: 2024-05-04 00:00:00 UTC\n #federalreserve   #marketsanalysis \nUS Labor Market Softening\r\nQRA Debrief\r\nJapan Finally Intervenes (twice!)\n\n00:00 - Intro \n1:10 - US Labor Market Softening\n4:49 - QRA Debrief\n10:25 - Japan Finally Intervenes (twice!)\n\n\nFor my latest thoughts:\nwww.fedguy.com\n\nFor macro courses:\nwww.centralbanking101.com\n\nMy best seller on monetary policy:\nhttps://www.amazon.com/Central-Banking-101-Joseph-Wang/dp/0999136747"
    assert_equal yt.thumbnail_url, "https://i.ytimg.com/vi_webp/2gqjFoVkHbo/maxresdefault.webp"
  end

  test "creating a private youtube video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: "https://www.youtube.com/watch?v=zOIOsej4xE8")
    refute yt.reachable
  end

  test "embedding images and resolving links" do
    original_html = File.read("test/fixtures/articles/substack_email.html")
    VCR.use_cassette("embedded-images-test", record: :new_episodes) do
      feed = MediaItem.create(description: original_html)
      feed.embed_images_and_resolve_links
      # File.write("test/fixtures/articles/substack_email.embedded.html", feed.description)
      refute feed.description.match?(%r{ href="https://substack\.com/redirect/})
      assert_equal File.read("test/fixtures/articles/substack_email.embedded.html"), feed.description
    end
  end

  test "private video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: "https://www.youtube.com/watch?v=YfWG3g3RRVU")

    assert_equal yt.title, "Private video. Sign in if you've been granted access to this video"
    assert_equal yt.author, "unknown"
    assert_equal yt.published_at, Date.parse("1970-01-01")
    assert_equal yt.duration_seconds, 0
    assert_equal yt.description, "Original Video: https://www.youtube.com/watch?v=YfWG3g3RRVU\nPublished At: 1970-01-01 00:00:00 UTC\n ERROR: [youtube] YfWG3g3RRVU: Private video. Sign in if you've been granted access to this video\n"
    assert_equal yt.thumbnail_url, ""
  end

  test "truncated video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: "https://www.youtube.com/watch?v=YfWG3g3RR")

    assert_equal yt.title, "//www.youtube.com/watch?v=YfWG3g3RR looks truncated."
    assert_equal yt.author, "unknown"
    assert_equal yt.published_at, Date.parse("1970-01-01")
    assert_equal yt.duration_seconds, 0
    assert_equal yt.description, "Original Video: https://www.youtube.com/watch?v=YfWG3g3RR\nPublished At: 1970-01-01 00:00:00 UTC\n ERROR: [youtube:truncated_id] YfWG3g3RR: Incomplete YouTube ID YfWG3g3RR. URL https://www.youtube.com/watch?v=YfWG3g3RR looks truncated.\n"
    assert_equal yt.thumbnail_url, ""
  end

  test "missing video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(url: "https://www.youtube.com/watch?v=YfWG3g3RRaa")

    assert_equal yt.title, "Video unavailable"
    assert_equal yt.author, "unknown"
    assert_equal yt.published_at, Date.parse("1970-01-01")
    assert_equal yt.duration_seconds, 0
    assert_equal yt.description, "Original Video: https://www.youtube.com/watch?v=YfWG3g3RRaa\nPublished At: 1970-01-01 00:00:00 UTC\n ERROR: [youtube] YfWG3g3RRaa: Video unavailable\n"
    assert_equal yt.thumbnail_url, ""
  end

  test "url validations" do
    mi = media_items(:one)
    assert mi.valid?

    mi.url = "'http://asdf.com"
    refute mi.valid?

    mi.url = "http://asd'f.com"
    refute mi.valid?
  end
end
