# Re-apply German UI strings after grouping admin pages into Filter / Spam / Settings tabs.
class SyncGuiTabsTranslations < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('support/de_translations.rb', __dir__)
    IntakeShieldDeTranslations.apply!
    Rails.cache.clear
  end

  def self.down
    # noop — leave translations as last applied
  end
end
