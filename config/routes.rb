Rails.application.routes.draw do
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
  resources :songbooks, only: %i[create show], param: :token
  delete "songbooks/:token/songs/:lyric_token",
    to: "songbooks#destroy_song",
    as: :songbook_song

  # The feedback form is a plain page and a plain POST, so it needs no resource
  # scaffolding. The page is noindex and is linked from the resource navigation.
  get "feedback", to: "feedbacks#new", as: :feedback
  post "feedback", to: "feedbacks#create", as: :submit_feedback

  get "sitemap", to: "sitemaps#show", defaults: { format: :xml }, as: :sitemap
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
