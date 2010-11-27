require 'rubygems'
require 'active_support'
require 'shoulda'

require 'shoulda/active_record'     if defined? ActiveRecord::Base
require 'shoulda/action_controller' if defined? ActionController::Base
require 'shoulda/action_view'       if defined? ActionView::Base
require 'shoulda/action_mailer'     if defined? ActionMailer::Base

if defined?(Rails.root)
  # load in the 3rd party macros from vendorized plugins and gems
  Shoulda.autoload_macros Rails.root, File.join("vendor", "{plugins,gems}", "*")
end
