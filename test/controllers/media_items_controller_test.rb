require "test_helper"

class MediaItemsControllerTest < ActionDispatch::IntegrationTest
  test "download video" do
    yt = feeds(:two).media_items.create!(url: media_items(:short_video).url)
    assert_equal "yt:video:_CBG3gz6gi4", yt.guid
    get media_item_video_url(yt)
    assert_response :success
    assert_equal 2_438_606, response.body.size
    assert_equal "64b88728bae12cba43fb7c056d5717fc", Digest::MD5.hexdigest(response.body)
    assert_equal "video/mp4", response.headers["content-type"]
  end

  test "download failure" do
    yt = feeds(:two).media_items.create!(url: "https://www.youtube.com/watch?v=_CBG3gzaaaa")
    get media_item_video_url(yt)
    assert_response :internal_server_error
    assert_equal '#<RuntimeError:"ERROR: [youtube] _CBG3gzaaaa: Video unavailable\n">', response.body
    assert_equal "text/plain", response.headers["content-type"]
  end

  test "download audio" do
    yt = feeds(:two).media_items.create!(url: media_items(:short_video).url)
    assert_equal "yt:video:_CBG3gz6gi4", yt.guid
    get media_item_audio_url(yt)
    assert_response :success
    assert_equal 621_641, response.body.size
    assert_equal "audio/mp4", response.headers["content-type"]
  end

  test "show article" do
    article = media_items(:two)
    article.update!(created_at: Time.at(0), updated_at: Time.at(1))
    get media_item_article_url(article)
    # File.write("test/fixtures/articles/two.html", response.body)
    assert_response :success
    assert_equal response.body, File.read("test/fixtures/articles/two.html")
    assert_equal "text/html; charset=utf-8", response.headers["content-type"]
  end

  test "article is santized from script tags" do
    article = media_items(:xss_article)
    get media_item_article_url(article)
    assert_response :success
    assert_not response.body =~ /<script>/
  end
end
