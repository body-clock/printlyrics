Rails.application.routes.draw do
  root "lyrics#new"
  get "print-lyrics-on-one-page", to: "printing_guides#one_page", as: :print_lyrics_on_one_page
  get "lyrics", to: redirect("/")
  resources :lyrics, only: %i[create show], param: :token do
    collection do
      post :search
      post :select
    end
  end
  resources :songs, only: %i[index show], param: :slug do
    member do
      post :load
    end
  end
  get "sitemap", to: "sitemaps#show", defaults: { format: :xml }, as: :sitemap
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
