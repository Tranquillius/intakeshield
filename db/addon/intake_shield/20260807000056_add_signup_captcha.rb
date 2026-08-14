# Signup / password-reset CAPTCHA settings (independent of the master switch).
class AddSignupCaptcha < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('20260807000000_create_base.rb', __dir__)
    CreateBase.create_signup_captcha_settings

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end

    Rails.cache.clear
  end

  def self.down
    Setting.find_by(name: 'intake_shield_signup_captcha')&.destroy
    Setting.find_by(name: 'intake_shield_captcha_source')&.destroy
  end
end
