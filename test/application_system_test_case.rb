require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1920, 1080]

  def setup
    Capybara.app_host = "http://" + ENV.fetch('HOSTNAME')
    Capybara.server_port = ENV.fetch('HOSTNAME').split(":").second
  end

  def host(subdomain_or_host)
    if subdomain_or_host.include?(".")
      Capybara.app_host = "http://#{subdomain_or_host}:#{Capybara.server_port}"
    else
      base_host = ENV.fetch('HOSTNAME').split(":").first
      Capybara.app_host = "http://#{subdomain_or_host}.#{base_host}:#{Capybara.server_port}"
    end
  end
end
