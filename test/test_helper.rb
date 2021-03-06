ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
#require 'ddl_include'

$lgr.level = if ARGV[0] == 'verbose' || ENV['verbose']
  Logger::DEBUG
else
  Logger::WARN
end

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all
  self.use_transactional_fixtures = true

  # Add more helper methods to be used by all tests here...
end
