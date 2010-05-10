class AdminController < ApplicationController
  layout "doctrack"
  def login 
    if request.post? 
      user = User.authenticate(params[:uid], params[:password]) 
      if user 
        session[:user_id] = user.id 
        session[:user_uid] = user.uid
        session[:user_level] = user.level
        session[:admin_flag] = user.admin?
        
        uri = session[:original_uri] 
        session[:original_uri] = nil 
        redirect_to(uri || {:controller=>:items, :action => "index" })
      else 
        flash.now[:notice] = "Invalid user/password combination" 
      end 
    end 
  end 

  def logout 
    session[:user_id] = nil 
    session[:admin_flag] = nil 
    session[:user_uid] = nil 
    session[:user_level] = nil 
    session[:query_count] = nil
    flash[:notice] = "Logged out" 
    redirect_to(:action => "login") 
  end 


  def index
  end

end
