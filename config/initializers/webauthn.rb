WebAuthn.configure do |config|
  hosts = Rails.application.config.hosts.filter_map { |h| h.is_a?(String) ? h : nil }

  config.allowed_origins = hosts.map do |host|
    if host.include?("localhost") || host.include?(".local")
      "http://#{host}:3000"
    else
      "https://#{host}"
    end
  end

  # rp_id must be a registrable domain shared by all origins (no subdomains, no port)
  bare_host = hosts.reject { |h| h.include?("localhost") || h.start_with?("admin.") }.first
  config.rp_id = bare_host || "localhost"
  config.rp_name = "Fiid"
end
