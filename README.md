# IntakeShield

[English](#english) · [Deutsch](#deutsch)

Zammad package against spam user accounts and spam-tagged tickets: e-mail whitelist/blacklist, keyword scoring, and automated cleanup via Zammad’s `DataPrivacyTask` mechanism.

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
2. **Detect likely spam** using hard filters (role, account age, ticket count), optional scoring (disposable domains, keywords, spam tags, and more), and admin-managed lists.
3. **Queue deletions with a delay**, so admins can review, cancel, or whitelist candidates in the UI.
4. **Execute through Data Privacy** — the actual removal of users or tickets is done by Zammad’s own `DataPrivacyTask` pipeline.
5. **Optional signup CAPTCHA** on the classic registration form and password-reset request, so bots never create the account in the first place.

### Features

#### Whitelist

- Manage trusted e-mail addresses and domains in **Admin → IntakeShield → Whitelist**.
- Patterns: exact address (`user@example.com`) or parent domain including subdomains (`@example.com`, `example.com`, `*@example.com`).
- Matching users receive the configured whitelist role (default: `Customer`) and are never deleted automatically.
- Hourly sync reapplies roles **only when membership actually changes**. Agents and admins are not given the whitelist role.
- Matching users that already have the role produce no write and no log line.
- Pending deletions for newly whitelisted users are cancelled.

#### Blacklist

- Manage untrusted / disposable domains in **Admin → IntakeShield → Blacklist**.
- Patterns: apex + subdomains (`example.com`, `@example.com`) or subdomains only (`*.example.com`).
- Used as the `disposable_domain` scoring signal.
- Domains of deleted spam users are learned automatically. Freemail providers, mail-infrastructure hosts (e.g. `udag.de`), and government domains (`*.gov`, `*.gov.*`) are never learned and never score as disposable — existing poisoned entries are deactivated on upgrade.

#### Keywords

- Manage spam phrases in **Admin → IntakeShield → Keywords**.
- Case-insensitive match in ticket title and first article body raises the spam score (`spam_keyword` signal).
- A default German-oriented seed list is installed with the package.

#### Spam users (account cleanup)

- Hourly scan finds deletion candidates.
- Hard filters (all must apply unless spam-tag mode applies):
  - not on the whitelist
  - has the configured candidate role and no admin/agent permissions
  - account older than `intake_shield_min_age_days` (default: 14)
  - account younger than `intake_shield_max_age_days` when set (default: `0` = no upper limit)
  - at most `intake_shield_max_ticket_count` tickets (default: 2)
- Optional scoring (`intake_shield_scoring_enabled`): signals such as never logged in, disposable domain, suspicious e-mail pattern, missing name, spam-tagged customer tickets, and keyword matches. Candidates are scheduled only when the score reaches `intake_shield_score_threshold`.
- Scheduled with delay `intake_shield_delay_hours` (default: 72; `0` = no delay). Due entries are executed every 30 minutes via `DataPrivacyTask`.
- Admin UI **Spam Users**: review queue, scan now, delete now, cancel, or add to whitelist.

#### Spam tickets (ticket-only cleanup)

- Hourly scan finds tickets carrying the configured spam tag.
- Customer accounts are kept; only the ticket is deleted via Data Privacy.
- If the customer is already a spam-user candidate (pending user deletion, or currently qualifying), the ticket is **not** queued separately — user deletion removes the tickets with the account.
- Admin UI **Spam Tickets**: review queue, scan now, delete now, or cancel.

#### Signup CAPTCHA

- Optional, independent of the master switch (you can block fake registrations without enabling automatic cleanup).
- Protects the **classic** sign-up form (`POST /api/v1/users` with `signup: true`) and the **classic** password-reset request (`POST /api/v1/users/password_reset`).
- Also injects a hidden honeypot field; filled honeypots are rejected.
- Captcha source (Admin → IntakeShield → Settings):
  - **ALTCHA (self-hosted)** — proof-of-work, no third-party keys, GDPR-friendly. Default.
  - **Form channel** — reuses the CAPTCHA already configured under **Channels → Form** (Turnstile, hCaptcha, Friendly Captcha, reCAPTCHA, …). Requires a current Zammad 7.x with `FormSpamProtection`. If that API or provider is missing, requests fail closed.
- Does **not** apply to admin/agent user creation, mail auto-create, LDAP, or the password-reset **verify** step (after the e-mail link).
- The new Desktop/Mobile UI (GraphQL `userSignup` / `userPasswordResetSend`) is **not** covered in this version — a classic package cannot inject a widget there.

ALTCHA proof-of-work runs in the page (no CDN, no Web Workers). If you use **Form channel**, your reverse proxy CSP must still allow the chosen provider (e.g. `https://challenges.cloudflare.com` for Turnstile).

#### Safety

- Agents and admins are excluded from automatic user deletion.
- Whitelist matches hard-block deletion (including cancellation of already scheduled entries).
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

4. Follow [Recommended setup](#recommended-setup-neu-role-and-spam-tag) (`Neu` role + `SPAM` tag), then open **Admin → IntakeShield**, fill Whitelist / Blacklist / Keywords / Settings, and enable the master switch **IntakeShield**.

> **Warning:** Data Privacy deletions are permanent. Use the delay and the Spam Users / Spam Tickets queues to review candidates before execution.

### Recommended setup: Neu role and SPAM tag

IntakeShield does not create Zammad roles or tags. Without a provisional role, mail-created users land in `Customer` — the same role trusted senders have — so cleanup cannot tell them apart and the whitelist promotion has nothing to remove. The intended split is:

- **Unknown / untrusted** accounts keep the provisional role `Neu` (cleanup candidates).
- **Whitelist matches** are promoted to `Customer` and lose `Neu` (never deleted automatically).
- Tickets marked `SPAM` feed scoring and the ticket-only cleanup scan.

`Neu` is a **user role**, not a ticket group.

#### 1. Role `Neu`

1. **Admin → Manage → Roles → New**.
2. Name: `Neu`.
3. Grant the same customer permission as `Customer` (`ticket.customer`). Do **not** grant agent or admin permissions.
4. Enable **Default at signup** on `Neu`.
5. Disable **Default at signup** on `Customer`, so self-registration and mail auto-create get only `Neu`.

Existing `Customer` accounts are unchanged. Only newly created users start in `Neu`.

#### 2. Tag `SPAM`

1. Create the tag `SPAM` (**Admin → Manage → Tags**, or tag any ticket once — Zammad creates the tag).
2. Optionally auto-apply it: **Postmaster Filter** or **Trigger** (e.g. spam reports from the mail gateway).
3. The name must match the IntakeShield setting exactly (`SPAM`, not `Spam`).

#### 3. IntakeShield settings

| Setting | Value | Why |
| --- | --- | --- |
| Whitelist role | `Customer` | Trusted addresses are promoted here |
| Roles to remove on whitelist | `Neu` | Drops the provisional role so they leave the candidate set |
| Candidate role | `Neu` | User cleanup looks only at unknown accounts |
| Spam tag | `SPAM` | Scoring signal and ticket-only cleanup |

Add your trusted domains under **Admin → IntakeShield → Whitelist** (e.g. `@example.com`). The hourly whitelist sync then assigns `Customer`, removes `Neu`, and cancels any pending deletion.

For ticket cleanup and the `spam_tag` score to run, set `intake_shield_spam_tag` to `SPAM` and enable scoring. If the `spam_tag` weight is at least the score threshold, customers with a `SPAM` ticket are considered even without role `Neu`.

### Configuration (Admin → IntakeShield → Settings)

| Setting | Default | Description |
| --- | --- | --- |
| `intake_shield_active` | `false` | Master switch for rules and cleanup |
| `intake_shield_whitelist_role_id` | `Customer` role | Role assigned on whitelist match |
| `intake_shield_whitelist_remove_role_ids` | `[]` | Roles removed when the whitelist role is assigned (e.g. provisional `Neu`) |
| `intake_shield_candidate_role_id` | `Customer` role | Candidate role for user cleanup |
| `intake_shield_min_age_days` | `14` | Minimum account age (days) |
| `intake_shield_max_age_days` | `0` | Maximum account age (days); `0` disables the upper limit |
| `intake_shield_max_ticket_count` | `2` | Maximum ticket count for candidates |
| `intake_shield_delay_hours` | `72` | Delay before Data Privacy deletion; `0` disables the delay (changing this reschedules pending rows) |
| `intake_shield_scoring_enabled` | `false` | Enable score-based scheduling |
| `intake_shield_spam_tag` | *(empty)* | Ticket tag used as scoring / ticket-scan signal |
| `intake_shield_score_threshold` | `100` | Minimum score to schedule deletion |
| `intake_shield_score_weights` | JSON | Weights per signal (`never_logged_in`, `low_ticket_count`, `disposable_domain`, `suspicious_email_pattern`, `missing_name`, `spam_tag`, `spam_keyword`, …) |
| `intake_shield_signup_captcha` | `false` | Require a CAPTCHA on classic sign-up and password-reset requests (independent of the master switch) |
| `intake_shield_captcha_source` | `altcha` | `altcha` (self-hosted) or `form_channel` (reuse **Channels → Form**) |

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
bin/build 0.4.3
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
2. **Wahrscheinlichen Spam erkennen** über harte Filter (Rolle, Kontenalter, Ticketanzahl), optionales Scoring (Wegwerf-Domains, Keywords, Spam-Tags u. a.) und Admin-Listen.
3. **Löschungen mit Verzögerung vormerken**, damit Admins prüfen, abbrechen oder whitelisten können.
4. **Ausführung über Data Privacy** — die eigentliche Löschung von Benutzern oder Tickets übernimmt Zammads `DataPrivacyTask`.
5. **Optionales Registrierungs-Captcha** auf dem klassischen Anmeldeformular und beim Anfordern eines Passwort-Resets, damit Bots das Konto gar nicht erst anlegen.

### Features

#### Whitelist

- Pflege unter **Admin → IntakeShield → Whitelist**.
- Muster: exakte Adresse (`user@example.com`) oder Parent-Domain inkl. Subdomains (`@example.com`, `example.com`, `*@example.com`).
- Treffer erhalten die konfigurierte Whitelist-Rolle (Standard: `Customer`) und werden nie automatisch gelöscht.
- Stündlicher Sync weist Rollen **nur bei tatsächlicher Änderung** zu. Agents und Admins bekommen die Whitelist-Rolle nicht.
- Benutzer, die die Rolle bereits haben, erzeugen weder Write noch Logzeile.
- Ausstehende Löschungen für neu gewhitelistete Benutzer werden storniert.

#### Blacklist

- Pflege unzuverlässiger/Wegwerf-Domains unter **Admin → IntakeShield → Blacklist**.
- Muster: Apex + Subdomains (`example.com`, `@example.com`) oder nur Subdomains (`*.example.com`).
- Wird als Scoring-Signal `disposable_domain` genutzt.
- Domains gelöschter Spam-Benutzer werden automatisch ergänzt. Freemail-Anbieter, Mail-Infrastruktur (z. B. `udag.de`) und Behörden-Domains (`*.gov`, `*.gov.*`) werden weder gelernt noch als Wegwerf-Domain gewertet — vorhandene Fehl-Einträge werden beim Upgrade deaktiviert.

#### Keywords

- Pflege unter **Admin → IntakeShield → Keywords**.
- Groß-/Kleinschreibung wird ignoriert; Treffer in Ticket-Titel und erstem Artikel-Body erhöhen den Spam-Score (`spam_keyword`).
- Mit dem Paket wird eine Standard-Keyword-Liste mitgeliefert.

#### Spam-Benutzer (Kontenbereinigung)

- Stündlicher Scan findet Löschkandidaten.
- Harte Bedingungen (alle müssen zutreffen, außer im Spam-Tag-Modus):
  - nicht auf der Whitelist
  - konfigurierte Kandidaten-Rolle, keine Admin-/Agent-Rechte
  - Konto älter als `intake_shield_min_age_days` (Standard: 14)
  - Konto jünger als `intake_shield_max_age_days`, sofern gesetzt (Standard: `0` = keine Obergrenze)
  - höchstens `intake_shield_max_ticket_count` Tickets (Standard: 2)
- Optionales Scoring (`intake_shield_scoring_enabled`): u. a. nie angemeldet, Wegwerf-Domain, verdächtiges E-Mail-Muster, fehlender Name, Spam-Tag auf Kunden-Tickets, Keyword-Treffer. Vormerkung erst ab `intake_shield_score_threshold`.
- Verzögerung `intake_shield_delay_hours` (Standard: 72; `0` = keine Verzögerung). Fällige Einträge alle 30 Minuten per `DataPrivacyTask`.
- Admin-UI **Spam-Benutzer**: Warteschlange, jetzt scannen, sofort löschen, abbrechen oder zur Whitelist hinzufügen.

#### Spam-Tickets (nur Ticket-Löschung)

- Stündlicher Scan findet Tickets mit dem konfigurierten Spam-Tag.
- Kundenkonten bleiben erhalten; gelöscht wird nur das Ticket per Data Privacy.
- Ist der Kunde bereits Spam-Benutzer-Kandidat (ausstehende Benutzerlöschung oder aktuell qualifiziert), wird das Ticket **nicht** separat vorgemerkt — die Benutzerlöschung entfernt die Tickets mit dem Konto.
- Admin-UI **Spam-Tickets**: Warteschlange, jetzt scannen, sofort löschen oder abbrechen.

#### Registrierungs-Captcha

- Optional und unabhängig vom Hauptschalter (Fake-Registrierungen blockieren, ohne automatische Löschung zu aktivieren).
- Schützt das **klassische** Registrierungsformular (`POST /api/v1/users` mit `signup: true`) und die **klassische** Passwort-Reset-Anfrage (`POST /api/v1/users/password_reset`).
- Zusätzlich ein verstecktes Honeypot-Feld; ausgefüllte Honeypots werden abgelehnt.
- Captcha-Quelle (Admin → IntakeShield → Settings):
  - **ALTCHA (selbst gehostet)** — Proof-of-Work, keine Drittanbieter-Keys, DSGVO-freundlich. Standard.
  - **Formular-Kanal** — verwendet das bereits unter **Kanäle → Formular** konfigurierte Captcha (Turnstile, hCaptcha, Friendly Captcha, reCAPTCHA, …). Setzt ein aktuelles Zammad 7.x mit `FormSpamProtection` voraus. Fehlt die API oder der Provider, werden Anfragen abgelehnt (fail-closed).
- Gilt **nicht** für das Anlegen durch Admins/Agents, Mail-Auto-Create, LDAP oder den Passwort-Reset-**Verify**-Schritt (nach dem E-Mail-Link).
- Die neue Desktop-/Mobile-UI (GraphQL `userSignup` / `userPasswordResetSend`) ist in dieser Version **nicht** abgedeckt — ein Classic-Paket kann dort kein Widget einbauen.

ALTCHA-Proof-of-Work läuft in der Seite (kein CDN, keine Web Worker). Bei **Formular-Kanal** muss die CSP des Reverse-Proxys den gewählten Provider weiterhin erlauben (z. B. `https://challenges.cloudflare.com` für Turnstile).

#### Sicherheit

- Agents und Admins sind von der automatischen Benutzerlöschung ausgeschlossen.
- Whitelist blockiert Löschung hart (inkl. Storno bereits vorgemerkter Einträge).
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

4. Zuerst [Empfohlene Einrichtung](#empfohlene-einrichtung-rolle-neu-und-tag-spam) (Rolle `Neu` + Tag `SPAM`), danach **Admin → IntakeShield** öffnen, Whitelist / Blacklist / Keywords / Settings pflegen und den Master-Switch **IntakeShield** aktivieren.

> **Achtung:** Löschungen über Data Privacy sind endgültig. Nutze den Delay und die Übersichten Spam-Benutzer / Spam-Tickets zur Prüfung vor der Ausführung.

### Empfohlene Einrichtung: Rolle Neu und Tag SPAM

IntakeShield legt keine Zammad-Rollen oder -Tags an. Ohne vorläufige Rolle landen per Mail erzeugte Benutzer direkt in `Customer` — derselben Rolle wie vertrauenswürdige Absender. Cleanup kann sie dann nicht unterscheiden, und die Whitelist hat nichts zum Entfernen. Die vorgesehene Trennung:

- **Unbekannte / nicht vertrauenswürdige** Konten behalten die vorläufige Rolle `Neu` (Löschkandidaten).
- **Whitelist-Treffer** werden zu `Customer` befördert und verlieren `Neu` (keine automatische Löschung).
- Tickets mit Tag `SPAM` speisen das Scoring und den Ticket-Cleanup.

`Neu` ist eine **Benutzerrolle**, keine Ticket-Gruppe.

#### 1. Rolle `Neu`

1. **Admin → Verwaltung → Rollen → Neu**.
2. Name: `Neu`.
3. Dieselbe Kundenberechtigung wie `Customer` (`ticket.customer`). **Keine** Agent- oder Admin-Rechte.
4. **Standard bei Registrierung** für `Neu` aktivieren.
5. **Standard bei Registrierung** für `Customer` deaktivieren, damit Selbstregistrierung und Mail-Auto-Create nur `Neu` bekommen.

Bestehende `Customer`-Konten bleiben unverändert. Nur neu angelegte Benutzer starten in `Neu`.

#### 2. Tag `SPAM`

1. Tag `SPAM` anlegen (**Admin → Verwaltung → Tags**, oder einmal an einem Ticket setzen — Zammad erzeugt das Tag).
2. Optional automatisch setzen: **Postmaster-Filter** oder **Trigger** (z. B. Spam-Kennzeichnung vom Mail-Gateway).
3. Der Name muss exakt zur IntakeShield-Einstellung passen (`SPAM`, nicht `Spam`).

#### 3. IntakeShield-Einstellungen

| Setting | Wert | Zweck |
| --- | --- | --- |
| Whitelist-Rolle | `Customer` | Vertrauenswürdige Adressen werden hierhin befördert |
| Rollen bei Whitelist entfernen | `Neu` | Vorläufige Rolle fällt weg, der Account verlässt die Kandidatenmenge |
| Kandidaten-Rolle | `Neu` | Benutzer-Cleanup betrachtet nur unbekannte Konten |
| Spam-Tag | `SPAM` | Scoring-Signal und Ticket-Cleanup |

Vertrauenswürdige Domains unter **Admin → IntakeShield → Whitelist** eintragen (z. B. `@example.com`). Der stündliche Whitelist-Sync weist dann `Customer` zu, entfernt `Neu` und storniert eine evtl. vorgemerkte Löschung.

Damit Ticket-Cleanup und das Signal `spam_tag` laufen, `intake_shield_spam_tag` auf `SPAM` setzen und Scoring aktivieren. Liegt das Gewicht `spam_tag` mindestens auf dem Score-Schwellwert, gelten Kunden mit einem `SPAM`-Ticket auch ohne Rolle `Neu` als Kandidaten.

### Konfiguration (Admin → IntakeShield → Settings)

| Setting | Standard | Beschreibung |
| --- | --- | --- |
| `intake_shield_active` | `false` | Master-Switch für Regeln und Cleanup |
| `intake_shield_whitelist_role_id` | Rolle `Customer` | Rolle bei Whitelist-Treffer |
| `intake_shield_whitelist_remove_role_ids` | `[]` | Rollen, die bei Whitelist-Zuweisung entfernt werden (z. B. vorläufige Rolle `Neu`) |
| `intake_shield_candidate_role_id` | Rolle `Customer` | Kandidaten-Rolle für Benutzer-Cleanup |
| `intake_shield_min_age_days` | `14` | Mindestalter des Kontos (Tage) |
| `intake_shield_max_age_days` | `0` | Maximalalter des Kontos (Tage); `0` deaktiviert die Obergrenze |
| `intake_shield_max_ticket_count` | `2` | Maximale Ticketanzahl |
| `intake_shield_delay_hours` | `72` | Verzögerung bis zur Data-Privacy-Löschung; `0` deaktiviert die Verzögerung (Änderung terminiert ausstehende Einträge neu) |
| `intake_shield_scoring_enabled` | `false` | Score-basiertes Vormerken aktivieren |
| `intake_shield_spam_tag` | *(leer)* | Ticket-Tag als Scoring- / Ticket-Scan-Signal |
| `intake_shield_score_threshold` | `100` | Mindest-Score für Vormerkung |
| `intake_shield_score_weights` | JSON | Gewichte der Signale (`never_logged_in`, `low_ticket_count`, `disposable_domain`, `suspicious_email_pattern`, `missing_name`, `spam_tag`, `spam_keyword`, …) |
| `intake_shield_signup_captcha` | `false` | Captcha auf klassischer Registrierung und Passwort-Reset-Anfrage (unabhängig vom Hauptschalter) |
| `intake_shield_captcha_source` | `altcha` | `altcha` (selbst gehostet) oder `form_channel` (wiederverwendet **Kanäle → Formular**) |

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
bin/build 0.4.3
```

`bin/build` liest `intake_shield.szpm`, sammelt Dateien unter `app/`, `config/`, `db/`, `lib/` und `public/` und erzeugt lokal `releases/intake_shield-<version>.zpm` (das Verzeichnis ist gitignored; Pakete erscheinen als GitHub Releases). Wie der öffentliche GitHub-Stand aus der privaten Entwicklungshistorie aktualisiert wird, steht in [CONTRIBUTING.md](CONTRIBUTING.md).

### Projekt unterstützen

Wenn dir IntakeShield Zeit spart, kannst du mir einen Kaffee spendieren:

**[paypal.me/tranquillius](https://paypal.me/tranquillius)**

---

## License

This project is licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0).  
See [LICENSE](LICENSE) for the full text.

Copyright © 2026 Tranquillius / IntakeShield.
