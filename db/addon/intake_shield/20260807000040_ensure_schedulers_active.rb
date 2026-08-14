# Re-activate IntakeShield schedulers after reinstall/upgrade.
# Scheduler.create_if_not_exists does not flip active back to true.
class EnsureSchedulersActive < ActiveRecord::Migration[7.0]
  def self.up
    [
      [__('IntakeShield: Apply whitelist role assignments.'), 'IntakeShield.whitelist_sync', 1.hour],
      [__('IntakeShield: Scan for spam users.'), 'IntakeShield.cleanup_scan', 1.hour],
      [__('IntakeShield: Execute pending deletions.'), 'IntakeShield.execute_pending_deletions', 30.minutes],
      [__('IntakeShield: Scan for spam tickets.'), 'IntakeShield.cleanup_ticket_scan', 1.hour],
      [__('IntakeShield: Execute pending ticket deletions.'), 'IntakeShield.execute_pending_tickets', 30.minutes],
    ].each do |name, method, period|
      Scheduler.create_if_not_exists(
        name:          name,
        method:        method,
        period:        period,
        prio:          2,
        active:        true,
        updated_by_id: 1,
        created_by_id: 1,
      )
      scheduler = Scheduler.find_by(method: method)
      next if scheduler.blank?

      attrs = {}
      attrs[:active] = true if !scheduler.active
      attrs[:period] = period if scheduler.period != period
      attrs[:name] = name if scheduler.name != name
      scheduler.update!(attrs) if attrs.present?
    end
  end

  def self.down
    # noop — leave scheduler state as configured by the admin
  end
end
