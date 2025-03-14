module Youtube
  class CLI
    class << self
      DL_BINARY = "./bin/yt-dlp".freeze
      PLAYLIST_LENGTH=100

      def sanitize_id!(id)
        unless id =~ /\A[a-z0-9\-_]+\z/i
          raise(ArgumentError, "The id #{id.inspect} can be dangerous!")
        end
      end

      def sanitize_url!(url)
        if url =~ /['"]/
          raise(ArgumentError, "The url #{url.inspect} can be dangerous!")
        end
      end

      def get_video_information(url)
        sanitize_url!(url)
        stdout, stderr = cmd("-j \"#{url}\"")
        if stderr.present?
          Rails.logger.error(stderr)
        end
        errors = stderr.lines.grep(/ERROR/)
        if errors.empty? && stdout.present?
          JSON.parse(stdout)
        else
          {
            "title" => errors.first,
            "uploader" => "unknown",
            "upload_date" => "1970-01-01",
            "duration" => 0,
            "description" => stderr
          }
        end
      end

      def get_playlist_information(id, length: PLAYLIST_LENGTH)
        sanitize_id!(id)
        stdout, stderr, status = cmd("-j -I1:#{length} --flat-playlist \"#{id}\"")
        if status.exitstatus.zero?
          stdout
        else
          raise stderr
        end
      end

      def stream(url, audio: false, &block)
        sanitize_url!(url)
        cmd = "#{DL_BINARY} -r 50M -q --no-call-home #{audio ? "--format bestaudio --extract-audio " : ""} '#{url}' -o -"
        Open3.popen3(cmd, &block)
      end

      def cmd(args)
        if Rails.env.test?
          args_hash = Digest::MD5.hexdigest(args)
          caller_method = caller.first.split(" ").last.gsub(/[^a-z_]/, '')
          fixture_file = "test/fixtures/youtube_cli/#{caller_method}-#{args_hash}.json"
          if File.exist?(fixture_file)
            stdout, stderr, status_attrs = JSON.parse(File.read(fixture_file))
            status = OpenStruct.new(status_attrs)
          end
        end

        unless stdout && stderr && status
          stdout, stderr, status = capture_cmd_output(args)
          fixture_file && File.write(fixture_file, [stdout, stderr, status].to_json)
        end

        [stdout, stderr, status]
      end

      def capture_cmd_output(args)
        cmd = "#{DL_BINARY} #{args}"
        Rails.logger.info("Executing #{cmd}")
        Open3.capture3(cmd)
      end
    end
  end
end
