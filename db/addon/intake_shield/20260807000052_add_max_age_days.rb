class AddMaxAgeDays < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('20260807000039_ensure_upgrade_from_021.rb', __dir__)
    EnsureUpgradeFrom021.ensure_max_age_days_setting!

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end

    Rails.cache.clear
  end

  def self.down
    Setting.find_by(name: 'intake_shield_max_age_days')&.destroy
  end
end
