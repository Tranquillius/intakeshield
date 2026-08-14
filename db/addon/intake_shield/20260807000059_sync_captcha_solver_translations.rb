# Refresh translations after the in-page ALTCHA solver replaced the widget.
class SyncCaptchaSolverTranslations < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('support/de_translations.rb', __dir__)
    IntakeShieldDeTranslations.apply!
  rescue StandardError => e
    Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
  end
end
