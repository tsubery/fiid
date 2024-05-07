require "vcr"

VCR.configure do |config|
  config.allow_http_connections_when_no_cassette = false
  config.cassette_library_dir = File.expand_path("../../cassettes", __FILE__)
  config.hook_into :webmock
  config.ignore_request do |request|
    # headless-chrome is requesting it
    request.uri == "https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build.json" || ENV["DISABLE_VCR"]
  end
  config.ignore_localhost = true
  config.default_cassette_options = { :record => :none }
end
