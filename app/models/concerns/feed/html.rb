module Feed::Html
  extend ActiveSupport::Concern

  def html_response
    @html_response ||= Typhoeus.get(html_url, timeout: 5, headers: { "If-None-Match" => etag })
  end

  def html
    if html_response&.code == 200
      Nokogiri::HTML.parse(@html_response.body)
    end
  rescue => e
    Rails.logger.error(e.inspect)
    nil
  end

  def html_url
    url
  end

  def get_title
    html&.css("title")&.text
  end

  def get_thumbnail_url
    html&.css("meta[property='og:image']")&.attribute("content")&.value
  end

  def get_description
    html&.css("meta[name='description']")&.attribute("content")&.value
  end

  def get_etag
    if html_response&.code == 200
      html_headers["etag"]
    end
  end

  def get_last_modified
    if html_response&.code == 200 && html_headers["last-modified"]
      DateTime.parse(html_headers["last-modified"])
    end
  end

  def html_headers
    html_response&.headers&.transform_keys(&:downcase)
  end
end
