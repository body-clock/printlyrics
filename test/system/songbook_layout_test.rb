require "application_system_test_case"

class SongbookLayoutTest < ApplicationSystemTestCase
  test "each song keeps its own size and columns" do
    first, second, songbook = songbook_with_two_songs

    visit songbook_path(songbook)
    wait_for_preview_render

    within(".song-format-dock") do
      find("[data-preview-layout='size'] [data-preview-value='xl']").click
      find("[data-preview-layout='columns'] [data-preview-value='2']").click
    end

    assert_selector ".paper[data-preview-song-token='#{first.token}'] .lyrics.cols-2"
    first_paper = find(".paper[data-preview-song-token='#{first.token}']")
    assert_equal "paper size-xl", first_paper[:class]
    assert_equal 2, first_paper.all(".lyric-column").length

    second_paper = find(".paper[data-preview-song-token='#{second.token}']")
    assert_equal "paper size-m", second_paper[:class]
    assert_equal 1, second_paper.all(".lyric-column").length

    wait_for_entry_layout(first, size: "xl", columns: 2)
    wait_for_entry_layout(second, size: "m", columns: 1)

    # The set is the same on the next visit because the entry holds the choice,
    # not the tab that made it.
    visit songbook_path(songbook)
    wait_for_preview_render

    assert_equal "paper size-xl", find(".paper[data-preview-song-token='#{first.token}']")[:class]
    assert_equal "paper size-m", find(".paper[data-preview-song-token='#{second.token}']")[:class]

    within(".song-format-dock") do
      assert_selector "[data-preview-layout='size'] [data-preview-value='xl'][aria-pressed='true']"
      assert_selector "[data-preview-layout='columns'] [data-preview-value='2'][aria-pressed='true']"
    end
  end

  test "a sheet carries its format into the songbook it starts" do
    lyric = Lyric.create!(lyrics: "A line to print", title: "Starting Song")

    visit lyric_path(lyric)
    wait_for_preview_render

    find("[data-preview-layout='size'] [data-preview-value='xl']").click
    find("[data-preview-layout='columns'] [data-preview-value='2']").click
    click_button "Add another song"
    assert_text "Adding to a songbook with 1 song"

    entry = SongbookEntry.find_by!(lyric: lyric)
    assert_equal [ "xl", 2 ], [ entry.size, entry.columns ]
  end

  test "the format dock follows the song being read" do
    first, second, songbook = songbook_with_two_songs

    visit songbook_path(songbook)
    wait_for_preview_render

    assert_selector ".song-format-dock-title", text: "First Song"
    open_outline
    assert_selector ".songbook-track.is-current", text: "First Song"
    assert_selector ".song-format-dock-all[href='#songbook-format']"

    scroll_to_song(second)
    assert_selector ".song-format-dock-title", text: "Second Song"
    assert_selector ".songbook-track.is-current", text: "Second Song"

    within(".song-format-dock") do
      find("[data-preview-layout='size'] [data-preview-value='l']").click
      find("[data-preview-layout='columns'] [data-preview-value='2']").click
    end
    assert_selector ".paper[data-preview-song-token='#{second.token}'].size-l .lyrics.cols-2"

    second_paper = find(".paper[data-preview-song-token='#{second.token}']")
    assert_equal "paper size-l", second_paper[:class]
    assert_equal 2, second_paper.all(".lyric-column").length
    assert_equal "paper size-m", find(".paper[data-preview-song-token='#{first.token}']")[:class]

    wait_for_entry_layout(first, size: "m", columns: 1)
    wait_for_entry_layout(second, size: "l", columns: 2)

    # The dock reads the entry's saved layout after the next load too.
    visit songbook_path(songbook)
    wait_for_preview_render
    open_format
    scroll_to_song(second)
    assert_selector ".song-format-dock-title", text: "Second Song"

    within(".song-format-dock") do
      assert_selector "[data-preview-layout='size'] [data-preview-value='l'][aria-pressed='true']"
      assert_selector "[data-preview-layout='columns'] [data-preview-value='2'][aria-pressed='true']"
    end
  end

  test "the binder card jumps to its song" do
    _first, second, songbook = songbook_with_two_songs

    visit songbook_path(songbook)
    wait_for_preview_render
    open_outline

    within(all(".songbook-track").last) do
      find(".songbook-track-link").click
    end

    open_format
    assert_selector ".song-format-dock-title", text: "Second Song"
    assert_selector ".songbook-track.is-current", text: "Second Song", visible: :all
  end

  test "a bulk size leaves a per-song column choice alone" do
    first, second, songbook = songbook_with_two_songs
    songbook.entries.find_by!(lyric: first).update!(columns: 2)

    visit songbook_path(songbook)
    wait_for_preview_render

    within("#songbook-format") do
      find("[data-preview-layout='size'] [data-preview-value='s']").click
    end

    wait_for_entry_layout(first, size: "s", columns: 2)
    wait_for_entry_layout(second, size: "s", columns: 1)

    visit songbook_path(songbook)
    wait_for_preview_render

    assert_equal 2, find(".paper[data-preview-song-token='#{first.token}']").all(".lyric-column").length
    assert_equal 1, find(".paper[data-preview-song-token='#{second.token}']").all(".lyric-column").length
  end

  test "the set controls apply one layout to every song" do
    first, second, songbook = songbook_with_two_songs

    visit songbook_path(songbook)
    wait_for_preview_render

    within("#songbook-format") do
      find("[data-preview-layout='size'] [data-preview-value='s']").click
      find("[data-preview-layout='columns'] [data-preview-value='2']").click
    end

    assert_selector ".paper.size-s .lyrics.cols-2", count: 2

    wait_for_entry_layout(first, size: "s", columns: 2)
    wait_for_entry_layout(second, size: "s", columns: 2)

    visit songbook_path(songbook)
    wait_for_preview_render

    assert_selector ".paper.size-s .lyrics.cols-2", count: 2
    within("#songbook-format") do
      assert_selector "[data-preview-layout='size'] [data-preview-value='s'][aria-pressed='true']"
      assert_selector "[data-preview-layout='columns'] [data-preview-value='2'][aria-pressed='true']"
    end
  end

  private

  def songbook_with_two_songs
    first = Lyric.create!(lyrics: "First song line", title: "First Song")
    second = Lyric.create!(lyrics: "Second song line", title: "Second Song")

    [ first, second, Songbook.start_with(first, second) ]
  end

  # The server renders the sources; the preview controller replaces them with
  # measured sheets. Waiting for the unpaginated source to leave means the
  # controls are connected before the test starts clicking them.
  def wait_for_preview_render
    assert_no_selector "[data-preview-page].is-unpaginated"
    open_format
  end

  def scroll_to_song(lyric)
    page.execute_script(<<~JS)
      document.querySelector(".paper[data-preview-song-token='#{lyric.token}']")
        .scrollIntoView({ block: "center" })
    JS
  end

  def wait_for_entry_layout(lyric, size:, columns:)
    deadline = Time.now + Capybara.default_max_wait_time

    loop do
      entry = SongbookEntry.find_by(lyric: lyric)
      break if entry&.size == size && entry&.columns == columns

      flunk "layout for #{lyric.title} was never saved" if Time.now > deadline
      sleep 0.05
    end
  end
end
