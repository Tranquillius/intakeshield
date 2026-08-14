class IntakeShield::Whitelist < ApplicationModel
  include HasDefaultModelUserRelations

  self.table_name = 'intake_shield_whitelists'

  CACHE_KEY = 'intake_shield/whitelist_patterns'.freeze

  before_validation :normalize_pattern
  after_commit :clear_pattern_cache
  after_commit :cancel_matching_pending_deletions, on: %i[create update]

  validates :pattern, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }

  # Matches an e-mail address against all active whitelist entries.
  # Supported pattern formats:
  #   user@example.com  - exact address
  #   @example.com      - domain including all subdomains
  #   example.com       - domain including all subdomains
  #   *@example.com     - domain including all subdomains
  #
  # Domain entries match the apex domain and any subdomain
  # (e.g. @example.com matches user@example.com and user@mail.example.com).
  def self.matches?(email)
    return false if email.blank?

    normalized = email.to_s.strip.downcase
    domain = normalized.split('@', 2).last
    return false if domain.blank?

    active_patterns.any? do |pattern|
      if pattern.start_with?('@', '*@')
        domain_matches?(domain, pattern.delete_prefix('*').delete_prefix('@'))
      elsif pattern.include?('@')
        normalized == pattern
      else
        domain_matches?(domain, pattern)
      end
    end
  end

  def self.active_patterns
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.minute) do
      active.order(:pattern).pluck(:pattern)
    end
  end

  # Scope of users matching this entry (used by the periodic sync job).
  def matching_users
    if domain_entry?
      # Apex domain (@example.com) and any subdomain (@*.example.com).
      User.where(
        'LOWER(email) LIKE ? OR LOWER(email) LIKE ?',
        "%@#{domain_part}",
        "%@%.#{domain_part}"
      )
    else
      User.where('LOWER(email) = ?', pattern)
    end
  end

  def self.domain_matches?(domain, pattern_domain)
    IntakeShield::DomainMatching.apex_or_subdomain?(domain, pattern_domain)
  end
  private_class_method :domain_matches?

  private

  def domain_entry?
    !pattern.include?('@') || pattern.start_with?('@') || pattern.start_with?('*@')
  end

  def domain_part
    pattern.delete_prefix('*').delete_prefix('@')
  end

  def normalize_pattern
    self.pattern = pattern.to_s.strip.downcase
  end

  def clear_pattern_cache
    Rails.cache.delete(CACHE_KEY)
  end

  def cancel_matching_pending_deletions
    return if !active?

    IntakeShield::PendingDeletion.pending.includes(:user).find_each do |pending_deletion|
      user = pending_deletion.user
      next if user.blank? || user.email.blank?
      next if !self.class.matches?(user.email)

      pending_deletion.cancel!('whitelisted')
      IntakeShield.logger.info "Cancelled pending deletion ##{pending_deletion.id} after whitelist change (#{user.email})"
    end
  end
end
