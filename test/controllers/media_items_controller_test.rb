require "test_helper"

class MediaItemsControllerTest < ActionDispatch::IntegrationTest
  test "download video" do
    yt = feeds(:two).media_items.create!(url: media_items(:short_video).url)
    assert_equal "yt:video:_CBG3gz6gi4", yt.guid
    get media_item_video_url(yt)
    assert_response :success
    assert_equal 6333305, response.body.size
    assert_equal "db840d4c105c919b14985f4dc279329d", Digest::MD5.hexdigest(response.body)
    assert_equal "video/mp4", response.headers["content-type"]
  end

  test "download failure" do
    yt = feeds(:two).media_items.create!(url:  "https://www.youtube.com/watch?v=_CBG3gzaaaa")
    get media_item_video_url(yt)
    assert_response 500
    assert_equal '#<RuntimeError:"ERROR: [youtube] _CBG3gzaaaa: Video unavailable\n">', response.body
    assert_equal "text/plain", response.headers["content-type"]
  end

  test "download audio" do
    yt = feeds(:two).media_items.create!(url: media_items(:short_video).url)
    assert_equal "yt:video:_CBG3gz6gi4", yt.guid
    get media_item_audio_url(yt)
    assert_response :success
    assert_equal 621641, response.body.size
    assert_equal "audio/mp4", response.headers["content-type"]
  end

  test "show article" do
    article = media_items(:two)
    get media_item_article_url(article)
    assert_response :success
    assert_equal response.body, article.description
    assert_equal "text/html; charset=utf-8", response.headers["content-type"]
  end
end
