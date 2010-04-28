
module Math
  MIN_PROB = 0.0000001
  MIN_NUM = -99999
  def log2(numeric)
    #raise ArgumentError if !numeric
    log(numeric) / log(2)
  end

  def log10(numeric)
    log(numeric) / log(10)
  end
  
  #Safe log
  def slog(numeric)
    (numeric > 0)? log(numeric) : (puts "[slog] arg = #{numeric}"; MIN_NUM)
  end
  
  def self.max(a, b)
    a > b ? a : b
  end

  def self.min(a, b)
    a < b ? a : b
  end
  
  def self.overlap(xy, x, y, type = :cosine)
    return 0 if xy == 0
    case type
    when :jaccard : xy.to_f / (x + y - xy )
    when :dice : 2 * xy.to_f / (x + y)
    when :overlap : xy.to_f / Math.min(x, y)
    when :cosine : xy.to_f / Math.sqrt(x * y)
    end
  end
end



class Float
  MAX_FEATURE_VALUE = 10
  
  def round_at(places)
   temp = self.to_s.length
   sprintf("%#{temp}.#{places}f",self).to_f
  end
  
  # threshold : maximum feature value
  def normalize(threshold = MAX_FEATURE_VALUE)
    new_value = Math.log(self+1) / Math.log(threshold+1)
    (new_value > 1)? 1 : new_value
  end
  
  def normalize_time()
    value_n = 1 / Math.log((self / 3600).abs+1)
    (value_n > 1)? 1 : value_n
  end

  def r3
    round_at(3)
  end

  def r1
    round_at(1)
  end

  def r2
    round_at(2)
  end
end

class Fixnum
  def round_at(places)
    self.to_f
  end
end

