require "test_helper"

class ReadingListControllerTest < ActionDispatch::IntegrationTest
  setup do
    authenticate
  end

  test "reading list page loads with toolbar" do
    get admin_reading_list_url
    assert_response :success
    assert_select "#reading-list-toolbar"
    assert_select "#prev-btn"
    assert_select "#archive-btn"
    assert_select "#next-btn"
    assert_select "#reading-list-content"
  end

  test "article API returns correct JSON structure" do
    article = media_items(:article_unarchived)
    get admin_reading_list_article_url(id: article.id)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal article.id, json["id"]
    assert_equal article.title, json["title"]
    assert_equal article.description, json["description"]
    assert_equal article.feed.title, json["feed_title"]
    assert_equal article.url, json["url"]
    assert_equal article.author, json["author"]
  end

  test "archive API archives article and returns success" do
    article = media_items(:article_unarchived)
    assert_not article.archived

    post admin_reading_list_archive_url(id: article.id)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert article.reload.archived
  end

  test "archive API requires authentication" do
    reset!
    article = media_items(:article_unarchived)
    post admin_reading_list_archive_url(id: article.id)
    assert_response :redirect
    assert_redirected_to login_url
  end
end
