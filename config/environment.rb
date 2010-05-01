# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
#RAILS_GEM_VERSION = '2.3.2' unless defined? RAILS_GEM_VERSION
TIMEZONE = 'Eastern Time (US & Canada)'
APP_ROOT = ""
# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
   #config.action_controller.session_store = ActionController::Session::PStore
  # Add additional load paths for your own custom dirs
   config.load_paths += %W( #{RAILS_ROOT}/test)
   config.logger = Logger.new(config.log_path, 10, 10 * (2 ** 20)) 
   $lgr = config.logger
  # Specify gems that this application depends on and have them installed with rake gems:install
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "sqlite3-ruby", :lib => "sqlite3"
  # config.gem "aws-s3", :lib => "aws/s3"
  #config.gem "daemon-spawn"
  #config.gem 'rcov'
  config.gem 'daemons'
  #config.gem 'pauldix-feedzirra'
  #config.gem 'yard'
  #config.gem 'openrain-action_mailer_tls'
  config.gem 'thoughtbot-shoulda', :lib => "shoulda", :source => "http://gems.github.com"
  #config.gem 'mislav-will_paginate', :version => '~> 2.3.11', :lib => 'will_paginate', 
  #  :source => 'http://gems.github.com'
  
  config.gem 'sunspot', :lib => 'sunspot'
  config.gem 'sunspot_rails', :lib => 'sunspot/rails'
  
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.delivery_method = :smtp

  # Only load the plugins named here, in the order given (default is alphabetical).
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Skip frameworks you're not going to use. To use Rails without a database,
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

  # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
  # Run "rake -D time" for a list of tasks for finding time zone names.
  config.time_zone = TIMEZONE
  #config.active_record.default_timezone = :local
  # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
  # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
  # config.i18n.default_locale = :de
end
#TagList.delimiter = " "
#ActiveRecord::Base.logger.level = :error
#$lgr = ActiveRecord::Base.logger
ActiveRecord::Base.logger.level = Logger::WARN if ENV['RAILS_ENV'] == 'production'
require 'ddl_include'
