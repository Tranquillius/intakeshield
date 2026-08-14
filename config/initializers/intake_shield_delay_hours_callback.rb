# When the deletion delay setting changes, recalculate execute_at for all
# pending user and ticket deletions (created_at + new delay).
ActiveSupport::Reloader.to_prepare do
  Setting.class_eval do
    unless _commit_callbacks.map(&:filter).include?(:intake_shield_reschedule_on_delay_change)
      after_commit :intake_shield_reschedule_on_delay_change, on: :update
    end

    def intake_shield_reschedule_on_delay_change
      return if name != 'intake_shield_delay_hours'
      return if previous_changes['state_current'].blank?

      IntakeShield.reschedule_pending_execute_at!
    rescue => e
      Rails.logger.error "IntakeShield delay reschedule failed: #{e.message}"
      IntakeShield.logger.error "Delay reschedule failed: #{e.message}"
    end
  end
end
