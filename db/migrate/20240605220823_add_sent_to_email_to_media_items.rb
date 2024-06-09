class AddSentToEmailToMediaItems < ActiveRecord::Migration[7.2]
  def change
    add_column :media_items, :sent_to, :string, null: false, default: ''
    add_index :media_items, :sent_to, where: "sent_to != ''"
    begin
      IncomingEmailFeed.all.each { |f| f.media_items.update_all(sent_to: f.url) }
    rescue => e
      p e
    end
  end
end
