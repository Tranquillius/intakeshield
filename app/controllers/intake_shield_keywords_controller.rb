class IntakeShieldKeywordsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    model_index_render(IntakeShield::Keyword, params)
  end

  def show
    model_show_render(IntakeShield::Keyword, params)
  end

  def create
    model_create_render(IntakeShield::Keyword, params)
  end

  def update
    model_update_render(IntakeShield::Keyword, params)
  end

  def destroy
    model_destroy_render(IntakeShield::Keyword, params)
  end
end
