class FeedbacksController < ApplicationController
  # Tests replace the verifier through this seam, so no test reaches Cloudflare.
  class_attribute :turnstile_client_factory, default: -> { TurnstileClient.new }

  # The same seam for the sender that reports a stored submission to this site's
  # own analytics service, so no test reaches Umami either.
  class_attribute :umami_client_factory, default: -> { UmamiClient.new }

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
      record_in_analytics(@feedback)
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

  # The submission is stored by the time this runs, so the report is about it
  # rather than part of it: a service that is refusing, unreachable, or slow
  # changes nothing the visitor sees, and the note is read from the table either
  # way. Only a submission that passed the challenge and was saved reaches here,
  # so no refused or unjudged note is ever reported.
  def record_in_analytics(feedback)
    client = umami_client
    return unless client.configured?

    client.record_feedback(
      feedback,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      hostname: request.host
    )
  rescue UmamiClient::ServiceError => error
    Rails.logger.warn("Feedback #{feedback.id} was not recorded in analytics (#{error.message}).")
  end

  def umami_client
    @umami_client ||= self.class.umami_client_factory.call
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
