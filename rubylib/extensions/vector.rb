# Hash as sparse Vector
module SparseVector
  def normalize
    Math.sqrt(values.inject(0){|sum,e| sum + e ** 2})
  end
  
  def product(other)
    result = {}
    each do |k,v|
      result[k] = v * other[k] if v && other[k]
    end
    result
    #self.merge(other){|k,v1,v2|v1*v2}
  end
  
  def cosim(other)
    #debugger
    self.product(other).sum{|k,v|v} / (self.normalize * other.normalize)
  end
end
