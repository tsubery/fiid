class InstapaperLibrary < Library
  def add_media_item(new_media_item)
    #InstapaperClient.add(new_media_item.url)
    media_items << new_media_item
  end

  def self.first
    super || create!(title: 'Reading List', url: "https://#{ENV.fetch('HOSTNAME')}")
  end
end
