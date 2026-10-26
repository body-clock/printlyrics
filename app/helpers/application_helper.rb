module ApplicationHelper
  def app_version
    Rails.configuration.x.app_version
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

  # The mark a printed sheet carries sends a scan to the site rather than to the
  # sheet it was printed from, tagged with the campaign value that makes the
  # visit readable as one that came off paper. Built here rather than in the
  # partial so the address and the code travel together, and so the markup holds
  # no address of its own: only the modules do.
  def sheet_mark_svg
    mark = SheetMark.new(root_url(utm_source: SheetMark::SOURCE))

    content_tag(
      :svg,
      mark.path.html_safe,
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 #{mark.extent} #{mark.extent}",
      aria: { hidden: "true" }
    )
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

  # Outcomes the server recorded for the page that follows. Reading clears them
  # so a reload does not report the same account creation or save again; the
  # response key covers a Turbo snapshot of this same page. A marker written by
  # the previous deploy has no properties, so a bare key still renders.
  def take_page_responses
    responses = session.delete(:analytics_page_responses)
    return {} unless responses.is_a?(Hash)

    responses.transform_values do |value|
      value.is_a?(Hash) ? value : { "key" => value, "props" => {} }
    end
  end

  def google_sign_in_available?
    GoogleSignIn.configured?
  end

  def password_hint
    t("accounts.password_hint", count: User::PASSWORD_MINIMUM_LENGTH)
  end

  def pending_save_item
    return @pending_save_item if defined?(@pending_save_item)

    pending = session[PendingSave::SESSION_KEY]
    @pending_save_item = if pending.is_a?(Hash)
      SavedItem.item_class(pending["item_type"])&.active&.find_by(token: pending["token"])
    end
  end

  def field_feedback_attributes(record, attribute, hint: nil)
    error_id = "#{record.model_name.param_key}_#{attribute}_error" if record.errors[attribute].any?
    {
      aria: {
        invalid: record.errors[attribute].any? ? "true" : nil,
        describedby: [ hint, error_id ].compact.join(" ").presence
      }
    }
  end

  # A songbook has no title of its own. The library names it by its first song,
  # which is what the owner recognizes, and says how many sheets sit behind it.
  def saved_songbook_title(songbook)
    first_entry = songbook.entries.first
    return t("accounts.library.untitled_songbook") unless first_entry

    t("accounts.library.songbook_title",
      title: lyric_title(first_entry.lyric),
      count: songbook.entries.size)
  end

  def saved_item_kind(saved_item)
    t("accounts.library.kinds.#{saved_item.item_type.underscore}")
  end

  def saved_item_title(saved_item)
    item = saved_item.item
    item.is_a?(Songbook) ? saved_songbook_title(item) : lyric_title(item)
  end
end
