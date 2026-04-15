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
    assert_match(/Private video/, yt.title)
    assert_not yt.reachable
  end

  test "fill_missing_info waits until video is done streaming" do
    yt = media_items(:live_video)
    yt.fill_missing_details
    assert_match(/\[LIVE\]/, yt.title)
    assert_nil yt.reachable
  end

  LIVE_INFO_DEFAULTS = {
    "id" => "stubVideoId1",
    "extractor" => "youtube",
    "title" => "Fake Stream",
    "uploader" => "Fake Uploader",
    "upload_date" => "20240101",
    "duration" => 3000,
    "description" => "fake description",
    "thumbnails" => [{ "url" => "https://example.com/thumb.jpg" }]
  }.freeze

  def stub_yt_info(overrides)
    info = LIVE_INFO_DEFAULTS.merge(overrides)
    sc = Youtube::CLI.singleton_class
    sc.send(:alias_method, :__orig_gvi, :get_video_information)
    sc.send(:define_method, :get_video_information) { |*_| info }
    yield
  ensure
    sc.send(:alias_method, :get_video_information, :__orig_gvi)
    sc.send(:remove_method, :__orig_gvi)
  end

  def with_stubbed_duration(video, value)
    video.define_singleton_method(:probe_cached_duration) { value }
    yield
  end

  def create_stubbed_video(overrides)
    feed = feeds(:fedguy_channel)
    stub_yt_info(overrides) do
      feed.media_items.create(url: "https://www.youtube.com/watch?v=stubVideoId1")
    end
  end

  test "live_status is_live marks unreachable and prefixes [LIVE]" do
    yt = create_stubbed_video("live_status" => "is_live")
    assert_nil yt.reachable
    assert_match(/\[LIVE\]/, yt.title)
  end

  test "live_status is_upcoming marks unreachable and prefixes [UPCOMING]" do
    yt = create_stubbed_video("live_status" => "is_upcoming")
    assert_nil yt.reachable
    assert_match(/\[UPCOMING\]/, yt.title)
  end

  test "live_status post_live marks unreachable and prefixes [PROCESSING]" do
    yt = create_stubbed_video("live_status" => "post_live")
    assert_nil yt.reachable
    assert_match(/\[PROCESSING\]/, yt.title)
  end

  test "live_status not_live marks reachable and adds no prefix" do
    yt = create_stubbed_video("live_status" => "not_live")
    assert_equal true, yt.reachable
    assert_no_match(/\[(LIVE|UPCOMING|PROCESSING)\]/, yt.title)
  end

  test "live_status was_live past cooldown marks reachable" do
    release = (Time.now - 10.hours).to_i
    yt = create_stubbed_video(
      "live_status" => "was_live",
      "release_timestamp" => release,
      "duration" => 3000
    )
    assert_equal true, yt.reachable
  end

  test "live_status was_live within cooldown stays unreachable" do
    release = (Time.now - 5.minutes).to_i
    yt = create_stubbed_video(
      "live_status" => "was_live",
      "release_timestamp" => release,
      "duration" => 3000
    )
    assert_nil yt.reachable
  end

  test "live_status was_live without release_timestamp marks reachable" do
    yt = create_stubbed_video(
      "live_status" => "was_live",
      "release_timestamp" => nil
    )
    assert_equal true, yt.reachable
  end

  test "flag_missing_duration! prefixes title when cached file is short" do
    video = media_items(:one)
    video.update_columns(duration_seconds: 100, title: "Original", reachable: true)
    cache_path = video.video_cache_file_path
    FileUtils.mkdir_p(File.dirname(cache_path))
    FileUtils.touch(cache_path)

    with_stubbed_duration(video, 40.0) do
      video.flag_missing_duration!
    end

    assert_equal "[60s missing] Original", video.reload.title
  ensure
    FileUtils.rm_rf(File.dirname(cache_path)) if cache_path
  end

  test "flag_missing_duration! is a no-op within threshold" do
    video = media_items(:one)
    video.update_columns(duration_seconds: 100, title: "Original", reachable: true)
    cache_path = video.video_cache_file_path
    FileUtils.mkdir_p(File.dirname(cache_path))
    FileUtils.touch(cache_path)

    with_stubbed_duration(video, 97.0) do
      video.flag_missing_duration!
    end

    assert_equal "Original", video.reload.title
  ensure
    FileUtils.rm_rf(File.dirname(cache_path)) if cache_path
  end

  test "flag_missing_duration! is idempotent" do
    video = media_items(:one)
    video.update_columns(duration_seconds: 100, title: "Original", reachable: true)
    cache_path = video.video_cache_file_path
    FileUtils.mkdir_p(File.dirname(cache_path))
    FileUtils.touch(cache_path)

    with_stubbed_duration(video, 40.0) do
      2.times { video.flag_missing_duration! }
    end

    assert_equal "[60s missing] Original", video.reload.title
  ensure
    FileUtils.rm_rf(File.dirname(cache_path)) if cache_path
  end

  test "flag_missing_duration! no-op when file missing" do
    video = media_items(:one)
    video.update_columns(duration_seconds: 100, title: "Original", reachable: true)
    FileUtils.rm_rf(File.dirname(video.video_cache_file_path))
    assert_not video.video_cached?

    with_stubbed_duration(video, 10.0) do
      video.flag_missing_duration!
    end

    assert_equal "Original", video.reload.title
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
    yt = feed.media_items.create(
      url: "https://www.youtube.com/watch?v=YfWG3g3RRVU",
      created_at: 1.week.ago
    )

    assert_equal "Joseph Wang - YouTube - ERROR: [youtube] YfWG3g3RRVU: Private video. Sign in if you've been granted access to this video\n", yt.title
    assert_equal "unknown", yt.author
    assert_equal Date.parse("1970-01-01"), yt.published_at
    assert_equal 0, yt.duration_seconds
    assert_equal "Original Video: https://www.youtube.com/watch?v=YfWG3g3RRVU\nPublished At: 1970-01-01 00:00:00 UTC\n ERROR: [youtube] YfWG3g3RRVU: Private video. Sign in if you've been granted access to this video\n", yt.description
    assert_equal "", yt.thumbnail_url
  end

  test "truncated video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(
      url: "https://www.youtube.com/watch?v=YfWG3g3RR",
      created_at: 1.week.ago
    )


    assert_equal yt.title, "Joseph Wang - YouTube - ERROR: [youtube:truncated_id] YfWG3g3RR: Incomplete YouTube ID YfWG3g3RR. URL https://www.youtube.com/watch?v=YfWG3g3RR looks truncated.\n"
    assert_equal "unknown", yt.author
    assert_equal Date.parse("1970-01-01"), yt.published_at
    assert_equal 0, yt.duration_seconds
    assert_equal "Original Video: https://www.youtube.com/watch?v=YfWG3g3RR\nPublished At: 1970-01-01 00:00:00 UTC\n ERROR: [youtube:truncated_id] YfWG3g3RR: Incomplete YouTube ID YfWG3g3RR. URL https://www.youtube.com/watch?v=YfWG3g3RR looks truncated.\n", yt.description
    assert_equal "", yt.thumbnail_url
  end

  test "missing video" do
    feed = feeds(:fedguy_channel)
    yt = feed.media_items.create(
      url: "https://www.youtube.com/watch?v=YfWG3g3RRaa",
      created_at: 1.week.ago
    )

    assert_equal  "Joseph Wang - YouTube - ERROR: [youtube] YfWG3g3RRaa: Video unavailable\n", yt.title
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

  test "feed validations" do
    mi = media_items(:one)
    assert mi.valid?
    mi.feed = nil

    assert_not media_items(:one).valid?
  end

  test "reading_list scope returns only unarchived HTML articles" do
    reading_list = MediaItem.reading_list
    assert reading_list.all? { |item| item.mime_type == MediaItem::HTML_MIME_TYPE }
    assert reading_list.all? { |item| item.archived == false }
    assert_not reading_list.include?(media_items(:article_archived))
    assert_not reading_list.include?(media_items(:one)) # video, not article
  end

  test "reading_list orders by feed priority then created_at" do
    reading_list = MediaItem.reading_list
    high_priority = media_items(:high_priority_article)
    assert_equal high_priority, reading_list.first
  end

  test "archive! sets archived to true" do
    article = media_items(:article_unarchived)
    assert_not article.archived
    article.archive!
    assert article.reload.archived
  end

  test "unarchive! sets archived to false" do
    article = media_items(:article_archived)
    assert article.archived
    article.unarchive!
    assert_not article.reload.archived
  end

  test "article? returns true for HTML mime type" do
    article = media_items(:article_unarchived)
    assert article.article?

    video = media_items(:one)
    assert_not video.article?
  end

  test "video_cache_file_path returns correct path" do
    video = media_items(:one)
    assert_equal "public/media_items/#{video.id}/video", video.video_cache_file_path
  end

  test "video_cached? returns false when cache file does not exist" do
    video = media_items(:one)
    FileUtils.rm_rf(File.dirname(video.video_cache_file_path))
    assert video.video?
    assert_not video.video_cached?
  end

  test "video_cached? returns true when cache file exists" do
    video = media_items(:one)
    cache_path = video.video_cache_file_path
    FileUtils.mkdir_p(File.dirname(cache_path))
    FileUtils.touch(cache_path)

    assert video.video_cached?
  ensure
    FileUtils.rm_rf(File.dirname(cache_path))
  end

  test "video_cached? returns false for non-video items" do
    article = media_items(:article_unarchived)
    assert_not article.video?
    assert_not article.video_cached?
  end
end
