# Inbound drop of blacklisted sender domains (independent of the master switch).
class AddDropBlacklistedMail < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('20260807000000_create_base.rb', __dir__)
    CreateBase.create_drop_blacklisted_mail_settings

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end

    Rails.cache.clear
  end

  def self.down
    Setting.find_by(name: 'intake_shield_drop_blacklisted_mail')&.destroy
    Setting.find_by(name: '0013_postmaster_filter_intake_shield_blacklist')&.destroy
    Setting.find_by(name: '0105_postmaster_filter_intake_shield_blacklist_followup')&.destroy
  end
end
