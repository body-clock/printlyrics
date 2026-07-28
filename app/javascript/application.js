// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import { trackGeneratedPage, trackPageview } from "lib/analytics"

document.addEventListener("turbo:load", () => {
  trackPageview()
  trackGeneratedPage()
})
