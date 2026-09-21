module ApplicationHelper
  def app_version
    Rails.configuration.x.app_version
  end

  def analytics_campaign_data
    AnalyticsCampaigns.to_json
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

  # Saved pages may carry no title at all, and every surface that lists one
  # needs the same fallback.
  def lyric_title(lyric)
    lyric.title.presence || t("lyrics.show.untitled")
  end
end
