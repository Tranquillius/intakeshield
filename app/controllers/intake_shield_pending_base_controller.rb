class IntakeShieldPendingBaseController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    before_index
    page, per_page = pagination

    pending = pending_scope.order(:execute_at)
    failed  = failed_scope.reorder(id: :desc).limit(50)

    render json: {
      total_count: pending.count,
      records:     serialize_records(pending.offset((page - 1) * per_page).limit(per_page)),
      failed:      serialize_records(failed),
    }, status: :ok
  end

  def cancel
    record = pending_scope.find(params[:id])
    record.cancel!("manually cancelled by #{current_user.login}")

    render json: { success: true }, status: :ok
  end

  def scan
    stats = run_scan
    pending = pending_scope.order(:execute_at)
    failed  = failed_scope.reorder(id: :desc).limit(50)

    render json: {
      total_count: pending.count,
      records:     serialize_records(pending.limit(150)),
      failed:      serialize_records(failed),
      scan_stats:  stats,
    }, status: :ok
  end

  def execute
    record = pending_scope.find(params[:id])
    execute_now!(record)

    render json: { success: true }, status: :ok
  end

  def execute_all
    executed = 0
    pending_scope.find_each do |record|
      execute_now!(record)
      executed += 1 if record.reload.state == 'executed'
    rescue => e
      Rails.logger.error "IntakeShield #{execute_all_label} execute_all failed for ##{record.id}: #{e.message}"
      IntakeShield.logger.error "#{execute_all_label} execute_all failed for ##{record.id}: #{e.message}"
    end

    render json: { success: true, executed: executed }, status: :ok
  end

  private

  def before_index
    # optional hook
  end

  def pagination
    per_page = (params[:per_page] || 150).to_i.clamp(1, 500)
    page     = [params[:page].to_i, 1].max
    [page, per_page]
  end

  def pending_model
    raise NotImplementedError
  end

  def pending_scope
    raise NotImplementedError
  end

  def failed_scope
    raise NotImplementedError
  end

  def run_scan
    raise NotImplementedError
  end

  def execute_now!(_record)
    raise NotImplementedError
  end

  def execute_all_label
    'pending'
  end

  def serialize_records(_scope)
    raise NotImplementedError
  end
end
