class Controllers::IntakeShieldPendingDeletionsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit!('admin.intake_shield')
end
