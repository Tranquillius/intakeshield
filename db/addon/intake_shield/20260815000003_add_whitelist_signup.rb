# Optional whitelist allow list for self-registration (independent of the master switch).
class AddWhitelistSignup < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('20260807000000_create_base.rb', __dir__)
    CreateBase.create_whitelist_signup_settings

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end

    Rails.cache.clear
  end

  def self.down
    Setting.find_by(name: 'intake_shield_whitelist_signup')&.destroy
  end
end
