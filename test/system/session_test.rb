require "application_system_test_case"

class SessionTest < ApplicationSystemTestCase
  test "redirected to login page" do
    visit admin_dashboard_url
    assert_equal login_url, page.current_url
    fill_in "Secret key", with: ENV.fetch("SECRET_KEY")
    click_on "Login"
    assert admin_dashboard_url, page.current_url
    assert_text "Dashboard"
    visit admin_feeds_url
    assert_selector "h2", text: "Feeds"
    visit admin_dashboard_url
    assert admin_dashboard_url, page.current_url
    visit login_url
    assert admin_dashboard_url, page.current_url
  end
end
