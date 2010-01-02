class SysConfig < ActiveRecord::Base
  
  def self.hour_daybreak
    @@hour_daybreak ||= Conf.hour_daybreak * 3600    
  end
end
