module ApplicationHelper
  def page_title
    content_for?(:title) ? content_for(:title) : "PrintLyrics | Clean, printable lyrics"
  end

  def page_description
    if content_for?(:description)
      content_for(:description)
    else
      "Create clean, printable lyric sheets from pasted lyrics or a Genius or AZLyrics URL."
    end
  end

  def canonical_url
    content_for?(:canonical_url) ? content_for(:canonical_url) : request.base_url + request.path
  end
end
