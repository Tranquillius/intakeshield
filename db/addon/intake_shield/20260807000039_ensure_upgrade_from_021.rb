# Abschluss-Migration for upgrades from IntakeShield >= 0.2.21.
# Intermediate migrations 001–035 were consolidated into create_base for
# fresh installs; this migration is idempotent for existing installations.
class EnsureUpgradeFrom021 < ActiveRecord::Migration[7.0]
  def self.up
    ensure_pending_tickets_table!
    ensure_keywords_table!
    ensure_spam_keyword_weight!
    ensure_missing_settings!
    ensure_settings_areas!
    ensure_ticket_schedulers!
    sync_l10n!
  end

  def self.down
    # noop — schema objects may be shared with create_base
  end

  def self.ensure_pending_tickets_table!
    return if table_exists?(:intake_shield_pending_tickets)

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

  def self.ensure_keywords_table!
    return if table_exists?(:intake_shield_keywords)

    create_table :intake_shield_keywords do |t|
      t.column :pattern, :string, limit: 255, null: false
      t.column :note, :string, limit: 500, null: true
      t.column :active, :boolean, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.timestamps null: false, limit: 3
    end
    add_index :intake_shield_keywords, :pattern, unique: true

    return if !defined?(IntakeShield::Keyword)

    IntakeShield::Keyword.seed_defaults!
  rescue StandardError => e
    Rails.logger.error "IntakeShield keyword seed skipped: #{e.class}: #{e.message}"
  end

  def self.ensure_spam_keyword_weight!
    load File.expand_path('support/parse_weights.rb', __dir__)
    weights = IntakeShieldParseWeights.call(Setting.get('intake_shield_score_weights'))
    return if weights.key?('spam_keyword')

    weights['spam_keyword'] = 50
    Setting.set('intake_shield_score_weights', JSON.pretty_generate(weights))
  end

  # Creates settings introduced after the initial create_base migration so
  # upgrades always get them even when an intermediate migration was skipped.
  def self.ensure_missing_settings!
    ensure_whitelist_remove_role_ids_setting!
    ensure_max_age_days_setting!
  end

  def self.ensure_whitelist_remove_role_ids_setting!
    return if Setting.exists?(name: 'intake_shield_whitelist_remove_role_ids')

    Setting.create_if_not_exists(
      title:       __('Roles to Remove on Whitelist'),
      name:        'intake_shield_whitelist_remove_role_ids',
      area:        'IntakeShield::Whitelist',
      description: __('Roles that are removed from a user when the whitelist role is assigned (e.g. a provisional "Neu" role). Leave empty to only add the whitelist role.'),
      options:     {
        form: [
          {
            display:  '',
            null:     true,
            name:     'intake_shield_whitelist_remove_role_ids',
            tag:      'select',
            multiple: true,
            relation: 'Role',
          },
        ],
      },
      preferences: {
        prio:       1110,
        permission: ['admin.intake_shield'],
      },
      state:       [],
      frontend:    false
    )
  end

  def self.ensure_max_age_days_setting!
    return if Setting.exists?(name: 'intake_shield_max_age_days')

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
  end

  def self.ensure_settings_areas!
    {
      'intake_shield_active'                        => 'IntakeShield::Base',
      'intake_shield_whitelist_role_id'             => 'IntakeShield::Whitelist',
      'intake_shield_whitelist_remove_role_ids'     => 'IntakeShield::Whitelist',
      'intake_shield_candidate_role_id'             => 'IntakeShield::Spam',
      'intake_shield_min_age_days'       => 'IntakeShield::Spam',
      'intake_shield_max_age_days'       => 'IntakeShield::Spam',
      'intake_shield_max_ticket_count'   => 'IntakeShield::Spam',
      'intake_shield_delay_hours'        => 'IntakeShield::Spam',
      'intake_shield_scoring_enabled'    => 'IntakeShield::Spam',
      'intake_shield_spam_tag'           => 'IntakeShield::Spam',
      'intake_shield_score_threshold'    => 'IntakeShield::Spam',
      'intake_shield_score_weights'      => 'IntakeShield::Spam',
    }.each do |name, area|
      setting = Setting.find_by(name: name)
      next if setting.blank? || setting.area == area

      setting.update!(area: area)
    end
  end

  def self.ensure_ticket_schedulers!
    ensure_all_schedulers!
  end

  def self.ensure_all_schedulers!
    [
      [__('IntakeShield: Apply whitelist role assignments.'), 'IntakeShield.whitelist_sync', 1.hour],
      [__('IntakeShield: Scan for spam users.'), 'IntakeShield.cleanup_scan', 1.hour],
      [__('IntakeShield: Execute pending deletions.'), 'IntakeShield.execute_pending_deletions', 30.minutes],
      [__('IntakeShield: Scan for spam tickets.'), 'IntakeShield.cleanup_ticket_scan', 1.hour],
      [__('IntakeShield: Execute pending ticket deletions.'), 'IntakeShield.execute_pending_tickets', 30.minutes],
    ].each do |name, method, period|
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
      next if scheduler.blank?

      attrs = {}
      attrs[:active] = true if !scheduler.active
      attrs[:period] = period if scheduler.period != period
      attrs[:name] = name if scheduler.name != name
      scheduler.update!(attrs) if attrs.present?
    end
  end


  def self.sync_l10n!
    load File.expand_path('support/de_translations.rb', __dir__)
    IntakeShieldDeTranslations.apply!
    Rails.cache.clear
  end
end
