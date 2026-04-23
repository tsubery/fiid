require "test_helper"

class PodchaserGuestFeedTest < ActiveSupport::TestCase
  JIM_CHANOS_PCID = "791950"

  def create_feed(guest_name: "Jim Chanos", pcid: JIM_CHANOS_PCID)
    PodchaserGuestFeed.create!(
      url: "podchaser://#{guest_name.parameterize}",
      config: {
        "podchaser_guest_name" => guest_name,
        "podchaser_guest_pcid" => pcid
      }
    )
  end

  test "fill_missing_details resolves guest name to pcid" do
    VCR.use_cassette("podchaser_search_jim_chanos", record: :new_episodes) do
      feed = PodchaserGuestFeed.new(
        url: "anything",
        config: { "podchaser_guest_name" => "Jim Chanos" }
      )
      feed.valid?

      assert_equal JIM_CHANOS_PCID, feed.podchaser_guest_pcid
      assert_equal "PodChaser - Jim Chanos", feed.title
      assert feed.thumbnail_url.present?
    end
  end

  test "fill_missing_details always sets normalized title" do
    VCR.use_cassette("podchaser_search_jim_chanos", record: :new_episodes) do
      feed = PodchaserGuestFeed.new(
        url: "anything",
        title: "Custom Title",
        config: { "podchaser_guest_name" => "Jim Chanos" }
      )
      feed.valid?

      assert_equal "PodChaser - Jim Chanos", feed.title
    end
  end

  test "fill_missing_details normalizes url from guest name" do
    VCR.use_cassette("podchaser_search_jim_chanos", record: :new_episodes) do
      feed = PodchaserGuestFeed.new(
        url: "anything",
        config: { "podchaser_guest_name" => "Jim Chanos" }
      )
      feed.valid?

      assert_equal "podchaser://jim-chanos", feed.url
    end
  end

  test "fill_missing_details skips API call when pcid already set" do
    feed = PodchaserGuestFeed.new(
      url: "podchaser://jim-chanos",
      config: {
        "podchaser_guest_name" => "Jim Chanos",
        "podchaser_guest_pcid" => JIM_CHANOS_PCID
      }
    )
    feed.valid?
    assert_equal JIM_CHANOS_PCID, feed.podchaser_guest_pcid
    assert_equal "PodChaser - Jim Chanos", feed.title
  end

  test "validates presence of podchaser_guest_name" do
    feed = PodchaserGuestFeed.new(
      url: "podchaser://blank",
      config: { "podchaser_guest_name" => "" }
    )
    assert_not feed.valid?
    assert feed.errors[:podchaser_guest_name].present?
  end

  test "fill_missing_details sets error when guest not found" do
    VCR.use_cassette("podchaser_search_nonexistent", record: :new_episodes) do
      feed = PodchaserGuestFeed.new(
        url: "podchaser://nobody",
        config: { "podchaser_guest_name" => "zzznonexistentperson12345" }
      )
      feed.valid?
      assert_nil feed.podchaser_guest_pcid
      assert_match(/not found on Podchaser/, feed.fetch_error_message)
    end
  end

  test "fill_missing_details persists error for existing record" do
    VCR.use_cassette("podchaser_search_nonexistent", record: :new_episodes) do
      feed = create_feed(guest_name: "zzznonexistentperson12345")
      feed.update_column(:config, feed.config.merge("podchaser_guest_pcid" => nil))

      feed.valid?
      assert_match(/not found on Podchaser/, feed.reload.fetch_error_message)
    end
  end

  test "recent_media_items returns guest episodes with expected values" do
    VCR.use_cassette("podchaser_episodes_jim_chanos", record: :new_episodes) do
      feed = create_feed

      items = feed.recent_media_items
      assert_equal 2, items.size

      rochard = items.find { |i| i.title.include?("Pierre Rochard") }
      assert_equal "podchaser:259526122", rochard.guid
      assert_equal "PodChaser - Jim Chanos: The Investor's Podcast (We Study Billionaires)  - The Investor\u2019s Podcast Network - BTC243: Jim Chanos Vs Pierre Rochard MSTR mNAV debate (Bitcoin Podcast)", rochard.title
      assert_equal "The Investor's Podcast (We Study Billionaires)  - The Investor\u2019s Podcast Network", rochard.author
      assert_equal 3292, rochard.duration_seconds
      assert_equal MediaItem::AUDIO_MIME_TYPE, rochard.mime_type
      assert_match(%r{mp3}, rochard.url)
      assert_match(/Bitcoin/, rochard.description)
      assert_match(/NAV/, rochard.description)
      assert_equal DateTime.parse("2025-07-16 00:00:00"), rochard.published_at
      assert_equal "https://megaphone.imgix.net/podcasts/8d32d4ea-61a0-11f0-8ac9-ef02c1c15bb7/image/7e6c9fd439174b0b41a400e4e9125583.jpg?ixlib=rails-4.3.1&max-w=3000&max-h=3000&fit=crop&auto=format%2Ccompress", rochard.thumbnail_url

      odd_lots = items.find { |i| i.title.include?("Odd Lots") }
      assert_equal "podchaser:257682886", odd_lots.guid
      assert_equal 2253, odd_lots.duration_seconds
      assert_match(/Nuttiness/, odd_lots.title)
      assert_equal DateTime.parse("2025-06-30 08:00:00"), odd_lots.published_at
      assert_equal "https://www.omnycontent.com/d/playlist/e73c998e-6e60-432f-8610-ae210140c5b1/8a94442e-5a74-4fa2-8b8d-ae27003a8d6b/982f5071-765c-403d-969d-ae27003a8d83/image.jpg?t=1681322812&size=Large", odd_lots.thumbnail_url
    end
  end

  test "recent_media_items uses audio URL when available" do
    VCR.use_cassette("podchaser_episodes_jim_chanos", record: :new_episodes) do
      feed = create_feed

      items = feed.recent_media_items
      audio_items = items.select { |i| i.mime_type == MediaItem::AUDIO_MIME_TYPE }
      assert audio_items.size > 0
    end
  end

  test "recent_media_items deduplicates by guid" do
    VCR.use_cassette("podchaser_episodes_jim_chanos", record: :new_episodes) do
      feed = create_feed

      items = feed.recent_media_items
      items.each(&:save!)

      items_again = feed.recent_media_items
      assert items_again.all?(&:persisted?)
    end
  end

  test "recent_media_items returns empty when synced within debounce interval" do
    feed = create_feed
    feed.update_column(:config, { "podchaser_guest_name" => "Jim Chanos" })

    result = feed.recent_media_items
    assert_kind_of String, result
    assert_match(/no guest ID resolved/, result)

    feed.define_singleton_method(:fill_missing_details) {}
    feed.update!(last_sync: 6.hours.ago)
    assert_equal [], feed.recent_media_items
  end

  test "recent_media_items fetches when last sync exceeds debounce interval" do
    VCR.use_cassette("podchaser_episodes_jim_chanos", record: :new_episodes) do
      feed = create_feed
      feed.update!(last_sync: 13.hours.ago)

      items = feed.recent_media_items
      assert_kind_of Array, items
      assert items.size > 0
    end
  end

  test "recent_media_items returns error when no pcid" do
    feed = create_feed
    feed.update_column(:config, { "podchaser_guest_name" => "Jim Chanos" })

    result = feed.recent_media_items
    assert_kind_of String, result
    assert_match(/no guest ID resolved/, result)
  end

  test "recent_media_items includes podcast title in item title" do
    VCR.use_cassette("podchaser_episodes_jim_chanos", record: :new_episodes) do
      feed = create_feed

      items = feed.recent_media_items
      assert_kind_of Array, items
      assert items.first.title.start_with?("PodChaser - Jim Chanos: ")
    end
  end

  test "recent_media_items sets podcast as author" do
    VCR.use_cassette("podchaser_episodes_jim_chanos", record: :new_episodes) do
      feed = create_feed

      items = feed.recent_media_items
      assert_kind_of Array, items
      assert items.all? { |i| i.author.present? && i.author != feed.title }
    end
  end

  test "set_type detects PodchaserGuestFeed from guest name" do
    feed = Feed.new(
      url: "anything",
      config: {
        "podchaser_guest_name" => "Jim Chanos",
        "podchaser_guest_pcid" => JIM_CHANOS_PCID
      }
    )
    feed.valid?
    assert_equal "PodchaserGuestFeed", feed.type
  end

  test "Feed.create with guest name sets type and url" do
    VCR.use_cassette("podchaser_search_jim_chanos", record: :new_episodes) do
      feed = Feed.create!(config: { "podchaser_guest_name" => "Jim Chanos" })
      assert_equal "PodchaserGuestFeed", feed.type
      assert_equal "podchaser://jim-chanos", feed.url
      assert_equal "PodChaser - Jim Chanos", feed.title
    end
  end

  test "PodchaserGuestFeed.poll? returns true" do
    assert PodchaserGuestFeed.poll?
  end

  test "podchaser_guest_name stored in config" do
    feed = create_feed
    assert_equal "Jim Chanos", feed.podchaser_guest_name
    assert_equal "Jim Chanos", feed.config["podchaser_guest_name"]
  end

  test "podchaser_guest_pcid stored in config" do
    feed = create_feed
    assert_equal JIM_CHANOS_PCID, feed.podchaser_guest_pcid
    assert_equal JIM_CHANOS_PCID, feed.config["podchaser_guest_pcid"]
  end
end
