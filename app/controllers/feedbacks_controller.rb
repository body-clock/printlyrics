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

    verification = turnstile_verification
    if verification == :rejected
      flash.now[:alert] = t("feedbacks.errors.verification")
      return render :new, status: :unprocessable_content
    end

    @feedback.verified = verification == :verified

    if @feedback.save
      redirect_back_or_to root_path, allow_other_host: false, notice: t("feedbacks.created")
    else
      flash.now[:alert] = @feedback.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  private

  def turnstile_verification
    turnstile_client.verify(params["cf-turnstile-response"]) ? :verified : :rejected
  rescue TurnstileClient::ServiceError => error
    # The challenge could not be judged, so the submission is kept unverified
    # rather than thrown away: losing a real reply costs more than keeping a
    # doubtful one.
    Rails.logger.warn("Turnstile verification unavailable (#{error.message}); storing feedback unverified.")
    :unavailable
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
