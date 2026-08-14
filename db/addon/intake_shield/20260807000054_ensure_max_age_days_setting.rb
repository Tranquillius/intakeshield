# Idempotent safety net: create max_age / whitelist-remove settings if an
# earlier package upgrade skipped their dedicated migrations.
class EnsureMaxAgeDaysSetting < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('20260807000039_ensure_upgrade_from_021.rb', __dir__)
    EnsureUpgradeFrom021.ensure_missing_settings!
    EnsureUpgradeFrom021.ensure_settings_areas!

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end

    Rails.cache.clear
  end

  def self.down
    # keep settings — removing them would break configured installs
  end
end
