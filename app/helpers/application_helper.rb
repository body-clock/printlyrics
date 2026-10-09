module ApplicationHelper
  def app_version
    Rails.configuration.x.app_version
  end

  def analytics_campaign_data
    AnalyticsCampaigns.to_json
  end

  # The tracker is served from the origin the content security policy allows,
  # and the layout renders it only once the deployment supplies a website ID.
  def umami_script_url
    "#{Rails.configuration.x.umami_origin}/script.js"
  end

  def umami_website_id
    Rails.configuration.x.umami_website_id
  end

  # Nil until the deployment sets TURNSTILE_SITE_KEY; the feedback form renders
  # the widget only when it is present, and the server stores submissions
  # unverified while the matching secret is absent.
  def turnstile_site_key
    Rails.configuration.x.turnstile_site_key
  end

  # The action the widget renders and the server validates; one value, so the
  # two halves cannot drift into rejecting every submission.
  def turnstile_action
    TurnstileClient::ACTION
  end

  # The answers the feedback form offers, in the order the model lists them, so a
  # new one is added in one place. The label is the visitor's words; the value is
  # what the row and the report carry.
  def feedback_reason_options
    Feedback::REASONS.map { |reason| [ t("feedbacks.reasons.#{reason}"), reason ] }
  end

  def page_title
    content_for?(:title) ? content_for(:title) : t("application.meta.default_title")
  end

  def page_description
    if content_for?(:description)
      content_for(:description)
    else
      t("application.meta.default_description")
    end
  end

  def canonical_url
    content_for?(:canonical_url) ? content_for(:canonical_url) : request.base_url + request.path
  end

  def song_duration(seconds)
    minutes, remainder = seconds.to_i.divmod(60)
    "#{minutes}:#{remainder.to_s.rjust(2, "0")}"
  end

  # Where the miss panel sends a visitor the source has nothing for: the song
  # they just typed, at a search engine that will have it, in a new tab so the
  # paste box behind it keeps the query. DuckDuckGo is the privacy-consistent
  # default. The link carries no analytics marker, so no payload gains the URL
  # and the query stays out of every destination; see docs/measurement-contract.md.
  LYRICS_LOOKUP_URL = "https://duckduckgo.com/"

  def lyrics_lookup_url(query)
    "#{LYRICS_LOOKUP_URL}?#{URI.encode_www_form(q: "#{query} lyrics")}"
  end

  # Saved pages may carry no title at all, and every surface that lists one
  # needs the same fallback.
  def lyric_title(lyric)
    lyric.title.presence || t("lyrics.show.untitled")
  end
end
