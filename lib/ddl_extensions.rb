require 'md5'
class String
  
  # Normalize string to unique ID
  def to_id
    gsub(/\s|\/|\\/,"_").downcase
  end
  
  # Convert
  def to_utc()
    Time.parse(self).utc
  end
  
  def to_localtime
    begin
      to_time(:local)
    rescue Exception => e
      self
    end
  end
  
  def to_md5()
    MD5.new(self).hexdigest
  end
end

class Date
  def to_utc()
    self.to_time.utc
  end
end

class Time
  def next_day
    tomorrow
  end
end

class Array
  def to_id
    join("#").to_id
  end
  
  # self : [[k1,v1],[k2,v2]]
  def to_hash
    map_hash{|e|e}
  end
  
  # Turn the array of feature names into values using Hash of param
  # @example
  #   self : [k1, k2, k3] / param : {k1=>v1,k2=>v2} / return : [v1,v2,def_val]
  def to_val(param, o = {})
    map{|e|param[e]||o[:def_val]}
  end
  
  # Skip the array until the target is found
  # - self : Array<ActiveRecord>
  # @param target_id <number> : id of target element
  def skip_to(target_id)
    result = [] ; target_found = false
    each{|d|
      result << d if target_found
      target_found = true if d.id == target_id
    }
    result
  end
  
  def merge_array_by_avg()
    result = [0] * self[0].size
    each{|e| e.each_with_index{|e2,i| result[i] += e2}}
    result.map{|e|e/size}
  end
end

