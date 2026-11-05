class ApplicationController < ActionController::Base
  private
  def secret_token
   ENV['SECRET_KEY'] || raise("Missing SECRET_KEY in environment")
  end

  def secret_token_equal?(param)
    param.present? && ActiveSupport::SecurityUtils.secure_compare(secret_token, param)
  end

  def require_admin
    unless authenticated?
      redirect_to login_url, allow_other_host: true
    end
  end

  def authenticated?
    session[:authenticated] == true
  end
end
