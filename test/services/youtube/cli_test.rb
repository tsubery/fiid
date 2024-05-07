require "test_helper"

class YoutubeCLI < ActiveSupport::TestCase
  test "input sanitization for playlist id" do
    exception = assert_raises(ArgumentError) {
      Youtube::CLI.get_playlist_information("id';echo injected! '")
    }
    assert_equal exception.message, "The id \"id';echo injected! '\" can be dangerous!"
  end

  test "input sanitation for video id" do
    %w[foo'bar foo"bar].each do |bad_id|
      url = "https://example.com/?video=#{bad_id}"
      exception = assert_raises(ArgumentError) {
        Youtube::CLI.get_video_information(url)
      }
      assert_equal exception.message, "The url #{url.inspect} can be dangerous!"
    end
  end

  test "reject urls with apostrophes" do
    %w[foo'bar foo"bar].each do |bad_id|
      url = "https://example.com/?video=#{bad_id}"

      exception = assert_raises(ArgumentError) {
        Youtube::CLI.stream(url, audio: true)
      }
      assert_equal exception.message, "The url #{url.inspect} can be dangerous!"

      exception = assert_raises(ArgumentError) {
        Youtube::CLI.stream(url)
      }
      assert_equal exception.message, "The url #{url.inspect} can be dangerous!"
    end
  end
end
