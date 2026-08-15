# Optional whitelist allow list for public self-registration.
# Independent of the IntakeShield master switch. Does not apply to
# admin/agent user creation, mail auto-create, LDAP, or password reset.
class IntakeShield::SignupAllowlist
  class << self
    def enabled?
      truthy?(Setting.get('intake_shield_whitelist_signup'))
    end

    # Service::User::Signup (classic REST via Deprecated::Signup, GraphQL userSignup).
    def verify!(user_data:, resend: false)
      return if !enabled?
      return if truthy?(resend)

      enforce!(extract_email(user_data))
    end

    # Classic UsersController#create fallback when the signup service is absent.
    def required?(action_name:, params:, current_user:)
      return false if !enabled?
      return false if action_name.to_s != 'create'
      return false if current_user.present?

      signup_flag?(params)
    end

    def enforce_from_params!(params:)
      return if !enabled?

      enforce!(extract_email(params))
    end

    private

    def enforce!(email)
      return if email.blank?
      return if IntakeShield.whitelisted?(email)

      IntakeShield.logger.info "Signup allowlist rejected #{email}"
      raise error_class, __('This e-mail domain is not approved for self-registration. Please use an address from an allowed domain or contact your administrator.')
    end

    def error_class
      if defined?(Exceptions::UnprocessableContent)
        Exceptions::UnprocessableContent
      else
        Exceptions::UnprocessableEntity
      end
    end

    def extract_email(source)
      return if source.blank?

      hash = indifferent_hash(source)
      value = hash[:email]
      nested = hash[:user]
      value = indifferent_hash(nested)[:email] if value.blank? && nested.present?
      value = value.find(&:present?) if value.is_a?(Array)
      value.to_s.strip.presence
    end

    def indifferent_hash(source)
      return {} if source.blank?

      hash = if source.respond_to?(:to_unsafe_h)
               source.to_unsafe_h
             elsif source.is_a?(Hash)
               source
             elsif source.respond_to?(:to_h)
               source.to_h
             else
               return {}
             end

      return {} if !hash.is_a?(Hash)

      hash.respond_to?(:with_indifferent_access) ? hash.with_indifferent_access : hash
    end

    def signup_flag?(params)
      hash = indifferent_hash(params)
      truthy?(hash[:signup])
    end

    def truthy?(value)
      value == true || value.to_s.strip.casecmp('true').zero? || value.to_s.strip == '1'
    end
  end

  module Patch
    def execute
      IntakeShield::SignupAllowlist.verify!(user_data: user_data, resend: resend)
      super
    end
  end
end
