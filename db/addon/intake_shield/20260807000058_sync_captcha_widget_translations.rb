# Refresh translations after serving the ALTCHA widget same-origin.
class SyncCaptchaWidgetTranslations < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('support/de_translations.rb', __dir__)
    IntakeShieldDeTranslations.apply!
  rescue StandardError => e
    Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
  end
end
