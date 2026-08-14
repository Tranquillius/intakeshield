# Shared apex/subdomain matching used by Whitelist and Blacklist patterns.
module IntakeShield::DomainMatching
  module_function

  # True when domain equals base or is a subdomain of base.
  def apex_or_subdomain?(domain, base)
    domain = domain.to_s
    base = base.to_s
    return false if domain.blank? || base.blank?

    domain == base || domain.end_with?(".#{base}")
  end
end
