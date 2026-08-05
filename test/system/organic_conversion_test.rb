require "application_system_test_case"

class OrganicConversionTest < ApplicationSystemTestCase
  test "manual entry generates a printable page at a narrow viewport" do
    page.current_window.resize_to(390, 844)

    visit root_path
    install_persistent_analytics_capture
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
    assert_equal "1", page.evaluate_script("getComputedStyle(document.querySelector('.lyrics')).columnCount")

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    begin
      assert_equal "2", page.evaluate_script("getComputedStyle(document.querySelector('.lyrics')).columnCount")
    ensure
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    end

    assert_equal(
      [ "Print Page Generated" ],
      captured_analytics_calls.map(&:first).reject { |name| name == "pageview" }
    )
  end

  test "search selection loads editable lyrics and records demand without publishing it" do
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
      assert_equal(
        [ "Song Search Submitted", "Song Selected" ],
        page.evaluate_script("window.__analyticsCalls.map((call) => call[0])")
      )

      assert_difference([ "Lyric.count", "Song.count" ], 1) do
        click_button "Generate print page"
        assert_text "Love, rising"
      end
    end

    assert_equal 42, Song.last.source_id
    refute Song.last.indexable?
  end

  test "public song page loads lyrics into the editable form" do
    song = Song.create!(
      source_id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      indexable_at: 1.day.ago
    )
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
    client.define_singleton_method(:find) { |_| result }

    with_song_lrc_lib_client(client) do
      visit song_path(song)
      click_button "Load lyrics to print"

      assert_field "Song title", with: "The Kiss"
      assert_field "Artist", with: "Judee Sill"
      assert_field "Lyrics", with: "Love, rising"
    end
  end

  test "public song page shows when lyrics become unavailable" do
    song = Song.create!(
      source_id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      indexable_at: 1.day.ago
    )
    client = Object.new
    client.define_singleton_method(:find) { |_| raise LrcLibClient::NotFoundError }

    with_song_lrc_lib_client(client) do
      visit song_path(song)
      click_button "Load lyrics to print"

      assert_text(/Song unavailable/i)
      assert_text "The source no longer has printable lyrics for this song."
    end
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
      assert_selector "h1", text: "PrintLyrics"
      page.execute_script("Turbo.visit(#{generated_path.to_json})")
      assert_button "Print"
    end

    count = page.evaluate_script(
      "JSON.parse(sessionStorage.getItem('test:analyticsCalls') || '[]')" \
        ".filter((call) => call[0] === 'Print Page Generated').length"
    )
    assert_equal 1, count
  end

  test "campaign attribution follows generation and optional use-case feedback" do
    visit "#{root_path}?utm_source=outreach&utm_campaign=worship_handouts"
    install_persistent_analytics_capture
    assert_equal(
      { "campaign_source" => "outreach", "campaign_name" => "worship_handouts" },
      JSON.parse(page.evaluate_script("sessionStorage.getItem('printlyrics:campaign') || '{}'"))
    )

    fill_in "Lyrics", with: "A congregation line"
    click_button "Generate print page"
    assert_text "What are you making this lyric sheet for?"

    generated = captured_analytics_calls.find { |call| call[0] == "Print Page Generated" }
    assert_equal "outreach", generated.dig(1, "props", "campaign_source")
    assert_equal "worship_handouts", generated.dig(1, "props", "campaign_name")

    click_button "Worship or community"

    assert_text "Thanks. That helps us keep PrintLyrics useful and focused."
    feedback = captured_analytics_calls.find { |call| call[0] == "Print Use Case Selected" }
    assert_equal "worship_community", feedback.dig(1, "props", "use_case")
    assert_equal "outreach", feedback.dig(1, "props", "campaign_source")
    assert_equal "worship_handouts", feedback.dig(1, "props", "campaign_name")
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

  def with_song_lrc_lib_client(client)
    SongsController.alias_method :__original_lrc_lib_client, :lrc_lib_client
    SongsController.define_method(:lrc_lib_client) { client }
    yield
  ensure
    SongsController.alias_method :lrc_lib_client, :__original_lrc_lib_client
    SongsController.remove_method :__original_lrc_lib_client
  end
end
