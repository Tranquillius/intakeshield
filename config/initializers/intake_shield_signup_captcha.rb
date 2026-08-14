# Verifies CAPTCHA + honeypot on public classic signup and password-reset send.
ActiveSupport::Reloader.to_prepare do
  next if !defined?(UsersController)

  UsersController.class_eval do
    unless _process_action_callbacks.any? { |cb| cb.filter == :intake_shield_verify_signup_captcha }
      append_before_action :intake_shield_verify_signup_captcha, only: %i[create password_reset_send]
    end

    def intake_shield_verify_signup_captcha
      return if !IntakeShield::SignupCaptcha.required?(
        action_name:  action_name,
        params:       params,
        current_user: (respond_to?(:current_user, true) ? current_user : nil)
      )
      return if IntakeShield::SignupCaptcha.verify!(params: params, request: request)

      raise intake_shield_captcha_error_class, __('Captcha verification failed.')
    end

    def intake_shield_captcha_error_class
      if defined?(Exceptions::UnprocessableContent)
        Exceptions::UnprocessableContent
      else
        Exceptions::UnprocessableEntity
      end
    end
    private :intake_shield_verify_signup_captcha
    private :intake_shield_captcha_error_class
  end
end
