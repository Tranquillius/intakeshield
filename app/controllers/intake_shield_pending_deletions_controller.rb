class IntakeShieldPendingDeletionsController < IntakeShieldPendingBaseController
  def whitelist
    pending_deletion = pending_scope.find(params[:id])
    user = pending_deletion.user

    if user.present? && user.email.present?
      IntakeShield::Whitelist.create_if_not_exists(
        pattern:       user.email.downcase,
        note:          __('Added from pending deletions'),
        active:        true,
        created_by_id: current_user.id,
        updated_by_id: current_user.id,
      )
    end
    pending_deletion.cancel!("whitelisted by #{current_user.login}")

    render json: { success: true }, status: :ok
  end

  private

  def before_index
    IntakeShield.cancel_pending_for_whitelisted
  end

  def pending_model
    IntakeShield::PendingDeletion
  end

  def pending_scope
    pending_model.pending.includes(:user)
  end

  def failed_scope
    pending_model.failed.includes(:user)
  end

  def run_scan
    IntakeShield.cleanup_scan
  end

  def execute_now!(record)
    IntakeShield.execute_now!(record)
  end

  def execute_all_label
    'deletion'
  end

  def serialize_records(scope)
    scope.map do |pending_deletion|
      user = pending_deletion.user
      {
        id:         pending_deletion.id,
        state:      pending_deletion.state,
        score:      pending_deletion.score,
        reasons:    pending_deletion.reasons || [],
        execute_at: pending_deletion.execute_at,
        created_at: pending_deletion.created_at,
        user:       user && {
          id:            user.id,
          firstname:     user.firstname,
          lastname:      user.lastname,
          email:         user.email,
          created_at:    user.created_at,
          tickets_count: user.customer_tickets.count,
        },
      }
    end
  end
end
