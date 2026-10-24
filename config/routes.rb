Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :registrations, only: %i[new create], path: "account"
  # OmniAuth answers the request phase at /auth/google_oauth2 itself, so only
  # the two ends it hands back are routed here.
  get "/auth/google_oauth2/callback", to: "omniauth_callbacks#create"
  get "/auth/failure", to: "omniauth_callbacks#failure"
  resources :passwords, only: %i[new create edit update], param: :token

  # An account's shelf. GET lists it, POST puts one page on it, DELETE takes one
  # off and returns that page to the anonymous retention clock.
  get "library", to: "saved_items#index", as: :library
  post "library", to: "saved_items#create", as: :saved_items
  delete "library/:id", to: "saved_items#destroy", as: :saved_item

  # The account prompt is a visit-level offer, so "not now" settles it for the
  # rest of that visit rather than leaving it to reappear on the next page.
  delete "account-prompt", to: "account_prompts#destroy", as: :account_prompt

  root "lyrics#new"
  get "print-lyrics-on-one-page", to: "printing_guides#one_page", as: :print_lyrics_on_one_page
  get "print-a-songbook", to: "printing_guides#songbook", as: :print_a_songbook
  get "lyrics", to: redirect("/")
  resources :lyrics, only: %i[create show], param: :token do
    collection do
      post :search
      post :select
    end
  end
  resources :songbooks, only: %i[create show update], param: :token
  patch "songbooks/:token/songs/:lyric_token",
    to: "songbooks#update_song",
    as: :update_songbook_song
  delete "songbooks/:token/songs/:lyric_token",
    to: "songbooks#destroy_song",
    as: :songbook_song

  # The feedback form is a plain page and a plain POST, so it needs no resource
  # scaffolding. The page is noindex and is linked from the resource navigation.
  get "feedback", to: "feedbacks#new", as: :feedback
  post "feedback", to: "feedbacks#create", as: :submit_feedback

  # The offer's "not now" is a state the next page render reads, so it is a
  # request rather than a client-side flag: the offer lives in the HTML, and a
  # dismissal only one tab knows about would come back on the next page.
  delete "songbook-offer", to: "songbook_offers#destroy", as: :songbook_offer

  get "sitemap", to: "sitemaps#show", defaults: { format: :xml }, as: :sitemap
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
