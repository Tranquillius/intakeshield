# Shared German (de-de) catalog for IntakeShield UI and setting strings.
# Loaded by package migrations; keep English sources identical to __()/ @T() calls.
module IntakeShieldDeTranslations
  MAP = {
    'IntakeShield'                                                                                                 => 'IntakeShield',
    'Whitelist'                                                                                                    => 'Whitelist',
    'Whitelist Entry'                                                                                              => 'Whitelist-Eintrag',
    'Whitelist Entries'                                                                                            => 'Whitelist-Einträge',
    'New Whitelist Entry'                                                                                          => 'Neuer Whitelist-Eintrag',
    'Blacklist'                                                                                                    => 'Blacklist',
    'Keywords'                                                                                                     => 'Keywords',
    'Keyword'                                                                                                      => 'Keyword',
    'New Keyword'                                                                                                  => 'Neues Keyword',
    'Case-insensitive match in ticket title and first article body. Raises the spam score.'                        => 'Groß-/Kleinschreibung wird ignoriert. Treffer in Ticket-Titel und erstem Artikel-Body erhöhen den Spam-Score.',
    'Typical spam marketing phrases (e.g. product ads). Matching customer tickets raise the spam score.'           => 'Typische Spam-/Werbebegriffe. Treffer in Kunden-Tickets erhöhen den Spam-Score.',
    'Spam keywords found in customer tickets raise the spam score.'                                                => 'Spam-Keywords in Kunden-Tickets erhöhen den Spam-Score.',
    'Spam keyword'                                                                                                 => 'Spam-Keyword',
    'Default spam keyword'                                                                                         => 'Standard-Spam-Keyword',
    'Blacklist Entry'                                                                                              => 'Blacklist-Eintrag',
    'Blacklist Entries'                                                                                            => 'Blacklist-Einträge',
    'New Blacklist Entry'                                                                                          => 'Neuer Blacklist-Eintrag',
    'Domain'                                                                                                       => 'Domain',
    'example.com / @example.com = domain + subdomains; *.example.com = subdomains only.'                           => 'example.com / @example.com = Domain + Subdomains; *.example.com = nur Subdomains.',
    'Disposable or otherwise untrusted domains. Matching addresses raise the spam score. Domains of deleted spam users are added automatically.' => 'Wegwerf- oder anderweitig unzuverlässige Domains. Treffer erhöhen den Spam-Score. Domains gelöschter Spam-Benutzer werden automatisch ergänzt.',
    'Auto-learned from deleted user'                                                                               => 'Automatisch von gelöschtem Benutzer gelernt',
    'Deactivated never-disposable domain'                                                                          => 'Deaktiviert: keine Wegwerf-Domain',
    'Default disposable domain'                                                                                    => 'Standard-Wegwerf-Domain',
    'Spam Users'                                                                                                   => 'Spam-Benutzer',
    'Details'                                                                                                      => 'Details',
    'State'                                                                                                        => 'Status',
    'Settings'                                                                                                     => 'Einstellungen',
    'Master Switch'                                                                                                => 'Hauptschalter',
    'Enable or disable IntakeShield as a whole.'                                                                   => 'IntakeShield insgesamt ein- oder ausschalten.',
    'Settings that control how trusted senders are handled.'                                                       => 'Einstellungen für den Umgang mit vertrauenswürdigen Absendern.',
    'Spam Detection'                                                                                               => 'Spam-Erkennung',
    'Settings for detecting spam users/tickets and scheduling deletions.'                                          => 'Einstellungen zur Erkennung von Spam-Benutzern/-Tickets und zur Planung von Löschungen.',
    'Pattern'                                                                                                      => 'Muster',
    'Note'                                                                                                         => 'Notiz',
    'Active'                                                                                                       => 'Aktiv',
    'Score'                                                                                                        => 'Punktzahl',
    'Reasons'                                                                                                      => 'Gründe',
    'Account created'                                                                                              => 'Konto erstellt',
    'Tickets'                                                                                                      => 'Tickets',
    'Scheduled deletion'                                                                                           => 'Geplante Löschung',
    'Cancel Deletion'                                                                                              => 'Löschung abbrechen',
    'Add to Whitelist'                                                                                             => 'Zur Whitelist hinzufügen',
    'No users are currently scheduled for deletion.'                                                               => 'Aktuell sind keine Benutzer zur Löschung vorgesehen.',
    'Failed deletions'                                                                                             => 'Fehlgeschlagene Löschungen',
    'Refresh'                                                                                                      => 'Aktualisieren',
    'Scan now'                                                                                                     => 'Jetzt scannen',
    'Scan finished: %s scheduled.'                                                                                 => 'Scan abgeschlossen: %s vorgemerkt.',
    'Scan failed.'                                                                                                 => 'Scan fehlgeschlagen.',
    'Last scan'                                                                                                    => 'Letzter Scan',
    'mode'                                                                                                         => 'Modus',
    'Delete now'                                                                                                   => 'Sofort löschen',
    'Delete all now'                                                                                               => 'Alle sofort löschen',
    'Really delete this user immediately via data privacy? This cannot be undone.'                                 => 'Diesen Benutzer wirklich sofort per Data Privacy löschen? Das kann nicht rückgängig gemacht werden.',
    'Really delete all pending users immediately via data privacy? This cannot be undone.'                         => 'Wirklich alle ausstehenden Benutzer sofort per Data Privacy löschen? Das kann nicht rückgängig gemacht werden.',
    'User deletion started.'                                                                                       => 'Benutzerlöschung gestartet.',
    'Immediate deletion started for %s users.'                                                                     => 'Sofortlöschung für %s Benutzer gestartet.',
    'Immediate deletion failed.'                                                                                   => 'Sofortlöschung fehlgeschlagen.',
    'considered'                                                                                                   => 'geprüft',
    'scheduled'                                                                                                    => 'vorgemerkt',
    'skipped (role)'                                                                                               => 'übersprungen (Rolle)',
    'skipped (ticket count)'                                                                                       => 'übersprungen (Ticketanzahl)',
    'skipped (low score)'                                                                                          => 'übersprungen (Score zu niedrig)',
    'skipped (already listed)'                                                                                     => 'übersprungen (bereits gelistet)',
    'skipped (whitelisted)'                                                                                        => 'übersprungen (Whitelist)',
    'skipped (privacy task)'                                                                                       => 'übersprungen (Datenschutz-Aufgabe)',
    'skipped (user deletion)'                                                                                      => 'übersprungen (Benutzerlöschung)',
    'pending'                                                                                                      => 'ausstehend',
    'cancelled'                                                                                                    => 'abgebrochen',
    'executed'                                                                                                     => 'ausgeführt',
    'failed'                                                                                                       => 'fehlgeschlagen',
    'inactive'                                                                                                     => 'inaktiv',
    'candidate_role_missing'                                                                                       => 'Kandidaten-Rolle fehlt',
    'spam_tag_missing'                                                                                             => 'Spam-Tag fehlt',
    'spam_tag'                                                                                                     => 'Spam-Tag',
    'full'                                                                                                         => 'vollständig',
    'spam_tag+full'                                                                                                => 'Spam-Tag+vollständig',
    'ticket no longer exists'                                                                                      => 'Ticket existiert nicht mehr',
    'customer scheduled for deletion'                                                                              => 'Kunde zur Löschung vorgemerkt',
    'user no longer exists'                                                                                        => 'Benutzer existiert nicht mehr',
    'whitelisted'                                                                                                  => 'auf Whitelist',
    'privileged user'                                                                                              => 'privilegierter Benutzer',
    'candidate role missing'                                                                                       => 'Kandidaten-Rolle fehlt',
    'roles changed'                                                                                                => 'Rollen geändert',
    'ticket count exceeded'                                                                                        => 'Ticketanzahl überschritten',
    'cancelled: manually cancelled by %s'                                                                          => 'abgebrochen: manuell abgebrochen von %s',
    'cancelled: whitelisted by %s'                                                                                 => 'abgebrochen: auf Whitelist gesetzt von %s',
    'Really cancel this deletion?'                                                                                 => 'Diese Löschung wirklich abbrechen?',
    'Really add this user to the whitelist and cancel the deletion?'                                               => 'Diesen Benutzer wirklich auf die Whitelist setzen und die Löschung abbrechen?',
    'Deletion cancelled.'                                                                                          => 'Löschung abgebrochen.',
    'User added to whitelist.'                                                                                     => 'Benutzer zur Whitelist hinzugefügt.',
    'Trusted e-mail addresses and domains. Matching users receive the configured whitelist role and are never deleted automatically.' => 'Vertrauenswürdige E-Mail-Adressen und Domains. Treffer erhalten die konfigurierte Whitelist-Rolle und werden nie automatisch gelöscht.',
    'Exact address (user@example.com) or parent domain including subdomains (@example.com, example.com, *@example.com).' => 'Exakte Adresse (user@example.com) oder Parent-Domain inkl. Subdomains (@example.com, example.com, *@example.com).',
    # Legacy English source (pre-hourly scan): keep mapping so cached assets still get the updated German text.
    'Users that will be deleted by a data privacy task after the configured delay. A background scan runs once per day; due deletions are executed every 30 minutes. Use "Scan now" to run the scan immediately.' => 'Benutzer, die nach Ablauf der konfigurierten Verzögerung per Data-Privacy-Task gelöscht werden. Ein Hintergrund-Scan läuft einmal stündlich; fällige Löschungen werden alle 30 Minuten ausgeführt. Mit „Jetzt scannen“ starten Sie den Scan sofort.',
    'Users that will be deleted by a data privacy task after the configured delay. A background scan runs once per hour; due deletions are executed every 30 minutes. Use "Scan now" to run the scan immediately.' => 'Benutzer, die nach Ablauf der konfigurierten Verzögerung per Data-Privacy-Task gelöscht werden. Ein Hintergrund-Scan läuft einmal stündlich; fällige Löschungen werden alle 30 Minuten ausgeführt. Mit „Jetzt scannen“ starten Sie den Scan sofort.',
    'E-Mail'                                                                                                       => 'E-Mail',
    'Name'                                                                                                         => 'Name',
    'Added from pending deletions'                                                                                 => 'Aus ausstehenden Löschungen hinzugefügt',
    'All conditions matched'                                                                                       => 'Alle Bedingungen erfüllt',
    'Never logged in'                                                                                              => 'Nie angemeldet',
    'Low ticket count'                                                                                             => 'Niedrige Ticketanzahl',
    'Disposable domain'                                                                                            => 'Wegwerf-Domain',
    'Suspicious e-mail pattern'                                                                                    => 'Verdächtiges E-Mail-Muster',
    'Missing name'                                                                                                 => 'Kein Name hinterlegt',
    'Master switch for the whitelist rules and the automatic cleanup of spam users.'                               => 'Hauptschalter für die Whitelist-Regeln und die automatische Bereinigung von Spam-Benutzern.',
    'Whitelist Role'                                                                                               => 'Whitelist-Rolle',
    'Role that is assigned to users whose e-mail address matches the whitelist.'                                   => 'Rolle, die Benutzern zugewiesen wird, deren E-Mail-Adresse auf die Whitelist passt.',
    'Roles to Remove on Whitelist'                                                                                 => 'Rollen bei Whitelist entfernen',
    'Roles that are removed from a user when the whitelist role is assigned (e.g. a provisional "Neu" role). Leave empty to only add the whitelist role.' => 'Rollen, die einem Benutzer entfernt werden, wenn die Whitelist-Rolle zugewiesen wird (z. B. eine vorläufige Rolle „Neu“). Leer lassen, um nur die Whitelist-Rolle hinzuzufügen.',
    'Candidate Role'                                                                                               => 'Kandidaten-Rolle',
    'Only users that have this role (and no admin/agent permissions) are considered for automatic deletion.'       => 'Nur Benutzer mit dieser Rolle (ohne Admin-/Agent-Rechte) werden für die automatische Löschung berücksichtigt.',
    'Minimum Account Age (days)'                                                                                   => 'Mindestalter des Kontos (Tage)',
    'Only user accounts older than this number of days are considered for deletion.'                               => 'Nur Benutzerkonten, die älter als diese Anzahl an Tagen sind, werden zur Löschung berücksichtigt.',
    'Maximum Account Age (days)'                                                                                   => 'Maximalalter des Kontos (Tage)',
    'Only user accounts younger than this number of days are considered for deletion. Set to 0 to disable the upper age limit.' => 'Nur Benutzerkonten, die jünger als diese Anzahl an Tagen sind, werden zur Löschung berücksichtigt. 0 deaktiviert die Altersobergrenze.',
    'Maximum Ticket Count'                                                                                         => 'Maximale Ticketanzahl',
    'Only users with at most this number of tickets are considered for deletion.'                                  => 'Nur Benutzer mit höchstens dieser Anzahl an Tickets werden zur Löschung berücksichtigt.',
    'Deletion Delay (hours)'                                                                                       => 'Löschverzögerung (Stunden)',
    'Delay in hours between detection and the data privacy deletion. Set to 0 to disable the delay (schedule immediately). Changing this updates the planned time of all pending deletions.' => 'Verzögerung in Stunden zwischen Erkennung und Datenschutz-Löschung. 0 deaktiviert die Verzögerung (sofortige Terminierung). Eine Änderung aktualisiert die geplante Löschung aller ausstehenden Einträge.',
    'Scoring Enabled'                                                                                              => 'Scoring aktiviert',
    'If enabled, candidates are only scheduled for deletion when their spam score reaches the threshold.'          => 'Wenn aktiviert, werden Kandidaten erst zur Löschung vorgemerkt, wenn ihr Spam-Score die Schwelle erreicht.',
    'Spam Tag'                                                                                                     => 'Spam-Tag',
    'Optional ticket tag used as a scoring signal when at least one customer ticket of the user carries this tag (e.g. SPAM). Leave empty to disable.' => 'Optionales Ticket-Tag als Scoring-Signal, wenn mindestens ein Kunden-Ticket des Benutzers dieses Tag trägt (z. B. SPAM). Leer lassen zum Deaktivieren.',
    'Tagged spam ticket'                                                                                           => 'Ticket mit Spam-Tag',
    'Score Threshold'                                                                                              => 'Score-Schwelle',
    'Minimum spam score that triggers a deletion (only used when scoring is enabled).'                             => 'Mindest-Spam-Score, der eine Löschung auslöst (nur bei aktiviertem Scoring).',
    'Score Weights'                                                                                                => 'Score-Gewichte',
    'JSON object with the point weights of the individual scoring signals.'                                        => 'JSON-Objekt mit den Punktegewichten der einzelnen Scoring-Signale.',
    'Manage IntakeShield whitelist and spam user cleanup.'                                                         => 'IntakeShield-Whitelist und Spam-Benutzerbereinigung verwalten.',
    'IntakeShield: Apply whitelist role assignments.'                                                              => 'IntakeShield: Whitelist-Rollenzuweisungen anwenden.',
    'IntakeShield: Scan for spam users.'                                                                           => 'IntakeShield: Nach Spam-Benutzern suchen.',
    'IntakeShield: Execute pending deletions.'                                                                     => 'IntakeShield: Ausstehende Löschungen ausführen.',
    'Spam Tickets'                                                                                                 => 'Spam-Tickets',
    'Tickets carrying the configured spam tag that will be deleted by a data privacy task after the configured delay. The customer account is kept. A background scan runs once per hour; due deletions are executed every 30 minutes. Use "Scan now" to run the scan immediately.' => 'Tickets mit dem konfigurierten Spam-Tag, die nach der konfigurierten Verzögerung per Datenschutz-Aufgabe gelöscht werden. Das Kundenkonto bleibt bestehen. Ein Hintergrund-Scan läuft einmal stündlich; fällige Löschungen werden alle 30 Minuten ausgeführt. Mit „Jetzt scannen“ starten Sie den Scan sofort.',
    'Tickets carrying the configured spam tag that will be deleted by a data privacy task after the configured delay. The customer account is kept unless that customer is already a spam-user candidate — then user deletion removes the tickets. A background scan runs once per hour; due deletions are executed every 30 minutes. Use "Scan now" to run the scan immediately.' => 'Tickets mit dem konfigurierten Spam-Tag, die nach der konfigurierten Verzögerung per Datenschutz-Aufgabe gelöscht werden. Das Kundenkonto bleibt bestehen, außer der Kunde ist bereits Spam-Benutzer-Kandidat — dann entfernt die Benutzerlöschung die Tickets mit. Ein Hintergrund-Scan läuft einmal stündlich; fällige Löschungen werden alle 30 Minuten ausgeführt. Mit „Jetzt scannen“ starten Sie den Scan sofort.',
    'Ticket'                                                                                                       => 'Ticket',
    'Title'                                                                                                        => 'Titel',
    'Customer'                                                                                                     => 'Kunde',
    'Ticket created'                                                                                               => 'Ticket erstellt',
    'No tickets are currently scheduled for deletion.'                                                             => 'Derzeit sind keine Tickets zur Löschung vorgesehen.',
    'Really delete this ticket immediately via data privacy? This cannot be undone.'                               => 'Dieses Ticket wirklich sofort per Datenschutz-Aufgabe löschen? Dies kann nicht rückgängig gemacht werden.',
    'Really delete all pending tickets immediately via data privacy? This cannot be undone.'                       => 'Alle ausstehenden Tickets wirklich sofort per Datenschutz-Aufgabe löschen? Dies kann nicht rückgängig gemacht werden.',
    'Ticket deletion started.'                                                                                     => 'Ticket-Löschung gestartet.',
    'Immediate deletion started for %s tickets.'                                                                   => 'Sofortige Löschung für %s Tickets gestartet.',
    'IntakeShield: Scan for spam tickets.'                                                                         => 'IntakeShield: Nach Spam-Tickets suchen.',
    'IntakeShield: Execute pending ticket deletions.'                                                              => 'IntakeShield: Ausstehende Ticket-Löschungen ausführen.',
    'Captcha'                                                                                                      => 'Captcha',
    'Protect the classic sign-up form and password reset requests from automated abuse.'                           => 'Schützt das klassische Registrierungsformular und Anfragen zum Zurücksetzen des Passworts vor automatisiertem Missbrauch.',
    'Signup Captcha'                                                                                               => 'Registrierungs-Captcha',
    'Require a CAPTCHA on the classic sign-up form and when requesting a password reset e-mail. Independent of the master switch.' => 'Captcha auf dem klassischen Registrierungsformular und beim Anfordern einer Passwort-Reset-E-Mail verlangen. Unabhängig vom Hauptschalter.',
    'Captcha Source'                                                                                               => 'Captcha-Quelle',
    'ALTCHA is self-hosted and needs no keys. Form channel reuses the CAPTCHA already configured under Channels → Form.' => 'ALTCHA wird selbst gehostet und benötigt keine Keys. Formular-Kanal verwendet das bereits unter Kanäle → Formular konfigurierte Captcha.',
    'ALTCHA (self-hosted)'                                                                                         => 'ALTCHA (selbst gehostet)',
    'Form channel'                                                                                                 => 'Formular-Kanal',
    'Captcha verification failed.'                                                                                 => 'Captcha-Prüfung fehlgeschlagen.',
    'Captcha is still verifying. Please wait a moment.'                                                            => 'Captcha wird noch geprüft. Bitte einen Moment warten.',
    'Captcha could not be loaded. Please reload the page.'                                                         => 'Captcha konnte nicht geladen werden. Bitte die Seite neu laden.',
    'Verifying that you are human…'                                                                                => 'Prüfung, ob Sie ein Mensch sind…',
    'Verified'                                                                                                     => 'Bestätigt',
  }.freeze

  def self.apply!
    MAP.each do |source, target|
      upsert!(source, target)
    end
  end

  # Some Zammad versions require created_by_id/updated_by_id on translations;
  # others reject those attributes. Detect columns and set user 1 when needed.
  def self.upsert!(source, target)
    translation = Translation.find_source('de-de', source) || Translation.find_by(locale: 'de-de', source: source)
    if translation
      attrs = {
        target:         target,
        target_initial: target,
      }
      attrs[:updated_by_id] = 1 if column?('updated_by_id') && translation.updated_by_id.blank?
      attrs[:created_by_id] = 1 if column?('created_by_id') && translation.created_by_id.blank?
      translation.update!(attrs)
      return translation
    end

    attrs = {
      locale:                        'de-de',
      source:                        source,
      target:                        target,
      target_initial:                target,
      is_synchronized_from_codebase: false,
    }
    attrs[:created_by_id] = 1 if column?('created_by_id')
    attrs[:updated_by_id] = 1 if column?('updated_by_id')

    # Prefer direct create when user FKs are required — Service::Translation::Upsert
    # on some Zammad builds inserts NULL into updated_by_id (NOT NULL).
    if defined?(Service::Translation::Upsert) && !column?('updated_by_id')
      Service::Translation::Upsert.execute(locale: 'de-de', source: source, target: target)
      translation = Translation.find_source('de-de', source)
      translation&.update!(target_initial: target) if translation && translation.target_initial != target
      return translation
    end

    Translation.create!(attrs)
  end

  def self.column?(name)
    Translation.column_names.include?(name)
  end
  private_class_method :column?
end
