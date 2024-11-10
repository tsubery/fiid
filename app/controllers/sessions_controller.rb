class SessionsController < ApplicationController
  def new
    if session[:authenticated]
      redirect_to admin_dashboard_path
    else
      render :new
    end
  end

  def create
    secret_key = ENV['SECRET_KEY'] || raise("Missing SECRET_KEY in environment")
    if ActiveSupport::SecurityUtils.secure_compare(secret_key, params[:secret_key])
      reset_session
      session[:authenticated] = true
      redirect_to admin_dashboard_url
    else
      flash[:alert] = "Incorrect secret key"
      redirect_to login_url
    end
  end
end
