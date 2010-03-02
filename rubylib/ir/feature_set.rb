# Set of Features 
class FeatureSet
  MAX_FEATURE_VALUE = Math.log(10+1)
  MAX_FEATURE_VALUE2 = Math.log(100+1)
  
  def initialize(fts = {})
    @fts = fts
  end
  
  def tsim(diff_time)
    value_n = 1 / Math.log((diff_time / 3600).abs+1)
    (value_n > 1)? 1 : value_n
  end
  
  def normalize(value, threshold = MAX_FEATURE_VALUE)
    new_value = Math.log(value+1) / threshold
    (new_value > 1)? 1 : new_value
  end
  
  def set(name, value, type = nil)
    @fts[name] = case type
    when :time
      tsim(value)
    else
      normalize(value)
    end
  end
  
  def values(array)
    Vector.elements array.map{|e|@fts[e] || 0}
  end
end