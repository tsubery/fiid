class PocketClient
  IS_VIDEO = "2".freeze

  class << self
    attr_reader :outobox

    def api_client
      Pocket::Client.new(
        consumer_key: ENV.fetch('POCKET_CONSUMER_KEY'),
        access_token: ENV.fetch('POCKET_ACCESS_TOKEN')
      )
    end

    def list_videos(since: 1.day.ago)
      api_client
        .retrieve(since: since.to_i, contentType: :video, deailType: :complete)
        .fetch("list")
        .map(&:second)
        .select { |e| e["has_video"] == IS_VIDEO }
    end

    def add(url)
      if Rails.env.test?
        @outbox << url
      elsif !ENV['DISABLE_POCKET']
        api_client.add(url: url)
      end
    end

    def set_outbox(outbox)
      @outbox = outbox
    end
  end
end
