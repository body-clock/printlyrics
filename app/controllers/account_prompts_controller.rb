class AccountPromptsController < ApplicationController
  SURFACES = %w[sheet songbook].freeze

  def destroy
    surface = params[:surface].to_s
    session[:account_prompt_dismissed] = true

    props = SURFACES.include?(surface) ? { account_prompt_surface: surface } : {}
    remember_page_response("Account Prompt Dismissed", **props)

    redirect_back_or_to root_path, allow_other_host: false
  end
end
