# Switch the spam-user cleanup scan from daily to hourly.
class HourlyUserCleanupScan < ActiveRecord::Migration[7.0]
  METHOD = 'IntakeShield.cleanup_scan'
  PERIOD = 1.hour

  def self.up
    scheduler = Scheduler.find_by(method: METHOD)
    if scheduler.present? && scheduler.period != PERIOD
      scheduler.update!(period: PERIOD)
    end

    load File.expand_path('support/de_translations.rb', __dir__)
    IntakeShieldDeTranslations.apply!
    Rails.cache.clear
  end

  def self.down
    scheduler = Scheduler.find_by(method: METHOD)
    return if scheduler.blank?

    scheduler.update!(period: 1.day)
  end
end
