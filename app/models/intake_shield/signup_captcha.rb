# Optional CAPTCHA + honeypot for classic self-registration and password-reset
# requests. Independent of the IntakeShield master switch. Always self-hosted ALTCHA.
class IntakeShield::SignupCaptcha
  HONEYPOT_FIELD = 'intake_shield_hp'.freeze

  class << self
    def enabled?
      truthy?(Setting.get('intake_shield_signup_captcha'))
    end

    # Whether this request must pass captcha/honeypot checks.
    def required?(action_name:, params:, current_user:)
      return false if !enabled?
      return true if action_name.to_s == 'password_reset_send'
      return false if action_name.to_s != 'create'
      return false if current_user.present?

      signup_flag?(params)
    end

    def verify!(params:)
      return true if !enabled?
      return false if !honeypot_ok?(params)

      IntakeShield::Captcha::Altcha.new.verify(params)
    end

    def frontend_config
      return { enabled: false } if !enabled?

      {
        enabled:  true,
        honeypot: { field: HONEYPOT_FIELD },
        captcha:  IntakeShield::Captcha::Altcha.new.frontend_config,
      }
    end

    def challenge
      return if !enabled?

      IntakeShield::Captcha::Altcha.new.challenge
    end

    private

    def signup_flag?(params)
      value = param_value(params, :signup)
      truthy?(value)
    end

    def honeypot_ok?(params)
      return true if param_value(params, HONEYPOT_FIELD).to_s.empty?

      IntakeShield.logger.info 'Signup captcha rejected (honeypot field was filled in).'
      false
    end

    def param_value(params, key)
      return if params.blank?

      value = params[key] || params[key.to_s] || params[key.to_sym]
      value = value.find(&:present?) if value.is_a?(Array)
      value
    end

    def truthy?(value)
      value == true || value.to_s.strip.casecmp('true').zero? || value.to_s.strip == '1'
    end
  end
end
