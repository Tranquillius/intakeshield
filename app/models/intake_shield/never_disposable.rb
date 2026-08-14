# Domains that must never count as disposable — scoring and auto-learn.
module IntakeShield::NeverDisposable
  module_function

  # Bounce / mailbox hosts, not throwaway-mail providers.
  INFRA_DOMAINS = %w[
    udag.de
  ].freeze

  def domain?(value)
    normalized = normalize(value)
    return true if normalized.blank?

    skipped_base?(normalized) || government?(normalized)
  end

  def pattern?(value)
    domain?(normalize(value))
  end

  def skipped_base?(domain)
    skip_domains.any? do |base|
      IntakeShield::DomainMatching.apex_or_subdomain?(domain, base)
    end
  end

  def government?(domain)
    domain == 'gov' || domain.end_with?('.gov') || domain.include?('.gov.')
  end

  def skip_domains
    IntakeShield::AUTO_LEARN_SKIP_DOMAINS + INFRA_DOMAINS
  end

  def normalize(value)
    value.to_s.strip.downcase.delete_prefix('*').delete_prefix('@').delete_prefix('.').presence
  end
end
