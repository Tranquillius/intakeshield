class IntakeShield::PendingTicket < ApplicationModel
  include IntakeShield::PendingRecord

  self.table_name = 'intake_shield_pending_tickets'

  belongs_to :ticket, optional: true

  validate :no_other_pending_entry, on: :create

  # Only an active pending row blocks re-scheduling.
  def self.exists_for?(ticket)
    pending.exists?(ticket_id: ticket.id)
  end

  def self.pending_foreign_key
    :ticket_id
  end

  def self.schedule!(ticket:, score:, reasons:, execute_at:)
    super(ticket: ticket, score: score, reasons: reasons, execute_at: execute_at)
  end

  def clear_target_on_cancel?
    true
  end

  private

  def no_other_pending_entry
    return if !self.class.pending.where(ticket_id: ticket_id).exists?

    errors.add(:ticket_id, 'already has a pending deletion')
  end
end
