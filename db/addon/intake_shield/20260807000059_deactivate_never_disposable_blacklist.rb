# Drop auto-learned (or manual) disposable entries for infrastructure and
# government domains so they no longer raise the spam score.
class DeactivateNeverDisposableBlacklist < ActiveRecord::Migration[7.0]
  NOTE = 'Deactivated never-disposable domain'.freeze

  def self.up
    return if !ActiveRecord::Base.connection.table_exists?(:intake_shield_blacklists)

    deactivated = 0
    IntakeShield::Blacklist.find_each do |entry|
      next if !IntakeShield::NeverDisposable.pattern?(entry.pattern)

      note = [entry.note.presence, NOTE].compact.join(' — ')
      entry.update_columns(active: false, note: note, updated_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
      deactivated += 1
    end

    Rails.cache.delete(IntakeShield::Blacklist::CACHE_KEY) if deactivated.positive?
    Rails.logger.info "IntakeShield deactivated #{deactivated} never-disposable blacklist pattern(s)" if deactivated.positive?

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end
  end

  def self.down
    # noop — do not re-activate poisoned disposable entries
  end
end
