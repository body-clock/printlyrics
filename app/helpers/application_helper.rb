module ApplicationHelper
  def page_title
    content_for?(:title) ? content_for(:title) : "Print Lyrics for Any Song | PrintLyrics"
  end

  def page_description
    if content_for?(:description)
      content_for(:description)
    else
      "Search by song or artist, customize the layout, and print lyrics for any song on a clean page."
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
