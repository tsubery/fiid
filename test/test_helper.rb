ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |rb| require(rb) }
module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def authenticate
      post login_url, params: { secret_key: ENV.fetch('SECRET_KEY') }
    end
    # Add more helper methods to be used by all tests here...
  end
end
