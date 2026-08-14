# Shared score-weights JSON parser for package migrations.
module IntakeShieldParseWeights
  module_function

  def call(value)
    IntakeShield::Scorer.score_weights
  rescue NameError
    parsed = case value
             when Hash
               value
             when String
               JSON.parse(value.presence || '{}')
             else
               {}
             end
    parsed.is_a?(Hash) ? parsed.stringify_keys : {}
  rescue JSON::ParserError, TypeError
    {}
  end
end
