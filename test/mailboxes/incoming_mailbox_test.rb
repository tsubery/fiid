require "test_helper"

class IncomingMailboxTest < ActionMailbox::TestCase
  test "receive mail to unmonitored inbox" do
    assert 0, feeds(:spam).media_items.count
    receive_inbound_email_from_mail \
      to: '"someone" <someone@example.com>',
      from: '"else" <else@example.com>',
      subject: "Hello world!",
      body: "Hello?"
    assert 1, feeds(:spam).media_items.count
    media_item = feeds(:spam).media_items.first
    assert_equal "Hello world!", media_item.title
    assert_in_delta media_item.published_at, Time.zone.now, 3
    assert_equal "http://#{ENV.fetch('HOSTNAME')}/media_items/#{media_item.id}/article", media_item.url
    assert_equal "text/html", media_item.mime_type
    assert_equal "else@example.com", media_item.author
  end

  test "receive mail to a monitored inbox" do
    assert 0, feeds(:newsletter).media_items.count
    library = feeds(:newsletter).libraries.create(title: 'email test')
    receive_inbound_email_from_mail \
      to: '"someone" <newsletter@example.com>',
      from: '"else" <else@example.com>',
      subject: "Hello world!",
      body: "Hello?"
    assert 1, feeds(:newsletter).media_items.count
    media_item = feeds(:newsletter).media_items.first
    assert_equal "Hello world!", media_item.title
    assert_in_delta media_item.published_at, Time.zone.now, 3
    assert_equal "http://#{ENV.fetch('HOSTNAME')}/media_items/#{media_item.id}/article", media_item.url
    assert_equal "text/html", media_item.mime_type
    assert_equal "else@example.com", media_item.author
    assert_equal [media_item], library.media_items.to_a
  end
end
