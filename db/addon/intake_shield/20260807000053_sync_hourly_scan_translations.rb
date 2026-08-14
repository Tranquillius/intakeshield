# Re-apply German UI strings after the hourly user-scan change.
# Updates the legacy "once per day" translation still used by cached assets.
class SyncHourlyScanTranslations < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('support/de_translations.rb', __dir__)
    IntakeShieldDeTranslations.apply!
    Rails.cache.clear
  end

  def self.down
    # noop — leave translations as last applied
  end
end
