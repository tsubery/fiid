class ApplicationController < ActionController::Base
  after_action :sync_feeds

  private

  def sync_feeds
    RetrieveFeedsJob.enqueue_all
  end

  def require_login
    unless session[:authenticated]
      redirect_to login_path
    end
  end
end
