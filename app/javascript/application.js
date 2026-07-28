// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import { captureCampaign, trackGeneratedPage, trackPageview } from "lib/analytics"

captureCampaign()

document.addEventListener("turbo:load", () => {
  trackPageview()
  trackGeneratedPage()
})
