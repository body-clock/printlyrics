require "application_system_test_case"

class WorkspaceInteractionTest < ApplicationSystemTestCase
  test "a completed preview starts a clean new sheet rather than reviving a dirty draft" do
    visit root_path
    fill_in_entry "Lyrics", with: "Completed draft"
    fill_in "lyric_title", with: "Completed title"
    click_button "Preview sheet"
    assert_selector ".paper", text: "Completed draft"
    click_link "New sheet"
    click_button "Edit", exact: true
    assert_field "lyric_lyrics", with: ""
    assert_field "lyric_title", with: ""
    click_button "Find", exact: true
    click_link "One-page printing guide", exact: true
    assert_current_path print_lyrics_on_one_page_path
  end

  test "a failed search and reload preserve both entry modes without creating a sheet" do
    client = Object.new
    client.define_singleton_method(:search) do |_, **|
      raise LrcLibClient::ServiceError.new("LRCLIB unavailable", endpoint: "/api/search", status: 503)
    end

    with_lrc_lib_client(client) do
      visit root_path
      fill_in_entry "Lyrics", with: "Words kept through failure\n\nAnother verse"
      fill_in "lyric_title", with: "Draft title"
      click_button "Find", exact: true
      fill_in "query", with: "A song to find"

      assert_no_difference "Lyric.count" do
        click_button "Search"
        assert_selector "#song-search-results [role='alert']"
        click_button "Edit", exact: true
        assert_field "lyric_lyrics", with: "Words kept through failure\n\nAnother verse"
        assert_field "lyric_title", with: "Draft title"
      end

      page.refresh
      assert_field "lyric_lyrics", with: "Words kept through failure\n\nAnother verse"
      click_button "Find", exact: true
      assert_field "query", with: "A song to find"
    end
  end

  test "mobile format dismissal restores focus and zoom cannot change the print layout" do
    lyric = Lyric.create!(lyrics: "First verse\nA second line", title: "A sheet")
    page.current_window.resize_to(320, 780)
    visit lyric_path(lyric)
    assert_no_selector ".paper.is-unpaginated"
    assert_button "Format sheet"
    find(".workspace-format-trigger").click
    assert_no_selector ".workspace-zoom", visible: true
    assert_no_selector "#preview-zoom-hint", visible: true
    find("[data-preview-layout='size'] [data-preview-value='xl']").click
    assert_selector ".paper.size-xl"
    find("[data-preview-layout='columns'] [data-preview-value='2']").click
    assert_selector ".paper.size-xl .lyrics.cols-2"
    close_position = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector(".workspace-inspector")
        panel.scrollTop = panel.scrollHeight
        const close = panel.querySelector(".workspace-inspector-close").getBoundingClientRect()
        const bounds = panel.getBoundingClientRect()
        return { top: close.top, bottom: close.bottom, panelTop: bounds.top, panelBottom: bounds.bottom }
      })()
    JS
    assert_operator close_position.fetch("top"), :>=, close_position.fetch("panelTop")
    assert_operator close_position.fetch("bottom"), :<=, close_position.fetch("panelBottom")
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector ".workspace-format-trigger:focus"
    assert_no_selector ".workspace-inspector"

    geometry = page.evaluate_script("[...document.querySelectorAll('.paper')].map(p => [p.offsetWidth, p.offsetHeight, getComputedStyle(p.querySelector('.lyrics')).fontSize])")

    # Inspection zoom is a wide-screen tool; selecting it must still change only
    # the screen scale, never the paper or its type.
    page.current_window.resize_to(1280, 900)
    select "125%", from: "Preview zoom"
    assert_equal geometry, page.evaluate_script("[...document.querySelectorAll('.paper')].map(p => [p.offsetWidth, p.offsetHeight, getComputedStyle(p.querySelector('.lyrics')).fontSize])")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("innerWidth")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    begin
      assert_no_selector ".skip-link, .control-bar, .workspace-inspector, .workspace-view-controls"
      assert_equal geometry, page.evaluate_script("[...document.querySelectorAll('.paper')].map(p => [p.offsetWidth, p.offsetHeight, getComputedStyle(p.querySelector('.lyrics')).fontSize])")
    ensure
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    end
  end

  test "the find panel reaches the paste form without opening the tab" do
    visit root_path
    click_link "Paste them"
    assert_selector "#entry-tab-paste[aria-selected='true']", text: "Edit"
    assert_selector "#entry-panel-paste", visible: true
    assert_equal "lyric_lyrics", page.evaluate_script("document.activeElement.id")
  end

  test "retry saves every failed formatting dimension without flattening neighbouring songs" do
    first = Lyric.create!(lyrics: "First line", title: "First")
    second = Lyric.create!(lyrics: "Second line", title: "Second")
    book = Songbook.start_with(first, second)
    visit songbook_path(book)
    assert_no_selector ".paper.is-unpaginated"
    page.execute_script(<<~JS)
      window.originalWorkspaceFetch = window.fetch
      window.fetch = (url, options) => options?.method === "PATCH" ?
        Promise.resolve(new Response("", { status: 503 })) : window.originalWorkspaceFetch(url, options)
    JS
    within("[data-preview-target='songFormatGroup']") do
      find("[data-preview-layout='size'] [data-preview-value='xl']").click
    end
    assert_selector ".layout-save-feedback"
    within("[data-preview-target='songFormatGroup']") do
      find("[data-preview-layout='columns'] [data-preview-value='2']").click
    end
    assert_selector ".paper.size-xl .lyrics.cols-2"
    assert_equal [ "m", 1 ], book.entries.find_by!(lyric: first).attributes.values_at("size", "columns")
    placement = page.evaluate_script(<<~JS)
      (() => {
        window.scrollTo(0, 600)
        const feedback = document.querySelector(".layout-save-feedback").getBoundingClientRect()
        const toolbar = document.querySelector(".control-bar").getBoundingClientRect()
        return { top: feedback.top, bottom: feedback.bottom, toolbarBottom: toolbar.bottom, viewport: innerHeight }
      })()
    JS
    assert_operator placement.fetch("top"), :>=, placement.fetch("toolbarBottom") - 1
    assert_operator placement.fetch("bottom"), :<=, placement.fetch("viewport")
    page.execute_script("window.fetch = window.originalWorkspaceFetch")
    click_button "Retry saving"
    assert_no_selector ".layout-save-feedback"
    page.refresh
    assert_no_selector ".paper.is-unpaginated"
    assert_selector ".paper[data-preview-song-token='#{first.token}'].size-xl .lyrics.cols-2"
    assert_selector ".paper[data-preview-song-token='#{second.token}'].size-m .lyrics:not(.cols-2)"
  end
end
