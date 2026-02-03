require "test_helper"

class MediaItemsControllerTest < ActionDispatch::IntegrationTest
  test "download audio" do
    yt = feeds(:two).media_items.create!(url: media_items(:short_video).url)
    assert_equal "yt:video:_CBG3gz6gi4", yt.guid
    get media_item_audio_url(yt)
    assert_response :success
    assert_equal 393_289, response.body.size
    assert_equal "f0e1fdea6ef75b0c3b1bd45b27e7e35a", Digest::MD5.hexdigest(response.body)
    assert_equal "audio/mp4", response.headers["content-type"]
  end

  test "download failure" do
    yt = feeds(:two).media_items.create!(url: "https://www.youtube.com/watch?v=_CBG3gzaaaa")
    get media_item_audio_url(yt)
    assert_response :internal_server_error
    assert_match(/Video unavailable/, response.body)
    assert_equal "text/plain", response.headers["content-type"]
  end
end
