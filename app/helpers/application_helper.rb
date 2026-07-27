module ApplicationHelper
  def page_title
    content_for?(:title) ? content_for(:title) : "PrintLyrics | Clean, printable lyrics"
  end

  def page_description
    if content_for?(:description)
      content_for(:description)
    else
      "Find lyrics by song or artist and create clean, printable lyric sheets."
    end
  end

  def canonical_url
    content_for?(:canonical_url) ? content_for(:canonical_url) : request.base_url + request.path
  end

  def song_duration(seconds)
    minutes, remainder = seconds.to_i.divmod(60)
    "#{minutes}:#{remainder.to_s.rjust(2, "0")}"
  end
end
