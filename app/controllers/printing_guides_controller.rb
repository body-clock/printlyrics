class PrintingGuidesController < ApplicationController
  def one_page
    expose_markdown_twin(html_path: print_lyrics_on_one_page_path)
    respond_to do |format|
      format.html
      format.md { render layout: false }
    end
  end

  def songbook
    expose_markdown_twin(html_path: print_a_songbook_path)
    respond_to do |format|
      format.html
      format.md { render layout: false }
    end
  end
end
