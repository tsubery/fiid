class PocketLibrary < Library
  def add_media_item(new_media_item)
    unless ENV['DISABLE_POCKET']
      PocketClient.add(new_media_item.url)
    end
    media_items << new_media_item
  end
end
