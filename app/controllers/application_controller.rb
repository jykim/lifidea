class ApplicationController < ActionController::Base
  protect_from_forgery
  include AdminHelper, ItemsHelper
  layout "default_2col"
  #layout "jquery"
  #before_filter :init_controller
  helper :all # include all helpers, all the time
  #before_filter :authorize, :except => :login 

  # See ActionController::RequestForgeryProtection for details 
  # Uncomment the :secret if you're not using the cookie session store 
  #protect_from_forgery :secret => '8fc080370e56e929a2d5afca5540a0f7' 

  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters 
  # from your application log (in this case, all fields with names like "password"). 
  #filter_parameter_logging :password

protected 
  def authorize
    return true if User.all().size == 0 #|| ENV['RAILS_ENV'] != 'production'
    session[:original_uri] = request.fullpath
    unless User.find_by_id(session[:user_id]) 
      flash[:notice] = "Please log in" 
      redirect_to :controller => 'admin', :action => 'login' 
    end 
  end

  def item_concept?
    Item.find(params[:id]).concept?
  end
end
