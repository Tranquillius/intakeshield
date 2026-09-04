class IntakeShield::Blacklist < ApplicationModel
  include HasDefaultModelUserRelations

  self.table_name = 'intake_shield_blacklists'

  CACHE_KEY = 'intake_shield/blacklist_domains'.freeze

  DEFAULT_DOMAINS = %w[
    mailinator.com
    tempmail.com
    10minutemail.com
    guerrillamail.com
    trashmail.com
    yopmail.com
    sharklasers.com
    getnada.com
  ].freeze

  before_validation :normalize_pattern
  after_commit :clear_domain_cache

  validates :pattern, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }

  # True when the given e-mail domain matches an active blacklist entry.
  # Supported pattern formats (same idea as Whitelist):
  #   example.com / @example.com / *@example.com  - apex + all subdomains
  #   *.example.com                               - subdomains only (not apex)
  def self.includes_domain?(domain)
    normalized = normalize_email_domain(domain)
    return false if normalized.blank?
    return false if IntakeShield::NeverDisposable.domain?(normalized)

    active_patterns.any? do |pattern|
      domain_matches?(normalized, pattern)
    end
  end

  def self.active_patterns
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.minute) do
      active.order(:pattern).pluck(:pattern)
    end
  end

  # Creates an active blacklist entry for a domain unless it already exists
  # or is never-disposable (freemail, mail infrastructure, government).
  # Returns the created (or reactivated) record, or nil.
  def self.remember_domain!(domain, note: nil, by: 1, reactivate: false)
    normalized = normalize_pattern_value(domain)
    return if normalized.blank?
    return if IntakeShield::NeverDisposable.pattern?(normalized)

    actor_id = actor_id_for(by)
    existing = find_by(['LOWER(pattern) = ?', normalized])
    if existing
      return if existing.active?
      return if !reactivate

      attrs = { active: true, updated_by_id: actor_id }
      attrs[:note] = note if note.present?
      existing.update!(attrs)
      return existing
    end

    create!(
      pattern:       normalized,
      note:          note,
      active:        true,
      created_by_id: actor_id,
      updated_by_id: actor_id,
    )
  end

  def self.seed_defaults!
    DEFAULT_DOMAINS.each do |domain|
      next if exists?(['LOWER(pattern) = ?', domain])

      create!(
        pattern:       domain,
        note:          __('Default disposable domain'),
        active:        true,
        created_by_id: 1,
        updated_by_id: 1,
      )
    end
  end

  # Normalizes a stored/entered blacklist pattern (keeps *. / @ prefixes).
  def self.normalize_pattern_value(value)
    value = value.to_s.strip.downcase
    return '' if value.blank?

    if value.start_with?('*.')
      base = value.delete_prefix('*.').delete_prefix('.').presence
      return base.present? ? "*.#{base}" : ''
    end

    if value.start_with?('*@') || value.start_with?('@')
      base = value.delete_prefix('*').delete_prefix('@').delete_prefix('.').presence
      return base.present? ? "@#{base}" : ''
    end

    value.delete_prefix('.').presence || ''
  end

  # Domain part of an e-mail address (no pattern syntax).
  def self.normalize_email_domain(value)
    value.to_s.strip.downcase.delete_prefix('@').delete_prefix('.').presence
  end

  # Backwards-compatible helper: bare domain without wildcard syntax.
  def self.normalize_domain(value)
    pattern_base(normalize_pattern_value(value))
  end

  def self.domain_matches?(domain, pattern)
    base = pattern_base(pattern)
    return false if base.blank?

    if pattern.start_with?('*.')
      domain.end_with?(".#{base}")
    else
      IntakeShield::DomainMatching.apex_or_subdomain?(domain, base)
    end
  end
  private_class_method :domain_matches?

  def self.pattern_base(pattern)
    pattern.to_s.delete_prefix('*').delete_prefix('@').delete_prefix('.')
  end
  private_class_method :pattern_base

  def self.actor_id_for(by)
    id = by.respond_to?(:id) ? by.id.to_i : by.to_i
    id.positive? ? id : 1
  end
  private_class_method :actor_id_for

  private

  def normalize_pattern
    self.pattern = self.class.normalize_pattern_value(pattern)
  end

  def clear_domain_cache
    Rails.cache.delete(CACHE_KEY)
  end
end
