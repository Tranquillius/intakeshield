# Self-hosted ALTCHA proof-of-work. Challenges are HMAC-signed with Zammad's
# application secret so no form data leaves the instance.
class IntakeShield::Captcha::Altcha
  ALGORITHM      = 'SHA-256'.freeze
  MAX_NUMBER     = 50_000
  CHALLENGE_TTL  = 1.hour
  RESPONSE_FIELD = 'altcha'.freeze
  SCRIPT_BASENAME = 'altcha.min.js'.freeze

  def self.script_file
    [
      Rails.root.join('public/intake_shield', SCRIPT_BASENAME),
      File.expand_path('../../../../../public/intake_shield/' + SCRIPT_BASENAME, __FILE__),
    ].find { |path| File.file?(path.to_s) }
  end

  def frontend_config
    {
      provider:       'altcha',
      type:           'altcha',
      script_url:     script_url,
      module:         false,
      response_field: RESPONSE_FIELD,
      challenge_url:  challenge_url,
    }
  end

  def challenge
    salt = "#{SecureRandom.hex(12)}?expires=#{(Time.zone.now + CHALLENGE_TTL).to_i}"
    number = SecureRandom.random_number(MAX_NUMBER)
    digest = hash_challenge(salt, number)

    {
      algorithm: ALGORITHM,
      challenge: digest,
      maxnumber: MAX_NUMBER,
      salt:      salt,
      signature: sign(digest),
    }
  end

  def verify(params)
    payload = decode_payload(param_value(params, RESPONSE_FIELD))
    return false if payload.nil?

    valid_payload?(payload) &&
      !expired?(payload['salt']) &&
      valid_solution?(payload) &&
      valid_signature?(payload['challenge'], payload['signature']) &&
      !replay?(payload['signature'])
  end

  private

  def challenge_url
    "#{Rails.configuration.api_path}/intake_shield/captcha_challenge"
  end

  def script_url
    "#{Rails.configuration.api_path}/intake_shield/captcha_script"
  end

  def hash_challenge(salt, number)
    Digest::SHA256.hexdigest("#{salt}#{number}")
  end

  def sign(challenge)
    OpenSSL::HMAC.hexdigest('SHA256', Setting.get('application_secret').to_s, challenge)
  end

  def decode_payload(value)
    if value.blank?
      IntakeShield.logger.info 'Signup captcha rejected (missing ALTCHA payload).'
      return
    end

    JSON.parse(Base64.decode64(value.to_s))
  rescue JSON::ParserError, ArgumentError
    IntakeShield.logger.info 'Signup captcha rejected (malformed ALTCHA payload).'
    nil
  end

  def valid_payload?(payload)
    if payload.is_a?(Hash) && payload['algorithm'] == ALGORITHM && payload['salt'].present? && payload['challenge'].present? && payload['signature'].present?
      return true
    end

    IntakeShield.logger.info 'Signup captcha rejected (incomplete ALTCHA payload).'
    false
  end

  def expired?(salt)
    expires = salt.to_s[%r{expires=(\d+)}, 1]
    return false if expires.blank?
    return false if Time.zone.now.to_i <= expires.to_i

    IntakeShield.logger.info 'Signup captcha rejected (expired ALTCHA challenge).'
    true
  end

  def valid_solution?(payload)
    expected = hash_challenge(payload['salt'], payload['number'])
    return true if ActiveSupport::SecurityUtils.secure_compare(expected, payload['challenge'].to_s)

    IntakeShield.logger.info 'Signup captcha rejected (invalid ALTCHA solution).'
    false
  end

  def valid_signature?(challenge, signature)
    return true if ActiveSupport::SecurityUtils.secure_compare(sign(challenge), signature.to_s)

    IntakeShield.logger.info 'Signup captcha rejected (invalid ALTCHA signature).'
    false
  end

  def replay?(signature)
    cache_key = "intake_shield/altcha/#{signature}"
    return false if Rails.cache.write(cache_key, true, expires_in: CHALLENGE_TTL, unless_exist: true)

    IntakeShield.logger.info 'Signup captcha rejected (ALTCHA solution reused).'
    true
  end

  def param_value(params, key)
    return if params.blank?

    value = params[key] || params[key.to_s] || params[key.to_sym]
    value = value.find(&:present?) if value.is_a?(Array)
    value
  end
end
