# IntakeShield

[English](#english) · [Deutsch](#deutsch)

Zammad package against spam user accounts and spam-tagged tickets: e-mail whitelist/blacklist, optional signup allow list, optional inbound drop of blacklisted mail, keyword scoring, and automated cleanup via Zammad’s `DataPrivacyTask` mechanism.

Compatible with **Zammad 7.x** (classic package system and classic admin UI).

Community-maintained package. Not affiliated with [Zammad GmbH](https://zammad.com/) or the [Zammad Foundation](https://zammad-foundation.org/).

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)
[![Zammad](https://img.shields.io/badge/Zammad-7.x-brightgreen)](https://zammad.org/)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-PayPal-blue?logo=paypal)](https://paypal.me/tranquillius)

- Source: [github.com/Tranquillius/intakeshield](https://github.com/Tranquillius/intakeshield)
- Installable packages: [Releases](https://github.com/Tranquillius/intakeshield/releases)
- Changelog: [CHANGELOG.md](CHANGELOG.md)

---

<a id="english"></a>

## English

### What it does

IntakeShield helps on-premise Zammad instances reduce spam registrations and spam tickets without deleting anything blindly.

1. **Protect trusted senders** with a whitelist (exact addresses or domains including subdomains) and optionally assign a whitelist role.
2. **Optionally restrict self-registration** to that same whitelist (classic form and Desktop/Mobile GraphQL `userSignup`).
3. **Drop inbound mail from blacklisted domains** (optional) so Zammad never creates a user or ticket. The original message still follows the e-mail channel option to keep or delete mail on the server.
4. **Detect likely spam** using hard filters (role, account age, ticket count), optional scoring (disposable domains, keywords, spam tags, gateway spam-engine headers, and more), and admin-managed lists.
5. **Queue deletions with a delay**, so admins can review, cancel, or whitelist candidates in the UI.
6. **Execute through Data Privacy** — the actual removal of users or tickets is done by Zammad’s own `DataPrivacyTask` pipeline.
7. **Optional signup CAPTCHA** on the classic registration form and password-reset request, so bots never create the account in the first place.

### Features

#### Whitelist

- Manage trusted e-mail addresses and domains in **Admin → IntakeShield → Filters → Whitelist**.
- Patterns: exact address (`user@example.com`) or parent domain including subdomains (`@example.com`, `example.com`, `*@example.com`).
- Matching users receive the configured whitelist role (default: `Customer`) and are never deleted automatically.
- Hourly sync reapplies roles **only when membership actually changes**. Agents and admins are not given the whitelist role.
- Matching users that already have the role produce no write and no log line.
- Pending deletions for newly whitelisted users are cancelled.
- Optional **Use whitelist for self-registration** (**Admin → IntakeShield → Settings → General**), independent of the master switch: only matching addresses can sign up. Classic `POST /api/v1/users` (`signup: true`) and GraphQL `userSignup` are both blocked with a clear error. Admin/agent creation, mail auto-create, LDAP, and password reset are unchanged. An empty whitelist blocks all self-registration.

#### Blacklist

- Manage untrusted / disposable domains in **Admin → IntakeShield → Filters → Blacklist**.
- Patterns: apex + subdomains (`example.com`, `@example.com`) or subdomains only (`*.example.com`).
- Used as the `disposable_domain` scoring signal.
- Optional inbound drop (**Admin → IntakeShield → Settings → Blacklist**), independent of the master switch:
  - **No** (default) — blacklist only affects scoring and cleanup.
  - **All mail from blacklisted domains** — silently ignore matching inbound mail (including follow-ups). No user or ticket is created.
  - **Only mail that would create a new user or ticket** — follow-ups on recognised existing tickets still arrive.
- Whitelist matches and existing agents/admins are never dropped.
- The original message is kept or deleted according to the e-mail channel option **Keep messages on server** (IMAP/Graph/Google). IntakeShield does not talk to the mailbox itself.
- Mode **All mail** also drops follow-ups. Domains auto-learned from deleted spam users apply here too — whitelist anything that must still get through.
- Domains of deleted spam users are learned automatically. Freemail providers, mail-infrastructure hosts (e.g. `udag.de`), and government domains (`*.gov`, `*.gov.*`) are never learned and never score as disposable — existing poisoned entries are deactivated on upgrade.
- Admins can also **Mark as spam** on a user under **Admin → Manage → Users → Actions** (classic UI). That adds the address (sub)domain to the blacklist. When the master switch is on, a targeted scan immediately queues matching accounts with the same rules as the hourly spam-user scan. Agents, admins, and never-disposable domains are rejected.

#### Keywords

- Manage spam phrases in **Admin → IntakeShield → Filters → Keywords**.
- Case-insensitive match in ticket title and first article body raises the spam score (`spam_keyword` signal).
- A default German-oriented seed list is installed with the package.

#### Suspicious scripts

- Select character sets in **Admin → IntakeShield → Settings → Cleanup → Suspicious scripts** (Han, Hiragana, Katakana, Hangul, Cyrillic, Greek, Arabic, Hebrew, Thai, Devanagari). For Chinese and Japanese spam select Han, Hiragana and Katakana.
- The `suspicious_script` signal fires when the user name, a ticket title or the first article body is written mostly in those scripts: their share of the letters must reach `intake_shield_suspicious_script_ratio` (default 30 %) and at least 3 characters must match. URLs, e-mail addresses and HTML markup are ignored. A German mail that quotes a Chinese name does not count.
- Off until at least one script is selected.

#### Spam users (account cleanup)

- Hourly scan finds deletion candidates.
- Hard filters (all must apply unless spam-tag mode applies):
  - not on the whitelist
  - has the configured candidate role and no admin/agent permissions
  - account older than `intake_shield_min_age_days` (default: 14)
  - account younger than `intake_shield_max_age_days` when set (default: `0` = no upper limit)
  - at most `intake_shield_max_ticket_count` tickets (default: 2)
- Optional scoring (`intake_shield_scoring_enabled`): signals such as never logged in, disposable domain, suspicious e-mail pattern, missing name, spam-tagged customer tickets, keyword matches, and gateway spam-engine headers. Candidates are scheduled only when the score reaches `intake_shield_score_threshold`.
- Scheduled with delay `intake_shield_delay_hours` (default: 72; `0` = no delay). Due entries are executed every 30 minutes via `DataPrivacyTask`.
- Admin UI **Spam → Users**: review queue, scan now, delete now, cancel, or add to whitelist.
- From **Admin → Manage → Users**, **Mark as spam** blacklists the address domain; the scan then queues matching accounts (including the hourly run). Very new accounts still wait until `intake_shield_min_age_days`.

#### Spam tickets (ticket-only cleanup)

- Hourly scan finds tickets carrying the configured spam tag.
- Customer accounts are kept; only the ticket is deleted via Data Privacy.
- If the customer is already a spam-user candidate (pending user deletion, or currently qualifying), the ticket is **not** queued separately — user deletion removes the tickets with the account.
- Admin UI **Spam → Tickets**: review queue, scan now, delete now, or cancel.

<a id="spam-engine-optional"></a>

#### Spam engine (optional)

IntakeShield does **not** ship or embed Apache SpamAssassin, Rspamd, or their rule sets. The classifier stays an operator-managed daemon on the mail gateway (preferred) or on localhost. This package only reads headers and, optionally, speaks the `spamd` / Rspamd HTTP protocol.

1. **Gateway scan (recommended).** Run Rspamd or SpamAssassin in front of Zammad (or let Microsoft 365 stamp `X-MS-Exchange-Organization-SCL`). Inbound mail then already carries `X-Spam-Flag` / `X-Spam-Status` / `X-Spamd-Result` / SCL.
2. **Zammad Postmaster Filter** so tickets enter the existing `spam_tag` cleanup path:

   - Condition: `X-Spam-Flag` contains `YES` (or your Rspamd equivalent).
   - Actions: Tag add `SPAM`, State `closed`.

   That is the Zammad-documented pattern. IntakeShield then sees the tag for scoring and ticket-only deletion.
3. **IntakeShield scoring signal** (**Admin → IntakeShield → Settings → Spam Engine**), independent of the master switch:

   - **Off** (default) — ignore engine headers.
   - **Gateway headers** — stamp matching inbound articles; scoring uses the `spam_engine` weight. Also understands Rspamd `X-Spamd-Result` / `X-Spam` and Microsoft SCL ≥ 5.
   - **Gateway headers, then local daemon** — if those headers are missing, send `mail[:raw]` to local `spamd` (port 783) or the Rspamd scan worker (port 11333). Timeouts and connection errors are ignored (fail-open). Point the host at `127.0.0.1`. Install the daemon yourself.

If a ticket already carries the configured spam tag (for example from the Postmaster Filter), `spam_engine` is **not** added on top of `spam_tag`. Follow-ups are never dropped by this feature. Whitelist matches and agents/admins are skipped. Apache-2.0 daemons stay separate processes (no combined work with this AGPL package). Do not bundle GPLv2-only classifiers into the package.

#### Signup CAPTCHA

- Optional, independent of the master switch (you can block fake registrations without enabling automatic cleanup).
- Protects the **classic** sign-up form (`POST /api/v1/users` with `signup: true`) and the **classic** password-reset request (`POST /api/v1/users/password_reset`).
- Also injects a hidden honeypot field; filled honeypots are rejected.
- Uses **ALTCHA** (self-hosted proof-of-work, no third-party keys). Toggle under Admin → IntakeShield → Settings → General.
- Does **not** apply to admin/agent user creation, mail auto-create, LDAP, or the password-reset **verify** step (after the e-mail link).
- The new Desktop/Mobile UI (GraphQL `userSignup` / `userPasswordResetSend`) is **not** covered in this version — a classic package cannot inject a widget there.

ALTCHA proof-of-work runs in the page (no CDN, no Web Workers).

#### Safety

- Agents and admins are excluded from automatic user deletion, inbound blacklist drop, and spam-engine stamping.
- Whitelist matches hard-block deletion (including cancellation of already scheduled entries), inbound blacklist drop, and spam-engine stamping.
- Conditions are re-checked before execution.
- Open Taskbar tabs and recent-view entries for the user/tickets are dropped before Data Privacy runs, so agents do not hit `RecordNotFound` on stale IDs.
- Manually cancelled user entries are not re-scheduled automatically.
- Deletion always goes through Zammad Data Privacy (audit trail / validators).

### Installation

1. Download a release `.zpm` from the [Releases](https://github.com/Tranquillius/intakeshield/releases) page, or build one locally (see [Development](#development-en)).
2. In Zammad: **Admin → Packages** → upload `intake_shield-<version>.zpm` and install.
3. On the server:

   ```bash
   zammad run rake zammad:package:post_install
   systemctl restart zammad
   ```

   > **Zammad 7.2.2 note:** on 7.2.2 the package precompile runs `pnpm install`
   > for every package, even classic-UI-only ones like this. If that step fails
   > during the install, the asset bundle is left without IntakeShield's code and
   > the admin tabs/actions never appear (the plugin looks "incompatible"). If that
   > happens, rebuild the assets manually and restart:
   >
   > ```bash
   > zammad run rake zammad:package:precompile
   > systemctl restart zammad
   > ```

4. Follow [Recommended setup](#recommended-setup-neu-role-and-spam-tag) (`Neu` role, `SPAM` tag, and the `Mark as Spam and Close` macro), then open **Admin → IntakeShield**, fill Filters / Spam queues / Settings, and enable the master switch in the Settings header.

> **Warning:** Data Privacy deletions are permanent. Use the delay and the Spam → Users / Tickets queues to review candidates before execution.

### Recommended setup: Neu role and SPAM tag

IntakeShield does not create Zammad roles or tags. Without a provisional role, mail-created users land in `Customer` — the same role trusted senders have — so cleanup cannot tell them apart and the whitelist promotion has nothing to remove. The intended split is:

- **Unknown / untrusted** accounts keep the provisional role `Neu` (cleanup candidates).
- **Whitelist matches** are promoted to `Customer` and lose `Neu` (never deleted automatically).
- Tickets marked `SPAM` feed scoring and the ticket-only cleanup scan. Use the macro `Mark as Spam and Close` so agents apply the tag and close the ticket in one step.

`Neu` is a **user role**, not a ticket group.

#### 1. Role `Neu`

1. **Admin → Manage → Roles → New**.
2. Name: `Neu`.
3. Grant the same customer permission as `Customer` (`ticket.customer`). Do **not** grant agent or admin permissions.
4. Enable **Default at signup** on `Neu`.
5. Disable **Default at signup** on `Customer`, so self-registration and mail auto-create get only `Neu`.

Existing `Customer` accounts are unchanged. Only newly created users start in `Neu`.

#### 2. Tag `SPAM` and macro `Mark as Spam and Close`

Do not stop at creating the tag. Agents should have a one-click action that tags **and** closes the ticket, so spam leaves the open queue while IntakeShield still sees the `SPAM` tag for scoring and ticket cleanup.

1. Create the tag `SPAM` (**Admin → Manage → Tags**, or tag any ticket once — Zammad creates the tag). The name must match the IntakeShield setting exactly (`SPAM`, not `Spam`).
2. Create the **Macro** `Mark as Spam and Close` (**Admin → Manage → Macros → New**) with these execute actions:
   - Tags: add `SPAM`
   - State: `closed`
3. Optionally also auto-apply the tag (without closing) via **Postmaster Filter** or **Trigger**. For a mail gateway that already runs SpamAssassin or Rspamd, use Zammad’s documented filter:

   - Condition: `X-Spam-Flag` contains `YES` (Rspamd: `X-Spam` contains `Yes`, or `X-Spamd-Result` matches `True`)
   - Actions: Tag add `SPAM`, State `closed`

   IntakeShield does not ship those engines. See [Spam engine](#spam-engine-optional).

#### 3. IntakeShield settings

| Setting | Value | Why |
| --- | --- | --- |
| Whitelist role | `Customer` | Trusted addresses are promoted here |
| Roles to remove on whitelist | `Neu` | Drops the provisional role so they leave the candidate set |
| Candidate role | `Neu` | User cleanup looks only at unknown accounts |
| Spam tag | `SPAM` | Scoring signal and ticket-only cleanup |

Add your trusted domains under **Admin → IntakeShield → Filters → Whitelist** (e.g. `@example.com`). The hourly whitelist sync then assigns `Customer`, removes `Neu`, and cancels any pending deletion.

For ticket cleanup and the `spam_tag` score to run, set `intake_shield_spam_tag` to `SPAM` and enable scoring. If the `spam_tag` weight is at least the score threshold, customers with a `SPAM` ticket are considered even without role `Neu`.

### Configuration (Admin → IntakeShield → Settings)

The master switch is the toggle in the Settings page header. Settings are grouped into **General**, **Blacklist**, **Cleanup** (including **Suspicious scripts**), and **Spam Engine**.

| Setting | Default | Description |
| --- | --- | --- |
| `intake_shield_active` | `false` | Master switch for rules and cleanup |
| `intake_shield_whitelist_role_id` | `Customer` role | Role assigned on whitelist match |
| `intake_shield_whitelist_remove_role_ids` | `[]` | Roles removed when the whitelist role is assigned (e.g. provisional `Neu`) |
| `intake_shield_whitelist_signup` | `false` | Use the whitelist as an allow list for self-registration (classic and GraphQL `userSignup`). Independent of the master switch. |
| `intake_shield_candidate_role_id` | `Customer` role | Candidate role for user cleanup |
| `intake_shield_min_age_days` | `14` | Minimum account age (days) |
| `intake_shield_max_age_days` | `0` | Maximum account age (days); `0` disables the upper limit |
| `intake_shield_max_ticket_count` | `2` | Maximum ticket count for candidates |
| `intake_shield_delay_hours` | `72` | Delay before Data Privacy deletion; `0` disables the delay (changing this reschedules pending rows) |
| `intake_shield_scoring_enabled` | `false` | Enable score-based scheduling |
| `intake_shield_spam_tag` | *(empty)* | Ticket tag used as scoring / ticket-scan signal |
| `intake_shield_score_threshold` | `100` | Minimum score to schedule deletion |
| `intake_shield_score_weights` | JSON | Weights per signal (`never_logged_in`, `low_ticket_count`, `disposable_domain`, `suspicious_email_pattern`, `missing_name`, `spam_tag`, `spam_keyword`, `suspicious_script`, `spam_engine`, …) |
| `intake_shield_suspicious_scripts` | `[]` | Character sets that count as suspicious for the `suspicious_script` signal; empty disables it |
| `intake_shield_suspicious_script_ratio` | `30` | Minimum share of letters (percent) in the selected scripts |
| `intake_shield_spam_engine` | `off` | Gateway spam headers / optional local daemon as scoring signal (`off`, `headers`, `live`). Independent of the master switch. Engines are not bundled. |
| `intake_shield_spam_engine_backend` | `spamassassin` | Live-mode daemon: `spamassassin` (spamd) or `rspamd` |
| `intake_shield_spam_engine_host` | `127.0.0.1` | Live-mode host (keep local) |
| `intake_shield_spam_engine_port` | `783` | Live-mode port (`783` spamd, `11333` Rspamd scan worker) |
| `intake_shield_spam_engine_timeout` | `2` | Live-mode timeout in seconds; failures are ignored |
| `intake_shield_spam_engine_password` | *(empty)* | Optional Rspamd password for live mode |
| `intake_shield_drop_blacklisted_mail` | `off` | Inbound drop: `off`, `all`, or `new_only` (independent of the master switch). Original mail follows the channel keep-on-server option. |
| `intake_shield_signup_captcha` | `false` | Require a CAPTCHA on classic sign-up and password-reset requests (independent of the master switch). Always self-hosted ALTCHA. |

User candidates appear after `IntakeShield.cleanup_scan` (hourly scheduler or **Scan now**). Ticket candidates appear after `IntakeShield.cleanup_ticket_scan` (hourly or **Scan now**).

### Logging

```text
log/intakeshield.log
```

(typically `/opt/zammad/log/intakeshield.log` on package installs).

### Upgrade notes

- Fresh installs use the consolidated base migration.
- Upgrades from **0.2.21+** are supported.
- Older intermediate versions: prefer a fresh install of the latest package.

<a id="development-en"></a>

### Development

```bash
# Link sources into a local Zammad installation
bin/link /path/to/zammad
export DEVELOPMENT_FILE_WATCHER="file_update_checker"

# Build a distributable package (updates .szpm file list + writes releases/)
bin/build 0.7.0
```

`bin/build` reads `intake_shield.szpm`, collects files under `app/`, `config/`, `db/`, `lib/`, and `public/`, and writes `releases/intake_shield-<version>.zpm` locally (that directory is gitignored; packages are published as GitHub Releases). See [CONTRIBUTING.md](CONTRIBUTING.md) for how this public GitHub tree is updated from the private development history.

### Support this project

If IntakeShield saves you time, you can buy me a coffee:

**[paypal.me/tranquillius](https://paypal.me/tranquillius)**

---

<a id="deutsch"></a>

## Deutsch

Community-Paket, nicht verbunden mit der [Zammad GmbH](https://zammad.com/) oder der [Zammad Foundation](https://zammad-foundation.org/).

### Was macht das Paket?

IntakeShield hilft On-Premise-Zammad-Instanzen gegen Spam-Registrierungen und Spam-Tickets — ohne blind zu löschen.

1. **Vertrauenswürdige Absender schützen** über eine Whitelist (exakte Adressen oder Domains inkl. Subdomains) und optional eine Whitelist-Rolle.
2. **Selbstregistrierung optional auf dieselbe Whitelist beschränken** (klassisches Formular und Desktop/Mobile GraphQL `userSignup`).
3. **Eingehende Mails von Blacklist-Domains verwerfen** (optional), sodass Zammad weder User noch Ticket anlegt. Die Originalmail folgt weiterhin der Kanal-Option, Nachrichten auf dem Server zu belassen oder zu löschen.
4. **Wahrscheinlichen Spam erkennen** über harte Filter (Rolle, Kontenalter, Ticketanzahl), optionales Scoring (Wegwerf-Domains, Keywords, Spam-Tags, Gateway-Spam-Engine-Header u. a.) und Admin-Listen.
5. **Löschungen mit Verzögerung vormerken**, damit Admins prüfen, abbrechen oder whitelisten können.
6. **Ausführung über Data Privacy** — die eigentliche Löschung von Benutzern oder Tickets übernimmt Zammads `DataPrivacyTask`.
7. **Optionales Registrierungs-Captcha** auf dem klassischen Anmeldeformular und beim Anfordern eines Passwort-Resets, damit Bots das Konto gar nicht erst anlegen.

### Features

#### Whitelist

- Pflege unter **Admin → IntakeShield → Filter → Whitelist**.
- Muster: exakte Adresse (`user@example.com`) oder Parent-Domain inkl. Subdomains (`@example.com`, `example.com`, `*@example.com`).
- Treffer erhalten die konfigurierte Whitelist-Rolle (Standard: `Customer`) und werden nie automatisch gelöscht.
- Stündlicher Sync weist Rollen **nur bei tatsächlicher Änderung** zu. Agents und Admins bekommen die Whitelist-Rolle nicht.
- Benutzer, die die Rolle bereits haben, erzeugen weder Write noch Logzeile.
- Ausstehende Löschungen für neu gewhitelistete Benutzer werden storniert.
- Optional **Whitelist für Selbstregistrierung nutzen** (**Admin → IntakeShield → Einstellungen → Allgemein**), unabhängig vom Hauptschalter: nur passende Adressen können sich registrieren. Klassisches `POST /api/v1/users` (`signup: true`) und GraphQL `userSignup` werden mit einer klaren Fehlermeldung blockiert. Anlegen durch Admins/Agents, Mail-Auto-Create, LDAP und Passwort-Reset bleiben unverändert. Eine leere Whitelist sperrt alle Selbstregistrierungen.

#### Blacklist

- Pflege unzuverlässiger/Wegwerf-Domains unter **Admin → IntakeShield → Filter → Blacklist**.
- Muster: Apex + Subdomains (`example.com`, `@example.com`) oder nur Subdomains (`*.example.com`).
- Wird als Scoring-Signal `disposable_domain` genutzt.
- Optionales Verwerfen eingehender Mails (**Admin → IntakeShield → Einstellungen → Blacklist**), unabhängig vom Hauptschalter:
  - **Nein** (Standard) — Blacklist wirkt nur auf Scoring und Cleanup.
  - **Alle Mails von Blacklist-Domains** — passende eingehende Mails still ignorieren (inkl. Follow-ups). Es entsteht weder User noch Ticket.
  - **Nur Mails, die einen neuen Benutzer oder ein neues Ticket anlegen würden** — Follow-ups auf erkannte Bestands-Tickets kommen weiterhin an.
- Whitelist-Treffer sowie bestehende Agents/Admins werden nie verworfen.
- Die Originalmail wird je nach Kanal-Option **Nachrichten auf dem Server belassen** behalten oder gelöscht (IMAP/Graph/Google). IntakeShield spricht den Postfach-Server nicht selbst an.
- Modus **Alle Mails** verwirft auch Follow-ups. Automatisch gelernte Domains gelöschter Spam-Benutzer gelten hier ebenfalls — alles, was durchkommen muss, auf die Whitelist setzen.
- Domains gelöschter Spam-Benutzer werden automatisch ergänzt. Freemail-Anbieter, Mail-Infrastruktur (z. B. `udag.de`) und Behörden-Domains (`*.gov`, `*.gov.*`) werden weder gelernt noch als Wegwerf-Domain gewertet — vorhandene Fehl-Einträge werden beim Upgrade deaktiviert.
- Admins können einen Benutzer unter **Admin → Manage → Users → Aktionen** (klassische UI) **Als Spam markieren**. Damit kommt die Adress-(Sub-)Domain auf die Blacklist. Ist der Hauptschalter an, merkt ein gezielter Scan passende Konten sofort nach denselben Regeln vor wie der stündliche Spam-Benutzer-Scan. Agents, Admins und Never-Disposable-Domains werden abgelehnt.

#### Keywords

- Pflege unter **Admin → IntakeShield → Filter → Schlüsselwörter**.
- Groß-/Kleinschreibung wird ignoriert; Treffer in Ticket-Titel und erstem Artikel-Body erhöhen den Spam-Score (`spam_keyword`).
- Mit dem Paket wird eine Standard-Keyword-Liste mitgeliefert.

#### Verdächtige Schriften

- Zeichensätze unter **Admin → IntakeShield → Einstellungen → Bereinigung → Verdächtige Schriften** auswählen (Han, Hiragana, Katakana, Hangul, Kyrillisch, Griechisch, Arabisch, Hebräisch, Thailändisch, Devanagari). Für chinesischen und japanischen Spam Han, Hiragana und Katakana auswählen.
- Das Signal `suspicious_script` greift, wenn Benutzername, Ticket-Titel oder erster Artikel-Body überwiegend in diesen Schriften geschrieben sind: Ihr Anteil an den Buchstaben muss `intake_shield_suspicious_script_ratio` erreichen (Standard 30 %), und mindestens 3 Zeichen müssen passen. URLs, E-Mail-Adressen und HTML-Markup werden ignoriert. Eine deutsche Mail, die einen chinesischen Namen zitiert, zählt nicht.
- Inaktiv, solange keine Schrift ausgewählt ist.

#### Spam-Benutzer (Kontenbereinigung)

- Stündlicher Scan findet Löschkandidaten.
- Harte Bedingungen (alle müssen zutreffen, außer im Spam-Tag-Modus):
  - nicht auf der Whitelist
  - konfigurierte Kandidaten-Rolle, keine Admin-/Agent-Rechte
  - Konto älter als `intake_shield_min_age_days` (Standard: 14)
  - Konto jünger als `intake_shield_max_age_days`, sofern gesetzt (Standard: `0` = keine Obergrenze)
  - höchstens `intake_shield_max_ticket_count` Tickets (Standard: 2)
- Optionales Scoring (`intake_shield_scoring_enabled`): u. a. nie angemeldet, Wegwerf-Domain, verdächtiges E-Mail-Muster, fehlender Name, Spam-Tag auf Kunden-Tickets, Keyword-Treffer, Gateway-Spam-Engine-Header. Vormerkung erst ab `intake_shield_score_threshold`.
- Verzögerung `intake_shield_delay_hours` (Standard: 72; `0` = keine Verzögerung). Fällige Einträge alle 30 Minuten per `DataPrivacyTask`.
- Admin-UI **Spam → Benutzer**: Warteschlange, jetzt scannen, sofort löschen, abbrechen oder zur Whitelist hinzufügen.
- Über **Admin → Manage → Users** setzt **Als Spam markieren** die Adressdomain auf die Blacklist; der Scan merkt passende Konten vor (auch der stündliche Lauf). Sehr neue Konten warten weiter auf `intake_shield_min_age_days`.

#### Spam-Tickets (nur Ticket-Löschung)

- Stündlicher Scan findet Tickets mit dem konfigurierten Spam-Tag.
- Kundenkonten bleiben erhalten; gelöscht wird nur das Ticket per Data Privacy.
- Ist der Kunde bereits Spam-Benutzer-Kandidat (ausstehende Benutzerlöschung oder aktuell qualifiziert), wird das Ticket **nicht** separat vorgemerkt — die Benutzerlöschung entfernt die Tickets mit dem Konto.
- Admin-UI **Spam → Tickets**: Warteschlange, jetzt scannen, sofort löschen oder abbrechen.

<a id="spam-engine-optional-de"></a>

#### Spam-Engine (optional)

IntakeShield liefert Apache SpamAssassin, Rspamd und deren Regelwerke **nicht** mit und bettet sie nicht ein. Der Klassifizierer bleibt ein vom Betreiber verwalteter Daemon am Mail-Gateway (bevorzugt) oder auf localhost. Dieses Paket liest nur Header und spricht optional das `spamd`- bzw. Rspamd-HTTP-Protokoll.

1. **Gateway-Scan (empfohlen).** Rspamd oder SpamAssassin vor Zammad betreiben (oder Microsoft 365 `X-MS-Exchange-Organization-SCL` stempeln lassen). Eingehende Mails tragen dann bereits `X-Spam-Flag` / `X-Spam-Status` / `X-Spamd-Result` / SCL.
2. **Zammad-Postmaster-Filter**, damit Tickets den bestehenden `spam_tag`-Cleanup-Pfad nutzen:

   - Bedingung: `X-Spam-Flag` enthält `YES` (oder das Rspamd-Äquivalent).
   - Aktionen: Tag `SPAM` hinzufügen, Status `closed`.

   Das ist das von Zammad dokumentierte Muster. IntakeShield sieht das Tag dann für Scoring und Ticket-Löschung.
3. **IntakeShield-Scoring-Signal** (**Admin → IntakeShield → Einstellungen → Spam-Engine**), unabhängig vom Hauptschalter:

   - **Aus** (Standard) — Engine-Header ignorieren.
   - **Gateway-Header** — passende eingehende Artikel stempeln; Scoring nutzt das Gewicht `spam_engine`. Versteht auch Rspamd `X-Spamd-Result` / `X-Spam` und Microsoft SCL ≥ 5.
   - **Gateway-Header, danach lokaler Daemon** — fehlen diese Header, wird `mail[:raw]` an lokales `spamd` (Port 783) oder den Rspamd-Scan-Worker (Port 11333) geschickt. Timeouts und Verbindungsfehler werden ignoriert (fail-open). Host auf `127.0.0.1` setzen. Den Daemon selbst installieren.

Trägt ein Ticket bereits das konfigurierte Spam-Tag (z. B. durch den Postmaster-Filter), wird `spam_engine` **nicht** zusätzlich zu `spam_tag` gezählt. Follow-ups werden durch dieses Feature nie verworfen. Whitelist-Treffer sowie Agents/Admins werden übersprungen. Apache-2.0-Daemons bleiben getrennte Prozesse (kein kombiniertes Werk mit diesem AGPL-Paket). GPLv2-only-Klassifizierer nicht ins Paket bundlen.

#### Registrierungs-Captcha

- Optional und unabhängig vom Hauptschalter (Fake-Registrierungen blockieren, ohne automatische Löschung zu aktivieren).
- Schützt das **klassische** Registrierungsformular (`POST /api/v1/users` mit `signup: true`) und die **klassische** Passwort-Reset-Anfrage (`POST /api/v1/users/password_reset`).
- Zusätzlich ein verstecktes Honeypot-Feld; ausgefüllte Honeypots werden abgelehnt.
- Verwendet **ALTCHA** (selbst gehostetes Proof-of-Work, keine Drittanbieter-Keys). Schalter unter Admin → IntakeShield → Einstellungen → Allgemein.
- Gilt **nicht** für das Anlegen durch Admins/Agents, Mail-Auto-Create, LDAP oder den Passwort-Reset-**Verify**-Schritt (nach dem E-Mail-Link).
- Die neue Desktop-/Mobile-UI (GraphQL `userSignup` / `userPasswordResetSend`) ist in dieser Version **nicht** abgedeckt — ein Classic-Paket kann dort kein Widget einbauen.

ALTCHA-Proof-of-Work läuft in der Seite (kein CDN, keine Web Worker).

#### Sicherheit

- Agents und Admins sind von der automatischen Benutzerlöschung, vom Verwerfen eingehender Blacklist-Mails und vom Spam-Engine-Stempeln ausgeschlossen.
- Whitelist blockiert Löschung hart (inkl. Storno bereits vorgemerkter Einträge), das Verwerfen eingehender Blacklist-Mails und das Spam-Engine-Stempeln.
- Vor der Ausführung werden die Bedingungen erneut geprüft.
- Offene Taskbar-Tabs und Recent-View-Einträge zu User/Tickets werden vor der Data-Privacy-Löschung entfernt, damit Agents nicht auf `RecordNotFound` für tote IDs stoßen.
- Manuell abgebrochene Benutzer-Einträge werden nicht erneut automatisch vorgemerkt.
- Löschung ausschließlich über Zammads Data-Privacy-Mechanismus.

### Installation

1. Release-`.zpm` von der [Releases](https://github.com/Tranquillius/intakeshield/releases)-Seite laden, oder lokal bauen (siehe [Entwicklung](#entwicklung-de)).
2. In Zammad: **Admin → Pakete** → `intake_shield-<version>.zpm` hochladen und installieren.
3. Auf dem Server:

   ```bash
   zammad run rake zammad:package:post_install
   systemctl restart zammad
   ```

   > **Hinweis zu Zammad 7.2.2:** Unter 7.2.2 führt der Paket-Precompile bei jedem
   > Paket `pnpm install` aus, auch bei reinen Classic-UI-Paketen wie diesem.
   > Schlägt dieser Schritt während der Installation fehl, bleibt das Asset-Bundle
   > ohne den IntakeShield-Code, und die Admin-Tabs/-Aktionen erscheinen nicht
   > (das Plugin wirkt „inkompatibel“). In diesem Fall die Assets manuell neu bauen
   > und neu starten:
   >
   > ```bash
   > zammad run rake zammad:package:precompile
   > systemctl restart zammad
   > ```

4. Zuerst [Empfohlene Einrichtung](#empfohlene-einrichtung-rolle-neu-und-tag-spam) (Rolle `Neu`, Tag `SPAM` und Makro `Mark as Spam and Close`), danach **Admin → IntakeShield** öffnen, Filter / Spam-Warteschlangen / Einstellungen pflegen und den Hauptschalter in der Einstellungs-Überschrift aktivieren.

> **Achtung:** Löschungen über Data Privacy sind endgültig. Nutze den Delay und die Übersichten Spam → Benutzer / Tickets zur Prüfung vor der Ausführung.

### Empfohlene Einrichtung: Rolle Neu und Tag SPAM

IntakeShield legt keine Zammad-Rollen oder -Tags an. Ohne vorläufige Rolle landen per Mail erzeugte Benutzer direkt in `Customer` — derselben Rolle wie vertrauenswürdige Absender. Cleanup kann sie dann nicht unterscheiden, und die Whitelist hat nichts zum Entfernen. Die vorgesehene Trennung:

- **Unbekannte / nicht vertrauenswürdige** Konten behalten die vorläufige Rolle `Neu` (Löschkandidaten).
- **Whitelist-Treffer** werden zu `Customer` befördert und verlieren `Neu` (keine automatische Löschung).
- Tickets mit Tag `SPAM` speisen das Scoring und den Ticket-Cleanup. Über das Makro `Mark as Spam and Close` setzen Agents das Tag und schließen das Ticket in einem Schritt.

`Neu` ist eine **Benutzerrolle**, keine Ticket-Gruppe.

#### 1. Rolle `Neu`

1. **Admin → Verwaltung → Rollen → Neu**.
2. Name: `Neu`.
3. Dieselbe Kundenberechtigung wie `Customer` (`ticket.customer`). **Keine** Agent- oder Admin-Rechte.
4. **Standard bei Registrierung** für `Neu` aktivieren.
5. **Standard bei Registrierung** für `Customer` deaktivieren, damit Selbstregistrierung und Mail-Auto-Create nur `Neu` bekommen.

Bestehende `Customer`-Konten bleiben unverändert. Nur neu angelegte Benutzer starten in `Neu`.

#### 2. Tag `SPAM` und Makro `Mark as Spam and Close`

Nicht nur das Tag anlegen. Agents brauchen eine Ein-Klick-Aktion, die das Ticket **taggt und schließt**, damit Spam die offene Queue verlässt — IntakeShield sieht das Tag `SPAM` trotzdem für Scoring und Ticket-Cleanup.

1. Tag `SPAM` anlegen (**Admin → Verwaltung → Tags**, oder einmal an einem Ticket setzen — Zammad erzeugt das Tag). Der Name muss exakt zur IntakeShield-Einstellung passen (`SPAM`, nicht `Spam`).
2. Zusätzlich das **Makro** `Mark as Spam and Close` anlegen (**Admin → Verwaltung → Makros → Neu**) mit diesen Aktionen:
   - Tags: `SPAM` hinzufügen
   - Status: `closed` (geschlossen)
3. Optional das Tag (ohne Schließen) automatisch setzen: **Postmaster-Filter** oder **Trigger**. Läuft am Mail-Gateway bereits SpamAssassin oder Rspamd, den von Zammad dokumentierten Filter nutzen:

   - Bedingung: `X-Spam-Flag` enthält `YES` (Rspamd: `X-Spam` enthält `Yes`, oder `X-Spamd-Result` passt auf `True`)
   - Aktionen: Tag `SPAM` hinzufügen, Status `closed` (geschlossen)

   IntakeShield liefert diese Engines nicht mit. Siehe [Spam-Engine](#spam-engine-optional-de).

#### 3. IntakeShield-Einstellungen

| Setting | Wert | Zweck |
| --- | --- | --- |
| Whitelist-Rolle | `Customer` | Vertrauenswürdige Adressen werden hierhin befördert |
| Rollen bei Whitelist entfernen | `Neu` | Vorläufige Rolle fällt weg, der Account verlässt die Kandidatenmenge |
| Kandidaten-Rolle | `Neu` | Benutzer-Cleanup betrachtet nur unbekannte Konten |
| Spam-Tag | `SPAM` | Scoring-Signal und Ticket-Cleanup |

Vertrauenswürdige Domains unter **Admin → IntakeShield → Filter → Whitelist** eintragen (z. B. `@example.com`). Der stündliche Whitelist-Sync weist dann `Customer` zu, entfernt `Neu` und storniert eine evtl. vorgemerkte Löschung.

Damit Ticket-Cleanup und das Signal `spam_tag` laufen, `intake_shield_spam_tag` auf `SPAM` setzen und Scoring aktivieren. Liegt das Gewicht `spam_tag` mindestens auf dem Score-Schwellwert, gelten Kunden mit einem `SPAM`-Ticket auch ohne Rolle `Neu` als Kandidaten.

### Konfiguration (Admin → IntakeShield → Einstellungen)

Der Hauptschalter sitzt in der Überschrift der Einstellungsseite. Die Optionen sind auf **Allgemein**, **Blacklist**, **Bereinigung** (inklusive **Verdächtige Schriften**) und **Spam-Engine** aufgeteilt.

| Setting | Standard | Beschreibung |
| --- | --- | --- |
| `intake_shield_active` | `false` | Master-Switch für Regeln und Cleanup |
| `intake_shield_whitelist_role_id` | Rolle `Customer` | Rolle bei Whitelist-Treffer |
| `intake_shield_whitelist_remove_role_ids` | `[]` | Rollen, die bei Whitelist-Zuweisung entfernt werden (z. B. vorläufige Rolle `Neu`) |
| `intake_shield_whitelist_signup` | `false` | Whitelist als Allow-Liste für die Selbstregistrierung (klassisch und GraphQL `userSignup`). Unabhängig vom Hauptschalter. |
| `intake_shield_candidate_role_id` | Rolle `Customer` | Kandidaten-Rolle für Benutzer-Cleanup |
| `intake_shield_min_age_days` | `14` | Mindestalter des Kontos (Tage) |
| `intake_shield_max_age_days` | `0` | Maximalalter des Kontos (Tage); `0` deaktiviert die Obergrenze |
| `intake_shield_max_ticket_count` | `2` | Maximale Ticketanzahl |
| `intake_shield_delay_hours` | `72` | Verzögerung bis zur Data-Privacy-Löschung; `0` deaktiviert die Verzögerung (Änderung terminiert ausstehende Einträge neu) |
| `intake_shield_scoring_enabled` | `false` | Score-basiertes Vormerken aktivieren |
| `intake_shield_spam_tag` | *(leer)* | Ticket-Tag als Scoring- / Ticket-Scan-Signal |
| `intake_shield_score_threshold` | `100` | Mindest-Score für Vormerkung |
| `intake_shield_score_weights` | JSON | Gewichte der Signale (`never_logged_in`, `low_ticket_count`, `disposable_domain`, `suspicious_email_pattern`, `missing_name`, `spam_tag`, `spam_keyword`, `suspicious_script`, `spam_engine`, …) |
| `intake_shield_suspicious_scripts` | `[]` | Zeichensätze, die für das Signal `suspicious_script` als verdächtig gelten; leer = deaktiviert |
| `intake_shield_suspicious_script_ratio` | `30` | Mindestanteil der Buchstaben (Prozent) in den ausgewählten Schriften |
| `intake_shield_spam_engine` | `off` | Gateway-Spam-Header / optionaler lokaler Daemon als Scoring-Signal (`off`, `headers`, `live`). Unabhängig vom Hauptschalter. Engines sind nicht Bestandteil des Pakets. |
| `intake_shield_spam_engine_backend` | `spamassassin` | Daemon im Live-Modus: `spamassassin` (spamd) oder `rspamd` |
| `intake_shield_spam_engine_host` | `127.0.0.1` | Host im Live-Modus (lokal halten) |
| `intake_shield_spam_engine_port` | `783` | Port im Live-Modus (`783` spamd, `11333` Rspamd-Scan-Worker) |
| `intake_shield_spam_engine_timeout` | `2` | Timeout im Live-Modus in Sekunden; Fehler werden ignoriert |
| `intake_shield_spam_engine_password` | *(leer)* | Optionales Rspamd-Passwort für den Live-Modus |
| `intake_shield_drop_blacklisted_mail` | `off` | Eingehende Mails verwerfen: `off`, `all` oder `new_only` (unabhängig vom Hauptschalter). Die Originalmail folgt der Kanal-Option „Nachrichten auf dem Server belassen“. |
| `intake_shield_signup_captcha` | `false` | Captcha auf klassischer Registrierung und Passwort-Reset-Anfrage (unabhängig vom Hauptschalter). Immer selbst gehostetes ALTCHA. |

Benutzer-Kandidaten erscheinen nach `IntakeShield.cleanup_scan` (stündlicher Scheduler oder **Jetzt scannen**). Ticket-Kandidaten nach `IntakeShield.cleanup_ticket_scan` (stündlich oder **Jetzt scannen**).

### Logging

```text
log/intakeshield.log
```

(typisch `/opt/zammad/log/intakeshield.log` bei Paketinstallationen).

### Upgrade-Hinweise

- Neuinstallationen nutzen die konsolidierte Basis-Migration.
- Upgrades ab **0.2.21+** werden unterstützt.
- Ältere Zwischenstände: bevorzugt Neuinstallation des aktuellen Pakets.

<a id="entwicklung-de"></a>

### Entwicklung

```bash
# Quellen in eine lokale Zammad-Installation linken
bin/link /path/to/zammad
export DEVELOPMENT_FILE_WATCHER="file_update_checker"

# Installierbares Paket bauen (aktualisiert .szpm-Dateiliste + schreibt releases/)
bin/build 0.7.0
```

`bin/build` liest `intake_shield.szpm`, sammelt Dateien unter `app/`, `config/`, `db/`, `lib/` und `public/` und erzeugt lokal `releases/intake_shield-<version>.zpm` (das Verzeichnis ist gitignored; Pakete erscheinen als GitHub Releases). Wie der öffentliche GitHub-Stand aus der privaten Entwicklungshistorie aktualisiert wird, steht in [CONTRIBUTING.md](CONTRIBUTING.md).

### Projekt unterstützen

Wenn dir IntakeShield Zeit spart, kannst du mir einen Kaffee spendieren:

**[paypal.me/tranquillius](https://paypal.me/tranquillius)**

---

## License

This project is licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0).  
See [LICENSE](LICENSE) for the full text.

Optional live checks talk to Apache SpamAssassin or Rspamd over the local network. Those projects are Apache License 2.0 and are **not** bundled here; a socket/HTTP client is not a combined work. Do not vendor GPLv2-only classifiers (e.g. Bogofilter) into this package.

Copyright © 2026 Tranquillius / IntakeShield.
