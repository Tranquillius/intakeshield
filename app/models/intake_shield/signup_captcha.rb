# Optional CAPTCHA + honeypot for classic self-registration and password-reset
# requests. Independent of the IntakeShield master switch.
class IntakeShield::SignupCaptcha
  HONEYPOT_FIELD = 'intake_shield_hp'.freeze
  SOURCE_ALTCHA  = 'altcha'.freeze
  SOURCE_FORM    = 'form_channel'.freeze

  class << self
    def enabled?
      truthy?(Setting.get('intake_shield_signup_captcha'))
    end

    def source
      value = Setting.get('intake_shield_captcha_source').to_s
      return SOURCE_FORM if value == SOURCE_FORM

      SOURCE_ALTCHA
    end

    # Whether this request must pass captcha/honeypot checks.
    def required?(action_name:, params:, current_user:)
      return false if !enabled?
      return true if action_name.to_s == 'password_reset_send'
      return false if action_name.to_s != 'create'
      return false if current_user.present?

      signup_flag?(params)
    end

    def verify!(params:, request: nil)
      return true if !enabled?
      return false if !honeypot_ok?(params)

      case source
      when SOURCE_FORM
        verify_form_channel!(params: params, request: request)
      else
        verify_altcha!(params)
      end
    end

    def frontend_config
      return { enabled: false } if !enabled?

      config = {
        enabled:  true,
        honeypot: { field: HONEYPOT_FIELD },
      }

      captcha = widget_config
      config[:captcha] = captcha if captcha.present?
      config
    end

    def challenge
      return if !enabled?
      return if source != SOURCE_ALTCHA

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

    def verify_altcha!(params)
      IntakeShield::Captcha::Altcha.new.verify(params)
    end

    def verify_form_channel!(params:, request:)
      unless defined?(FormSpamProtection)
        IntakeShield.logger.error 'Signup captcha source is form_channel but FormSpamProtection is not available.'
        return false
      end

      provider = FormSpamProtection::Captcha.configured_provider
      if provider.blank?
        IntakeShield.logger.error 'Signup captcha source is form_channel but no form CAPTCHA provider is configured.'
        return false
      end

      submission = FormSpamProtection::Submission.new(params: params, request: request)
      return true if FormSpamProtection.verify_challenge(submission)

      IntakeShield.logger.info 'Signup captcha rejected (form channel verification failed).'
      false
    end

    def widget_config
      case source
      when SOURCE_FORM
        form_channel_widget_config
      else
        IntakeShield::Captcha::Altcha.new.frontend_config
      end
    end

    def form_channel_widget_config
      unless defined?(FormSpamProtection)
        IntakeShield.logger.error 'Signup captcha source is form_channel but FormSpamProtection is not available.'
        return
      end

      captcha = FormSpamProtection.frontend_config[:captcha] || FormSpamProtection.frontend_config['captcha']
      if captcha.blank?
        IntakeShield.logger.error 'Signup captcha source is form_channel but no form CAPTCHA provider is configured.'
        return
      end

      hash = captcha.respond_to?(:to_unsafe_h) ? captcha.to_unsafe_h : captcha.to_h
      hash = hash.deep_stringify_keys if hash.respond_to?(:deep_stringify_keys)
      hash
    rescue StandardError => e
      IntakeShield.logger.error "Signup captcha form_channel config failed: #{e.message}"
      nil
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
