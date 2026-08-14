class Controllers::IntakeShieldWhitelistsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit!('admin.intake_shield')
end
