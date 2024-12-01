class SessionsController < ApplicationController
  def new
    if secret_token_equal?(cookies[:secret_key])
      redirect_to admin_dashboard_path
    else
      render :new
    end
  end

  def create
    if secret_token_equal?(params[:secret_key])
      reset_session
      cookies.permanent[:secret_key] = params[:secret_key]
      redirect_to admin_dashboard_url
    else
      flash[:alert] = "Incorrect secret key"
      redirect_to login_url
    end
  end
end
