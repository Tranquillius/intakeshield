require 'json'
require 'net/http'
require 'socket'
require 'timeout'
require 'uri'

# Tiny TCP/HTTP clients for local spamd / Rspamd. No gems — Zammad packages
# cannot add Gemfile entries. Fail-open on any transport or parse error.
class IntakeShield::SpamEngine::Client
  class << self
    def check(raw)
      message = raw.to_s
      return if message.blank?

      case IntakeShield::SpamEngine.backend
      when 'rspamd'
        check_rspamd(message)
      else
        check_spamassassin(message)
      end
    rescue => e
      IntakeShield.logger.error "Spam engine live check failed: #{e.class}: #{e.message}"
      nil
    end

    private

    def check_spamassassin(message)
      response = with_timeout do
        Socket.tcp(IntakeShield::SpamEngine.host, IntakeShield::SpamEngine.port, connect_timeout: IntakeShield::SpamEngine.timeout) do |sock|
          payload = +"CHECK SPAMC/1.5\r\nContent-length: #{message.bytesize}\r\n\r\n"
          payload << message
          sock.write(payload)
          sock.close_write
          sock.read
        end
      end
      parse_spamd(response)
    end

    def check_rspamd(message)
      uri = URI::HTTP.build(
        host: IntakeShield::SpamEngine.host,
        port: IntakeShield::SpamEngine.port,
        path: '/checkv2',
      )
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = IntakeShield::SpamEngine.timeout
      http.read_timeout = IntakeShield::SpamEngine.timeout
      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = message
      request['Content-Type'] = 'application/octet-stream'
      password = IntakeShield::SpamEngine.password
      request['Password'] = password if password.present?

      response = with_timeout { http.request(request) }
      return if !response.is_a?(Net::HTTPSuccess)

      parse_rspamd(response.body)
    end

    def parse_spamd(response)
      return if response.blank?

      line = response.to_s.lines.find { |entry| entry.match?(%r{\ASpam:}i) }
      return if line.blank?
      return if !line.match?(%r{\ASpam:\s*True\b}i)

      score = nil
      if line =~ %r{;\s*([+-]?\d+(?:\.\d+)?)\s*/}
        score = $1.to_f
      end

      IntakeShield::SpamEngine::Verdict.new(
        engine: 'spamassassin',
        source: 'live',
        score:  score,
      )
    end

    def parse_rspamd(body)
      parsed = JSON.parse(body.to_s)
      return if !parsed.is_a?(Hash)

      score = parsed['score']
      required = parsed['required_score']
      action = parsed['action'].to_s
      spam = parsed['is_spam'] == true ||
             (score.present? && required.present? && score.to_f >= required.to_f) ||
             ['reject', 'add header', 'rewrite subject'].include?(action)
      return if !spam

      IntakeShield::SpamEngine::Verdict.new(
        engine: 'rspamd',
        source: 'live',
        score:  score.nil? ? nil : score.to_f,
      )
    rescue JSON::ParserError
      nil
    end

    def with_timeout(&block)
      Timeout.timeout(IntakeShield::SpamEngine.timeout, &block)
    end
  end
end
