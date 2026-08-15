# Optional inbound spam-engine signal. The classifier (SpamAssassin, Rspamd,
# Microsoft SCL) stays on the mail gateway or a local daemon — this package
# never vendors those engines.
class IntakeShield::SpamEngine
  PREFERENCE_KEY = 'intake_shield_spam_engine'.freeze
  MODES = %w[off headers live].freeze
  BACKENDS = %w[spamassassin rspamd].freeze
  DEFAULT_PORTS = {
    'spamassassin' => 783,
    'rspamd'       => 11_333,
  }.freeze
  SCL_MIN = 5

  Verdict = Struct.new(:engine, :source, :score, keyword_init: true)

  class << self
    def mode
      value = Setting.get('intake_shield_spam_engine').to_s.strip
      return value if MODES.include?(value)

      'off'
    end

    def enabled?
      mode != 'off'
    end

    def live?
      mode == 'live'
    end

    def backend
      value = Setting.get('intake_shield_spam_engine_backend').to_s.strip
      return value if BACKENDS.include?(value)

      'spamassassin'
    end

    def host
      Setting.get('intake_shield_spam_engine_host').to_s.strip.presence || '127.0.0.1'
    end

    def port
      value = Setting.get('intake_shield_spam_engine_port')
      parsed = value.nil? ? DEFAULT_PORTS[backend] : value.to_i
      parsed = DEFAULT_PORTS[backend] if parsed <= 0 || parsed > 65_535
      parsed
    end

    def timeout
      seconds = Setting.get('intake_shield_spam_engine_timeout').to_i
      seconds = 2 if seconds <= 0
      seconds > 15 ? 15 : seconds
    end

    def password
      Setting.get('intake_shield_spam_engine_password').to_s
    end

    # Header scan first; live daemon only when mode is live and no gateway
    # verdict is present. Fail-open: errors return nil.
    def evaluate(mail)
      return if !enabled?
      return if mail.blank?

      header_verdict = IntakeShield::SpamEngine::Headers.verdict(mail)
      return header_verdict if header_verdict
      return if IntakeShield::SpamEngine::Headers.explicit_ham?(mail)
      return if !live?

      IntakeShield::SpamEngine::Client.check(mail[:raw] || mail['raw'])
    rescue => e
      IntakeShield.logger.error "Spam engine evaluate failed: #{e.class}: #{e.message}"
      nil
    end

    def stamp!(article, verdict)
      return if article.blank? || verdict.blank?

      prefs = article.preferences.is_a?(Hash) ? article.preferences.dup : {}
      prefs[PREFERENCE_KEY] = {
        'spam'   => true,
        'engine' => verdict.engine.to_s,
        'source' => verdict.source.to_s,
        'score'  => verdict.score,
      }
      article.preferences = prefs
      article.save!
    end

    def stamped?(article)
      payload = preference_payload(article)
      return false if payload.blank?

      value = payload['spam']
      value == true || value.to_s.strip.casecmp('true').zero? || value.to_s.strip == '1'
    end

    def preference_payload(article)
      return if article.blank?

      prefs = article.preferences
      return if !prefs.is_a?(Hash)

      payload = prefs[PREFERENCE_KEY] || prefs[PREFERENCE_KEY.to_sym]
      payload.is_a?(Hash) ? payload.stringify_keys : nil
    end

    def customer_ids
      ticket_ids = stamped_ticket_ids
      return [] if ticket_ids.blank?

      Ticket.where(id: ticket_ids).distinct.pluck(:customer_id).compact
    rescue ActiveRecord::StatementInvalid, NameError
      []
    end

    private

    def stamped_ticket_ids
      Ticket::Article.where('preferences LIKE ?', "%#{PREFERENCE_KEY}%").distinct.pluck(:ticket_id)
    rescue ActiveRecord::StatementInvalid
      Ticket::Article.where('CAST(preferences AS TEXT) LIKE ?', "%#{PREFERENCE_KEY}%").distinct.pluck(:ticket_id)
    end
  end
end
