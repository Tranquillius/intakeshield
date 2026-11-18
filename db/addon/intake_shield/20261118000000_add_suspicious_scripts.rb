# Optional scoring signal for text written mostly in suspicious scripts
# (e.g. Chinese / Japanese spam).
class AddSuspiciousScripts < ActiveRecord::Migration[7.0]
  def self.up
    load File.expand_path('20260807000000_create_base.rb', __dir__)
    CreateBase.create_suspicious_script_settings
    ensure_suspicious_script_weight!

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
      intake_shield_suspicious_scripts
      intake_shield_suspicious_script_ratio
    ].each do |name|
      Setting.find_by(name: name)&.destroy
    end
  end

  def self.ensure_suspicious_script_weight!
    load File.expand_path('support/parse_weights.rb', __dir__)
    weights = IntakeShieldParseWeights.call(Setting.get('intake_shield_score_weights'))
    return if weights.key?('suspicious_script')

    weights['suspicious_script'] = 50
    Setting.set('intake_shield_score_weights', JSON.pretty_generate(weights))
  end
end
