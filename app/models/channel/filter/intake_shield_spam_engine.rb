# Postmaster post-filter: records a spam-engine verdict on the article so
# scoring can see it later. Never drops mail (including follow-ups). Independent
# of the master switch. Fail-open on errors.
class Channel::Filter::IntakeShieldSpamEngine
  def self.run(_channel, mail, _ticket = nil, article = nil, _session_user = nil)
    return if article.blank? || !article.respond_to?(:preferences)
    return if !IntakeShield::SpamEngine.enabled?
    return if ignored?(mail)
    return if skip_sender?(mail)

    verdict = IntakeShield::SpamEngine.evaluate(mail)
    return if verdict.blank?

    IntakeShield::SpamEngine.stamp!(article, verdict)
    IntakeShield.logger.info "Spam engine hit msgid=#{mail[:message_id]} engine=#{verdict.engine} source=#{verdict.source} score=#{verdict.score}"
  rescue => e
    IntakeShield.logger.error "Spam engine inbound filter failed: #{e.message}"
  end

  def self.ignored?(mail)
    return false if mail.blank?

    ['true', true].include?(mail[:'x-zammad-ignore'])
  end
  private_class_method :ignored?

  def self.skip_sender?(mail)
    email = sender_email(mail)
    return true if email.blank?
    return true if IntakeShield.whitelisted?(email)

    user = User.find_by('LOWER(email) = :email OR LOWER(login) = :email', email: email)
    user.present? && user.permissions?(['admin', 'ticket.agent'])
  rescue
    false
  end
  private_class_method :skip_sender?

  def self.sender_email(mail)
    value = mail[:'x-zammad-customer-email'].presence || mail[:from_email].presence || mail[:from]
    return if value.blank?

    normalized = value.to_s.strip.downcase
    if normalized =~ %r{<([^>]+)>}
      normalized = $1.strip.downcase
    end
    normalized.presence
  end
  private_class_method :sender_email
end
