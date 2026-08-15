# Changelog

Package versions are also recorded in `intake_shield.szpm`.

## 0.8.0 — 2026-08-15

Group the admin UI into Filters (Whitelist / Blacklist / Keywords), Spam (Users / Tickets), and Settings tabs, matching Zammad's Knowledge Base pattern. The master switch is the Settings header toggle.

## 0.7.0 — 2026-08-15

Optional switch to use the whitelist as an allow list for self-registration. Addresses that do not match are rejected with a clear error on classic signup and GraphQL `userSignup`. Independent of the master switch; admin/agent creation, mail auto-create, and LDAP are unchanged.

## 0.6.0 — 2026-08-15

Optional scoring from gateway spam headers (SpamAssassin, Rspamd, Microsoft SCL) or a local daemon. IntakeShield does not ship those engines. The `spam_engine` weight is skipped when the ticket already carries the configured spam tag.

## 0.5.0 — 2026-08-15

Optional inbound drop of mail from blacklist domains before Zammad creates a user or ticket. Choose off, all mail, or only mail that would create a new user or ticket. The original message still follows the e-mail channel option to keep or delete mail on the server. Signup CAPTCHA always uses self-hosted ALTCHA (the form-channel source option is removed).

## 0.4.3 — 2026-08-14

Solve the signup CAPTCHA on the main thread. Zammad's CSP blocks ALTCHA's blob/data Web Workers, which left the widget retrying challenges forever.

## 0.4.2 — 2026-08-14

Drop stale Taskbar/RecentView IDs before Data Privacy deletion; never score or auto-learn infrastructure and government domains as disposable; whitelist sync only writes and logs when role membership actually changes.

## 0.4.1 — 2026-08-14

Serve the ALTCHA widget from the Zammad instance instead of jsdelivr so the default CSP no longer blocks sign-up and password-reset captchas.

## 0.4.0 — 2026-08-13

Optional CAPTCHA on classic sign-up and password-reset requests (self-hosted ALTCHA or the form-channel provider). Skip ticket-only deletion when the customer is already a spam-user candidate so user deletion removes the tickets.

## 0.3.9 — 2026-08-11

Make `IntakeShield.diagnose_user` public and include active whitelist/blacklist patterns in the diagnosis output.

## 0.3.8 — 2026-08-11

When `disposable_domain` weight meets the score threshold, skip candidate-role and ticket-count filters for blacklisted users; add `IntakeShield.diagnose_user`.

## 0.3.7 — 2026-08-11

Treat integer setting value `0` as valid (e.g. `min_age_days=0`) instead of falling back to defaults via `.presence`.

## 0.3.6 — 2026-08-11

Ensure max account age setting is created on upgrades; refresh settings UI from server.

## 0.3.5 — 2026-08-11

Add maximum account age setting, whitelist role removal, and hourly user cleanup scan.

## 0.1.0 — 2026-08-07

Initial version.
