class FeedbacksController < ApplicationController
  # Tests replace the verifier through this seam, so no test reaches Cloudflare.
  class_attribute :turnstile_client_factory, default: -> { TurnstileClient.new }

  def new
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(feedback_params)

    # Validation runs before the challenge so a half-filled form does not spend
    # the single-use token and make the visitor solve it a second time.
    unless @feedback.valid?
      flash.now[:alert] = @feedback.errors.full_messages.to_sentence
      return render :new, status: :unprocessable_content
    end

    unless verified_human?
      flash.now[:alert] = t("feedbacks.errors.verification")
      return render :new, status: :unprocessable_content
    end

    @feedback.verified = true

    if @feedback.save
      redirect_back_or_to root_path, allow_other_host: false, notice: t("feedbacks.created")
    else
      flash.now[:alert] = @feedback.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  private

  # A declined token, a token minted for another surface or hostname, and a
  # challenge that could not be judged at all all refuse the submission: the
  # note is not stored, so nothing is kept on an unconfirmed pass.
  def verified_human?
    turnstile_client.verify(params["cf-turnstile-response"], remote_ip: request.remote_ip)
  rescue TurnstileClient::ServiceError => error
    Rails.logger.warn("Turnstile verification unavailable (#{error.message}); refusing the submission.")
    false
  end

  def turnstile_client
    @turnstile_client ||= self.class.turnstile_client_factory.call
  end

  def feedback_params
    permitted = params.require(:feedback).permit(:message, :query, :contact_email, :surface)
    # The surface is a label for reading submissions, not a permission, so an
    # unknown value falls back to the page it was sent from instead of failing
    # the visitor's submission.
    permitted[:surface] = "feedback_page" unless Feedback::SURFACES.include?(permitted[:surface])

    permitted
  end
end
