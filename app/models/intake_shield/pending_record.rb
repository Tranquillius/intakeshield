# Shared behaviour for pending user/ticket deletion rows.
module IntakeShield::PendingRecord
  extend ActiveSupport::Concern

  STATES = %w[pending cancelled executed failed].freeze

  included do
    include HasDefaultModelUserRelations

    serialize :reasons, coder: JSON

    validates :state, inclusion: { in: STATES }

    scope :pending, -> { where(state: 'pending') }
    scope :failed, -> { where(state: 'failed') }
    scope :due, -> { pending.where(execute_at: ..Time.zone.now) }
  end

  class_methods do
    def schedule!(attrs)
      create!(
        attrs.merge(
          state:         'pending',
          created_by_id: 1,
          updated_by_id: 1,
        )
      )
    end
  end

  def cancel!(reason = nil)
    self.reasons = (reasons || []) + ["cancelled: #{reason}"] if reason.present?
    attrs = { state: 'cancelled' }
    attrs[foreign_key] = nil if respond_to?(:clear_target_on_cancel?) && clear_target_on_cancel?
    update!(attrs)
  end

  def mark_executed!
    update!(state: 'executed', foreign_key => nil)
  end

  private

  def foreign_key
    self.class.pending_foreign_key
  end
end
