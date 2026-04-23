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

  test "recent_media_items returns guest episodes" do
    VCR.use_cassette("podchaser_episodes_jim_chanos", record: :new_episodes) do
      feed = create_feed

      items = feed.recent_media_items
      assert_kind_of Array, items
      assert items.size > 0

      item = items.first
      assert item.guid.start_with?("podchaser:")
      assert item.url.present?
      assert item.title.include?("PodChaser - Jim Chanos")
      assert item.author.present?
      assert item.published_at.present?
      assert item.duration_seconds.present?
      assert item.thumbnail_url.present?
    end
  end

  test "recent_media_items uses audio URL when available" do
    VCR.use_cassette("podchaser_episodes_jim_chanos", record: :new_episodes) do
      feed = create_feed

      items = feed.recent_media_items
      audio_items = items.select { |i| i.mime_type == MediaItem::VIDEO_MIME_TYPE }
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

  test "set_type does not override PodchaserGuestFeed" do
    feed = PodchaserGuestFeed.new(
      url: "podchaser://jim-chanos",
      config: {
        "podchaser_guest_name" => "Jim Chanos",
        "podchaser_guest_pcid" => JIM_CHANOS_PCID
      }
    )
    feed.valid?
    assert_equal "PodchaserGuestFeed", feed.type
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
