Rails.application.routes.draw do
  resource :session
  resources :registrations, only: %i[new create], path: "account"
  # OmniAuth answers the request phase at /auth/google_oauth2 itself, so only the
  # two ends it hands back are routed here.
  get "/auth/google_oauth2/callback", to: "omniauth_callbacks#create"
  get "/auth/failure", to: "omniauth_callbacks#failure"
  get "save-songbooks", to: "songbook_saving#show", as: :save_songbooks
  resources :passwords, param: :token
  get "account/songbooks", to: "account_songbooks#index", as: :account_songbooks
  # Premium access is bought through Stripe Checkout and granted by the webhook
  # that follows the payment, never by returning to a page.
  resource :premium_checkout, only: :create
  resource :billing_portal, only: :create
  post "stripe/webhook", to: "stripe_webhooks#create", as: :stripe_webhook
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
  post "songbooks/:token/share", to: "songbooks#share", as: :share_songbook
  delete "songbooks/:token/share", to: "songbooks#revoke_share", as: :revoke_songbook_share
  get "songbook-shares/:share_token", to: "songbooks#shared", as: :shared_songbook
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
