# Detects text written mostly in Unicode scripts the admin marked as
# suspicious (e.g. Han/Hiragana/Katakana for Chinese and Japanese spam).
# A text counts when the selected scripts make up at least the configured
# share of its letters. URLs and e-mail addresses are ignored, so links in
# otherwise foreign-script spam do not dilute the ratio.
class IntakeShield::ScriptDetector
  # Setting value => Onigmo script property.
  SCRIPTS = {
    'han'        => 'Han',
    'hiragana'   => 'Hiragana',
    'katakana'   => 'Katakana',
    'hangul'     => 'Hangul',
    'cyrillic'   => 'Cyrillic',
    'greek'      => 'Greek',
    'arabic'     => 'Arabic',
    'hebrew'     => 'Hebrew',
    'thai'       => 'Thai',
    'devanagari' => 'Devanagari',
  }.freeze

  DEFAULT_RATIO = 30
  # Fewer matching characters never count, whatever the ratio (e.g. a single
  # quoted symbol in a short title).
  MIN_CHARS = 3

  LETTER = %r{\p{L}}
  URL_OR_EMAIL = %r{(?:https?://|www\.)\S+|[^\s@<>]+@[^\s@<>]+}i

  class << self
    def configured_scripts
      value = Setting.get('intake_shield_suspicious_scripts')
      list = case value
             when Array
               value
             when String
               stripped = value.strip
               stripped.start_with?('[') ? JSON.parse(stripped) : stripped.split(',')
             else
               []
             end
      Array(list).map { |entry| entry.to_s.strip.downcase }.select { |entry| SCRIPTS.key?(entry) }.uniq
    rescue JSON::ParserError
      []
    end

    def enabled?
      configured_scripts.any?
    end

    # Minimum share (percent) of letters in the selected scripts.
    def min_ratio
      value = Setting.get('intake_shield_suspicious_script_ratio')
      ratio = value.nil? || value.to_s.strip.empty? ? DEFAULT_RATIO : value.to_i
      ratio.clamp(1, 100)
    end

    def suspicious?(text, scripts: configured_scripts, ratio: min_ratio)
      return false if scripts.blank?

      cleaned = text.to_s.gsub(URL_OR_EMAIL, ' ')
      hits = cleaned.scan(pattern(scripts)).size
      return false if hits < MIN_CHARS

      letters = cleaned.scan(LETTER).size
      (hits * 100) >= (ratio * letters)
    end

    # Plain text of an article body; HTML is converted so markup and entities
    # do not count as Latin letters.
    def article_text(article)
      return '' if article.blank?

      body = article.body.to_s
      return body if !article.content_type.to_s.include?('html')
      return body.html2text if body.respond_to?(:html2text)

      body.gsub(%r{<[^>]*>}, ' ')
    end

    private

    def pattern(scripts)
      @patterns ||= {}
      @patterns[scripts.sort.join(',')] ||= Regexp.new(
        "[#{scripts.map { |key| "\\p{#{SCRIPTS.fetch(key)}}" }.join}]"
      )
    end
  end
end
