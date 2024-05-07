class IncomingMailbox < ApplicationMailbox
  def process
    feed = IncomingEmailFeed.target_feed(mail.to.first)
    new_media_item = feed.media_items.create!(
      author: mail.from.join(","),
      title: mail.subject,
      published_at: mail.date,
      description: mail.html_part&.decoded || mail.body.to_s,
      url: MediaItem.temporary_url,
      guid: Digest::MD5.hexdigest(Time.now.to_s + mail.body.to_s),
      mime_type: "text/html"
    )
    feed.touch(:last_sync)
    feed.libraries.each { |l| l.add_media_item(new_media_item) }
  end
end
