class IntakeShield::Scorer
  Result = Struct.new(:score, :reasons, keyword_init: true)

  SIGNALS = %i[
    never_logged_in
    low_ticket_count
    disposable_domain
    suspicious_email_pattern
    missing_name
    spam_tag
    spam_keyword
    suspicious_script
    spam_engine
  ].freeze

  SIGNAL_LABELS = {
    never_logged_in:          __('Never logged in'),
    low_ticket_count:         __('Low ticket count'),
    disposable_domain:        __('Disposable domain'),
    suspicious_email_pattern: __('Suspicious e-mail pattern'),
    missing_name:             __('Missing name'),
    spam_tag:                 __('Tagged spam ticket'),
    spam_keyword:             __('Spam keyword'),
    suspicious_script:        __('Suspicious script'),
    spam_engine:              __('Spam engine'),
  }.freeze

  def self.configured_spam_tag_name
    value = Setting.get('intake_shield_spam_tag')
    tags = case value
           when Array
             value
           when String
             stripped = value.strip
             if stripped.start_with?('[')
               JSON.parse(stripped)
             else
               stripped.split(',')
             end
           else
             []
           end
    Array(tags).map { |tag| tag.to_s.strip }.reject(&:blank?).first
  rescue JSON::ParserError
    value.to_s.split(',').map(&:strip).reject(&:blank?).first
  end

  def self.score_weights
    value = Setting.get('intake_shield_score_weights')
    parsed = case value
             when Hash
               value
             when String
               JSON.parse(value.presence || '{}')
             else
               {}
             end
    parsed.is_a?(Hash) ? parsed.stringify_keys : {}
  rescue JSON::ParserError, TypeError
    {}
  end

  def initialize(user)
    @user = user
  end

  def result
    score = 0
    reasons = []
    counted_spam_tag = false
    SIGNALS.each do |signal|
      next unless send(:"#{signal}?")

      weight = weights[signal.to_s].to_i
      next if weight <= 0

      # Gateway engines often also drive the SPAM tag via a Postmaster filter.
      # Count only one of the two when both fire.
      if signal == :spam_engine && counted_spam_tag
        next
      end

      score += weight
      reasons << "#{SIGNAL_LABELS.fetch(signal)} (+#{weight})"
      counted_spam_tag = true if signal == :spam_tag
    end
    Result.new(score: score, reasons: reasons)
  end

  private

  def weights
    @weights ||= self.class.score_weights
  end

  def ticket_count
    @ticket_count ||= @user.customer_tickets.count
  end

  def never_logged_in?
    @user.last_login.blank?
  end

  def low_ticket_count?
    ticket_count <= 1
  end

  def disposable_domain?
    IntakeShield::Blacklist.includes_domain?(email_domain)
  rescue ActiveRecord::StatementInvalid, NameError
    false
  end

  # Heuristic for machine generated addresses: long local part with a high
  # digit ratio or a very low vowel ratio looks like a random string.
  def suspicious_email_pattern?
    local = email_local_part
    return false if local.length < 10

    digit_ratio = local.count('0-9').to_f / local.length
    vowel_ratio = local.count('aeiou').to_f / local.length
    digit_ratio > 0.4 || vowel_ratio < 0.2
  end

  def missing_name?
    @user.firstname.blank? && @user.lastname.blank?
  end

  # True when an active keyword appears in a customer ticket title or the
  # body of its first article.
  def spam_keyword?
    keywords = IntakeShield::Keyword.active_keywords
    return false if keywords.blank?

    first_articles.any? do |ticket, article|
      text = [ticket.title, article&.body].compact.join("\n")
      IntakeShield::Keyword.matches_text?(text, keywords)
    end
  rescue ActiveRecord::StatementInvalid, NameError
    false
  end

  # True when the user's name, or the title or first article body of a
  # customer ticket, is written mostly in a script marked as suspicious.
  def suspicious_script?
    scripts = IntakeShield::ScriptDetector.configured_scripts
    return false if scripts.blank?

    ratio = IntakeShield::ScriptDetector.min_ratio
    name = [@user.firstname, @user.lastname].compact.join(' ')
    return true if IntakeShield::ScriptDetector.suspicious?(name, scripts: scripts, ratio: ratio)

    first_articles.any? do |ticket, article|
      IntakeShield::ScriptDetector.suspicious?(ticket.title, scripts: scripts, ratio: ratio) ||
        IntakeShield::ScriptDetector.suspicious?(IntakeShield::ScriptDetector.article_text(article), scripts: scripts, ratio: ratio)
    end
  rescue ActiveRecord::StatementInvalid, NameError
    false
  end

  # [ticket, first article] pairs of the user's customer tickets, shared by
  # the text based signals.
  def first_articles
    @first_articles ||= @user.customer_tickets.map do |ticket|
      [ticket, ticket.articles.reorder(:id).first]
    end
  end

  # True when inbound mail was classified as spam by a gateway engine
  # (SpamAssassin / Rspamd / Microsoft SCL) or a local live check.
  def spam_engine?
    return false if IntakeShield::SpamEngine.mode == 'off'

    @user.customer_tickets.find_each do |ticket|
      ticket.articles.reorder(:id).limit(8).each do |article|
        return true if IntakeShield::SpamEngine.stamped?(article)
      end
    end

    false
  rescue ActiveRecord::StatementInvalid, NameError
    false
  end

  # True when the configured spam tag is set and at least one customer ticket
  # of the user carries that tag.
  def spam_tag?
    tag_name = configured_spam_tag
    return false if tag_name.blank?

    tag_item = IntakeShield.spam_tag_item
    if tag_item.present?
      tag_object = Tag::Object.lookup(name: 'Ticket')
      if tag_object.present?
        ticket_ids = @user.customer_tickets.pluck(:id)
        if ticket_ids.present? && Tag.where(tag_object_id: tag_object.id, tag_item_id: tag_item.id, o_id: ticket_ids).exists?
          return true
        end
      end
    end

    # Fallback via Ticket#tag_list (covers edge cases around tag storage).
    @user.customer_tickets.find_each do |ticket|
      return true if Array(ticket.tag_list).any? { |entry| entry.to_s.casecmp?(tag_name) }
    end

    false
  end

  def configured_spam_tag
    self.class.configured_spam_tag_name
  end

  def email_domain
    @user.email.to_s.split('@', 2).last.to_s.downcase
  end

  def email_local_part
    @user.email.to_s.split('@', 2).first.to_s.downcase
  end
end
