# Dedicated IntakeShield logger writing to Zammad's standard log directory:
#   <Rails.root>/log/intakeshield.log
#
# Lives under app/models/intake_shield/ so Zeitwerk owns the IntakeShield
# namespace via app/models/intake_shield.rb (do not define IntakeShield from lib/).
require 'fileutils'

class IntakeShield::Logger
  LOG_FILE = 'intakeshield.log'.freeze

  class << self
    def instance
      @instance ||= build
    end

    def build
      path = Rails.root.join('log', LOG_FILE)
      FileUtils.mkdir_p(File.dirname(path))

      logger = ActiveSupport::Logger.new(path)
      logger.level = rails_log_level
      logger.formatter = ::Logger::Formatter.new
      logger
    end

    def rails_log_level
      return Rails.logger.level if defined?(Rails) && Rails.logger

      ::Logger::INFO
    end
  end
end
