require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1200, 900 ]

  # `Page.addScriptToEvaluateOnNewDocument` scripts outlive the tab that
  # installed them, so each test removes the ones it injected.
  teardown do
    Array(@injected_scripts).each do |identifier|
      page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: identifier)
    end
  end

  # Install a script that runs before the page's own scripts on every
  # navigation in this test.
  def inject_on_new_document(source)
    result = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: source)
    @injected_scripts = Array(@injected_scripts) << result.fetch("identifier")
  end
end
