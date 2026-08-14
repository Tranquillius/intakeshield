class Controllers::IntakeShieldKeywordsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit!('admin.intake_shield')
end
