# Google Analytics 4 runs beside Plausible until the cutover documented in
# docs/organic-search-operations.md. The measurement ID arrives from the
# deployment environment, so a host without one renders no tag at all rather
# than a broken one. The ID is public — it is in the page source — so it belongs
# in config/deploy.yml, not in a secret.
Rails.application.config.x.google_analytics_id =
  ENV["GA_MEASUREMENT_ID"].presence || ("G-TEST000000" if Rails.env.test?)
