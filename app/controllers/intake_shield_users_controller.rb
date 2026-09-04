class IntakeShieldUsersController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def mark_spam
    user = User.find_by(id: params[:id])
    result = IntakeShield.mark_spam_domain_from_user!(user, by: current_user)
    render json: result, status: result[:success] ? :ok : mark_spam_error_status(result[:error])
  end

  private

  def mark_spam_error_status(code)
    code == 'user_not_found' ? :not_found : :unprocessable_entity
  end
end
