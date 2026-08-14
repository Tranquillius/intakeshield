class IntakeShield::PendingDeletion < ApplicationModel
  include IntakeShield::PendingRecord

  self.table_name = 'intake_shield_pending_deletions'

  belongs_to :user, optional: true

  validate :no_other_pending_entry, on: :create

  # Any existing entry (independent of the state) blocks re-scheduling,
  # so manually cancelled users are never picked up again automatically.
  def self.exists_for?(user)
    exists?(user_id: user.id)
  end

  def self.pending_foreign_key
    :user_id
  end

  def self.schedule!(user:, score:, reasons:, execute_at:)
    super(user: user, score: score, reasons: reasons, execute_at: execute_at)
  end

  def clear_target_on_cancel?
    false
  end

  private

  def no_other_pending_entry
    return if !self.class.pending.where(user_id: user_id).exists?

    errors.add(:user_id, 'already has a pending deletion')
  end
end
