require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1200, 900 ]

  setup do
    page.current_window.resize_to(1200, 900)
  end

  def fill_in_entry(label, with:)
    click_button "Paste" unless has_selector?("#entry-panel-paste", visible: true)
    fill_in label, with: with
  end

  def open_format
    click_button "Format", exact: true if has_button?("Format", exact: true)
  end

  def open_outline
    find(".workspace-outline summary").click unless page.evaluate_script("document.querySelector('.workspace-outline').open")
  end

  # Turbo and the preview controller legitimately replace the document shortly
  # after a load. Chrome reports a node caught in that replacement as an
  # unclassified UnknownError instead of StaleElementReferenceError, so
  # Capybara does not retry the query. Map that one message onto the stale
  # error Capybara already retries, so the assertion runs against the new DOM.
  module RetryDetachedNodes
    DETACHED_NODE = /Node with given id does not belong to the document/

    def synchronize(seconds = nil, errors: nil, &block)
      super(seconds, errors: errors) do
        begin
          block.call
        rescue Selenium::WebDriver::Error::UnknownError => error
          raise unless error.message.match?(DETACHED_NODE)

          raise Selenium::WebDriver::Error::StaleElementReferenceError, error.message
        end
      end
    end
  end

  Capybara::Node::Base.prepend(RetryDetachedNodes)

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
