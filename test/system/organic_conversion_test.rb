require "application_system_test_case"

class OrganicConversionTest < ApplicationSystemTestCase
  test "manual entry preview mirrors the printed page across viewport sizes" do
    page.current_window.resize_to(390, 844)

    visit root_path
    install_persistent_analytics_capture
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"),
      :<=, page.evaluate_script("window.innerWidth")
    fill_in "Song title", with: "Practice Song"
    fill_in "Artist", with: "Home Guitarist"
    fill_in "Lyrics", with: "First line\nSecond line"
    click_button "Generate print page"

    assert_text "Practice Song"
    assert_text "Home Guitarist"
    assert_text "First line"
    assert_button "Print"
    assert_selector "meta[name='robots'][content*='noindex']", visible: false
    find("[data-columns='2']").click
    assert_selector ".lyrics.cols-2"

    screen_layout = preview_layout
    mobile_preview_scale = page.evaluate_script(
      "document.querySelector('.paper').style.getPropertyValue('--preview-scale')"
    )
    mobile_preview_height = page.evaluate_script(
      "document.querySelector('.paper-frame').style.height"
    )

    page.execute_script("window.dispatchEvent(new Event('beforeprint'))")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    begin
      print_layout = preview_layout
      page.execute_script("window.dispatchEvent(new Event('resize'))")
    ensure
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
      page.execute_script("window.dispatchEvent(new Event('afterprint'))")
    end
    page.evaluate_async_script("requestAnimationFrame(arguments[0])")

    assert_equal 2, screen_layout.fetch("columnCount")
    assert_equal print_layout, screen_layout
    assert_equal mobile_preview_scale, page.evaluate_script(
      "document.querySelector('.paper').style.getPropertyValue('--preview-scale')"
    )
    assert_equal mobile_preview_height, page.evaluate_script(
      "document.querySelector('.paper-frame').style.height"
    )
    assert_operator page.evaluate_script("document.querySelector('.paper').getBoundingClientRect().width"),
      :<=, page.evaluate_script("document.querySelector('.paper-frame').clientWidth")
    assert_operator page.evaluate_script("document.querySelector('.paper').getBoundingClientRect().width"),
      :<=, page.evaluate_script("window.innerWidth")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"),
      :<=, page.evaluate_script("window.innerWidth")

    page.current_window.resize_to(1200, 900)

    assert_equal print_layout, preview_layout
    assert_equal "", page.evaluate_script("document.querySelector('.paper-frame').style.height")
    assert_equal "", page.evaluate_script(
      "document.querySelector('.paper-pages').style.getPropertyValue('--preview-scale')"
    )

    assert_equal(
      [ "Print Page Generated" ],
      captured_analytics_calls.map(&:first).reject { |name| name == "pageview" }
    )
  end

  test "long lyrics are split into the same visible sheets that are printed" do
    lyrics = 36.times.map do |stanza|
      "[Verse #{stanza + 1}]\nThis is a deliberately long line of lyrics for measuring the printed page.\nAnother line stays with its stanza."
    end.join("\n\n")

    visit root_path
    fill_in "Song title", with: "A Long Song"
    fill_in "Lyrics", with: lyrics
    click_button "Generate print page"

    assert_selector "[data-preview-page]", minimum: 2
    assert_text(/\d+ pages/)
    screen_pages = printed_page_geometry

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    begin
      assert_equal screen_pages, printed_page_geometry
    ensure
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    end

    find("[data-columns='2']").click
    assert_operator all("[data-preview-page]").count, :<, screen_pages.length
    assert_equal 2, page.evaluate_script(
      "document.querySelector('[data-preview-page] .lyrics').children.length"
    )
  end

  test "search selection loads editable lyrics without publishing it" do
    result = LrcLibResult.new(
      id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214,
      plain_lyrics: "Love, rising",
      synced_lyrics: nil,
      instrumental: false
    )
    client = Object.new
    client.define_singleton_method(:search) { |_| [ result ] }
    client.define_singleton_method(:find) do |_|
      sleep 0.05
      result
    end

    with_lrc_lib_client(client) do
      visit root_path
      page.execute_script(<<~JS)
        window.__analyticsCalls = []
        window.plausible = (...args) => window.__analyticsCalls.push(args)
      JS
      fill_in "Song title or artist", with: "The Kiss"
      click_button "Search"
      assert_text "1 match found"

      click_button "The Kiss"
      assert_button "Loading lyrics…", disabled: true
      assert_field "Song title", with: "The Kiss"
      assert_field "Artist", with: "Judee Sill"
      assert_field "Lyrics", with: "Love, rising"
      assert_empty page.evaluate_script("window.__analyticsCalls.map((call) => call[0])")

      assert_difference([ "Lyric.count", "Song.count" ], 1) do
        click_button "Generate print page"
        # Wait for the generated page. Asserting the lyric text would not
        # synchronise: it is already on screen in the form's textarea, so this
        # block used to exit and sample the counts while the POST was still in
        # flight. The generated-page key only appears on the new page.
        assert_selector "body[data-generated-page-key]"
      end

      assert_text "Love, rising"
    end

    assert_equal 42, Song.last.source_id
  end

  test "token page analytics redact the token and print event precedes print" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Song title", with: "Test Song"
    fill_in "Artist", with: "Test Artist"
    fill_in "Lyrics", with: "Line one"
    click_button "Generate print page"
    assert_text "Test Song"

    lyric = Lyric.last
    calls = captured_analytics_calls
    generated = calls.find { |call| call[0] == "Print Page Generated" }
    pageview = calls.find { |call| call[0] == "pageview" }
    assert generated
    assert pageview
    assert_equal "/lyrics/:token", URI(pageview.dig(1, "url")).path
    assert_equal "/lyrics/:token", URI(generated.dig(1, "url")).path
    refute_includes calls.to_json, lyric.token
    refute_includes calls.to_json, lyric.title
    refute_includes calls.to_json, lyric.artist

    page.execute_script(<<~JS)
      window.__analyticsCalls = []
      window.plausible = (...args) => window.__analyticsCalls.push(["plausible", ...args])
      window.print = () => window.__analyticsCalls.push(["print"])
    JS
    click_button "Print"

    calls = page.evaluate_script("window.__analyticsCalls")
    print_event_index = calls.index { |call| call[1] == "Print Dialog Opened" }
    native_print_index = calls.index { |call| call[0] == "print" }
    assert print_event_index
    assert native_print_index
    assert_operator print_event_index, :<, native_print_index
    assert_equal "1", calls.dig(print_event_index, 2, "props", "page_count_in_session")
  end

  test "restoring a generated page does not duplicate its generation event" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Lyrics", with: "Line one"
    click_button "Generate print page"
    assert_selector "body[data-generated-page-key]"
    generated_path = current_path
    page.execute_script(analytics_capture_source)

    2.times do
      page.execute_script("Turbo.visit('/')")
      assert_selector "h1", text: "Find, format, and print song lyrics"
      page.execute_script("Turbo.visit(#{generated_path.to_json})")
      assert_button "Print"
    end

    count = page.evaluate_script(
      "JSON.parse(sessionStorage.getItem('test:analyticsCalls') || '[]')" \
        ".filter((call) => call[0] === 'Print Page Generated').length"
    )
    assert_equal 1, count
  end

  test "generating a second sheet in one session records packet intent once" do
    visit root_path
    install_persistent_analytics_capture
    page.execute_script("sessionStorage.removeItem('printlyrics:session-pages')")

    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    assert_text "First song line"

    2.times do |index|
      page.execute_script("Turbo.visit('/')")
      assert_selector "h1", text: "Find, format, and print song lyrics"
      fill_in "Lyrics", with: "Later song line #{index}"
      click_button "Generate print page"
      assert_text "Later song line #{index}"
    end

    calls = captured_analytics_calls
    assert_equal(
      [ "1", "2", "3-5" ],
      calls.select { |call| call[0] == "Print Page Generated" }
        .map { |call| call.dig(1, "props", "page_count_in_session") }
    )
    assert_equal 1, calls.count { |call| call[0] == "Second Print Page Generated" }
  end

  test "campaign attribution follows generation" do
    visit "#{root_path}?utm_source=outreach&utm_campaign=worship_handouts"
    install_persistent_analytics_capture
    assert_equal(
      { "campaign_source" => "outreach", "campaign_name" => "worship_handouts" },
      JSON.parse(page.evaluate_script("sessionStorage.getItem('printlyrics:campaign') || '{}'"))
    )

    fill_in "Lyrics", with: "A congregation line"
    click_button "Generate print page"
    assert_text "A congregation line"

    generated = captured_analytics_calls.find { |call| call[0] == "Print Page Generated" }
    assert_equal "outreach", generated.dig(1, "props", "campaign_source")
    assert_equal "worship_handouts", generated.dig(1, "props", "campaign_name")

    refute_selector "[data-use-case]"
    refute_includes captured_analytics_calls.to_json, "Print Use Case Selected"
  end

  test "opening an existing shared page does not record a generation" do
    lyric = Lyric.create!(lyrics: "Shared line")

    visit root_path
    page.execute_script(<<~JS)
      window.__analyticsCalls = []
      window.plausible = (...args) => window.__analyticsCalls.push(args)
      sessionStorage.clear()
    JS
    page.execute_script("Turbo.visit(#{lyric_path(lyric).to_json})")
    assert_text "Shared line"

    refute_selector "body[data-generated-page-key]"
    assert_equal(
      [ "pageview" ],
      page.evaluate_script("window.__analyticsCalls.map((call) => call[0])")
    )
  end

  private

  def preview_layout
    page.evaluate_script(<<~JS)
      (() => {
        const paper = getComputedStyle(document.querySelector(".paper"))
        const header = getComputedStyle(document.querySelector(".lyric-header"))
        const lyricsElement = document.querySelector(".lyrics")
        const lyrics = getComputedStyle(lyricsElement)

        return {
          columnCount: lyricsElement.children.length,
          columnGap: lyrics.columnGap,
          fontSize: lyrics.fontSize,
          lineHeight: lyrics.lineHeight,
          width: paper.width,
          height: paper.height,
          paddingTop: paper.paddingTop,
          paddingRight: paper.paddingRight,
          paddingBottom: paper.paddingBottom,
          paddingLeft: paper.paddingLeft,
          backgroundColor: paper.backgroundColor,
          color: paper.color,
          headerMarginBottom: header.marginBottom,
          headerPaddingBottom: header.paddingBottom
        }
      })()
    JS
  end


  def printed_page_geometry
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-preview-page]")].map((paper) => {
        const style = getComputedStyle(paper)
        return {
          width: style.width,
          height: style.height,
          padding: [style.paddingTop, style.paddingRight, style.paddingBottom, style.paddingLeft],
          columns: paper.querySelector(".lyrics").children.length
        }
      })
    JS
  end

  def install_persistent_analytics_capture
    page.execute_script("sessionStorage.removeItem('test:analyticsCalls')")
    page.driver.browser.execute_cdp(
      "Page.addScriptToEvaluateOnNewDocument",
      source: analytics_capture_source
    )
  end

  def analytics_capture_source
    <<~JS
      window.plausible = (...args) => {
        const key = "test:analyticsCalls"
        const calls = JSON.parse(sessionStorage.getItem(key) || "[]")
        calls.push(args)
        sessionStorage.setItem(key, JSON.stringify(calls))
      }
      window.plausible.init = () => {}
    JS
  end

  def captured_analytics_calls
    JSON.parse(page.evaluate_script("sessionStorage.getItem('test:analyticsCalls') || '[]'"))
  end

  def with_lrc_lib_client(client)
    LyricsController.alias_method :__original_lrc_lib_client, :lrc_lib_client
    LyricsController.define_method(:lrc_lib_client) { client }
    yield
  ensure
    LyricsController.alias_method :lrc_lib_client, :__original_lrc_lib_client
    LyricsController.remove_method :__original_lrc_lib_client
  end
end
