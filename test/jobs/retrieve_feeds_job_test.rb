require "test_helper"

class RetrieveFeedsJobTest < ActiveJob::TestCase
  test "successfull new youtube channel feed" do
    feed = feeds(:fedguy_channel)
    library = feed.libraries.create(title: :library1)
    assert_nil feed.last_sync
    assert_equal 0, feed.media_items.count
    VCR.use_cassette("fedguy-channel") do
      RetrieveFeedsJob.new.perform(feed.id)
    end
    feed.reload
    assert_equal 15, feed.media_items.count
    assert_equal 15, library.media_items.count
    assert_in_delta feed.last_sync, Time.current, 1
    assert_equal "", feed.fetch_error_message

    last_item = feed.media_items.last
    last_item_url = last_item.url
    last_item.destroy!
    feed.update(etag: 'foo')
    # last item recognized as new and restored
    VCR.use_cassette("fedguy-channel") do
      RetrieveFeedsJob.new.perform(feed.id)
    end
    feed.reload
    assert_equal "", feed.fetch_error_message
    assert_equal 15, feed.media_items.count
    assert_equal 15, library.media_items.count
    assert_in_delta feed.last_sync, Time.current, 1
    assert_equal last_item_url, feed.media_items.last.url
    assert_equal "", feed.fetch_error_message
  end

  test "non existent channel feed" do
    feed = feeds(:malformed_channel)
    library = feed.libraries.create(title: :library1)
    assert_nil feed.last_sync
    assert_equal 0, feed.media_items.count
    VCR.use_cassette("non-existent-channel") do
      RetrieveFeedsJob.new.perform(feed.id)
      feed.reload
      assert_equal 0, feed.media_items.count
      assert_equal 0, library.media_items.count
      assert_nil feed.last_sync
      assert_equal "Error fetching feed ##{feed.id}: response code 404", feed.fetch_error_message

      feed.update!(url: feed.url + 'g') # restore missing character
      RetrieveFeedsJob.new.perform(feed.id)
      feed.reload

      # Remove error message when successful
      assert_in_delta feed.last_sync, Time.current, 1
      assert_equal 15, feed.media_items.count
      assert_equal "", feed.fetch_error_message
    end
  end

  test "successfull new youtube playlist feed" do
    feed = feeds(:playlist)
    library = feed.libraries.create(title: :library1)
    assert_nil feed.last_sync
    assert_equal 0, feed.media_items.count
    RetrieveFeedsJob.new.perform(feed.id)
    feed.reload
    assert_equal 25, feed.media_items.count
    assert_equal 25, library.media_items.count
    assert_equal "https://www.youtube.com/watch?v=Jm_lAk4u5uA", feed.media_items.first.url
    assert_equal "https://www.youtube.com/watch?v=vPuyDbQwfHs", feed.media_items.last.url
    assert_in_delta feed.last_sync, Time.current, 1
    assert_equal "", feed.fetch_error_message

    last_item = feed.media_items.last
    last_item_url = last_item.url
    last_item.destroy!
    # last item recognized as new and restored
    RetrieveFeedsJob.new.perform(feed.id)
    feed.reload
    assert_equal "", feed.fetch_error_message
    assert_equal 25, feed.media_items.count
    assert_equal 25, library.media_items.count
    assert_equal "https://www.youtube.com/watch?v=Jm_lAk4u5uA", feed.media_items.first.url
    assert_equal "https://www.youtube.com/watch?v=vPuyDbQwfHs", feed.media_items.last.url
    assert_in_delta feed.last_sync, Time.current, 1
    assert_equal last_item_url, feed.media_items.last.url
    assert_equal "", feed.fetch_error_message
  end

  test "new rss feed does not load old articles" do
    feed = feeds(:doomberg)
    library = feed.libraries.create(title: :pocket, type: "PocketLibrary")
    VCR.use_cassette("doomberg") do
      RetrieveFeedsJob.new.perform(feed.id)
    end
    feed.reload
    assert_equal 20, feed.media_items.count
    assert_equal 0, library.media_items.count
    assert_equal "", feed.fetch_error_message
    assert_in_delta feed.last_sync, Time.current, 1

    # as if the articles are new
    feed.media_items.destroy_all
    feed.update(etag: 'foo')
    outbox = []
    PocketClient.set_outbox(outbox)
    VCR.use_cassette("doomberg") do
      RetrieveFeedsJob.new.perform(feed.id)
    end
    feed.reload
    assert_equal 20, feed.media_items.count
    assert_equal 20, library.media_items.count
    assert_equal feed.media_items.map(&:url).sort, outbox.sort
    assert_equal library.media_items.map(&:url).sort, outbox.sort
    assert_in_delta feed.last_sync, Time.current, 1
    PocketClient.set_outbox(nil)
  end

  test "pocket feed" do
    feed = feeds(:pocket)
    library1 = libraries(:one)
    feed.libraries << library1
    VCR.use_cassette("pocket-list") do
      RetrieveFeedsJob.new.perform(feed.id)
    end
    feed.reload
    assert_equal "", feed.fetch_error_message
    assert_equal 2, feed.media_items.count
    assert_equal library1.media_items, feed.media_items
  end
end
