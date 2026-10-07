// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import {
  captureCampaign,
  trackCreatedSongbook,
  trackGeneratedPage,
  trackPageResponses,
  trackPageview,
  trackResponseEvents,
  trackSubmittedEvent
} from "lib/analytics"

captureCampaign()

document.addEventListener("turbo:load", () => {
  trackPageview()
  trackGeneratedPage()
  trackCreatedSongbook()
  trackPageResponses(document.body)
})

// The entry panel's own moments cannot ride turbo:load: the manual form posts a
// whole page, so its event has to fire before the navigation, and the search
// outcome arrives in a Turbo frame, which never loads the body again. Both
// markers are declared in the view beside the surface they describe. The submit
// listener captures, because Turbo's own submit observer intercepts the forms
// it handles and stops the event before a later bubble listener would see it.
document.addEventListener("submit", (event) => trackSubmittedEvent(event.target), true)
document.addEventListener("turbo:frame-load", (event) => {
  trackResponseEvents(event.target)
  // The entry panel's songbook offer arrives with a frame render as well as with
  // a whole page, so the same response is read for both kinds of marker.
  trackPageResponses(event.target)
})
