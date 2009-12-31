class AdminController < ApplicationController
  layout "doctrack"
  def login 
    if request.post? 
      user = User.authenticate(params[:uid], params[:password]) 
      if user 
        session[:user_id] = user.id 
        session[:user_uid] = user.uid
        session[:admin_flag] = user.admin?
        redirect_to(:controller=>:documents, :action => "index") 
      else 
        flash.now[:notice] = "Invalid user/password combination" 
      end 
    end 
  end 

  def logout 
    session[:user_id] = nil 
    session[:admin_flag] = nil 
    session[:user_uid] = nil 
    session[:query_count] = nil
    flash[:notice] = "Logged out" 
    redirect_to(:action => "login") 
  end 


  def index
  end

end
