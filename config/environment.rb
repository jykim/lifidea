# Load the rails application
require File.expand_path('../application', __FILE__)
require 'ddl_include'

# Initialize the rails application
Ddl::Application.initialize!

# App-specific initialization
TIMEZONE = 'Eastern Time (US & Canada)'
APP_ROOT = ""
CACHE = Dalli::Client.new("localhost:#{Conf.memcached_port}") #if defined? MemCache

ActiveRecord::Base.logger.level = Logger::WARN if ENV['RAILS_ENV'] == 'production'
$lgr = Rails.logger
$lgr_e = Logger.new( File.expand_path(File.dirname(__FILE__) + "/../log/#{ENV['RAILS_ENV']}_error.log") )
#debugger
