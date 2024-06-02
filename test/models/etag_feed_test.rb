require "test_helper"

class EtagFeedTest < ActiveSupport::TestCase
  test "sets correct title and description" do
    VCR.use_cassette("hoisington", record: :new_episodes) do
      feed = EtagFeed.create(url: "https://hoisington.com/economic_overview.html")
      assert_equal "Hoisington Investment Management Company - Economic Overview", feed.title
      assert_equal "Hoisington,Hoisington Investment, Hoisington Investment Management,Van Hoisington,U.S. Bonds, Dr. Lacy Hunt, Wasatch-Hoisington, David Hoisington",
                   feed.description
      assert_equal '"157f-6165f40a329b8"', feed.etag

      # when etag is known
      assert [], feed.recent_media_items

      feed.update!(etag: "foo")
      # when etag changes

      new_media_items = feed.recent_media_items
      assert_equal '"157f-6165f40a329b8"', feed.etag
      assert_equal 1, new_media_items.count
      new_mi = new_media_items.first
      assert_equal feed.title + " - #{Date.today}", new_mi.title
      assert_equal feed.description, new_mi.description
      assert_equal new_mi.author, feed.title
      assert_equal DateTime.parse("Thu, 18 Apr 2024 13:50:22.000000000 UTC +00:00"), new_mi.published_at
      assert_equal "text/html", new_mi.mime_type
      assert_equal feed.url, new_mi.url
    end
  end
end
