require "test_helper"

class YoutubeVideoTest < ActiveSupport::TestCase
  test "parse video ids" do
    {
      "https://www.youtube.com/watch?v=12345" => "12345",
      "https://m.youtube.com/watch?v=12345" => "12345",
      "https://youtube.com/watch?v=12345" => "12345",
      "https://youtu.be/12345" => "12345",
      "https://www.youtube.com/live/12345" => "12345",
      "https://m.youtube.com/live/12345" => "12345",
      "https://youtube.com/live/12345" => "12345"
    }.each do |url, id|
      assert_equal id, Youtube::Video.new(url).id
    end
  end
end
