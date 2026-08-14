# Drops agent Taskbar tabs and RecentView rows for records about to be
# deleted via DataPrivacyTask, so the classic UI does not reload stale IDs.
module IntakeShield::StaleUiCleanup
  module_function

  def call(deletable)
    user_ids, ticket_ids = collect_ids(deletable)
    return if user_ids.empty? && ticket_ids.empty?

    dropped = 0
    dropped += drop_recent_views(user_ids: user_ids, ticket_ids: ticket_ids)
    dropped += drop_taskbars(user_ids: user_ids, ticket_ids: ticket_ids)
    return if dropped.zero?

    IntakeShield.logger.info "Dropped #{dropped} stale UI reference(s) for #{deletable.class.name} ##{deletable.id}"
  rescue => e
    IntakeShield.logger.error "Failed to drop stale UI references for #{deletable.class.name} ##{deletable.id}: #{e.message}"
  end

  def collect_ids(deletable)
    user_ids = []
    ticket_ids = []

    case deletable
    when User
      user_ids << deletable.id
      ticket_ids.concat(Array(deletable.customer_tickets.pluck(:id))) if deletable.respond_to?(:customer_tickets)
    when Ticket
      ticket_ids << deletable.id
    end

    [user_ids.compact.uniq, ticket_ids.compact.uniq]
  end

  def drop_recent_views(user_ids:, ticket_ids:)
    return 0 if !defined?(RecentView)
    return 0 if RecentView.respond_to?(:table_exists?) && !RecentView.table_exists?

    columns = RecentView.column_names
    count = 0
    if columns.include?('o_id') && columns.include?('object')
      count += RecentView.where(object: 'User', o_id: user_ids).delete_all if user_ids.any?
      count += RecentView.where(object: 'Ticket', o_id: ticket_ids).delete_all if ticket_ids.any?
    elsif columns.include?('recent_viewable_id')
      type_col = columns.include?('recent_viewable_type') ? :recent_viewable_type : :object
      count += RecentView.where(type_col => 'User', recent_viewable_id: user_ids).delete_all if user_ids.any?
      count += RecentView.where(type_col => 'Ticket', recent_viewable_id: ticket_ids).delete_all if ticket_ids.any?
    end
    count
  rescue => e
    IntakeShield.logger.error "Failed to drop RecentView rows: #{e.message}"
    0
  end

  def drop_taskbars(user_ids:, ticket_ids:)
    return 0 if !defined?(Taskbar)
    return 0 if Taskbar.respond_to?(:table_exists?) && !Taskbar.table_exists?

    keys = []
    ticket_ids.each { |id| keys << "Ticket-#{id}" }
    user_ids.each do |id|
      keys << "User-#{id}"
      keys << "UserProfile-#{id}"
    end
    return 0 if keys.empty?

    dropped = 0
    Taskbar.where(key: keys).find_each do |taskbar|
      taskbar.destroy
      dropped += 1
    rescue => e
      IntakeShield.logger.error "Failed to destroy taskbar ##{taskbar.id}: #{e.message}"
    end
    dropped
  rescue => e
    IntakeShield.logger.error "Failed to drop Taskbar rows: #{e.message}"
    0
  end
end
