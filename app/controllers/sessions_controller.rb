class SessionsController < ApplicationController
  def new
    if authenticated?
      redirect_to admin_dashboard_path
    else
      render :new
    end
  end

  def create
    if secret_token_equal?(params[:secret_key])
      reset_session
      session[:authenticated] = true
      redirect_to admin_dashboard_url
    else
      flash[:alert] = "Incorrect secret key"
      redirect_to login_url
    end
  end
end
