require "test_helper"

class WebScrapeFeedTest < ActiveSupport::TestCase
  LISTING_HTML = <<~HTML.freeze
    <html>
    <head><title>Test Site</title></head>
    <body>
      <a class="article" href="/knowledge/article-one">Article One</a>
      <a class="article" href="/knowledge/article-two">Article Two</a>
      <a class="nav-link" href="/about">About</a>
    </body>
    </html>
  HTML

  EMPTY_HTML = <<~HTML.freeze
    <html>
    <head><title>Test Site</title></head>
    <body><p>No articles here</p></body>
    </html>
  HTML

  MockResponse = Struct.new(:code, :body, :headers, :return_message, keyword_init: true) do
    def initialize(code:, body: "", headers: {}, return_message: "")
      super(code: code, body: body, headers: headers, return_message: return_message)
    end
  end

  def create_feed(selector: "a.article")
    WebScrapeFeed.create!(
      url: "https://example.com/articles",
      title: "Test Feed",
      config: { "article_link_selector" => selector }
    )
  end

  def stub_response(feed, code: 200, body: LISTING_HTML)
    feed.instance_variable_set(:@html_response, MockResponse.new(code: code, body: body))
  end

  def with_rollbar_tracking
    calls = []
    sc = Rollbar.singleton_class
    sc.send(:alias_method, :__orig_error, :error)
    sc.send(:define_method, :error) { |*args, **kwargs| calls << [args, kwargs] }
    yield calls
  ensure
    sc.send(:alias_method, :error, :__orig_error)
    sc.send(:remove_method, :__orig_error)
  end

  test "extracts articles matching CSS selector" do
    feed = create_feed
    stub_response(feed)

    items = feed.recent_media_items
    assert_equal 2, items.size
    assert_equal "https://example.com/knowledge/article-one", items[0].url
    assert_equal "https://example.com/knowledge/article-two", items[1].url
    assert items.all? { |i| i.mime_type == "text/html" }
    assert items.all? { |i| i.author == "Test Feed" }
  end

  test "resolves relative URLs against feed URL" do
    feed = create_feed
    stub_response(feed)

    items = feed.recent_media_items
    assert items.all? { |i| i.url.start_with?("https://example.com/") }
  end

  test "sets title from link text" do
    feed = create_feed
    stub_response(feed)

    items = feed.recent_media_items
    assert_equal "Test Feed - Article One", items[0].title
    assert_equal "Test Feed - Article Two", items[1].title
  end

  test "uses article URL as guid" do
    feed = create_feed
    stub_response(feed)

    items = feed.recent_media_items
    assert_equal items[0].url, items[0].guid
  end

  test "deduplicates by guid" do
    feed = create_feed
    stub_response(feed)

    items = feed.recent_media_items
    items.each(&:save!)

    stub_response(feed)
    items_again = feed.recent_media_items
    assert items_again.all?(&:persisted?)
  end

  test "reports Rollbar error when selector matches nothing on valid page" do
    feed = create_feed(selector: "a.nonexistent")
    stub_response(feed, body: LISTING_HTML)

    with_rollbar_tracking do |calls|
      items = feed.recent_media_items
      assert_equal [], items
      assert_equal 1, calls.size
      assert_match(/matched 0 items/, calls.first[0].first)
    end
  end

  test "does not report Rollbar error when articles are found" do
    feed = create_feed
    stub_response(feed)

    with_rollbar_tracking do |calls|
      feed.recent_media_items
      assert_empty calls
    end
  end

  test "returns error string on HTTP failure" do
    feed = create_feed
    stub_response(feed, code: 403)

    result = feed.recent_media_items
    assert_kind_of String, result
    assert_match(/Error fetching feed/, result)
  end

  test "returns error string on server error" do
    feed = create_feed
    stub_response(feed, code: 500)

    result = feed.recent_media_items
    assert_kind_of String, result
    assert_match(/response code 500/, result)
  end

  test "skips links without href" do
    html = <<~HTML
      <html><body>
        <a class="article">No href</a>
        <a class="article" href="/real">Real link</a>
      </body></html>
    HTML
    feed = create_feed
    stub_response(feed, body: html)

    items = feed.recent_media_items
    assert_equal 1, items.size
    assert_equal "https://example.com/real", items[0].url
  end

  test "only matches configured selector" do
    feed = create_feed(selector: "a.nav-link")
    stub_response(feed)

    items = feed.recent_media_items
    assert_equal 1, items.size
    assert_equal "https://example.com/about", items[0].url
  end

  test "set_type does not override WebScrapeFeed" do
    feed = WebScrapeFeed.new(url: "https://example.com/articles", title: "Test")
    feed.valid?
    assert_equal "WebScrapeFeed", feed.type
  end

  test "article_link_selector stored in config" do
    feed = create_feed(selector: "div.card > a")
    assert_equal "div.card > a", feed.article_link_selector
    assert_equal "div.card > a", feed.config["article_link_selector"]
  end
end
