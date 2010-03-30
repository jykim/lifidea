# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include AdminHelper
  layout "default"
  before_filter :init_controller
  helper :all # include all helpers, all the time
  #before_filter :authorize, :except => :login 

  # See ActionController::RequestForgeryProtection for details 
  # Uncomment the :secret if you're not using the cookie session store 
  #protect_from_forgery :secret => '8fc080370e56e929a2d5afca5540a0f7' 

  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters 
  # from your application log (in this case, all fields with names like "password"). 
  filter_parameter_logging :password

protected 
  def authorize
    return true if User.all().size == 0 #|| ENV['RAILS_ENV'] != 'production'
    unless User.find_by_id(session[:user_id]) 
      flash[:notice] = "Please log in" 
      redirect_to :controller => 'admin', :action => 'login' 
    end 
  end
  
  def init_controller
    #error "[init_controller] initializing... #{cache_data("exists")}"
    #if !cache_data("exists")
    #  #debugger
    #  error "[init_controller] searcher initializd..."
    #  $searcher = SolrSearcher.new
    #  $searcher.open_index()
    #  cache_data("exists", "true")
    #end
  end
end
