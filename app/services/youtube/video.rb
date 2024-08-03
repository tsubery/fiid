require_relative 'cli'
module Youtube
  class Video
    attr_reader :id, :url

    def initialize(url)
      @url = url
      @id = if %r{\Ahttps://(m\.|www\.)?youtube.com/watch\?} =~ url
              parsed_query = Rack::Utils.parse_nested_query(URI.parse(url).query)
              parsed_query["v"]
            elsif %r{https://(youtu.be|(m\.|www\.)?youtube.com/live)/([^/?]+)} =~ url
              ::Regexp.last_match(3)
            end
    end

    def self.from_id(id)
      new("https://www.youtube.com/watch?v=#{id}")
    end

    def guid
      "yt:video:#{id}"
    end

    def get_information
      CLI.get_video_information(url)
    end

    def each_chunk(audio:)
      #i = 0
      CLI.stream(url, audio: audio) do |_stdin, stdout, stderr, _thread|
        until stdout.eof?
          #((i += 1) % 10).zero? && GC.start # aggressive garbage collection to reduce footprint
          yield stdout.read(2**18)
        end
        error_log = stderr.read
        if error_log != ""
          Rails.logger.error(error_log)
          raise error_log
        end
      end
    end
  end
end
