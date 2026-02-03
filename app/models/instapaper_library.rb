class InstapaperLibrary < Library
  def add_media_item(new_media_item)
    #InstapaperClient.add(new_media_item.url)
    media_items << new_media_item
  end
end
