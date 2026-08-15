# Zammad's EmailParser runs every Postmaster::PreFilter before it honours
# x-zammad-ignore. IdentifySessionUser / IdentifySender would still create
# the sender user. Skip them when a pre-filter already marked the mail ignored.
ActiveSupport::Reloader.to_prepare do
  %w[Channel::Filter::IdentifySessionUser Channel::Filter::IdentifySender].each do |class_name|
    klass = class_name.safe_constantize
    next if klass.blank?
    next if klass.singleton_class.method_defined?(:intake_shield_run_without_ignore_skip)

    klass.singleton_class.class_eval do
      alias_method :intake_shield_run_without_ignore_skip, :run

      def run(*args)
        mail = args[1]
        return if Channel::Filter::IntakeShieldBlacklist.ignored?(mail)

        intake_shield_run_without_ignore_skip(*args)
      end
    end
  end
end
