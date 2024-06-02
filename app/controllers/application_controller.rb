class ApplicationController < ActionController::Base
  after_action :sync_feeds

  private

  def sync_feeds
    RetrieveFeedsJob.enqueue_all
  end

  def require_admin
    unless session[:authenticated]
      redirect_to login_url, allow_other_host: true
    end
  end
end
