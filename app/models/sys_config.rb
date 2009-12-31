class SysConfig < ActiveRecord::Base
  
  def self.hour_daybreak
    @@hour_daybreak ||= get_config("HOUR_DAYBREAK").to_i*3600    
  end
end
