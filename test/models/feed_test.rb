require "test_helper"

class FeedTest < ActiveSupport::TestCase
  test "sets correct type" do
    VCR.use_cassette(:feed_info) do
      feeds.each do |fixture|
        new_feed = Feed.create(url: fixture.url + 'test').reload

        assert_equal fixture.type, new_feed.type
        assert_equal fixture.class, Feed.find(new_feed.id).class
      end
    end
  end

  test "#recent_media_items for rss feed" do
    VCR.use_cassette(:rss_feed) do
      feed1 = feeds(:doomberg)
      assert_equal feed1.class, RssFeed
      items = feed1.recent_media_items
      assert_equal items.count, 20
      assert items.all?(&:url)
      assert items.all?(&:title)
      assert items.all?(&:author)
      assert items.all?(&:description)
      assert items.all?(&:published_at)
      assert_equal items.map(&:mime_type).uniq, ["text/html"]
      assert_equal items.map(&:feed).uniq, [feed1]
    end
  end

  test "#recent_media_items for youtube channel" do
    VCR.use_cassette(:youtube_channel) do
      feed2 = feeds(:two)
      assert_equal feed2.class, YoutubeChannelFeed
      items = feed2.recent_media_items
      assert_equal items.count, 15
      assert items.map(&:url).all?(&:present?)
      assert items.map(&:title).all?(&:present?)
      assert items.map(&:author).all?(&:present?)
      assert items.map(&:description).all?(&:present?)
      assert items.map(&:thumbnail_url).all?(&:present?)
      assert items.map(&:published_at).all?(&:present?)
      assert items.map(&:guid).all?(&:present?)
      assert_equal items.map(&:mime_type).uniq, ["video/mp4"]
      assert_equal items.map(&:feed).uniq, [feed2]
    end
  end

  test "#fill_missing_details" do
    VCR.use_cassette("doomberg") do
      t1 = feeds(:doomberg)
      t1.valid?
      assert_equal "Doomberg", t1.title
      expected_description = "Energy, finance, and the economy at-large | Doomberg readers are better informed and smartly entertained | Enter your email address below to receive free previews | Bonus access to 5 of our top articles is included in the Welcome email!"
      assert_equal expected_description, t1.description
    end
  end

  test "301 redirection" do
    VCR.use_cassette("redirection") do
      f = RssFeed.new(url: "https://thelastbearstanding.substack.com/feed")
      f.recent_media_items
      assert_equal "https://www.thelastbearstanding.com/feed", f.url
    end
  end

  test "priority validation accepts 0 and positive integers" do
    feed = feeds(:one)
    feed.priority = 0
    assert feed.valid?

    feed.priority = 100
    assert feed.valid?
  end

  test "priority validation rejects negative numbers" do
    feed = feeds(:one)
    feed.priority = -1
    assert_not feed.valid?
    assert feed.errors[:priority].present?
  end
end
