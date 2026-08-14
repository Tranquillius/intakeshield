class IntakeShieldPendingTicketsController < IntakeShieldPendingBaseController
  private

  def pending_model
    IntakeShield::PendingTicket
  end

  def pending_scope
    pending_model.pending.includes(ticket: :customer)
  end

  def failed_scope
    pending_model.failed.includes(ticket: :customer)
  end

  def run_scan
    IntakeShield.cleanup_ticket_scan
  end

  def execute_now!(record)
    IntakeShield.execute_ticket_now!(record)
  end

  def execute_all_label
    'ticket'
  end

  def serialize_records(scope)
    scope.map do |pending_ticket|
      ticket = pending_ticket.ticket
      customer = ticket&.customer
      {
        id:         pending_ticket.id,
        state:      pending_ticket.state,
        score:      pending_ticket.score,
        reasons:    pending_ticket.reasons || [],
        execute_at: pending_ticket.execute_at,
        created_at: pending_ticket.created_at,
        ticket:     ticket && {
          id:         ticket.id,
          number:     ticket.number,
          title:      ticket.title,
          created_at: ticket.created_at,
          customer:   customer && {
            id:        customer.id,
            firstname: customer.firstname,
            lastname:  customer.lastname,
            email:     customer.email,
          },
        },
      }
    end
  end
end
