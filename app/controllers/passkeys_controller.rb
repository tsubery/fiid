class PasskeysController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create_options, :create, :authenticate_options, :authenticate]
  before_action :require_admin, only: [:create_options, :create, :destroy]

  def create_options
    options = WebAuthn::Credential.options_for_create(
      user: { id: "fiid-admin", name: "admin", display_name: "Fiid Admin" },
      exclude: Passkey.pluck(:external_id)
    )
    session[:webauthn_challenge] = options.challenge
    render json: options
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_create(params[:credential])
    webauthn_credential.verify(session[:webauthn_challenge])

    Passkey.create!(
      label: params[:label].presence || "Passkey",
      external_id: Base64.urlsafe_encode64(webauthn_credential.raw_id, padding: false),
      public_key: Base64.urlsafe_encode64(webauthn_credential.public_key, padding: false),
      sign_count: webauthn_credential.sign_count
    )

    session.delete(:webauthn_challenge)
    render json: { status: "ok" }
  rescue WebAuthn::Error => e
    session.delete(:webauthn_challenge)
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def authenticate_options
    credentials = Passkey.all.map do |passkey|
      { id: passkey.external_id, type: "public-key" }
    end

    options = WebAuthn::Credential.options_for_get(allow: credentials)
    session[:webauthn_challenge] = options.challenge
    render json: options
  end

  def authenticate
    webauthn_credential = WebAuthn::Credential.from_get(params[:credential])
    passkey = Passkey.find_by!(external_id: Base64.urlsafe_encode64(webauthn_credential.raw_id, padding: false))

    webauthn_credential.verify(
      session[:webauthn_challenge],
      public_key: Base64.urlsafe_decode64(passkey.public_key),
      sign_count: passkey.sign_count
    )

    passkey.update!(sign_count: webauthn_credential.sign_count)
    session.delete(:webauthn_challenge)
    reset_session
    session[:authenticated] = true
    render json: { status: "ok" }
  rescue WebAuthn::Error, ActiveRecord::RecordNotFound => e
    session.delete(:webauthn_challenge)
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    passkey = Passkey.find(params[:id])
    passkey.destroy!
    redirect_to admin_passkeys_path, notice: "Passkey deleted."
  end
end
