class Controllers::IntakeShieldPendingTicketsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit!('admin.intake_shield')
end
