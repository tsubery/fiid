ActiveAdmin.register_page "Reading List" do
  menu label: "Reading List"

  page_action :articles, method: :get do
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    days = params[:days].present? ? params[:days].to_i : nil

    base_query = InstapaperLibrary.first().media_items.reading_list
    base_query = base_query.where("media_items.created_at >= ?", days.days.ago) if days
    base_query = base_query
    total = base_query.count

    items = base_query
      .offset((page - 1) * per_page)
      .limit(per_page)
      .pluck(*%i[id
             title
             feeds.title
             url
             published_at
             author
             sent_to
             ])
      .uniq

    render json: {
      items: items.map { |(id, title, feed_title, url, published_at, author, sent_to)|
        {
          id: id,
          title: title,
          feed_title: feed_title,
          url: url,
          published_at: published_at,
          author: author,
          sent_to: sent_to
        }
      },
      page: page,
      per_page: per_page,
      total: total,
      has_more: (page * per_page) < total
    }
  end

  page_action :article, method: :get do
    item = MediaItem.find(params[:id])
    # Articles are immutable - cache for 1 year
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
    render json: {
      id: item.id,
      title: item.title,
      description: item.description,
      feed_title: item.feed&.title,
      url: item.url,
      published_at: item.published_at,
      author: item.author,
      sent_to: item.sent_to
    }
  end

  page_action :archive, method: :post do
    item = MediaItem.find(params[:id])
    item.archive!
    render json: { success: true }
  end

  page_action :add_url, method: :post do
    url = params[:url]&.strip

    if url.blank? || !url.match?(/\Ahttps?:\/\//i)
      render json: { success: false, error: "Invalid URL" }, status: :unprocessable_entity
      return
    end

    if MediaItem.video_url?(url)
      mime_type = MediaItem::VIDEO_MIME_TYPE
      library = Library.where.not(type: 'InstapaperLibrary').first
    else
      mime_type = MediaItem::HTML_MIME_TYPE
      library = Library.where(type: 'InstapaperLibrary').first
    end

    unless library
      render json: { success: false, error: "No library to attach to #{url}" }, status: :unprocessable_entity
    end

    media_item = MediaItem.find_or_create_by!(
      feed: PersonalFeed.first(),
      guid: url,
      mime_type: mime_type,
      title: url,
      url: url,
    )

    unless media_item.libraries.include?(library)
      media_item.libraries << library
    end

    render json: { success: true, id: media_item.id }
  end

  content do
    style do
      text_node "#header, #title_bar, .breadcrumb { display: none !important; }"
      text_node "#active_admin_content { padding: 0 !important; margin: 0 !important; }"
      text_node "#wrapper { padding-top: 0 !important; }"
      text_node "@media (max-width: 768px) { #reading-list-toolbar { padding: 15px 20px !important; } #reading-list-toolbar button { padding: 12px 24px !important; font-size: 18px !important; } #reading-list-content { margin-top: 80px !important; } #reading-list-sidebar { top: 71px !important; height: calc(100vh - 71px) !important; } }"
    end

    days = params[:days].present? ? params[:days].to_i : nil
    per_page = params[:per_page].present? ? params[:per_page].to_i : nil

    div id: "reading-list-app", data: { days: days, per_page: per_page } do
      div id: "reading-list-toolbar", style: "position: fixed; top: 0; left: 0; right: 0; z-index: 1000; background: #fff; border-bottom: 1px solid #ccc; padding: 10px 20px; display: flex; align-items: center;" do
        button "☰", id: "sidebar-toggle", style: "padding: 6px 12px; cursor: pointer; font-size: 16px; margin-right: 10px;"
        button "+", id: "add-url-btn", style: "padding: 6px 12px; cursor: pointer; font-size: 18px; font-weight: bold; margin-right: 10px;", title: "Add URL from clipboard"
        button "Prev", id: "prev-btn", style: "padding: 6px 32px; cursor: pointer; font-size: 14px;"
        button "Archive", id: "archive-btn", style: "padding: 6px 64px; cursor: pointer; background: #dc3545; color: white; border: none; border-radius: 4px; font-size: 14px; margin: 0 auto;"
        button "Next", id: "next-btn", style: "padding: 6px 32px; cursor: pointer; font-size: 14px;"
        span id: "article-title", style: "display: none;"
      end

      div id: "reading-list-sidebar", style: "position: fixed; top: 51px; left: 0; width: 250px; height: calc(100vh - 51px); overflow-y: auto; background: #f5f5f5; border-right: 1px solid #ccc; padding: 10px 0;" do
        para "Loading..."
      end

      div id: "reading-list-content", style: "margin-top: 60px; margin-left: 270px; padding: 20px; max-width: 800px;" do
        para "Loading..."
      end
    end

    script src: "https://cdnjs.cloudflare.com/ajax/libs/dompurify/3.0.6/purify.min.js"
  end
end
