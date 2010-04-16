load 'extensions/rails_extensions.rb'
load 'extensions/table.rb'
load 'extensions/statistics.rb'
load 'extensions/vector.rb'
load 'extensions/probability.rb'
load 'extensions/entropy.rb'
load 'extensions/string.rb'
load 'extensions/number.rb'
load 'extensions/enumerable.rb'

class MyException < Exception
  
end

class Time
  def ymdhms
    strftime('%Y%m%d%H%M%S')
  end
  
  def ymd
    strftime('%Y%m%d')
  end
end

class NilClass
  def to_hash
    {}
  end
  
  def in_time_zone(arg)
    nil
  end
end
