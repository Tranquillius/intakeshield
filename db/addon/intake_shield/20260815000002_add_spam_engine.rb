# Optional gateway / local spam-engine scoring (headers first, live daemon fallback).
class AddSpamEngine < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('20260807000000_create_base.rb', __dir__)
    CreateBase.create_spam_engine_settings
    ensure_spam_engine_weight!

    begin
      load File.expand_path('support/de_translations.rb', __dir__)
      IntakeShieldDeTranslations.apply!
    rescue StandardError => e
      Rails.logger.error "IntakeShield translations sync skipped: #{e.class}: #{e.message}"
    end

    Rails.cache.clear
  end

  def self.down
    %w[
      intake_shield_spam_engine
      intake_shield_spam_engine_backend
      intake_shield_spam_engine_host
      intake_shield_spam_engine_port
      intake_shield_spam_engine_timeout
      intake_shield_spam_engine_password
      5405_postmaster_filter_intake_shield_spam_engine
    ].each do |name|
      Setting.find_by(name: name)&.destroy
    end
  end

  def self.ensure_spam_engine_weight!
    load File.expand_path('support/parse_weights.rb', __dir__)
    weights = IntakeShieldParseWeights.call(Setting.get('intake_shield_score_weights'))
    return if weights.key?('spam_engine')

    weights['spam_engine'] = 50
    Setting.set('intake_shield_score_weights', JSON.pretty_generate(weights))
  end
end
