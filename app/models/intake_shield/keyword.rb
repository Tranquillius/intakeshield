class IntakeShield::Keyword < ApplicationModel
  include HasDefaultModelUserRelations

  self.table_name = 'intake_shield_keywords'

  CACHE_KEY = 'intake_shield/keywords'.freeze

  DEFAULT_KEYWORDS = [
    'penisvergrößerung',
    'potenzmittel',
    'viagra',
    'cialis',
    'treppenlift',
    'hörgerät',
    'zahnersatz',
    'schmerzfrei',
    'gewinnspiel',
    'gratisgeld',
    'kreditanfrage',
    'schuldenfrei',
    'bitcoins',
    'krypto investment',
    'doppelte deine',
    'abnehmpillen',
    'fettverbrenner',
    'faltenfrei',
    'offline treffen',
    'diskrete begegnung',
  ].freeze

  before_validation :normalize_pattern
  after_commit :clear_keyword_cache

  validates :pattern, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }

  # Creates the keywords table when package migrations were skipped or rolled back.
  def self.ensure_table!
    connection = ActiveRecord::Base.connection
    return false if connection.table_exists?(table_name)

    connection.create_table(table_name) do |t|
      t.column :pattern, :string, limit: 255, null: false
      t.column :note, :string, limit: 500, null: true
      t.column :active, :boolean, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.timestamps null: false, limit: 3
    end
    connection.add_index table_name, :pattern, unique: true
    true
  end

  def self.active_keywords
    return [] if !ActiveRecord::Base.connection.table_exists?(table_name)

    Rails.cache.fetch(CACHE_KEY, expires_in: 1.minute) do
      active.order(:pattern).pluck(:pattern)
    end
  end

  # Case-insensitive substring match of any keyword in text.
  def self.matches_text?(text, keywords = active_keywords)
    haystack = text.to_s.downcase
    return false if haystack.blank? || keywords.blank?

    keywords.any? { |keyword| haystack.include?(keyword) }
  end

  def self.seed_defaults!
    ensure_table!

    DEFAULT_KEYWORDS.each do |keyword|
      normalized = normalize_pattern_value(keyword)
      next if normalized.blank?
      next if exists?(['LOWER(pattern) = ?', normalized])

      create!(
        pattern:       normalized,
        note:          __('Default spam keyword'),
        active:        true,
        created_by_id: 1,
        updated_by_id: 1,
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      # ignore duplicates under race / re-seed
    end
  end

  def self.normalize_pattern_value(value)
    value.to_s.strip.downcase.presence || ''
  end

  private

  def normalize_pattern
    self.pattern = self.class.normalize_pattern_value(pattern)
  end

  def clear_keyword_cache
    Rails.cache.delete(CACHE_KEY)
  end
end
