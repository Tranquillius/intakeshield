class Controllers::IntakeShieldCaptchaControllerPolicy < Controllers::ApplicationControllerPolicy
  USER_REQUIRED = false

  def configuration?
    true
  end

  def challenge?
    true
  end

  def script?
    true
  end
end
