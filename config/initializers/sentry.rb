Sentry.init do |config|
  config.dsn = "https://94e093f826a04988893f8f33eb6fd9a4@escrevezap.bugsink.com/1"
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Allow all environments to report to ensure we catch manual reporting during testing/dev if needed,
  # but Sentry defaults to only reporting when DSN is present.
  # We can also restrict environments if desired:
  config.enabled_environments = %w[production]
end
