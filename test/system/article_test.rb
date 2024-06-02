require "application_system_test_case"

class ArticleTest < ApplicationSystemTestCase
  test "sanitizes script tags" do
    article = media_items(:xss_article)
    visit media_item_article_url(article)
    assert_equal "evil", page.title
    assert article.description =~ /<script>/
    assert Nokogiri::HTML(page.body).css("body").text.blank?
  end
end
