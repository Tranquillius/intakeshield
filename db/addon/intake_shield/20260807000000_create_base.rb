class CreateBase < ActiveRecord::Migration[7.0]
  def self.up
    create_tables
    create_settings
    create_permission
    create_schedulers
    create_translations
    seed_blacklist
    seed_keywords
  end

  def self.down
    remove_schedulers
    remove_permission
    remove_settings
    drop_tables
  end

  def self.create_tables
    if !table_exists?(:intake_shield_whitelists)
      create_table :intake_shield_whitelists do |t|
        t.column :pattern, :string, limit: 255, null: false
        t.column :note, :string, limit: 500, null: true
        t.column :active, :boolean, null: false, default: true
        t.references :created_by, null: false, foreign_key: { to_table: :users }
        t.references :updated_by, null: false, foreign_key: { to_table: :users }
        t.timestamps null: false, limit: 3
      end
      add_index :intake_shield_whitelists, :pattern, unique: true
    end

    if !table_exists?(:intake_shield_pending_deletions)
      create_table :intake_shield_pending_deletions do |t|
        # optional + nullify: DataPrivacyTask must be able to destroy the user
        # while a history row in this table still exists.
        t.references :user, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
        t.column :score, :integer, null: false, default: 0
        t.column :reasons, :text, null: true
        t.column :state, :string, limit: 50, null: false, default: 'pending'
        t.column :execute_at, :datetime, limit: 3, null: false
        t.references :created_by, null: false, foreign_key: { to_table: :users }
        t.references :updated_by, null: false, foreign_key: { to_table: :users }
        t.timestamps null: false, limit: 3
      end
      add_index :intake_shield_pending_deletions, %i[state execute_at]
    end

    if !table_exists?(:intake_shield_blacklists)
      create_table :intake_shield_blacklists do |t|
        t.column :pattern, :string, limit: 255, null: false
        t.column :note, :string, limit: 500, null: true
        t.column :active, :boolean, null: false, default: true
        t.references :created_by, null: false, foreign_key: { to_table: :users }
        t.references :updated_by, null: false, foreign_key: { to_table: :users }
        t.timestamps null: false, limit: 3
      end
      add_index :intake_shield_blacklists, :pattern, unique: true
    end

    if !table_exists?(:intake_shield_keywords)
      create_table :intake_shield_keywords do |t|
        t.column :pattern, :string, limit: 255, null: false
        t.column :note, :string, limit: 500, null: true
        t.column :active, :boolean, null: false, default: true
        t.references :created_by, null: false, foreign_key: { to_table: :users }
        t.references :updated_by, null: false, foreign_key: { to_table: :users }
        t.timestamps null: false, limit: 3
      end
      add_index :intake_shield_keywords, :pattern, unique: true
    end

    if !table_exists?(:intake_shield_pending_tickets)
      create_table :intake_shield_pending_tickets do |t|
        t.references :ticket, null: true, foreign_key: { to_table: :tickets, on_delete: :nullify }
        t.column :score, :integer, null: false, default: 0
        t.column :reasons, :text, null: true
        t.column :state, :string, limit: 50, null: false, default: 'pending'
        t.column :execute_at, :datetime, limit: 3, null: false
        t.references :created_by, null: false, foreign_key: { to_table: :users }
        t.references :updated_by, null: false, foreign_key: { to_table: :users }
        t.timestamps null: false, limit: 3
      end
      add_index :intake_shield_pending_tickets, %i[state execute_at]
    end
  end

  def self.drop_tables
    drop_table :intake_shield_pending_tickets, if_exists: true
    drop_table :intake_shield_pending_deletions, if_exists: true
    drop_table :intake_shield_keywords, if_exists: true
    drop_table :intake_shield_blacklists, if_exists: true
    drop_table :intake_shield_whitelists, if_exists: true
  end

  def self.create_settings
    Setting.create_if_not_exists(
      title:       __('IntakeShield'),
      name:        'intake_shield_active',
      area:        'IntakeShield::Base',
      description: __('Master switch for the whitelist rules and the automatic cleanup of spam users.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'intake_shield_active',
            tag:     'boolean',
            options: {
              true  => 'yes',
              false => 'no',
            },
          },
        ],
      },
      preferences: {
        prio:       1000,
        permission: ['admin.intake_shield'],
        controller: 'SettingsAreaSwitch',
        sub:        [],
      },
      state:       false,
      frontend:    true
    )
    customer_role_id = Role.find_by(name: 'Customer')&.id

    Setting.create_if_not_exists(
      title:       __('Whitelist Role'),
      name:        'intake_shield_whitelist_role_id',
      area:        'IntakeShield::Whitelist',
      description: __('Role that is assigned to users whose e-mail address matches the whitelist.'),
      options:     {
        form: [
          {
            display:  '',
            null:     false,
            name:     'intake_shield_whitelist_role_id',
            tag:      'select',
            relation: 'Role',
          },
        ],
      },
      preferences: {
        prio:       1100,
        permission: ['admin.intake_shield'],
      },
      state:       customer_role_id,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Candidate Role'),
      name:        'intake_shield_candidate_role_id',
      area:        'IntakeShield::Spam',
      description: __('Only users that have this role (and no admin/agent permissions) are considered for automatic deletion.'),
      options:     {
        form: [
          {
            display:  '',
            null:     false,
            name:     'intake_shield_candidate_role_id',
            tag:      'select',
            relation: 'Role',
          },
        ],
      },
      preferences: {
        prio:       1200,
        permission: ['admin.intake_shield'],
      },
      state:       customer_role_id,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Minimum Account Age (days)'),
      name:        'intake_shield_min_age_days',
      area:        'IntakeShield::Spam',
      description: __('Only user accounts older than this number of days are considered for deletion.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_min_age_days',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1300,
        permission: ['admin.intake_shield'],
      },
      state:       14,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Maximum Account Age (days)'),
      name:        'intake_shield_max_age_days',
      area:        'IntakeShield::Spam',
      description: __('Only user accounts younger than this number of days are considered for deletion. Set to 0 to disable the upper age limit.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_max_age_days',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1350,
        permission: ['admin.intake_shield'],
      },
      state:       0,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Maximum Ticket Count'),
      name:        'intake_shield_max_ticket_count',
      area:        'IntakeShield::Spam',
      description: __('Only users with at most this number of tickets are considered for deletion.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_max_ticket_count',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1400,
        permission: ['admin.intake_shield'],
      },
      state:       2,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Deletion Delay (hours)'),
      name:        'intake_shield_delay_hours',
      area:        'IntakeShield::Spam',
      description: __('Delay in hours between detection and the data privacy deletion. Set to 0 to disable the delay (schedule immediately). Changing this updates the planned time of all pending deletions.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_delay_hours',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1500,
        permission: ['admin.intake_shield'],
      },
      state:       72,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Scoring Enabled'),
      name:        'intake_shield_scoring_enabled',
      area:        'IntakeShield::Spam',
      description: __('If enabled, candidates are only scheduled for deletion when their spam score reaches the threshold.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'intake_shield_scoring_enabled',
            tag:     'boolean',
            options: {
              true  => 'yes',
              false => 'no',
            },
          },
        ],
      },
      preferences: {
        prio:       1600,
        permission: ['admin.intake_shield'],
      },
      state:       false,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Spam Tag'),
      name:        'intake_shield_spam_tag',
      area:        'IntakeShield::Spam',
      description: __('Optional ticket tag used as a scoring signal when at least one customer ticket of the user carries this tag (e.g. SPAM). Leave empty to disable.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'intake_shield_spam_tag',
            tag:     'tag',
          },
        ],
      },
      preferences: {
        prio:       1650,
        permission: ['admin.intake_shield'],
      },
      state:       '',
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Score Threshold'),
      name:        'intake_shield_score_threshold',
      area:        'IntakeShield::Spam',
      description: __('Minimum spam score that triggers a deletion (only used when scoring is enabled).'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_score_threshold',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1700,
        permission: ['admin.intake_shield'],
      },
      state:       100,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Score Weights'),
      name:        'intake_shield_score_weights',
      area:        'IntakeShield::Spam',
      description: __('JSON object with the point weights of the individual scoring signals.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_score_weights',
            tag:     'textarea',
            rows:    8,
          },
        ],
      },
      preferences: {
        prio:       1800,
        permission: ['admin.intake_shield'],
      },
      state:       JSON.pretty_generate(
        {
          'never_logged_in'          => 25,
          'low_ticket_count'         => 25,
          'disposable_domain'        => 50,
          'suspicious_email_pattern' => 20,
          'missing_name'             => 10,
          'spam_tag'                 => 50,
          'spam_keyword'             => 50,
          'spam_engine'              => 50,
        }
      ),
      frontend:    true
    )
    create_signup_captcha_settings
    create_drop_blacklisted_mail_settings
    create_spam_engine_settings
    create_whitelist_signup_settings
  end

  def self.create_whitelist_signup_settings
    Setting.create_if_not_exists(
      title:       __('Use whitelist for self-registration'),
      name:        'intake_shield_whitelist_signup',
      area:        'IntakeShield::Whitelist',
      description: __('When enabled, self-registration is allowed only for e-mail addresses that match an existing whitelist entry. Independent of the master switch. Does not apply to admin/agent user creation, mail auto-create, or LDAP. An empty whitelist blocks all self-registration.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'intake_shield_whitelist_signup',
            tag:     'boolean',
            options: {
              true  => 'yes',
              false => 'no',
            },
          },
        ],
      },
      preferences: {
        prio:       1120,
        permission: ['admin.intake_shield'],
      },
      state:       false,
      frontend:    true
    )
  end

  def self.create_signup_captcha_settings
    Setting.create_if_not_exists(
      title:       __('Signup Captcha'),
      name:        'intake_shield_signup_captcha',
      area:        'IntakeShield::Captcha',
      description: __('Require a CAPTCHA on the classic sign-up form and when requesting a password reset e-mail. Independent of the master switch.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'intake_shield_signup_captcha',
            tag:     'boolean',
            options: {
              true  => 'yes',
              false => 'no',
            },
          },
        ],
      },
      preferences: {
        prio:       2000,
        permission: ['admin.intake_shield'],
      },
      state:       false,
      frontend:    true
    )
  end

  POSTMASTER_FILTER_SETTING_NAMES = %w[
    0013_postmaster_filter_intake_shield_blacklist
    0105_postmaster_filter_intake_shield_blacklist_followup
    5405_postmaster_filter_intake_shield_spam_engine
  ].freeze

  def self.create_drop_blacklisted_mail_settings
    Setting.create_if_not_exists(
      title:       __('Drop blacklisted mail'),
      name:        'intake_shield_drop_blacklisted_mail',
      area:        'IntakeShield::Blacklist',
      description: __('Do not create users or tickets from blacklisted sender domains. The original message still follows the e-mail channel option to keep or delete mail on the server. Independent of the master switch.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_drop_blacklisted_mail',
            tag:     'select',
            options: {
              'off'      => 'No',
              'all'      => 'All mail from blacklisted domains',
              'new_only' => 'Only mail that would create a new user or ticket',
            },
          },
        ],
      },
      preferences: {
        prio:       1500,
        permission: ['admin.intake_shield'],
      },
      state:       'off',
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Defines postmaster filter.'),
      name:        '0013_postmaster_filter_intake_shield_blacklist',
      area:        'Postmaster::PreFilter',
      description: __('Defines postmaster filter to drop inbound mail from IntakeShield blacklist domains before user identification.'),
      options:     {},
      state:       'Channel::Filter::IntakeShieldBlacklist',
      frontend:    false
    )
    Setting.create_if_not_exists(
      title:       __('Defines postmaster filter.'),
      name:        '0105_postmaster_filter_intake_shield_blacklist_followup',
      area:        'Postmaster::PreFilter',
      description: __('Defines postmaster filter to drop new tickets from known senders on IntakeShield blacklist domains after follow-up detection.'),
      options:     {},
      state:       'Channel::Filter::IntakeShieldBlacklist',
      frontend:    false
    )
  end

  def self.create_spam_engine_settings
    Setting.create_if_not_exists(
      title:       __('Spam engine'),
      name:        'intake_shield_spam_engine',
      area:        'IntakeShield::SpamEngine',
      description: __('Use gateway spam headers (SpamAssassin, Rspamd, Microsoft SCL) as a scoring signal. IntakeShield does not ship or embed those engines. Independent of the master switch. Live mode talks to a local daemon only when headers are missing; failures are ignored.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_spam_engine',
            tag:     'select',
            options: {
              'off'     => 'Off',
              'headers' => 'Gateway headers',
              'live'    => 'Gateway headers, then local daemon',
            },
          },
        ],
      },
      preferences: {
        prio:       1900,
        permission: ['admin.intake_shield'],
      },
      state:       'off',
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Spam engine backend'),
      name:        'intake_shield_spam_engine_backend',
      area:        'IntakeShield::SpamEngine',
      description: __('Local daemon for live mode. SpamAssassin uses spamd (default port 783). Rspamd uses the HTTP scan worker (default port 11333). Install the daemon yourself; this package only speaks the protocol.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_spam_engine_backend',
            tag:     'select',
            options: {
              'spamassassin' => 'SpamAssassin',
              'rspamd'       => 'Rspamd',
            },
          },
        ],
      },
      preferences: {
        prio:       1910,
        permission: ['admin.intake_shield'],
      },
      state:       'spamassassin',
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Spam engine host'),
      name:        'intake_shield_spam_engine_host',
      area:        'IntakeShield::SpamEngine',
      description: __('Host of the local spam daemon for live mode. Prefer 127.0.0.1 so mail content does not leave the Zammad host.'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_spam_engine_host',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1920,
        permission: ['admin.intake_shield'],
      },
      state:       '127.0.0.1',
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Spam engine port'),
      name:        'intake_shield_spam_engine_port',
      area:        'IntakeShield::SpamEngine',
      description: __('TCP port of the local spam daemon for live mode. 783 for SpamAssassin spamd, 11333 for the Rspamd scan worker (11334 is the controller).'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_spam_engine_port',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1930,
        permission: ['admin.intake_shield'],
      },
      state:       783,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Spam engine timeout (seconds)'),
      name:        'intake_shield_spam_engine_timeout',
      area:        'IntakeShield::SpamEngine',
      description: __('How long to wait for the local daemon in live mode. Timeouts and connection errors are ignored (fail-open).'),
      options:     {
        form: [
          {
            display: '',
            null:    false,
            name:    'intake_shield_spam_engine_timeout',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1940,
        permission: ['admin.intake_shield'],
      },
      state:       2,
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Spam engine password'),
      name:        'intake_shield_spam_engine_password',
      area:        'IntakeShield::SpamEngine',
      description: __('Optional Rspamd controller/worker password for live mode. Leave empty when the local scan socket needs no password.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'intake_shield_spam_engine_password',
            tag:     'input',
          },
        ],
      },
      preferences: {
        prio:       1950,
        permission: ['admin.intake_shield'],
      },
      state:       '',
      frontend:    true
    )
    Setting.create_if_not_exists(
      title:       __('Defines postmaster filter.'),
      name:        '5405_postmaster_filter_intake_shield_spam_engine',
      area:        'Postmaster::PostFilter',
      description: __('Defines postmaster filter to record IntakeShield spam-engine verdicts on inbound articles.'),
      options:     {},
      state:       'Channel::Filter::IntakeShieldSpamEngine',
      frontend:    false
    )
  end

  def self.seed_blacklist
    return if !defined?(IntakeShield::Blacklist)

    IntakeShield::Blacklist.seed_defaults!
  end

  def self.seed_keywords
    return if !defined?(IntakeShield::Keyword)

    IntakeShield::Keyword.seed_defaults!
  end

  def self.remove_settings
    Setting.where('name LIKE ?', 'intake_shield_%').destroy_all
    Setting.where(name: POSTMASTER_FILTER_SETTING_NAMES).destroy_all
  end

  def self.create_permission
    Permission.create_if_not_exists(
      name:        'admin.intake_shield',
      label:       __('IntakeShield'),
      description: __('Manage IntakeShield whitelist and spam user cleanup.'),
      preferences: {
        prio: 1455,
      },
    )

    admin_role = Role.find_by(name: 'Admin')
    return if admin_role.blank?

    admin_role.permission_grant('admin.intake_shield')
  end

  def self.remove_permission
    Permission.find_by(name: 'admin.intake_shield')&.destroy
  end

  def self.create_schedulers
    ensure_scheduler!(
      name:   __('IntakeShield: Apply whitelist role assignments.'),
      method: 'IntakeShield.whitelist_sync',
      period: 1.hour,
    )
    ensure_scheduler!(
      name:   __('IntakeShield: Scan for spam users.'),
      method: 'IntakeShield.cleanup_scan',
      period: 1.hour,
    )
    ensure_scheduler!(
      name:   __('IntakeShield: Execute pending deletions.'),
      method: 'IntakeShield.execute_pending_deletions',
      period: 30.minutes,
    )
    ensure_scheduler!(
      name:   __('IntakeShield: Scan for spam tickets.'),
      method: 'IntakeShield.cleanup_ticket_scan',
      period: 1.hour,
    )
    ensure_scheduler!(
      name:   __('IntakeShield: Execute pending ticket deletions.'),
      method: 'IntakeShield.execute_pending_tickets',
      period: 30.minutes,
    )
  end

  # create_if_not_exists alone leaves existing inactive schedulers inactive
  # after reinstall/upgrade — always (re)assert active + period.
  def self.ensure_scheduler!(name:, method:, period:)
    Scheduler.create_if_not_exists(
      name:          name,
      method:        method,
      period:        period,
      prio:          2,
      active:        true,
      updated_by_id: 1,
      created_by_id: 1,
    )
    scheduler = Scheduler.find_by(method: method)
    return if scheduler.blank?

    attrs = {}
    attrs[:active] = true if !scheduler.active
    attrs[:period] = period if scheduler.period != period
    attrs[:name] = name if scheduler.name != name
    scheduler.update!(attrs) if attrs.present?
  end


  def self.remove_schedulers
    Scheduler.where('method LIKE ?', 'IntakeShield.%').destroy_all
  end

  def self.create_translations
    load File.expand_path('support/de_translations.rb', __dir__)
    IntakeShieldDeTranslations.apply!
  end
end
