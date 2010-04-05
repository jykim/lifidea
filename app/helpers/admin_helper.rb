module AdminHelper
  def get_user_id()
    session[:user_id] || session[:session_id]
  end
end
