require "application_system_test_case"

class OrganicConversionTest < ApplicationSystemTestCase
  test "manual entry preview mirrors the printed page across viewport sizes" do
    page.current_window.resize_to(390, 844)

    visit root_path
    install_persistent_analytics_capture
    # The manual form reports its attempt in the document it is submitted from,
    # so the capture has to be live here as well as in the page that follows.
    page.execute_script(analytics_capture_source)
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
      [ "Manual Entry Submitted", "Print Page Generated" ],
      captured_analytics_calls.map(&:first).reject { |name| name == "pageview" }
    )
  end

  test "long lyrics are split into the same visible sheets that are printed" do
    lyrics = long_lyrics

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
    lookup_started = Queue.new
    allow_lookup_to_finish = Queue.new
    client = Object.new
    client.define_singleton_method(:search) { |_| [ result ] }
    client.define_singleton_method(:find) do |_|
      lookup_started << true
      allow_lookup_to_finish.pop
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
      lookup_started.pop
      begin
        assert_button "Loading lyrics…", disabled: true
      ensure
        allow_lookup_to_finish << true
      end
      assert_field "Song title", with: "The Kiss"
      assert_field "Artist", with: "Judee Sill"
      assert_field "Lyrics", with: "Love, rising"
      # Every step of the search reports itself: the attempt, then the match the
      # visitor chose. A search that matched leaves the miss prompt out of the
      # panel, so nothing else arrives.
      assert_equal [ "Song Search Submitted", "Song Result Selected" ],
        page.evaluate_script("window.__analyticsCalls.map((call) => call[0])")

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
    # A single sheet is not a set print.
    assert_nil calls.index { |call| call[1] == "Songbook Printed" }
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
    # The lyric text is already on screen in the form's textarea, so asserting it
    # does not wait for the POST: the paper only exists on the generated page.
    assert_selector ".paper .lyrics", text: "First song line"

    2.times do |index|
      page.execute_script("Turbo.visit('/')")
      assert_selector "h1", text: "Find, format, and print song lyrics"
      fill_in "Lyrics", with: "Later song line #{index}"
      click_button "Generate print page"
      assert_selector ".paper .lyrics", text: "Later song line #{index}"
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

  test "a second sheet offers to gather the visit into one songbook" do
    visit root_path
    fill_in "Song title", with: "First Song"
    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    refute_selector ".songbook-prompt"

    click_link "Back"
    fill_in "Song title", with: "Second Song"
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"

    assert_selector ".songbook-prompt", text: "2 sheets so far"
    click_button "Make a songbook"

    assert_current_path %r{/songbooks/}
    assert_selector ".songbook-track", count: 2
    assert_equal [ "First Song", "Second Song" ], all(".paper .lyric-header h1").map(&:text)
  end

  test "the entry panel offers the sheets the tab already made" do
    visit root_path
    refute_selector ".songbook-prompt"

    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    click_link "Back"
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"
    assert_selector ".songbook-prompt", text: "2 sheets so far"

    click_link "Back"

    # The entry panel is where a visit that already made sheets returns for the
    # next one, so the offer is there too, not only on the sheet it just made.
    assert_selector ".songbook-prompt", text: "2 sheets so far"
    click_button "Make a songbook"

    assert_current_path %r{/songbooks/}
    assert_selector ".songbook-track", count: 2
  end

  test "declining the songbook suggestion keeps it away for the tab" do
    visit root_path
    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    click_link "Back"
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"
    assert_selector ".songbook-prompt", text: "2 sheets so far"

    click_button "Not now"
    refute_selector ".songbook-prompt"

    click_link "Back"
    fill_in "Lyrics", with: "Third song line"
    click_button "Generate print page"

    assert_selector ".paper"
    refute_selector ".songbook-prompt"
  end

  test "adding another song goes straight to the entry form" do
    visit root_path
    fill_in "Song title", with: "First Song"
    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"

    click_button "Add another song"

    # One click, not two: the button used to stop at a set of one, so the
    # visitor had to find "Add a song" before doing what they just asked for.
    assert_text "Adding to a songbook with 1 song"
    assert_selector "form[action='#{lyrics_path}'] input[name='songbook']", visible: :all
    refute_selector ".songbook-tracks"

    fill_in "Song title", with: "Second Song"
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"

    assert_selector ".songbook-track", count: 2
    assert_equal [ "First Song", "Second Song" ], all(".paper .lyric-header h1").map(&:text)
  end

  test "a set gathered from existing sheets records its creation once" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    click_link "Back"
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"
    click_button "Make a songbook"
    assert_selector ".songbook-track", count: 2

    assert_equal 1, created_songbook_calls.length
    assert_equal "2", created_songbook_calls.first.dig(1, "props", "songbook_size")
    assert_equal "offer", created_songbook_calls.first.dig(1, "props", "songbook_origin")
    assert_equal 1, analytics_calls_named("Songbook Created From Offer").length

    # Returning to the same set later is not another creation.
    set_path = current_path
    page.execute_script("Turbo.visit(#{set_path.to_json})")
    assert_selector ".songbook-track", count: 2
    assert_equal 1, created_songbook_calls.length
    assert_equal 1, analytics_calls_named("Songbook Created From Offer").length
  end

  test "restoring the set from the browser cache does not record the creation again" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    click_link "Back"
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"
    click_button "Make a songbook"
    assert_selector ".songbook-track", count: 2
    assert_equal 1, created_songbook_calls.length

    # Leaving and returning with the Back button restores Turbo's cached copy of
    # this page, creation marker and all. The server's one-shot flag is long
    # consumed by then, so only the client can tell the two apart.
    click_link "Add a song"
    assert_selector "form[action='#{lyrics_path}']"
    page.go_back

    assert_selector ".songbook-track", count: 2
    assert_equal 1, created_songbook_calls.length
    assert_equal 1, analytics_calls_named("Songbook Created From Offer").length
  end

  test "a set built by adding a song records its creation once" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    click_button "Add another song"
    assert_text "Adding to a songbook with 1 song"

    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"
    assert_selector ".songbook-track", count: 2

    assert_equal 1, created_songbook_calls.length
    assert_equal "2", created_songbook_calls.first.dig(1, "props", "songbook_size")
    assert_equal "add_song", created_songbook_calls.first.dig(1, "props", "songbook_origin")
    # A set built by adding a song is the total only, never the offer subset.
    assert_empty analytics_calls_named("Songbook Created From Offer")

    click_link "Add a song"
    fill_in "Lyrics", with: "Third song line"
    click_button "Generate print page"

    assert_selector ".songbook-track", count: 3
    assert_equal 1, created_songbook_calls.length
  end

  test "a one-song songbook is not reported as a creation" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    click_button "Add another song"
    click_link "View songbook"

    assert_selector ".songbook-track", count: 1
    assert_empty created_songbook_calls
  end

  test "the songbook context notice clears the list below it" do
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First song line", title: "First Song"))

    visit root_path(songbook: songbook.token)

    gap_below = page.evaluate_script(<<~JS)
      (() => {
        const strip = document.querySelector(".songbook-context").getBoundingClientRect()
        const below = document.querySelector(".tool-benefits").getBoundingClientRect()
        return Math.round(below.top - strip.bottom)
      })()
    JS

    # The notice sits between the introduction and the benefit list, and shipped
    # flush against the list below it while keeping its full gap above.
    assert_operator gap_below, :>=, 8
  end

  test "the songbook link leaves the entry frame" do
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First song line", title: "First Song"))

    visit root_path(songbook: songbook.token)
    click_link "View songbook"

    assert_current_path songbook_path(songbook)
    assert_selector ".songbook-track", count: 1
    assert_no_text "Content missing"
  end

  test "a long song keeps its sheets together inside a set" do
    visit root_path
    fill_in "Song title", with: "Long Song"
    fill_in "Lyrics", with: long_lyrics
    click_button "Generate print page"
    click_button "Add another song"
    assert_text "Adding to a songbook with 1 song"
    fill_in "Song title", with: "Short Song"
    fill_in "Lyrics", with: "One short line"
    click_button "Generate print page"

    assert_selector ".paper", minimum: 3
    # One heading per song: the set never runs two titles together, and a
    # continuation sheet carries only lyrics.
    assert_equal [ "Long Song", "Short Song" ], all(".paper .lyric-header h1").map(&:text)
  end

  test "songbook analytics redact both tokens" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    click_button "Add another song"
    assert_text "Adding to a songbook with 1 song"
    songbook_token = URI.decode_www_form(URI(current_url).query).to_h.fetch("songbook")
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"

    assert_selector ".paper", count: 2
    refute_includes captured_analytics_calls.to_json, songbook_token

    entry_urls = captured_analytics_calls.filter_map { |call| call.dig(1, "url") }
      .select { |url| URI(url).query.to_s.include?("songbook") }
    refute_empty entry_urls
    assert(entry_urls.all? { |url| URI.decode_www_form(URI(url).query).to_h["songbook"] == ":token" })

    page.execute_script(<<~JS)
      window.__analyticsCalls = []
      window.plausible = (...args) => window.__analyticsCalls.push(["plausible", ...args])
      window.print = () => {}
    JS
    click_button "Print all"

    calls = page.evaluate_script("window.__analyticsCalls")
    print_call = calls.find { |call| call[1] == "Print Dialog Opened" }
    assert_equal "/songbooks/:token", URI(print_call[2]["url"]).path
    refute_includes calls.to_json, songbook_token
    refute_includes calls.to_json, Lyric.last.token
  end

  test "printing and pagination survive blocked browser storage" do
    # A browser that blocks storage throws on the property itself and on every
    # method call, which used to take the preview and the print dialog with it.
    inject_on_new_document(<<~JS)
      for (const name of ["localStorage", "sessionStorage"]) {
        Object.defineProperty(window, name, {
          configurable: true,
          get() { throw new DOMException("storage blocked", "SecurityError") }
        })
      }
      for (const method of ["getItem", "setItem", "removeItem"]) {
        Object.defineProperty(Storage.prototype, method, {
          configurable: true,
          value() { throw new DOMException("storage blocked", "SecurityError") }
        })
      }
      window.__printed = false
      window.print = () => { window.__printed = true }
    JS

    visit root_path
    fill_in "Lyrics", with: "First line"
    click_button "Generate print page"

    assert_text "First line"
    assert_selector "[data-preview-page]", count: 1
    assert_selector ".page-summary", text: /1 page/

    click_button "Print"
    assert page.evaluate_script("window.__printed")
  end

  test "a songbook prints every song in one job and reports the set" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Song title", with: "First Song"
    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    assert_text "First song line"

    click_button "Add another song"
    assert_text "Adding to a songbook with 1 song"

    fill_in "Song title", with: "Second Song"
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"

    assert_selector ".paper", count: 2
    assert_equal [ "First Song", "Second Song" ], all(".paper .lyric-header h1").map(&:text)

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    begin
      assert_equal 2, printed_page_geometry.length
    ensure
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
    end

    page.execute_script(<<~JS)
      window.__analyticsCalls = []
      window.plausible = (...args) => window.__analyticsCalls.push(["plausible", ...args])
      window.print = () => window.__analyticsCalls.push(["print"])
    JS
    click_button "Print all"

    calls = page.evaluate_script("window.__analyticsCalls")
    print_event_index = calls.index { |call| call[1] == "Print Dialog Opened" }
    native_print_index = calls.index { |call| call[0] == "print" }
    assert print_event_index
    assert native_print_index
    assert_operator print_event_index, :<, native_print_index
    assert_equal "songbook", calls.dig(print_event_index, 2, "props", "entry_method")
    assert_equal "2", calls.dig(print_event_index, 2, "props", "songbook_size")

    # Printing a set is also its own goal, which is the only way it stays
    # readable without custom properties.
    set_print_index = calls.index { |call| call[1] == "Songbook Printed" }
    assert set_print_index
    assert_operator set_print_index, :<, native_print_index
    assert_equal 1, calls.count { |call| call[1] == "Songbook Printed" }

    # The generation funnel keeps reporting its buckets from the new surface.
    generated = captured_analytics_calls.select { |call| call[0] == "Print Page Generated" }
    assert_equal [ "1", "2" ], generated.map { |call| call.dig(1, "props", "page_count_in_session") }
    assert_equal 1, captured_analytics_calls.count { |call| call[0] == "Second Print Page Generated" }
  end

  test "umami reports each event under its own name and redacts saved pages" do
    visit root_path
    install_persistent_analytics_capture
    page.execute_script(analytics_capture_source)

    fill_in "Song title", with: "Test Song"
    fill_in "Artist", with: "Test Artist"
    fill_in "Lyrics", with: "Line one"
    click_button "Generate print page"
    assert_text "Test Song"

    lyric = Lyric.last
    pageview = captured_umami_payloads.find { |payload| !payload["name"] }
    generated = captured_umami_events.find { |name, _| name == "Print Page Generated" }
    assert pageview
    assert generated

    # Umami fills the location, title, and referrer from the document unless the
    # payload replaces them, and on a saved page the document carries all three.
    assert_equal "/lyrics/:token", URI(pageview.fetch("url")).path
    assert_equal "/lyrics/:token", pageview.fetch("title")
    assert_equal "/lyrics/:token", URI(generated.last.fetch("url")).path
    assert_equal "1", generated.last.dig("data", "page_count_in_session")
    refute_includes captured_umami_payloads.to_json, lyric.token
    refute_includes captured_umami_payloads.to_json, lyric.title
    refute_includes captured_umami_payloads.to_json, lyric.artist

    page.execute_script("window.print = () => {}")
    click_button "Print"

    # Umami keeps the product's names verbatim, spaces and all, so there is no
    # mapping table between the two, and a pageview is the payload with no name.
    assert_equal(
      [ "Manual Entry Submitted", nil, "Print Page Generated", "Print Dialog Opened" ],
      captured_umami_payloads.map { |payload| payload["name"] }
    )
  end

  test "umami reports the songbook events with their properties" do
    visit root_path
    install_persistent_analytics_capture

    fill_in "Lyrics", with: "First song line"
    click_button "Generate print page"
    click_link "Back"
    fill_in "Lyrics", with: "Second song line"
    click_button "Generate print page"
    click_button "Make a songbook"
    assert_selector ".songbook-track", count: 2

    created = captured_umami_events.find { |name, _| name == "Songbook Created" }
    assert created
    assert_equal "2", created.last.dig("data", "songbook_size")
    assert_equal "offer", created.last.dig("data", "songbook_origin")
    assert_equal 1, captured_umami_events.count { |name, _| name == "Songbook Created From Offer" }
  end

  test "umami redacts a saved page that referred the visit" do
    lyric = Lyric.create!(lyrics: "Shared line", title: "Shared Song")

    visit lyric_path(lyric)
    assert_text "Shared line"
    install_persistent_analytics_capture

    # A same-origin referrer is itself a saved page, and the tracker reports
    # document.referrer on every payload unless the payload replaces it. The
    # link leaves Turbo so the browser records a real referrer.
    page.execute_script(<<~JS)
      const link = document.createElement("a")
      link.href = #{root_path.to_json}
      link.dataset.turbo = "false"
      link.textContent = "Home"
      document.body.append(link)
    JS
    click_link "Home"
    assert_selector "h1", text: "Find, format, and print song lyrics"

    pageview = captured_umami_payloads.find { |payload| !payload["name"] }
    assert pageview
    assert_equal "/lyrics/:token", URI(pageview.fetch("referrer")).path
    refute_includes captured_umami_payloads.to_json, lyric.token
  end

  test "a saved page reached with a trailing slash still redacts its token" do
    lyric = Lyric.create!(lyrics: "Shared line", title: "Shared Song")

    # Rails serves `/lyrics/<token>/` as the same page, so a shared link that
    # gained a slash would otherwise report the real token to every destination.
    visit root_path
    install_persistent_analytics_capture
    visit "#{lyric_path(lyric)}/"
    assert_text "Shared line"

    pageview = captured_umami_payloads.last
    assert_equal "/lyrics/:token", URI(pageview.fetch("url")).path
    assert_equal "/lyrics/:token", pageview.fetch("title")
    refute_includes captured_umami_payloads.to_json, lyric.token
    refute_includes captured_analytics_calls.to_json, lyric.token
  end

  test "a search that finds nothing reports its attempt and its miss once" do
    client = Object.new
    client.define_singleton_method(:search) { |_| [] }

    with_lrc_lib_client(client) do
      visit root_path
      install_persistent_analytics_capture
      # The results arrive in a Turbo frame, which is this same document, so the
      # capture has to be live here as well as in the document that follows.
      page.execute_script(analytics_capture_source)

      fill_in "Song title or artist", with: "A song nobody has"
      click_button "Search"
      assert_text "No matches found"
      wait_for_analytics_event("Song Search Missed")

      assert_equal 1, analytics_calls_named("Song Search Submitted").length
      assert_equal 1, analytics_calls_named("Song Search Missed").length

      # The miss rides the response that carried it, so returning to a panel
      # restored from Turbo's cache is not another miss.
      page.execute_script("Turbo.visit('/print-lyrics-on-one-page')")
      assert_current_path "/print-lyrics-on-one-page"
      page.go_back
      assert_selector ".search-miss"

      assert_equal 1, analytics_calls_named("Song Search Missed").length
      assert_equal 1, analytics_calls_named("Song Search Submitted").length

      # The manual form reports its own attempt, which is the other way in.
      fill_in "Lyrics", with: "A line we typed ourselves"
      click_button "Generate print page"
      assert_selector "body[data-generated-page-key]"

      assert_equal 1, analytics_calls_named("Manual Entry Submitted").length
      assert_equal 1, analytics_calls_named("Song Search Missed").length
    end
  end

  test "the manual form reports its attempt before the page it generates" do
    visit root_path
    install_persistent_analytics_capture
    page.execute_script(analytics_capture_source)

    fill_in "Song title", with: "Practice Song"
    fill_in "Lyrics", with: "A line we typed ourselves"
    click_button "Generate print page"
    assert_selector "body[data-generated-page-key]"

    calls = captured_analytics_calls
    attempt = calls.index { |call| call[0] == "Manual Entry Submitted" }
    generated = calls.index { |call| call[0] == "Print Page Generated" }
    assert attempt
    assert generated
    assert_operator attempt, :<, generated
    assert_equal 1, analytics_calls_named("Manual Entry Submitted").length
    # The event names the moment; what the visitor typed stays out of it.
    refute_includes calls.to_json, "A line we typed ourselves"
    refute_includes calls.to_json, "Practice Song"
  end

  private

  def long_lyrics
    36.times.map do |stanza|
      "[Verse #{stanza + 1}]\nThis is a deliberately long line of lyrics for measuring the printed page.\nAnother line stays with its stanza."
    end.join("\n\n")
  end

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
    page.execute_script("sessionStorage.removeItem('test:umamiCalls')")
    inject_on_new_document(analytics_capture_source)
  end

  # Both destinations are stubbed before the page's own scripts run. Each one
  # keeps an existing definition — Plausible's bootstrap queues into whatever is
  # already there, and the Umami tracker only assigns `window.umami` when nothing
  # has — so the stubs survive the real scripts and no request leaves the browser.
  def analytics_capture_source
    <<~JS
      window.plausible = (...args) => {
        const key = "test:analyticsCalls"
        const calls = JSON.parse(sessionStorage.getItem(key) || "[]")
        calls.push(args)
        sessionStorage.setItem(key, JSON.stringify(calls))
      }
      window.plausible.init = () => {}
      // The tracker runs the payload function against the properties it
      // collected and sends the result, so the stub hands it the same document
      // values a real tracker would. On a saved page those are the share token
      // and the song title that the redaction exists to replace.
      window.umami = {
        track: (name) => {
          const payload = typeof name === "function"
            ? name({
                website: "test-website",
                hostname: location.hostname,
                language: "en-US",
                screen: `${screen.width}x${screen.height}`,
                title: document.title,
                url: location.href,
                referrer: document.referrer
              })
            : name
          const key = "test:umamiCalls"
          const calls = JSON.parse(sessionStorage.getItem(key) || "[]")
          calls.push(payload)
          sessionStorage.setItem(key, JSON.stringify(calls))
        }
      }
    JS
  end

  def captured_analytics_calls
    JSON.parse(page.evaluate_script("sessionStorage.getItem('test:analyticsCalls') || '[]'"))
  end

  def captured_umami_payloads
    JSON.parse(page.evaluate_script("sessionStorage.getItem('test:umamiCalls') || '[]'"))
  end

  # The tracker treats a payload with no name as a pageview and the rest as
  # custom events.
  def captured_umami_events
    captured_umami_payloads
      .select { |payload| payload["name"] }
      .map { |payload| [ payload["name"], payload ] }
  end

  def created_songbook_calls
    analytics_calls_named("Songbook Created")
  end

  # A frame reports its outcome once Turbo has finished rendering it, which can
  # be a repaint later than the text the assertions wait for, so the report is
  # waited for rather than assumed to have already happened.
  def wait_for_analytics_event(name)
    deadline = Time.now + Capybara.default_max_wait_time

    until analytics_calls_named(name).any?
      flunk "no #{name} call arrived" if Time.now > deadline
      sleep 0.05
    end
  end

  def analytics_calls_named(name)
    captured_analytics_calls.select { |call| call[0] == name }
  end
end
