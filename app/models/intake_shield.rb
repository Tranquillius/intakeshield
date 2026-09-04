module IntakeShield
  def self.table_name_prefix
    'intake_shield_'
  end

  def self.logger
    IntakeShield::Logger.instance
  end

  # Freemail providers that must never count as disposable (scoring + auto-learn).
  # Mail infrastructure and government domains live in IntakeShield::NeverDisposable.
  AUTO_LEARN_SKIP_DOMAINS = %w[
    gmail.com
    googlemail.com
    outlook.com
    hotmail.com
    live.com
    msn.com
    yahoo.com
    yahoo.de
    icloud.com
    me.com
    mac.com
    aol.com
    gmx.de
    gmx.net
    gmx.com
    web.de
    t-online.de
    freenet.de
    mail.de
    posteo.de
    protonmail.com
    proton.me
  ].freeze

  class << self
    def active?
      truthy?(Setting.get('intake_shield_active'))
    end

    def whitelisted?(email)
      IntakeShield::Whitelist.matches?(email)
    end

    # How inbound mail from blacklisted domains is handled. Independent of the
    # master switch. Values: off, all, new_only.
    def drop_blacklisted_mail_mode
      value = Setting.get('intake_shield_drop_blacklisted_mail').to_s.strip
      return value if %w[all new_only].include?(value)

      'off'
    end

    def drop_blacklisted_mail?
      drop_blacklisted_mail_mode != 'off'
    end

    # Assigns the configured whitelist role to the given user when the
    # e-mail address matches an active whitelist entry. Optionally removes
    # roles listed in intake_shield_whitelist_remove_role_ids (e.g. "Neu").
    def apply_whitelist_role(user)
      return false if !active?
      return false if user.blank? || user.email.blank?
      return false if !whitelisted?(user.email)

      apply_whitelist_roles_to_user(user)
    end

    # Periodically re-applies the whitelist rules and auto-cancels pending
    # deletions of users that are whitelisted meanwhile.
    def whitelist_sync
      return if !active?

      logger.info 'Starting whitelist sync'
      apply_whitelist_roles
      cancel_pending_for_whitelisted
      logger.info 'Finished whitelist sync'
    end

    # Scans deletion candidates and schedules them with the configured delay.
    def cleanup_scan
      stats = empty_scan_stats
      return stats.merge(error: 'inactive') if !active?

      role = prepare_scan_stats!(stats)
      return stats if stats[:error]

      logger.info "Starting cleanup scan (role=#{role&.name}, mode=#{stats[:scan_mode]}, scoring=#{scoring_enabled?}, threshold=#{score_threshold})"
      cancel_pending_for_whitelisted
      each_scan_candidate do |user, user_spam_tag_mode|
        stats[:considered] += 1
        scan_user(user, role, stats, spam_tag_mode: user_spam_tag_mode)
      rescue => e
        stats[:errors] += 1
        logger.error "Scan failed for user ##{user.id}: #{e.message}"
      end
      logger.info "Finished cleanup scan (#{stats.inspect})"
      stats
    end

    # Adds the user's e-mail host to the blacklist. When the master switch is
    # on, matching accounts are scanned with the same rules as cleanup_scan.
    def mark_spam_domain_from_user!(user, by:)
      return mark_spam_error('user_not_found') if user.blank?
      return mark_spam_error('system_user') if user.id == 1
      return mark_spam_error('no_email') if user.email.blank?
      return mark_spam_error('privileged') if privileged_user?(user)

      domain = user_email_domain(user)
      return mark_spam_error('no_email') if domain.blank?
      return mark_spam_error('never_disposable', domain: domain) if IntakeShield::NeverDisposable.domain?(domain)

      normalized = IntakeShield::Blacklist.normalize_pattern_value(domain)
      existing = IntakeShield::Blacklist.find_by(['LOWER(pattern) = ?', normalized])
      already_listed = existing&.active? || false

      entry = IntakeShield::Blacklist.remember_domain!(
        domain,
        note:       format(__('Manually marked as spam by %s'), by.respond_to?(:login) ? by.login : by.to_s),
        by:         by,
        reactivate: true,
      )
      if !already_listed && entry.blank?
        return mark_spam_error('never_disposable', domain: domain)
      end

      actor_login = by.respond_to?(:login) ? by.login : by.to_s
      if already_listed
        logger.info "Blacklist domain '#{domain}' already listed (manual mark by #{actor_login} for user ##{user.id})"
      else
        logger.info "Blacklisted domain '#{domain}' from user ##{user.id} (#{user.email}) by #{actor_login}"
      end

      scan_scheduled = false
      scan_stats = nil
      if active?
        scan_stats = cleanup_scan_for_domain(domain)
        scan_scheduled = true
      end

      {
        success:         true,
        domain:          domain,
        blacklist_added: !already_listed,
        already_listed:  already_listed,
        scan_scheduled:  scan_scheduled,
        scan_stats:      scan_stats,
      }
    end

    # Immediately creates the data privacy task for a pending deletion.
    def execute_now!(pending_deletion)
      raise ArgumentError, 'pending deletion required' if pending_deletion.blank?
      raise ArgumentError, 'not pending' if pending_deletion.state != 'pending'

      execute_pending_deletion(pending_deletion)
      pending_deletion
    end

    # Recalculates execute_at for all pending user/ticket deletions from
    # created_at + current delay_hours (called when the setting changes).
    def reschedule_pending_execute_at!
      hours = delay_hours

      updated = 0
      [
        IntakeShield::PendingDeletion,
        IntakeShield::PendingTicket,
      ].each do |model|
        next if !ActiveRecord::Base.connection.table_exists?(model.table_name)

        model.pending.find_each do |record|
          new_at = record.created_at + hours.hours
          next if record.execute_at.to_i == new_at.to_i

          record.update_columns(execute_at: new_at, updated_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
          updated += 1
        end
      end

      logger.info "Rescheduled #{updated} pending deletion(s) to created_at + #{hours}h"
      updated
    end

    # Scans tickets carrying the configured spam tag and schedules them for
    # ticket-only deletion. Whitelist does not protect tickets. Tickets whose
    # customer is already (or would be) scheduled as a spam user are skipped
    # so the user deletion removes the tickets together with the account.
    def cleanup_ticket_scan
      stats = empty_ticket_scan_stats
      return stats.merge(error: 'inactive') if !active?

      tag_name = configured_spam_tag_name
      return stats.merge(error: 'spam_tag_missing') if tag_name.blank?

      stats[:spam_tag] = tag_name
      covered_user_ids = {}
      logger.info "Starting ticket cleanup scan (spam_tag=#{tag_name})"
      spam_tagged_ticket_ids.each do |ticket_id|
        stats[:considered] += 1
        scan_ticket(ticket_id, stats, covered_user_ids: covered_user_ids)
      rescue => e
        stats[:errors] += 1
        logger.error "Ticket scan failed for ticket ##{ticket_id}: #{e.message}"
      end
      logger.info "Finished ticket cleanup scan (#{stats.inspect})"
      stats
    end

    def execute_pending_tickets
      execute_due_records(IntakeShield::PendingTicket, :execute_pending_ticket, 'ticket')
    end

    def execute_ticket_now!(pending_ticket)
      raise ArgumentError, 'pending ticket required' if pending_ticket.blank?
      raise ArgumentError, 'not pending' if pending_ticket.state != 'pending'

      execute_pending_ticket(pending_ticket)
      pending_ticket
    end

    def execute_pending_deletions
      execute_due_records(IntakeShield::PendingDeletion, :execute_pending_deletion, 'deletion')
    end

    # Shared Tag::Item lookup for the configured spam tag.
    def spam_tag_item
      tag_name = configured_spam_tag_name
      return if tag_name.blank?

      Tag::Item.find_by(name_downcase: tag_name.downcase) || Tag::Item.lookup(name: tag_name)
    end

    # Drops pending deletions whose users are (now) whitelisted.
    def cancel_pending_for_whitelisted
      IntakeShield::PendingDeletion.pending.includes(:user).find_each do |pending_deletion|
        next if pending_deletion.user.blank?
        next if !whitelisted?(pending_deletion.user.email)

        pending_deletion.cancel!('whitelisted')
        logger.info "Cancelled pending deletion ##{pending_deletion.id} (user whitelisted)"
      end
    end

    # Console helper: IntakeShield.diagnose_user(8348)
    def diagnose_user(user_or_id)
      user = user_or_id.is_a?(User) ? user_or_id : User.find_by(id: user_or_id)
      return { error: 'user_not_found' } if user.blank?

      role = candidate_role
      in_spam_tag_pass = prefer_spam_tag_user_scan? && spam_tagged_customer_ids.include?(user.id)
      in_spam_engine_pass = prefer_spam_engine_user_scan? && IntakeShield::SpamEngine.customer_ids.include?(user.id)
      skip = deletion_skip_reason(user, role, spam_tag_mode: in_spam_tag_pass || in_spam_engine_pass)
      score_result = scoring_enabled? ? IntakeShield::Scorer.new(user).result : nil
      domain = user.email.to_s.split('@', 2).last.to_s.downcase

      {
        user_id:                       user.id,
        email:                         user.email,
        domain:                        domain,
        active:                        active?,
        drop_blacklisted_mail:         drop_blacklisted_mail_mode,
        spam_engine:                   IntakeShield::SpamEngine.mode,
        created_at:                    user.created_at,
        min_age_days:                  min_age_days,
        max_age_days:                  max_age_days,
        max_ticket_count:              max_ticket_count,
        scoring_enabled:               scoring_enabled?,
        score_threshold:               score_threshold,
        candidate_role:                role&.name,
        user_roles:                    Role.where(id: user.role_ids).pluck(:name),
        has_candidate_role:            role.present? && user.role_ids.include?(role.id),
        ticket_count:                  user.customer_tickets.count,
        blacklisted:                   blacklisted_user?(user),
        never_disposable:              IntakeShield::NeverDisposable.domain?(domain),
        blacklist_patterns:            IntakeShield::Blacklist.active.order(:pattern).pluck(:pattern),
        whitelisted:                   whitelisted?(user.email),
        whitelist_patterns:            IntakeShield::Whitelist.active.order(:pattern).pluck(:pattern),
        privileged:                    privileged_user?(user),
        prefer_spam_tag_scan:          prefer_spam_tag_user_scan?,
        prefer_spam_engine_scan:       prefer_spam_engine_user_scan?,
        prefer_disposable_domain_scan: prefer_disposable_domain_scan?,
        disposable_domain_relaxed:     disposable_domain_relaxed?(user),
        in_spam_tag_pass:              in_spam_tag_pass,
        in_spam_engine_pass:           in_spam_engine_pass,
        skip_reason:                   skip,
        score:                         score_result&.score,
        score_reasons:                 score_result&.reasons,
        pending_deletion:              IntakeShield::PendingDeletion.exists_for?(user),
        pending_user_deletion:         pending_user_deletion?(user),
        covers_ticket_deletion:        user_deletion_covers_ticket?(user, spam_tag_mode: in_spam_tag_pass || in_spam_engine_pass),
        would_schedule:                skip.nil? && !IntakeShield::PendingDeletion.exists_for?(user) && (
                                         !scoring_enabled? || (score_result && score_result.score >= score_threshold)
                                       ),
      }
    end

    private

    def mark_spam_error(code, domain: nil)
      {
        success:     false,
        error:       code,
        error_human: mark_spam_error_human(code),
        domain:      domain,
      }
    end

    def mark_spam_error_human(code)
      case code
      when 'user_not_found'
        __('User could not be found.')
      when 'system_user'
        __('The system user cannot be marked as spam.')
      when 'no_email'
        __('This user has no e-mail address.')
      when 'privileged'
        __('Agents and admins cannot be marked as spam.')
      when 'never_disposable'
        __('This e-mail domain cannot be added to the blacklist.')
      else
        __('Could not mark user as spam.')
      end
    end

    def user_email_domain(user)
      user.email.to_s.split('@', 2).last.to_s.strip.downcase.presence
    end

    def prepare_scan_stats!(stats)
      spam_tag_mode = prefer_spam_tag_user_scan?
      spam_engine_mode = prefer_spam_engine_user_scan?
      blacklist_mode = prefer_disposable_domain_scan?
      role = candidate_role
      if !spam_tag_mode && !spam_engine_mode && !blacklist_mode && role.blank?
        stats[:error] = 'candidate_role_missing'
        return
      end

      relaxed_note = [spam_tag_mode && 'spam_tag', spam_engine_mode && 'spam_engine', blacklist_mode && 'blacklist'].select { |part| part }.join('+')
      stats[:candidate_role] = if relaxed_note.present?
                                 "#{role&.name || '-'} (ignored in #{relaxed_note} mode)"
                               else
                                 role.name
                               end
      stats[:scoring_enabled] = scoring_enabled?
      stats[:score_threshold] = score_threshold
      stats[:min_age_days] = min_age_days
      stats[:max_age_days] = max_age_days
      stats[:max_ticket_count] = max_ticket_count
      stats[:scan_mode] = [spam_tag_mode && 'spam_tag', spam_engine_mode && 'spam_engine', blacklist_mode && 'blacklist', 'full'].select { |part| part }.join('+')
      role
    end

    def cleanup_scan_for_domain(domain)
      stats = empty_scan_stats
      return stats.merge(error: 'inactive') if !active?

      role = prepare_scan_stats!(stats)
      return stats if stats[:error]

      logger.info "Starting domain cleanup scan (domain=#{domain}, role=#{role&.name}, mode=#{stats[:scan_mode]}, scoring=#{scoring_enabled?}, threshold=#{score_threshold})"
      cancel_pending_for_whitelisted
      each_domain_scan_candidate(domain) do |user, user_spam_tag_mode|
        stats[:considered] += 1
        scan_user(user, role, stats, spam_tag_mode: user_spam_tag_mode)
      rescue => e
        stats[:errors] += 1
        logger.error "Scan failed for user ##{user.id}: #{e.message}"
      end
      logger.info "Finished domain cleanup scan (domain=#{domain}, #{stats.inspect})"
      stats
    end

    def each_domain_scan_candidate(domain)
      normalized = IntakeShield::Blacklist.normalize_email_domain(domain)
      return if normalized.blank?

      spam_tag_ids = {}
      if prefer_spam_tag_user_scan?
        spam_tagged_customer_ids.each { |id| spam_tag_ids[id] = true }
      end
      spam_engine_ids = {}
      if prefer_spam_engine_user_scan?
        IntakeShield::SpamEngine.customer_ids.each { |id| spam_engine_ids[id] = true }
      end

      users_matching_email_domain(normalized).includes(:roles).order(:id).find_each do |user|
        spam_tag_mode = spam_tag_ids[user.id] || spam_engine_ids[user.id] || false
        yield user, spam_tag_mode
      end
    end

    def users_matching_email_domain(domain)
      escaped = User.sanitize_sql_like(domain)
      User.where(
        "LOWER(SPLIT_PART(email, '@', 2)) = ? OR LOWER(SPLIT_PART(email, '@', 2)) LIKE ?",
        domain,
        "%.#{escaped}",
      )
    end

    def truthy?(value)
      value == true || value.to_s.strip.casecmp('true').zero? || value.to_s.strip == '1'
    end

    def execute_due_records(model, method_name, label)
      return if !active?

      logger.info "Starting pending #{label} execution"
      model.due.includes(model.pending_foreign_key.to_s.delete_suffix('_id').to_sym).find_each do |record|
        send(method_name, record)
      rescue => e
        logger.error "Execution failed for pending #{label} ##{record.id}: #{e.message}"
        record.update_columns(state: 'failed', updated_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
      end
      logger.info "Finished pending #{label} execution"
    end

    def empty_scan_stats
      {
        considered:             0,
        scheduled:              0,
        skipped_system_user:    0,
        skipped_no_email:       0,
        skipped_whitelisted:    0,
        skipped_role:           0,
        skipped_privileged:     0,
        skipped_too_young:      0,
        skipped_too_old:        0,
        skipped_ticket_count:   0,
        skipped_privacy_task:   0,
        skipped_already_listed: 0,
        skipped_low_score:      0,
        errors:                 0,
      }
    end

    def empty_ticket_scan_stats
      {
        considered:              0,
        scheduled:               0,
        skipped_already_listed:  0,
        skipped_privacy_task:    0,
        skipped_user_deletion:   0,
        errors:                  0,
      }
    end

    def each_scan_candidate
      seen_ids = {}

      if prefer_spam_tag_user_scan?
        ids = spam_tagged_customer_ids
        logger.info "Spam-tag pass targeting #{ids.size} customer(s)"
        User.where(id: ids).includes(:roles).order(:id).find_each do |user|
          seen_ids[user.id] = true
          yield user, true
        end
      end

      if prefer_spam_engine_user_scan?
        ids = IntakeShield::SpamEngine.customer_ids
        logger.info "Spam-engine pass targeting #{ids.size} customer(s)"
        User.where(id: ids).includes(:roles).order(:id).find_each do |user|
          next if seen_ids[user.id]

          seen_ids[user.id] = true
          yield user, true
        end
      end

      logger.info 'Full age-based scan pass'
      scope = User.where('created_at < ?', min_age_days.days.ago)
      scope = scope.where('created_at > ?', max_age_days.days.ago) if max_age_days.positive?
      scope.includes(:roles).order(:id).find_each do |user|
        next if seen_ids[user.id]

        yield user, false
      end
    end

    def prefer_spam_tag_user_scan?
      return false if !scoring_enabled?
      return false if configured_spam_tag_name.blank?

      spam_tag_weight >= score_threshold
    end

    # When spam_engine alone reaches the threshold, engine-stamped senders
    # skip candidate-role and ticket-count filters (like spam-tag mode).
    def prefer_spam_engine_user_scan?
      return false if !scoring_enabled?
      return false if IntakeShield::SpamEngine.mode == 'off'

      spam_engine_weight >= score_threshold
    end

    # When disposable_domain alone reaches the threshold, blacklisted addresses
    # are treated like spam-tag hits: candidate role and ticket-count limits
    # are ignored (whitelist / privileged / age filters still apply).
    def prefer_disposable_domain_scan?
      return false if !scoring_enabled?

      disposable_domain_weight >= score_threshold
    end

    def configured_spam_tag_name
      IntakeShield::Scorer.configured_spam_tag_name
    end

    def spam_tag_weight
      IntakeShield::Scorer.score_weights['spam_tag'].to_i
    end

    def spam_engine_weight
      IntakeShield::Scorer.score_weights['spam_engine'].to_i
    end

    def disposable_domain_weight
      IntakeShield::Scorer.score_weights['disposable_domain'].to_i
    end

    def blacklisted_user?(user)
      return false if user.blank? || user.email.blank?

      domain = user.email.to_s.split('@', 2).last.to_s.downcase
      IntakeShield::Blacklist.includes_domain?(domain)
    end

    def disposable_domain_relaxed?(user)
      prefer_disposable_domain_scan? && blacklisted_user?(user)
    end

    def spam_tagged_customer_ids
      ticket_ids = spam_tagged_ticket_ids
      return [] if ticket_ids.blank?

      Ticket.where(id: ticket_ids).distinct.pluck(:customer_id).compact
    end

    def spam_tagged_ticket_ids
      tag_item = spam_tag_item
      return [] if tag_item.blank?

      tag_object = Tag::Object.lookup(name: 'Ticket')
      return [] if tag_object.blank?

      Tag.where(tag_item_id: tag_item.id, tag_object_id: tag_object.id).distinct.pluck(:o_id)
    end

    def scan_ticket(ticket_id, stats, covered_user_ids: {})
      ticket = Ticket.find_by(id: ticket_id)
      return if ticket.blank?

      if IntakeShield::PendingTicket.exists_for?(ticket)
        stats[:skipped_already_listed] += 1
        return
      end

      if data_privacy_task_running_for?(ticket)
        stats[:skipped_privacy_task] += 1
        return
      end

      customer = ticket.customer
      covered = covered_user_ids.fetch(customer&.id) do
        covered_user_ids[customer&.id] = user_deletion_covers_ticket?(customer)
      end
      if covered
        stats[:skipped_user_deletion] += 1
        logger.info "Skipped ticket ##{ticket.id} (#{ticket.number}): customer ##{customer.id} covered by user deletion"
        return
      end

      weight = spam_tag_weight
      IntakeShield::PendingTicket.schedule!(
        ticket:     ticket,
        score:      weight,
        reasons:    ["#{__('Tagged spam ticket')} (+#{weight})"],
        execute_at: delay_hours.hours.from_now,
      )
      stats[:scheduled] += 1
      logger.info "Scheduled ticket ##{ticket.id} (#{ticket.number}) for deletion (spam tag)"
    end

    def execute_pending_ticket(pending_ticket)
      ticket = pending_ticket.ticket
      return pending_ticket.cancel!('ticket no longer exists') if ticket.blank?
      return pending_ticket.mark_executed! if data_privacy_task_running_for?(ticket)

      customer = ticket.customer
      if user_deletion_covers_ticket?(customer)
        logger.info "Cancelled pending ticket ##{pending_ticket.id} (ticket ##{ticket.id}): customer ##{customer&.id} covered by user deletion"
        return pending_ticket.cancel!('customer scheduled for deletion')
      end

      ticket_id     = ticket.id
      ticket_number = ticket.number
      create_privacy_task!(pending_ticket, ticket)
      logger.info "Created data privacy task for ticket ##{ticket_id} (#{ticket_number}), pending ticket ##{pending_ticket.id}"
    end

    # Ticket-only deletion yields when the customer is already queued for
    # user deletion, a user privacy task is running, or the customer currently
    # qualifies as a spam user (so the later user scan/deletion keeps the
    # tickets attached). Cancelled user entries are not treated as coverage,
    # so ticket-only cleanup can still run.
    def user_deletion_covers_ticket?(user, spam_tag_mode: prefer_spam_tag_user_scan? || prefer_spam_engine_user_scan?)
      return false if user.blank?
      return true if pending_user_deletion?(user)
      return true if data_privacy_task_running_for?(user)
      return false if IntakeShield::PendingDeletion.exists_for?(user)

      qualifies_for_user_deletion?(user, spam_tag_mode: spam_tag_mode)
    end

    def pending_user_deletion?(user)
      return false if user.blank?

      IntakeShield::PendingDeletion.pending.exists?(user_id: user.id)
    rescue ActiveRecord::StatementInvalid, NameError
      false
    end

    def qualifies_for_user_deletion?(user, spam_tag_mode:)
      return false if !active?
      return false if deletion_skip_reason(user, candidate_role, spam_tag_mode: spam_tag_mode)
      return true if !scoring_enabled?

      IntakeShield::Scorer.new(user).result.score >= score_threshold
    end

    def cancel_pending_tickets_for_user!(user)
      return if user.blank?

      ticket_ids = Ticket.where(customer_id: user.id).pluck(:id)
      return if ticket_ids.blank?

      IntakeShield::PendingTicket.pending.where(ticket_id: ticket_ids).find_each do |pending_ticket|
        pending_ticket.cancel!('customer scheduled for deletion')
        logger.info "Cancelled pending ticket ##{pending_ticket.id} (ticket ##{pending_ticket.ticket_id}) because user ##{user.id} is scheduled for deletion"
      end
    rescue ActiveRecord::StatementInvalid, NameError => e
      logger.error "Failed to cancel pending tickets for user ##{user.id}: #{e.message}"
    end

    def data_privacy_task_running_for?(deletable)
      DataPrivacyTask.where(deletable: deletable, state: %w[new in\ process]).exists?
    end

    # Marks the pending row executed (nullifies FK) then enqueues DataPrivacyTask.
    def create_privacy_task!(pending_record, deletable)
      IntakeShield::StaleUiCleanup.call(deletable)
      pending_record.mark_executed!
      DataPrivacyTask.create!(
        deletable:     deletable,
        state:         'in process',
        created_by_id: 1,
        updated_by_id: 1,
      )
    end

    def whitelist_role
      resolve_role(:whitelist_role_id, :whitelist_role_name)
    end

    # Role IDs to drop when applying the whitelist role. Never includes the
    # whitelist role itself, even if misconfigured in settings.
    def whitelist_remove_role_ids
      raw = Setting.get('intake_shield_whitelist_remove_role_ids')
      ids = Array(raw).map { |value| value.to_i }.reject(&:zero?).uniq
      return [] if ids.empty?

      Role.where(id: ids, active: true).pluck(:id)
    end

    # Ensures the whitelist role is present and removes configured roles.
    # Returns true when role membership actually changed. Agents/admins are
    # skipped so hourly sync does not keep forcing Customer onto staff.
    def apply_whitelist_roles_to_user(user)
      role = whitelist_role
      return false if role.blank? || user.blank?
      return false if privileged_user?(user)

      role_id = role.id.to_i
      current_ids = Array(user.role_ids).map(&:to_i).uniq
      new_ids = current_ids.dup

      added = !current_ids.include?(role_id)
      new_ids |= [role_id] if added

      remove_ids = whitelist_remove_role_ids.map(&:to_i) - [role_id]
      removed_ids = new_ids & remove_ids
      new_ids -= removed_ids
      new_ids.uniq!

      return false if new_ids.sort == current_ids.sort

      user.role_ids = new_ids
      persisted = Array(user.role_ids).map(&:to_i).uniq.sort
      return false if persisted == current_ids.sort

      if added && persisted.include?(role_id)
        logger.info "Assigned whitelist role '#{role.name}' to user ##{user.id} (#{user.email})"
      end
      actually_removed = (current_ids - persisted) & remove_ids
      if actually_removed.any?
        names = Role.where(id: actually_removed).pluck(:name)
        logger.info "Removed role(s) #{names.join(', ')} from user ##{user.id} (#{user.email}) after whitelist assignment"
      end
      true
    end

    def candidate_role
      resolve_role(:candidate_role_id, :candidate_role_name)
    end

    def resolve_role(id_key, legacy_name_key)
      role_id = Setting.get("intake_shield_#{id_key}")
      if role_id.present?
        role = Role.find_by(id: role_id, active: true)
        return role if role.present?
      end

      role_name = Setting.get("intake_shield_#{legacy_name_key}")
      Role.find_by(name: role_name.presence || 'Customer', active: true)
    end

    # Integer settings may be 0 (e.g. min_age_days = no minimum, delay_hours =
    # no delay). Do not use .presence — in Rails 0.blank? is true and would
    # wrongly apply the fallback. String "0" is fine either way (.to_i => 0).
    def setting(name, fallback)
      value = Setting.get("intake_shield_#{name}")
      value.nil? ? fallback : value
    end

    def min_age_days
      setting('min_age_days', 14).to_i
    end

    def max_age_days
      setting('max_age_days', 0).to_i
    end

    def max_ticket_count
      setting('max_ticket_count', 2).to_i
    end

    # 0 / "0" = no delay (execute_at immediately due). Negatives clamp to 0.
    def delay_hours
      hours = setting('delay_hours', 72).to_i
      hours.negative? ? 0 : hours
    end

    def scoring_enabled?
      truthy?(Setting.get('intake_shield_scoring_enabled'))
    end

    def score_threshold
      setting('score_threshold', 100).to_i
    end

    def scan_user(user, role, stats, spam_tag_mode: false)
      reason = deletion_skip_reason(user, role, spam_tag_mode: spam_tag_mode)
      if reason
        stats[reason] += 1
        return
      end

      if IntakeShield::PendingDeletion.exists_for?(user)
        stats[:skipped_already_listed] += 1
        return
      end

      execute_at = delay_hours.hours.from_now
      if scoring_enabled?
        result = IntakeShield::Scorer.new(user).result
        if result.score < score_threshold
          stats[:skipped_low_score] += 1
          return
        end

        IntakeShield::PendingDeletion.schedule!(user: user, score: result.score, reasons: result.reasons, execute_at: execute_at)
        cancel_pending_tickets_for_user!(user)
        stats[:scheduled] += 1
        logger.info "Scheduled user ##{user.id} (#{user.email}) for deletion at #{execute_at} (score=#{result.score}, reasons=#{result.reasons.join('; ')})"
      else
        IntakeShield::PendingDeletion.schedule!(user: user, score: 0, reasons: [__('All conditions matched')], execute_at: execute_at)
        cancel_pending_tickets_for_user!(user)
        stats[:scheduled] += 1
        logger.info "Scheduled user ##{user.id} (#{user.email}) for deletion at #{execute_at} (all conditions matched)"
      end
    end

    # Hard filters before scoring. In spam_tag / spam_engine mode (or when a
    # blacklisted domain alone meets the score threshold) the candidate role
    # and ticket-count limits are ignored; admin/agent accounts stay protected.
    def deletion_skip_reason(user, role, spam_tag_mode: prefer_spam_tag_user_scan?)
      return :skipped_system_user if user.id == 1
      return :skipped_no_email if user.email.blank?
      return :skipped_whitelisted if whitelisted?(user.email)
      return :skipped_privileged if privileged_user?(user)
      return :skipped_too_young if user.created_at > min_age_days.days.ago
      return :skipped_too_old if max_age_days.positive? && user.created_at < max_age_days.days.ago
      return :skipped_privacy_task if data_privacy_task_running_for?(user)

      if !spam_tag_mode && !disposable_domain_relaxed?(user)
        return :skipped_role if role.blank? || !user.role_ids.include?(role.id)
        return :skipped_ticket_count if user.customer_tickets.count > max_ticket_count
      end

      nil
    end

    def privileged_user?(user)
      user.permissions?(['admin', 'ticket.agent'])
    end

    def apply_whitelist_roles
      return if whitelist_role.blank?

      IntakeShield::Whitelist.active.find_each do |entry|
        entry.matching_users.find_each do |user|
          apply_whitelist_roles_to_user(user)
        rescue => e
          logger.error "Role assignment failed for user ##{user.id}: #{e.message}"
        end
      end
    end

    def execute_pending_deletion(pending_deletion)
      user = pending_deletion.user
      return pending_deletion.cancel!('user no longer exists') if user.blank?
      return pending_deletion.cancel!('whitelisted') if whitelisted?(user.email)
      return pending_deletion.cancel!('privileged user') if privileged_user?(user)
      return pending_deletion.mark_executed! if data_privacy_task_running_for?(user)

      if !prefer_spam_tag_user_scan? && !prefer_spam_engine_user_scan? && !disposable_domain_relaxed?(user)
        role = candidate_role
        return pending_deletion.cancel!('candidate role missing') if role.blank?
        return pending_deletion.cancel!('roles changed') if !user.role_ids.include?(role.id)
        return pending_deletion.cancel!('ticket count exceeded') if user.customer_tickets.count > max_ticket_count
      end

      email   = user.email
      user_id = user.id
      cancel_pending_tickets_for_user!(user)
      create_privacy_task!(pending_deletion, user)
      remember_disposable_domain_from!(email)
      logger.info "Created data privacy task for user ##{user_id} (#{email}), pending deletion ##{pending_deletion.id}"
    end

    def remember_disposable_domain_from!(email)
      domain = email.to_s.split('@', 2).last.to_s.strip.downcase
      return if domain.blank?

      entry = IntakeShield::Blacklist.remember_domain!(
        domain,
        note: __('Auto-learned from deleted user'),
      )
      return if entry.blank?

      logger.info "Added blacklist domain '#{domain}' from deleted user #{email}"
    rescue => e
      logger.error "Failed to remember blacklist domain from #{email}: #{e.message}"
    end
  end
end
