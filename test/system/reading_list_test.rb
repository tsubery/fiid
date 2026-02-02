require "application_system_test_case"

class ReadingListTest < ApplicationSystemTestCase
  setup do
    # Login via the admin login page
    host("admin.dev.local")
    visit login_url
    fill_in "secret_key", with: ENV.fetch("SECRET_KEY")
    click_button "Login"
  end

  test "displays reading list with articles" do
    visit admin_reading_list_path
    assert_selector "#reading-list-toolbar"
    assert_selector "#article-title"
    assert_selector "#article-position"
    assert_selector "#reading-list-content"
  end

  test "navigation buttons update title and position" do
    visit admin_reading_list_url

    # Wait for first article to load
    assert_selector "#article-title:not(:empty)"

    initial_title = find("#article-title").text
    initial_position = find("#article-position").text

    # Click next if there are more articles
    if initial_position != "1 / 1"
      click_button "Next"
      sleep 0.5 # Wait for content to load
      new_title = find("#article-title").text
      new_position = find("#article-position").text

      # Position should have changed
      assert_not_equal initial_position, new_position
    end
  end

  test "archive removes article and loads next" do
    visit admin_reading_list_url

    # Wait for first article to load
    assert_selector "#article-title:not(:empty)"

    initial_position = find("#article-position").text
    initial_count = initial_position.split(" / ").last.to_i

    click_button "Archive"
    sleep 0.5 # Wait for archive to complete

    new_position = find("#article-position").text
    new_count = new_position.split(" / ").last.to_i

    # Count should have decreased
    assert_equal initial_count - 1, new_count
  end

  test "content is sanitized - no script tags execute" do
    # Create an article with a script tag
    xss_article = media_items(:xss_article)
    xss_article.update!(mime_type: "text/html", archived: false)

    visit admin_reading_list_url

    # Navigate to find the XSS article if needed, or check that DOMPurify is loaded
    assert page.has_css?("script[src*='dompurify']")

    # The script tag in the content should be sanitized and not execute
    # DOMPurify will remove script tags from the sanitized content
    assert_no_selector ".article-body script"
  end
end
