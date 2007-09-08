# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Enable the breakpoint server that script/breakpointer connects to
config.breakpoint_server = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false
config.action_view.cache_template_extensions         = false
config.action_view.debug_rjs                         = true

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

begin
  require 'syslog_logger'
  RAILS_DEFAULT_LOGGER = SyslogLogger.new
rescue LoadError => exc
  # i guess there is no syslog_logger
end

# bundled_assets plugin:
# don't compress asset bundles (javascript and css) when in development mode.
# otherwise, they will get recompressed on every page load!
MAKE_ASSET_BUNDLES =  false
