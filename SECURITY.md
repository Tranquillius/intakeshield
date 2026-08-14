# Security Policy

## Supported versions

Please report issues against the latest [GitHub Release](https://github.com/Tranquillius/intakeshield/releases). Older package versions are not patched separately.

## Reporting a vulnerability

Use [GitHub Security Advisories](https://github.com/Tranquillius/intakeshield/security/advisories/new) so the report stays private until a fix is published.

Do **not** open a public issue for:

- authentication or CAPTCHA bypasses
- ways to trigger unintended Data Privacy deletions
- exploit details, payloads, or proof-of-concept attack steps

Include the IntakeShield version, Zammad version, and a minimal description of the impact.

## Data Privacy

IntakeShield can queue **permanent** user and ticket deletions through Zammad’s `DataPrivacyTask` pipeline. Treat misconfiguration reports that could cause unintended removal of accounts or tickets as security issues.

Keep the master switch off until whitelist, candidate role, delay, and review queues are in place.
