# Document and sync that delay_hours 0 / "0" means no delay.
class SyncDelayHoursZeroSemantics < ActiveRecord::Migration[7.0]
  DESCRIPTION = 'Delay in hours between detection and the data privacy deletion. Set to 0 to disable the delay (schedule immediately). Changing this updates the planned time of all pending deletions.'.freeze

  def self.up
    setting = Setting.find_by(name: 'intake_shield_delay_hours')
    if setting && setting.description != DESCRIPTION
      setting.description = __(DESCRIPTION)
      setting.save!
    end

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end

    Rails.cache.clear
  end

  def self.down
    # noop — leave description/translations as last applied
  end
end
