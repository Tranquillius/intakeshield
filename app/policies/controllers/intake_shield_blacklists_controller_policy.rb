class Controllers::IntakeShieldBlacklistsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit!('admin.intake_shield')
end
