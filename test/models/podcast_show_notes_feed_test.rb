require "test_helper"

class PodcastShowNotesFeedTest < ActiveSupport::TestCase
  FEED_URL = "https://feed.podbean.com/saxostrats/feed.xml".freeze
  ARTWORK_URL = "https://pbcdn1.podbean.com/imglogo/image-logo/5709963/smc_perfect_SquareJPGtemp72_2.jpg".freeze

  def create_feed
    PodcastShowNotesFeed.create!(url: FEED_URL)
  end

  test "keeps its type and fills details from the feed" do
    VCR.use_cassette("podcast_show_notes") do
      feed = Feed.create!(url: FEED_URL, type: "PodcastShowNotesFeed")

      assert_instance_of PodcastShowNotesFeed, Feed.find(feed.id)
      assert_equal "Saxo Market Call", feed.title
      assert_equal ARTWORK_URL, feed.thumbnail_url
    end
  end

  test "recent_media_items renders show notes as an html document" do
    VCR.use_cassette("podcast_show_notes") do
      feed = create_feed
      items = feed.recent_media_items

      assert_equal 2, items.size
      item = items.first
      assert_equal "Saxo Market Call - The AI trade is down even as most stocks are way up.", item.title
      assert_equal "saxostrats.podbean.com/7b45a422-9d5f-31e1-b65e-6e931f1702e8", item.guid
      assert_equal "SaxoStrats", item.author
      assert_equal MediaItem::HTML_MIME_TYPE, item.mime_type
      assert_equal Time.utc(2026, 11, 5, 10, 51, 16), item.published_at
      assert_equal ARTWORK_URL, item.thumbnail_url
      assert item.url.start_with?(MediaItem::TEMPORARY_URL)

      assert item.html?
      doc = Nokogiri::HTML(item.description)
      assert_equal "The AI trade is down even as most stocks are way up.", doc.at_css("h1").text
      assert_equal "Saxo Market Call", doc.at_css(".podcast").text
      assert_equal "November 5, 2026 · 33 min", doc.at_css(".meta").text.strip
      assert_equal "https://mcdn.podbean.com/mf/web/ydqsetyy55h5vcwu/2026_11_05_SaxoMarketCall.mp3",
                   doc.at_css("a.button")["href"]
      assert_equal "https://saxostrats.podbean.com/e/the-ai-trade-is-down-even-as-most-stocks-are-way-up/",
                   doc.at_css("a.button.secondary")["href"]
      assert_match(/Democratic mid-term sweep/, doc.at_css(".notes").text)
      assert doc.at_css(".notes a[href='https://www.home.saxo/insights']")
    end
  end

  test "saved show notes link to the admin page and keep remote artwork" do
    VCR.use_cassette("podcast_show_notes") do
      feed = create_feed
      item = feed.recent_media_items.first
      item.save!

      assert_equal item.article_url, item.reload.url
      assert_equal ARTWORK_URL, Nokogiri::HTML(item.description).at_css("img.artwork")["src"]
    end
  end

  test "parse_duration handles seconds and clock formats" do
    assert_equal 1963, PodcastShowNotesFeed.parse_duration("1963")
    assert_equal 1963, PodcastShowNotesFeed.parse_duration("32:43")
    assert_equal 3723, PodcastShowNotesFeed.parse_duration("1:02:03")
    assert_nil PodcastShowNotesFeed.parse_duration(nil)
  end

  test "format_duration rounds to minutes" do
    assert_equal "33 min", PodcastShowNotesFeed.format_duration(1963)
    assert_equal "1 h 2 min", PodcastShowNotesFeed.format_duration(3723)
    assert_nil PodcastShowNotesFeed.format_duration(0)
    assert_nil PodcastShowNotesFeed.format_duration(nil)
  end
end
