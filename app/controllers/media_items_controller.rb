class MediaItemsController < ApplicationController
  # Deprecated after dropping Pocket & Instapaper
  # def article

  #   if @media_item.libraries.none?
  #     render plain: 'This article is not visible because it is not associated with any library'
  #     return
  #   end

  #   if cookies.count > 0
  #     render :article, layout: false
  #   else
  #     render html: @media_item.description.html_safe
  #   end
  # end

  def video
    CacheVideoJob.perform_later(params[:media_item_id])

    response.headers["Retry-After"] = 90
    render plain: "Gateway Timeout", status: :gateway_timeout
  end
end
