module AdminHelper
  def get_user_id()
    session[:user_uid] || session[:session_id]
  end
end
