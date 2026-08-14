class IntakeShieldCaptchaController < ApplicationController
  prepend_before_action -> { authorize! }
  skip_before_action :verify_csrf_token
  skip_before_action :user_device_log, raise: false

  def configuration
    render json: IntakeShield::SignupCaptcha.frontend_config
  end

  def challenge
    payload = IntakeShield::SignupCaptcha.challenge
    return head :not_found if payload.nil?

    render json: payload, status: :ok
  end

  def script
    path = IntakeShield::Captcha::Altcha.script_file
    return head :not_found if path.blank?

    expires_in 7.days, public: true
    send_data File.binread(path),
              type:        'application/javascript; charset=utf-8',
              disposition: 'inline',
              filename:    'altcha.min.js'
  end
end
