require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new form" do
    get login_url(subdomain: :admin)
    assert_response :success
  end

  test "login with wrong secret key" do
    post login_url, params: { secret_key: :foo }
    assert flash.to_a == [["alert", "Incorrect secret key"]]
    assert_response :redirect
    assert_not session["authenticated"]
    assert response.status == 302
    assert response.headers["location"] == login_url
  end

  test "login with correct secret key" do
    post login_url, params: { secret_key: ENV.fetch("SECRET_KEY") }
    assert flash.to_a == []
    assert_response :redirect
    assert response.status == 302
    assert session["authenticated"]
    assert response.headers["location"] == admin_dashboard_url

    get login_url
    assert_response :redirect
    assert response.status == 302
    assert session["authenticated"]
    assert response.headers["location"] == admin_dashboard_url
  end
end
