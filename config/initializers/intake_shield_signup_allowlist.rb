# Restrict public self-registration to whitelist matches when the setting is on.
ActiveSupport::Reloader.to_prepare do
  if defined?(Service::User::Signup)
    patch = IntakeShield::SignupAllowlist::Patch
    Service::User::Signup.prepend(patch) unless Service::User::Signup.ancestors.include?(patch)
  end

  next if !defined?(UsersController)

  UsersController.class_eval do
    unless _process_action_callbacks.any? { |cb| cb.filter == :intake_shield_verify_signup_allowlist }
      append_before_action :intake_shield_verify_signup_allowlist, only: :create
    end

    def intake_shield_verify_signup_allowlist
      return if !IntakeShield::SignupAllowlist.required?(
        action_name:  action_name,
        params:       params,
        current_user: (respond_to?(:current_user, true) ? current_user : nil)
      )

      IntakeShield::SignupAllowlist.enforce_from_params!(params: params)
    end
    private :intake_shield_verify_signup_allowlist
  end
end
