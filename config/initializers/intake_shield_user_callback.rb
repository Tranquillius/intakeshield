# Applies the IntakeShield whitelist rule right after a user account is
# created (e.g. by an incoming e-mail from an unknown sender), so trusted
# senders immediately receive the configured whitelist role.
ActiveSupport::Reloader.to_prepare do
  User.class_eval do
    unless _create_callbacks.map(&:filter).include?(:intake_shield_apply_whitelist_role)
      after_create :intake_shield_apply_whitelist_role
    end

    def intake_shield_apply_whitelist_role
      return if !Setting.get('intake_shield_active')

      IntakeShield.apply_whitelist_role(self)
    rescue => e
      IntakeShield.logger.error "Whitelist role assignment failed for user ##{id}: #{e.message}"
    end
  end
end
