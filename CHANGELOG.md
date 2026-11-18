# Changelog

All notable changes to [IntakeShield](https://github.com/Tranquillius/intakeshield) are documented here.

This file is the source for [GitHub Release](https://github.com/Tranquillius/intakeshield/releases) notes (`bin/changelog-notes`). When you bump the package version, add a new section at the top (below **Unreleased**) and move finished items out of **Unreleased**.

Only tagged GitHub releases are top-level headings. Package versions that were never tagged separately are listed under the GitHub release that first published them.

## [Unreleased]

## [0.10.1] - 2026-11-18

### Fixed

- **Package precompile crash**: `rails generate zammad:setting_types` (run by `zammad:package:precompile` / `post_install`) failed with ``undefined method 'keys' for nil`` because the role pickers (`intake_shield_whitelist_role_id`, `intake_shield_whitelist_remove_role_ids`, `intake_shield_candidate_role_id`) were frontend select settings without static options. They are now backend-only; a migration updates existing installs. This failure left the classic UI assets without IntakeShield's code.

## [0.10.0] - 2026-11-18

### Added

- **Suspicious scripts**: optional `suspicious_script` scoring signal (default weight 50). Pick character sets such as Han, Hiragana and Katakana under Settings → Cleanup; a user name, ticket title or first article body written mostly in them (share of letters ≥ `intake_shield_suspicious_script_ratio`, default 30 %) raises the spam score. URLs, e-mail addresses and HTML are ignored. Off until a script is selected.

### Changed

- README: on Zammad 7.2.2 a failed `pnpm install` during package precompile leaves the plugin out of the classic UI assets; run `zammad run rake zammad:package:precompile` and restart Zammad to recover.

## [0.9.1] - 2026-09-04

### Fixed

- Use Zammad’s existing `danger` icon for **Mark as spam** so the Manage → Users action stays normal size (`icon-ignore` is not in the sprite).

### Changed

- GitHub Release notes are generated from this changelog (`bin/changelog-notes`).

## [0.9.0] - 2026-09-04

### Added

- **Mark as spam** on the classic Admin → Manage → Users action menu. Adds the user’s e-mail (sub)domain to the blacklist; matching accounts are queued by the existing spam-user scan.

## [0.8.2] - 2026-08-15

### Changed

- Show Filters and Spam help text under the nav tabs (no Description button).
- Label the Settings master switch separately from the page heading.

### Fixed

- Empty Filters/Spam admin pages and duplicated Settings tabs caused by CoffeeScript controllers not being visible across files (package 0.8.1, shipped in this GitHub release).

## [0.8.0] - 2026-08-15

### Changed

- Group the admin UI into **Filters** (Whitelist / Blacklist / Keywords), **Spam** (Users / Tickets), and **Settings** tabs, matching Zammad’s Knowledge Base pattern. The master switch is the Settings header toggle.

This GitHub release also includes package versions 0.5.0–0.7.0, which were not tagged separately:

### Added

- **0.7.0** — Optional whitelist allow list for self-registration (classic signup and GraphQL `userSignup`). Independent of the master switch; admin/agent creation, mail auto-create, and LDAP are unchanged.
- **0.6.0** — Optional scoring from gateway spam headers (SpamAssassin, Rspamd, Microsoft SCL) or a local daemon. The engines are not bundled. The `spam_engine` weight is skipped when the ticket already carries the configured spam tag.
- **0.5.0** — Optional inbound drop of mail from blacklist domains (`off` / all mail / only mail that would create a new user or ticket). The original message still follows the e-mail channel keep-on-server setting. Signup CAPTCHA always uses self-hosted ALTCHA.

## [0.4.3] - 2026-08-14

First public GitHub release.

### Fixed

- Solve the signup CAPTCHA on the main thread. Zammad’s CSP blocks ALTCHA’s blob/data Web Workers, which left the widget retrying challenges forever.

This GitHub release also includes earlier package versions that were not tagged on GitHub:

### Added

- **0.4.2** — Drop stale Taskbar/RecentView IDs before Data Privacy deletion; never score or auto-learn infrastructure and government domains as disposable; whitelist sync only writes and logs when role membership actually changes.
- **0.4.1** — Serve the ALTCHA widget from the Zammad instance instead of jsdelivr so the default CSP no longer blocks sign-up and password-reset captchas.
- **0.4.0** — Optional CAPTCHA on classic sign-up and password-reset requests. Skip ticket-only deletion when the customer is already a spam-user candidate.
- **0.3.9** — Make `IntakeShield.diagnose_user` public and include active whitelist/blacklist patterns in the diagnosis output.
- **0.3.8** — When `disposable_domain` weight meets the score threshold, skip candidate-role and ticket-count filters for blacklisted users; add `IntakeShield.diagnose_user`.
- **0.3.7** — Treat integer setting value `0` as valid (e.g. `min_age_days=0`) instead of falling back via `.presence`.
- **0.3.6** — Ensure max account age setting is created on upgrades; refresh settings UI from server.
- **0.3.5** — Maximum account age setting, whitelist role removal, and hourly user cleanup scan.
- **0.1.0** — Initial version.

[Unreleased]: https://github.com/Tranquillius/intakeshield/compare/v0.10.1...HEAD
[0.10.1]: https://github.com/Tranquillius/intakeshield/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/Tranquillius/intakeshield/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/Tranquillius/intakeshield/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/Tranquillius/intakeshield/compare/v0.8.2...v0.9.0
[0.8.2]: https://github.com/Tranquillius/intakeshield/compare/v0.8.0...v0.8.2
[0.8.0]: https://github.com/Tranquillius/intakeshield/compare/v0.4.3...v0.8.0
[0.4.3]: https://github.com/Tranquillius/intakeshield/releases/tag/v0.4.3
