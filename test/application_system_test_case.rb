require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]

  def setup
   Capybara.app_host = ENV.fetch('HOSTNAME')
   Capybara.server_port = ENV.fetch('HOSTNAME').split(":").second
  end
end
