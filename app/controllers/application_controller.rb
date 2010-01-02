# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include AdminHelper
  layout "default"
  helper :all # include all helpers, all the time
  #before_filter :authorize, :except => :login 

  # See ActionController::RequestForgeryProtection for details 
  # Uncomment the :secret if you're not using the cookie session store 
  #protect_from_forgery :secret => '8fc080370e56e929a2d5afca5540a0f7' 

  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters 
  # from your application log (in this case, all fields with names like "password"). 
  filter_parameter_logging :password 
  
  #ActiveScaffold.set_defaults do |config| 
  #  config.ignore_columns.add [:created_at, :updated_at]
  #end
  
  # Process & log user click
  # - Add to history
  # - Add to concept occurrence (for con<->doc click)
  # - Add to concept relation (for con<->con click)
  # - Add to document relation (for doc<->doc click)
  #def process_click(params)
  #  src_item, tgt_item = params[:src_item_id].to_i, params[:id].to_i
  #  History.create(:htype=>params[:htype], :basetime=>Time.now, :src_item_id=>src_item, :item_id=>tgt_item, :user_id=>get_user_id(),
  #    :metadata=>{:position=>params[:position], :url=>request.url})
  #  Link.find_or_create(src_item, tgt_item, 'c', :add=>1)
  #end

protected 
  def authorize
    return true if User.all().size == 0 #|| ENV['RAILS_ENV'] != 'production'
    unless User.find_by_id(session[:user_id]) 
      flash[:notice] = "Please log in" 
      redirect_to :controller => 'admin', :action => 'login' 
    end 
  end 
end
