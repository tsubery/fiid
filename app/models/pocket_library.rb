class PocketLibrary < Library
  def add_media_item(new_media_item)
    PocketClient.add(new_media_item.url)
    media_items << new_media_item
  end
end
