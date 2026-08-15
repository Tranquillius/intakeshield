class IntakeShield::SpamEngine::Headers
  class << self
    def verdict(mail)
      return if mail.blank?

      sa = spamassassin_verdict(mail)
      return sa if sa

      rspamd = rspamd_verdict(mail)
      return rspamd if rspamd

      microsoft_scl_verdict(mail)
    end

    # Gateway already classified the message as ham. Live check must not override.
    def explicit_ham?(mail)
      return false if mail.blank?
      return true if no?(header(mail, 'x-spam-flag'))
      return true if no?(header(mail, 'x-spam'))

      status = header(mail, 'x-spam-status')
      return true if status.present? && status.match?(%r{\A\s*No\b}i)

      scl = scl_value(mail)
      scl.present? && scl >= 0 && scl < IntakeShield::SpamEngine::SCL_MIN
    end

    private

    def spamassassin_verdict(mail)
      flag = header(mail, 'x-spam-flag')
      status = header(mail, 'x-spam-status')
      return if !yes?(flag) && !(status.present? && status.match?(%r{\A\s*Yes\b}i))

      IntakeShield::SpamEngine::Verdict.new(
        engine: 'spamassassin',
        source: 'headers',
        score:  score_from_spamassassin(mail, status),
      )
    end

    def rspamd_verdict(mail)
      flag = header(mail, 'x-spam')
      result = header(mail, 'x-spamd-result')
      return if !yes?(flag) && !(result.present? && result.match?(%r{:\s*True\b}i))

      IntakeShield::SpamEngine::Verdict.new(
        engine: 'rspamd',
        source: 'headers',
        score:  score_from_rspamd(result),
      )
    end

    def microsoft_scl_verdict(mail)
      scl = scl_value(mail)
      return if scl.blank? || scl < IntakeShield::SpamEngine::SCL_MIN

      IntakeShield::SpamEngine::Verdict.new(
        engine: 'microsoft_scl',
        source: 'headers',
        score:  scl,
      )
    end

    def score_from_spamassassin(mail, status)
      score = parse_float(header(mail, 'x-spam-score'))
      return score if score

      if status.to_s =~ %r{score\s*=\s*([+-]?\d+(?:\.\d+)?)}i
        return $1.to_f
      end

      nil
    end

    def score_from_rspamd(result)
      if result.to_s =~ %r{\[\s*([+-]?\d+(?:\.\d+)?)\s*/}
        return $1.to_f
      end

      nil
    end

    def scl_value(mail)
      raw = header(mail, 'x-ms-exchange-organization-scl')
      if raw.blank?
        report = header(mail, 'x-forefront-antispam-report')
        raw = $1 if report.to_s =~ %r{(?:^|;)\s*SCL:(-?\d+)}i
      end
      return if raw.blank?

      Integer(raw.to_s.strip)
    rescue ArgumentError, TypeError
      nil
    end

    def header(mail, name)
      value = if mail.respond_to?(:[])
                mail[name] || mail[name.to_sym] || mail[name.to_s]
              end
      value = value.first if value.is_a?(Array)
      value.to_s.strip.presence
    end

    def yes?(value)
      value.to_s.strip.match?(%r{\A(yes|true|1)\z}i)
    end

    def no?(value)
      value.to_s.strip.match?(%r{\A(no|false|0)\z}i)
    end

    def parse_float(value)
      return if value.blank?

      Float(value.to_s.strip)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
