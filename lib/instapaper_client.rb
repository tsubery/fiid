class InstapaperClient
  IS_VIDEO = "2".freeze
  API_URL = URI.parse('https://www.instapaper.com/api/add')

  class << self
    attr_reader :outobox

    def username
      ENV.fetch('INSTAPAPER_USERNAME')
    end

    def password
      ENV.fetch('INSTAPAPER_PASSWORD')
    end

    def list_videos(since: 1.day.ago)
      api_client
        .retrieve(since: since.to_i, contentType: :video, deailType: :complete)
        .fetch("list")
        .map(&:second)
        .select { |e| e["has_video"] == IS_VIDEO }
    end


    def set_outbox(outbox)
      @outbox = outbox
    end

    def add(url)
      if Rails.env.test?
        @outbox << url
      elsif !ENV['DISABLE_INSTAPAPER']
        http = Net::HTTP.new(API_URL.host, API_URL.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        request = Net::HTTP::Post.new(API_URL.path)
        request.basic_auth(username, password)

        request.set_form_data('url' => url)

        response = http.request(request)

        unless [200,201].include?(response&.code&.to_i)
          raise "Unexpected response code #{response&.code&.inspect} for response #{response&.inspect}"
        end
      end
    end
  end
end
