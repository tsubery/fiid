require "test_helper"

class LibrariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @library = libraries(:one)
  end

  test "should get podcast" do
    VCR.use_cassette('fedguy-channel') do
      @library.media_items << feeds(:fedguy_channel).recent_media_items
      @library.media_items.update_all(created_at: Time.at(1111111111)) # fixed time
      get "/podcasts/#{@library.id}"
    end

    assert response.headers["content-type"] == "application/rss+xml; charset=utf-8"
    assert_response :success
    podcast_content = response.body.gsub(%r{media_items/[0-9]+/}, "media_items/XXXXXX/")
    File.write('test/podcasts/fedguy.xml', podcast_content)
    regression_file = File.read('test/podcasts/fedguy.xml')
    assert_equal podcast_content, regression_file
  end
end
