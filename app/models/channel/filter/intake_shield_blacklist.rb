# Drops inbound mail from blacklisted sender domains before Zammad creates
# a user or ticket. Registered twice (0013 before identify, 0105 after
# follow-up detection) so new_only can keep follow-ups on existing tickets.
class Channel::Filter::IntakeShieldBlacklist
  CHECKED_KEY = :intake_shield_blacklist_checked

  def self.run(_channel, mail, _transaction_params = nil)
    return if ignored?(mail)

    mode = IntakeShield.drop_blacklisted_mail_mode
    return if mode == 'off'

    email = sender_email(mail)
    return if email.blank?
    return if IntakeShield.whitelisted?(email)

    domain = sender_domain(mail, email)
    return if domain.blank?
    return if !IntakeShield::Blacklist.includes_domain?(domain)

    user = find_user(email)
    return if privileged?(user)

    if mode == 'all'
      ignore!(mail, domain: domain, mode: mode)
      return
    end

    # new_only: unknown senders would create a user (and usually a ticket).
    if user.blank?
      ignore!(mail, domain: domain, mode: mode)
      return
    end

    # Existing user: wait until follow-up detection has run, then drop only
    # mail that would open a new ticket.
    return if follow_up?(mail)

    if mail[CHECKED_KEY]
      ignore!(mail, domain: domain, mode: mode)
    else
      mail[CHECKED_KEY] = true
    end
  rescue => e
    IntakeShield.logger.error "Blacklist inbound filter failed: #{e.message}"
  end

  def self.ignored?(mail)
    return false if mail.blank?

    ['true', true].include?(mail[:'x-zammad-ignore'])
  end

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

  def self.sender_domain(mail, email)
    domain = mail[:from_domain].to_s.strip.downcase.presence
    domain.presence || email.to_s.split('@', 2).last.to_s.downcase.presence
  end
  private_class_method :sender_domain

  def self.find_user(email)
    User.find_by('LOWER(email) = :email OR LOWER(login) = :email', email: email)
  end
  private_class_method :find_user

  def self.privileged?(user)
    user.present? && user.permissions?(['admin', 'ticket.agent'])
  end
  private_class_method :privileged?

  def self.follow_up?(mail)
    mail[:'x-zammad-ticket-id'].present? || mail[:'x-zammad-ticket-number'].present?
  end
  private_class_method :follow_up?

  def self.ignore!(mail, domain:, mode:)
    mail[:'x-zammad-ignore'] = true
    IntakeShield.logger.info "Dropped inbound mail from blacklisted domain #{domain} (msgid=#{mail[:message_id]}, mode=#{mode})"
  end
  private_class_method :ignore!
end
